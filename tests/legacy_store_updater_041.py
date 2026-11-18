#!/usr/bin/env python3
"""Atualizador da R36S ROMS STORE: canal dedicado, SHA-256, backup e rollback.

Nunca instala ROMs. A loja pode verificar/baixar enquanto roda; aplicar atualização
só é permitido depois que o LÖVE fecha e o launcher assume o controle.
"""
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import time
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

APP_ID = "r36s-roms-store"
PUBLIC_REPO = "JammesPark/R36S-ROMS-STORE-UPDATES"
FEED_URL = "https://raw.githubusercontent.com/" + PUBLIC_REPO + "/main/update.json"
VERS = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-(beta|rc))?$")
SHA = re.compile(r"^[0-9a-f]{64}$")
LEGACY_ALLOWED = frozenset((
    "R36S ROMS STORE.sh",
    APP_ID + "/game.love",
    APP_ID + "/bin/gamestore_source.py",
    APP_ID + "/bin/store_updater.py",
    APP_ID + "/LICENSE",
    APP_ID + "/THIRD_PARTY_NOTICES.txt",
    APP_ID + "/VERSION",
))
ALLOWED = LEGACY_ALLOWED | frozenset((APP_ID + "/bin/bios_manager.py",))
# 0.3.1-beta tem lista rígida de sete arquivos. 0.4.1 aceita ambos
# os formatos SEM permitir arquivos arbitrários ou destinos externos.
SUPPORTED_PACKAGES = (LEGACY_ALLOWED, ALLOWED)
MAX_DOWNLOAD = 50 * 1024 * 1024
MAX_FEED = 256 * 1024 * 1


def version_key(value):
    m = VERS.fullmatch(str(value))
    if not m:
        raise ValueError("Versão inválida")
    a, b, c = (int(n) for n in m.groups()[:3])
    phase = m.group(4)
    return a, b, c, {"beta": 0, "rc": 1, None: 2}[phase]


def digest(blob):
    return hashlib.sha256(blob).hexdigest()


def filehash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(131072), b""):
            h.update(chunk)
    return h.hexdigest()


def atomic_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp." + str(os.getpid()))
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (ValueError, OSError):
        return None


def expected_url(version):
    filename = "R36S_ROMS_STORE_v" + version + "_UPDATE.zip"
    return "https://github.com/" + PUBLIC_REPO + "/releases/download/roms-v" + version + "/" + filename


def validate_feed(info, installed):
    if not isinstance(info, dict) or info.get("status") != "published":
        return None
    version = info.get("version")
    if info.get("app") != APP_ID or info.get("channel") != "beta":
        raise ValueError("Canal ou identidade de atualização inválido")
    version_key(version)
    url = info.get("url")
    if url != expected_url(version):
        raise ValueError("Origem da atualização não autorizada")
    sha = info.get("sha256")
    if not isinstance(sha, str) or not SHA.fullmatch(sha):
        raise ValueError("SHA-256 do pacote ausente/inválido")
    size = info.get("size")
    if type(size) is not int or not 0 < size <= MAX_DOWNLOAD:
        raise ValueError("Tamanho de pacote inválido")
    if version_key(version) <= version_key(installed):
        return None
    return {k: info.get(k) for k in ("version", "url", "sha256", "size", "notes")}


def safe_zip(archive, version):
    """Confere todo arquivo, manifesto, caminhos fixos, tamanho e hash."""
    with zipfile.ZipFile(archive) as z:
        members = z.infolist()
        names = [i.filename for i in members]
        if len(names) != len(set(names)):
            raise ValueError("ZIP tem entradas duplicadas")
        paths = frozenset(names) - {"update_manifest.json"}
        if paths not in SUPPORTED_PACKAGES:
            raise ValueError("ZIP contém arquivos inesperados ou ausentes")
        for i in members:
            if stat.S_ISLNK((i.external_attr >> 16) & 0o170000) or i.is_dir():
                raise ValueError("ZIP contém links ou diretórios")
        manifest = json.loads(z.read("update_manifest.json"))
        if not isinstance(manifest, dict) or manifest.get("app") != APP_ID or manifest.get("version") != version:
            raise ValueError("Identidade/versão do manifesto divergente")
        entries = manifest.get("files")
        if not isinstance(entries, list) or {e.get("path") for e in entries if isinstance(e, dict)} != paths or len(entries) != len(paths):
            raise ValueError("Manifesto incompleto")
        for e in entries:
            path = e["path"]
            size = e.get("size")
            sha = e.get("sha256")
            if not isinstance(sha, str) or not SHA.fullmatch(sha):
                raise ValueError("SHA inválido: " + path)
            if type(size) is not int or size < 0 or size > MAX_DOWNLOAD:
                raise ValueError("Tamanho inválido: " + path)
            member = z.getinfo(path)
            if member.file_size != size:
                raise ValueError("Tamanho diverge: " + path)
            if digest(z.read(path)) != sha:
                raise ValueError("Hash inválido: " + path)
        if z.read(APP_ID + "/VERSION").decode("utf-8").strip() != version:
            raise ValueError("VERSION do aplicativo diverge")
        with zipfile.ZipFile(__import__("io").BytesIO(z.read(APP_ID + "/game.love"))) as lovezip:
            if lovezip.read("VERSION").decode("utf-8").strip() != version:
                raise ValueError("VERSION no game.love diverge")
    return paths


class Updater:
    def __init__(self, app=None):
        self.app = Path(app or Path(__file__).resolve().parents[1]).resolve()
        self.ports = self.app.parent
        if self.app.name != APP_ID or self.app.is_symlink():
            raise ValueError("Pasta da aplicação inválida")
        self.state = self.app / "state"
        self.work = self.state / "updates"
        self.status = self.state / "store_update_status.json"
        self.request = self.state / "store_update_apply.request"
        self.pending = self.work / "pending_health.json"
        self.feed = FEED_URL

    def installed(self):
        text = (self.app / "VERSION").read_text(encoding="utf-8").strip()
        version_key(text)
        return text

    def publish(self, phase, **fields):
        atomic_json(self.status, dict(phase=phase, **fields))

    def fetch(self):
        req = urllib.request.Request(self.feed, headers={"User-Agent": "R36S-ROMs-Store-Updater/1"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            if urllib.parse.urlparse(resp.url).scheme != "https":
                raise ValueError("Feed redirecionado fora de HTTPS")
            content = resp.read(MAX_FEED + 1)
        if len(content) > MAX_FEED:
            raise ValueError("Feed muito grande")
        return json.loads(content)

    def check(self):
        self.publish("checking")
        data = self.fetch()
        if not isinstance(data, dict) or data.get("status") != "published":
            self.publish("no_release")
            return None
        info = validate_feed(data, self.installed())
        if info:
            self.publish("available", **info)
        else:
            self.publish("uptodate", version=self.installed())
        return info

    def download(self):
        info = self.check()
        if not info:
            return
        self.work.mkdir(parents=True, exist_ok=True)
        filename = "R36S_ROMS_STORE_v" + info["version"] + "_UPDATE.zip"
        path = self.work / filename
        temp = self.work / (filename + ".part")
        temp.unlink(missing_ok=True)
        got = 0
        self.publish("downloading", version=info["version"], downloaded=0, expected=info["size"])
        try:
            req = urllib.request.Request(info["url"], headers={"User-Agent": "R36S-ROMs-Store-Updater/1"})
            with urllib.request.urlopen(req, timeout=40) as resp, open(temp, "wb") as f:
                if urllib.parse.urlparse(resp.url).scheme != "https":
                    raise ValueError("Download redirecionado fora de HTTPS")
                h = hashlib.sha256()
                while True:
                    block = resp.read(131072)
                    if not block:
                        break
                    got += len(block)
                    if got > info["size"] or got > MAX_DOWNLOAD:
                        raise ValueError("Download excedeu o tamanho anunciado")
                    f.write(block)
                    h.update(block)
                    if got % (1024 * 1024) < len(block):
                        self.publish("downloading", version=info["version"], downloaded=got, expected=info["size"])
                f.flush()
                os.fsync(f.fileno())
            if got != info["size"] or h.hexdigest() != info["sha256"]:
                raise ValueError("SHA-256 ou tamanho do download divergente")
            self.publish("verifying", version=info["version"])
            safe_zip(temp, info["version"])
            os.replace(temp, path)
            self.publish("ready", version=info["version"], sha256=info["sha256"], size=got,
                         notes=str(info.get("notes") or "")[:600], filename=filename)
        finally:
            temp.unlink(missing_ok=True)

    def target(self, rel):
        if rel not in ALLOWED:
            raise ValueError("Arquivo fora da aplicação")
        dest = self.ports / rel
        if rel != "R36S ROMS STORE.sh":
            try:
                dest.relative_to(self.app)
            except ValueError:
                raise ValueError("Destino fora da aplicação")
        p = dest
        while p != self.ports:
            if p.is_symlink():
                raise ValueError("Link simbólico no destino")
            p = p.parent
        return dest

    def request_apply(self):
        state = load_json(self.status)
        if not state or state.get("phase") != "ready":
            raise ValueError("Atualização não foi baixada/validada")
        atomic_json(self.request, {"version": state["version"], "sha256": state["sha256"]})

    def apply(self):
        intent = load_json(self.request)
        self.request.unlink(missing_ok=True)
        status = load_json(self.status)
        if not intent or not status or status.get("phase") != "ready":
            return False
        version = intent.get("version")
        if version != status.get("version") or intent.get("sha256") != status.get("sha256"):
            raise ValueError("Pedido de instalação diverge do download")
        if version_key(version) <= version_key(self.installed()):
            raise ValueError("A versão não é mais recente")
        path = self.work / status.get("filename", "")
        if path.name != "R36S_ROMS_STORE_v" + version + "_UPDATE.zip" or not path.is_file():
            raise ValueError("Pacote de atualização ausente")
        if filehash(path) != status["sha256"] or path.stat().st_size != status["size"]:
            raise ValueError("Pacote alterado após download")
        paths = safe_zip(path, version)
        # Não permitir uma segunda atualização enquanto existe rollback pendente.
        if self.pending.exists():
            raise ValueError("Existe uma atualização aguardando validação")
        stamp = "backup-" + str(time.time_ns()) + "-" + str(os.getpid())
        backup = self.work / stamp
        backup.mkdir(parents=True, exist_ok=False)
        existing = []
        added = []
        try:
            with zipfile.ZipFile(path) as z:
                # Fazer TODOS os backups antes de alterar qualquer arquivo.
                for rel in sorted(paths):
                    dst = self.target(rel)
                    if dst.exists():
                        if not dst.is_file():
                            raise ValueError("Destino não é arquivo")
                        old = backup / rel
                        old.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(dst, old)
                        existing.append(rel)
                    else:
                        added.append(rel)
                meta = {"version": version, "existing": existing, "added": added, "backup": stamp}
                atomic_json(backup / "metadata.json", meta)
                atomic_json(self.pending, meta)
                for rel in sorted(paths):
                    dst = self.target(rel)
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    tmp = dst.with_name(dst.name + ".store_update_new")
                    with open(tmp, "wb") as f:
                        f.write(z.read(rel))
                        f.flush()
                        os.fsync(f.fileno())
                    os.chmod(tmp, 0o755 if rel.endswith(".sh") else 0o644)
                    os.replace(tmp, dst)
            self.publish("installed", version=version)
            return True
        except Exception:
            self.rollback()
            raise

    def rollback(self):
        meta = load_json(self.pending)
        if not meta:
            return False
        name = meta.get("backup")
        if not isinstance(name, str) or not re.fullmatch(r"backup-[0-9]+-[0-9]+", name):
            raise ValueError("Backup inválido")
        backup = self.work / name
        for rel in meta.get("added", []):
            self.target(rel).unlink(missing_ok=True)
        for rel in meta.get("existing", []):
            dst = self.target(rel)
            source = backup / rel
            if not source.is_file() or source.is_symlink():
                raise ValueError("Backup incompleto: " + rel)
            tmp = dst.with_name(dst.name + ".store_update_restore")
            shutil.copy2(source, tmp)
            os.replace(tmp, dst)
        self.pending.unlink(missing_ok=True)
        self.publish("rolled_back", version=self.installed())
        return True

    def confirm(self):
        meta = load_json(self.pending)
        if meta:
            self.pending.unlink(missing_ok=True)
            self.publish("installed", version=self.installed())
        return bool(meta)


def main(argv):
    if len(argv) != 2 or argv[1] not in ("check", "download", "apply", "rollback", "confirm", "recover"):
        raise SystemExit("Uso: store_updater.py check|download|apply|rollback|confirm|recover")
    task = argv[1]
    updater = Updater()
    try:
        if task == "check":
            updater.check()
        elif task == "download":
            updater.download()
        elif task == "apply":
            updater.apply()
        elif task == "rollback":
            updater.rollback()
        elif task == "recover" and updater.pending.exists():
            updater.rollback()
        elif task == "confirm":
            updater.confirm()
        return 0
    except Exception as e:
        updater.publish("error", message=str(e)[:240])
        print("Atualizador:", str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
