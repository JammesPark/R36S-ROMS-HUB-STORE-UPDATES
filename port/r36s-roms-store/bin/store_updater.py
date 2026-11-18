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
BRIDGE_ALLOWED = LEGACY_ALLOWED | frozenset((APP_ID + "/bin/bios_manager.py",))
# Lista FECHADA: o bootstrap inicial utiliza oito arquivos para alcançar até
# consoles com atualizador 0.4.1-beta. Os próximos OTA usam o conjunto completo.
ALLOWED = BRIDGE_ALLOWED | frozenset((
    APP_ID + "/bin/es_theme_manager.py",
    APP_ID + "/bin/es_themes_seed.json",
    APP_ID + "/bin/fetch.sh",
    APP_ID + "/bin/7zzs",
))
SUPPORTED_PACKAGES = (LEGACY_ALLOWED, BRIDGE_ALLOWED, ALLOWED)
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


def expected_delta_url(version):
    return expected_url(version).replace('_UPDATE.zip', '_UPDATE_DELTA.zip')


def valid_package(info, prefix, version, url_expected):
    url = info.get(prefix + "url")
    sha = info.get(prefix + "sha256")
    size = info.get(prefix + "size")
    return (url == url_expected and isinstance(sha, str) and bool(SHA.fullmatch(sha))
            and type(size) is int and 0 < size <= MAX_DOWNLOAD)


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
    result = {k: info.get(k) for k in ("version", "url", "sha256", "size", "notes")}
    result["kind"] = "full"
    # O URL legado sempre aponta ao UPDATE completo. Delta é opcional e apenas
    # para uma versão-base exata. Clientes mais antigos ignoram esses campos.
    if valid_package(info, "incremental_", version, expected_delta_url(version)):
        base_min = info.get("incremental_min_version")
        base_max = info.get("incremental_max_version")
        if base_min == base_max == installed and version_key(version) > version_key(installed):
            result.update(url=info["incremental_url"], sha256=info["incremental_sha256"],
                          size=info["incremental_size"], kind="incremental")
    return result


def safe_zip(archive, version, installed=None):
    """Confere todo arquivo, manifesto, caminhos fixos, tamanho e hash."""
    with zipfile.ZipFile(archive) as z:
        members = z.infolist()
        names = [i.filename for i in members]
        if len(names) != len(set(names)):
            raise ValueError("ZIP tem entradas duplicadas")
        paths = frozenset(names) - {"update_manifest.json"}
        manifest = json.loads(z.read("update_manifest.json"))
        kind = manifest.get("type", "full") if isinstance(manifest, dict) else None
        if kind == "full":
            if paths not in SUPPORTED_PACKAGES:
                raise ValueError("ZIP completo contém arquivos inesperados ou ausentes")
        elif kind == "incremental":
            must = frozenset((APP_ID + "/VERSION", APP_ID + "/game.love"))
            if not (must <= paths <= ALLOWED) or len(paths) > len(ALLOWED):
                raise ValueError("Delta contém arquivos fora da lista autorizada")
            base_min, base_max = manifest.get("min_version"), manifest.get("max_version")
            if not isinstance(base_min, str) or not base_min == base_max:
                raise ValueError("Delta sem versão-base única")
            version_key(base_min)
            if version_key(base_min) >= version_key(version):
                raise ValueError("Versão-base do delta inválida")
            if installed is not None and base_min != installed:
                raise ValueError("Delta incompatível com a versão instalada")
        else:
            raise ValueError("Tipo de atualização desconhecido")
        for i in members:
            if stat.S_ISLNK((i.external_attr >> 16) & 0o170000) or i.is_dir():
                raise ValueError("ZIP contém links ou diretórios")
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
        self.history_file = self.work / "history.json"
        self.backups_index = self.work / "backups.json"
        self.local_index = self.work / "local_packages.json"

    def installed(self):
        text = (self.app / "VERSION").read_text(encoding="utf-8").strip()
        version_key(text)
        return text

    def publish(self, phase, **fields):
        atomic_json(self.status, dict(phase=phase, **fields))

    def history(self):
        rows = load_json(self.history_file)
        return rows if isinstance(rows, list) else []

    def add_history(self, event, **info):
        rows = self.history()
        rows.append({"event": event, "time": int(time.time()), **info})
        atomic_json(self.history_file, rows[-100:])

    def list_backups(self):
        result = []
        for path in self.work.glob("backup-*") if self.work.is_dir() else ():
            if not path.is_dir() or path.is_symlink() or not re.fullmatch(r"backup-[0-9]+-[0-9]+", path.name):
                continue
            item = load_json(path / "metadata.json")
            if not isinstance(item, dict) or item.get("backup") != path.name:
                continue
            existing, added = item.get("existing"), item.get("added")
            if (not isinstance(existing, list) or not isinstance(added, list)
                    or any(x not in ALLOWED for x in existing + added)):
                continue
            if any(not (path / x).is_file() or (path / x).is_symlink() for x in existing):
                continue
            result.append({"id": path.name, "from": item.get("from_version", "?"),
                           "to": item.get("version", "?"), "created": item.get("created", 0),
                           "files": len(existing) + len(added)})
        result.sort(key=lambda x: x["id"], reverse=True)
        return result

    def list_backups_to_disk(self):
        atomic_json(self.backups_index, self.list_backups())

    def prune_backups(self, keep=3):
        active = load_json(self.pending) or {}
        pinned = active.get("backup")
        kept = 0
        for item in self.list_backups():
            if item["id"] == pinned:
                continue
            kept += 1
            if kept > keep:
                shutil.rmtree(self.work / item["id"])
        self.list_backups_to_disk()

    def delete_backup(self, name):
        if not isinstance(name, str) or not re.fullmatch(r"backup-[0-9]+-[0-9]+", name):
            raise ValueError("Backup inválido")
        if (load_json(self.pending) or {}).get("backup") == name:
            raise ValueError("Backup em uso não pode ser excluído")
        if name not in {x["id"] for x in self.list_backups()}:
            raise ValueError("Backup ausente ou incompleto")
        shutil.rmtree(self.work / name)
        self.add_history("deleted_backup", backup=name)
        self.list_backups_to_disk()

    def scan_local(self):
        inbox = self.work / "inbox"
        results = []
        if inbox.exists() and not inbox.is_symlink():
            for entry in sorted(inbox.glob("R36S_ROMS_STORE_v*_UPDATE.zip"))[:30]:
                if not entry.is_file() or entry.is_symlink() or entry.stat().st_size > MAX_DOWNLOAD:
                    continue
                m = re.fullmatch(r"R36S_ROMS_STORE_v(.+)_UPDATE.zip", entry.name)
                try:
                    if not m or version_key(m.group(1)) <= version_key(self.installed()):
                        continue
                    safe_zip(entry, m.group(1), installed=self.installed())
                    results.append({"name": entry.name, "version": m.group(1),
                                    "size": entry.stat().st_size})
                except (ValueError, KeyError, zipfile.BadZipFile, OSError):
                    pass
        atomic_json(self.local_index, results)
        return results

    def local(self, name):
        entries = {x["name"]: x for x in self.scan_local()}
        if name not in entries:
            raise ValueError("Pacote local não autorizado")
        data = entries[name]
        src = self.work / "inbox" / name
        target = self.work / name
        shutil.copy2(src, target)
        sha = filehash(target)
        safe_zip(target, data["version"], installed=self.installed())
        self.publish("ready", version=data["version"], filename=name,
                     sha256=sha, size=data["size"], notes="Pacote local validado")

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
        filename = "R36S_ROMS_STORE_v" + info["version"] + (
            "_UPDATE_DELTA.zip" if info["kind"] == "incremental" else "_UPDATE.zip")
        path = self.work / filename
        temp = self.work / (filename + ".part")
        temp.unlink(missing_ok=True)
        got = 0
        self.publish("downloading", version=info["version"], downloaded=0,
                     expected=info["size"], kind=info["kind"])
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
            safe_zip(temp, info["version"], installed=self.installed())
            os.replace(temp, path)
            self.publish("ready", version=info["version"], sha256=info["sha256"], size=got,
                         notes=str(info.get("notes") or "")[:600], filename=filename,
                         kind=info["kind"])
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
        if isinstance(intent, dict) and intent.get("action") == "restore":
            return self.restore_backup(intent.get("backup"))
        if not intent or not status or status.get("phase") != "ready":
            return False
        version = intent.get("version")
        if version != status.get("version") or intent.get("sha256") != status.get("sha256"):
            raise ValueError("Pedido de instalação diverge do download")
        if version_key(version) <= version_key(self.installed()):
            raise ValueError("A versão não é mais recente")
        path = self.work / status.get("filename", "")
        if path.name not in ("R36S_ROMS_STORE_v" + version + "_UPDATE.zip",
                             "R36S_ROMS_STORE_v" + version + "_UPDATE_DELTA.zip") or not path.is_file():
            raise ValueError("Pacote de atualização ausente")
        if filehash(path) != status["sha256"] or path.stat().st_size != status["size"]:
            raise ValueError("Pacote alterado após download")
        paths = safe_zip(path, version, installed=self.installed())
        # Não permitir uma segunda atualização enquanto existe rollback pendente.
        if self.pending.exists():
            raise ValueError("Existe uma atualização aguardando validação")
        from_version = self.installed()
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
                meta = {"version": version, "from_version": from_version,
                        "created": int(time.time()), "existing": existing,
                        "added": added, "backup": stamp}
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
                    os.chmod(tmp, 0o755 if (rel.endswith(".sh") or rel.endswith("/bin/7zzs")) else 0o644)
                    os.replace(tmp, dst)
            self.publish("installed", version=version)
            self.add_history("installed", source=from_version, target=version,
                             package=path.name, backup=stamp)
            self.list_backups_to_disk()
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
        self.add_history("rolled_back", version=self.installed(), backup=name)
        self.list_backups_to_disk()
        self.publish("rolled_back", version=self.installed())
        return True

    def restore_backup(self, name):
        if not isinstance(name, str) or name not in {x["id"] for x in self.list_backups()}:
            raise ValueError("Backup não encontrado")
        if self.pending.exists():
            raise ValueError("Já existe uma atualização pendente")
        source = self.work / name
        selected = load_json(source / "metadata.json")
        files = selected["existing"]
        remove = selected["added"]
        for rel in files:
            self.target(rel)
            if not (source / rel).is_file() or (source / rel).is_symlink():
                raise ValueError("Backup incompleto")
        for rel in remove:
            self.target(rel)
        previous = self.installed()
        stamp = "backup-" + str(time.time_ns()) + "-" + str(os.getpid())
        current = self.work / stamp
        current.mkdir(parents=True)
        have, added = [], []
        try:
            for rel in sorted(set(files + remove)):
                dst = self.target(rel)
                if dst.exists():
                    if not dst.is_file():
                        raise ValueError("Destino inválido")
                    save = current / rel
                    save.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(dst, save)
                    have.append(rel)
                else:
                    added.append(rel)
            meta = {"version": selected.get("from_version", "?"),
                    "from_version": previous, "created": int(time.time()),
                    "existing": have, "added": added, "backup": stamp}
            atomic_json(current / "metadata.json", meta)
            atomic_json(self.pending, meta)
            for rel in files:
                dst = self.target(rel)
                tmp = dst.with_name(dst.name + ".store_restore_new")
                shutil.copy2(source / rel, tmp)
                os.replace(tmp, dst)
            for rel in remove:
                self.target(rel).unlink(missing_ok=True)
            restored = self.installed()
            self.add_history("restored", source=previous, target=restored, backup=name)
            self.publish("installed", version=restored)
            return True
        except Exception:
            self.rollback()
            raise

    def confirm(self):
        meta = load_json(self.pending)
        if meta:
            self.pending.unlink(missing_ok=True)
            self.add_history("confirmed", version=self.installed())
            self.prune_backups()
            self.publish("installed", version=self.installed())
        return bool(meta)


def main(argv):
    if len(argv) < 2 or argv[1] not in ("check", "download", "apply", "rollback", "confirm", "recover", "list", "scan_local", "local", "delete"):
        raise SystemExit("Uso: store_updater.py check|download|apply|rollback|confirm|recover|list|scan_local|local|delete")
    if (argv[1] in ("local", "delete") and len(argv) != 3) or (argv[1] not in ("local", "delete") and len(argv) != 2):
        raise SystemExit("Parâmetros inválidos")
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
        elif task == "list":
            updater.list_backups_to_disk()
        elif task == "scan_local":
            updater.scan_local()
        elif task == "local":
            updater.local(argv[2])
        elif task == "delete":
            updater.delete_backup(argv[2])
        return 0
    except Exception as e:
        updater.publish("error", message=str(e)[:240])
        print("Atualizador:", str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
