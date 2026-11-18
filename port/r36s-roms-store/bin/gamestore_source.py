#!/usr/bin/env python3
"""Adaptador independente para o catálogo remoto usado pelo GameStoreBR.
Não importa nem redistribui o aplicativo/arquivos enviados pelo usuário.
Sem instalação/executável automático: ROMs são baixadas como arquivo no SD.
"""
import hashlib
import ipaddress
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_PATH = "/getgames.php"
API_HOST = "r36swiki.com"
ALLOWED = frozenset("""3do amigacd32 atari2600 nes snes gba gb gbc psx mame neogeo
ports megadrive genesis n64 nds psp dreamcast saturn pcengine mastersystem
gamegear""".split())
CATEGORY_ALIAS = {"genesis": "megadrive"}
MAX_JSON = 3 * 1024 * 1024
MAX_DOWNLOAD = 16 * 1024**3
MAX_COVER_BYTES = 700 * 1024
HOME = os.environ.get("R36S_STORE_HOME", "/roms/ports/r36s-roms-store")
STATE = os.path.join(HOME, "state")
STATUS = os.path.join(STATE, "gamestore_status.json")
LOCK = os.path.join(STATE, "gamestore.lock")

def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp." + str(os.getpid())
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)

def status(phase, message, **extra):
    save_json(STATUS, {"phase": phase, "message": message, **extra})

def category_name(raw):
    raw = str(raw or "").lower()
    if raw == "all":
        return "ALL"
    if raw not in ALLOWED:
        raise ValueError("Plataforma não permitida: " + raw)
    return CATEGORY_ALIAS.get(raw, raw)

def safe_url(raw, *, allow_http=False):
    url = urllib.parse.urlsplit(str(raw))
    if url.scheme not in (("http", "https") if allow_http else ("https",)):
        raise ValueError("Endereço não permitido")
    if not url.hostname or url.username or url.password:
        raise ValueError("Host inválido")
    hostname = url.hostname.lower()
    if hostname in ("localhost",) or hostname.endswith(".local"):
        raise ValueError("Host privado")
    try:
        ip = ipaddress.ip_address(hostname)
        if not ip.is_global:
            raise ValueError("Host privado")
    except ValueError as exc:
        if str(exc) == "Host privado":
            raise
    return urllib.parse.urlunsplit(url)

class NoLocalRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        safe_url(newurl, allow_http=True)
        return super().redirect_request(req, fp, code, msg, headers, newurl)

OPENER = urllib.request.build_opener(NoLocalRedirect())

def load_api(action, **params):
    qs = urllib.parse.urlencode({"action": action, **params})
    last = None
    for proto in ("https", "http"):
        url = f"{proto}://{API_HOST}{API_PATH}?{qs}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "R36S-ROMs-Store/0.2.3"})
            with OPENER.open(req, timeout=22) as r:
                raw = r.read(MAX_JSON + 1)
                if len(raw) > MAX_JSON:
                    raise ValueError("Resposta grande demais")
                data = json.loads(raw.decode("utf-8"))
                if isinstance(data, dict) and (data.get("maintenance") is True or
                  str(data.get("status", "")).lower() in ("maintenance", "manutencao", "manutenção")):
                    raise RuntimeError("maintenance")
                if not isinstance(data, dict) or data.get("success") is not True:
                    raise ValueError("API indisponível ou resposta inválida")
                return data
        except (OSError, urllib.error.URLError, ValueError) as exc:
            last = exc
            # O aplicativo GameStoreBR enviado usa HTTP; aceita fallback somente
            # para esse host, sem executar qualquer conteúdo recebido.
    raise RuntimeError("GameStoreBR indisponível: " + str(last))

def categories():
    data = load_api("categories")
    result = [{"category": "ALL", "count": 0}]
    total = 0
    for entry in data.get("categories", [])[:80]:
        if not isinstance(entry, dict):
            continue
        try:
            cat = category_name(entry.get("category"))
            if cat == "ALL":
                continue
        except ValueError:
            continue
        count = max(0, int(entry.get("count", 0) or 0))
        total += count
        result.append({"category": cat, "count": count})
    result[0]["count"] = total
    save_json(os.path.join(STATE, "gamestore_categories.json"), {"categories": result})
    status("done", "Categorias GameStoreBR carregadas", task="categories", count=len(result))

def validated_games(data, cat):
    """Sanitizacao compartilhada por listagem e pesquisa remota."""
    clean = []
    for entry in data.get("games", [])[:30]:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("name") or "").strip()[:160]
        path = str(entry.get("game_path") or "").strip()
        raw_category = entry.get("category", "ports" if cat == "ALL" else cat)
        try:
            platform = category_name(raw_category)
        except ValueError:
            continue
        if platform == "ALL" or not name or not path:
            continue
        if not (path.startswith("http://") or path.startswith("https://")):
            path = urllib.parse.urljoin("http://"+API_HOST+"/", path.lstrip("/"))
        try:
            safe_url(path, allow_http=True)
        except ValueError:
            continue
        image_url = str(entry.get("image_url") or "")[:400]
        try:
            safe_url(image_url, allow_http=True)
            cover_id = hashlib.sha1(image_url.encode("utf-8")).hexdigest()
        except ValueError:
            image_url, cover_id = "", ""
        clean.append({"name": name, "category": platform, "game_path": path,
                      "image_url": image_url, "cover_id": cover_id})
    return clean


def search_games(query, page):
    """Usa action=search do catalogo, nao apenas a pagina de 10 itens carregados."""
    query = str(query or "").strip()
    if len(query) < 2 or len(query) > 80 or any(ord(c)<32 for c in query):
        raise ValueError("Busca deve ter entre 2 e 80 caracteres")
    page = int(page)
    if not 1 <= page <= 100000:
        raise ValueError("Pagina de busca invalida")
    data = load_api("search", search=query, page=page, limit=10)
    clean = validated_games(data, "ALL")
    out = {"games": clean, "query": query, "page": page,
           "total_pages": max(1, int(data.get("total_pages", 1) or 1)),
           "total": max(0, int(data.get("total", 0) or 0))}
    save_json(os.path.join(STATE, "gamestore_search.json"), out)
    status("done", f"{len(clean)} resultados para {query[:32]}", task="search", page=page)


def games(category, page):
    cat = category_name(category)
    page = int(page)
    if not 1 <= page <= 100000:
        raise ValueError("Página inválida")
    params = {"page": page, "limit": 10}
    if cat != "ALL":
        params["category"] = cat
    data = load_api("games", **params)
    clean = validated_games(data, cat)
    out = {"games": clean, "category": cat, "page": page,
           "total_pages": max(1,int(data.get("total_pages", 1) or 1)),
           "total": max(0,int(data.get("total", 0) or 0))}
    save_json(os.path.join(STATE, "gamestore_games.json"), out)
    status("done", f"{len(clean)} jogos recebidos: {cat}", task="games", page=page)

def target_root(sd):
    if sd not in ("sd1", "sd2"):
        raise ValueError("Cartão inválido")
    base = "/roms" if sd == "sd1" else "/roms2"
    if not os.path.isdir(base) or os.path.islink(base):
        raise ValueError("Cartão não montado")
    if sd == "sd2":
        a = subprocess.check_output(["findmnt", "-T", "/roms", "-no", "SOURCE"], text=True).strip()
        b = subprocess.check_output(["findmnt", "-T", "/roms2", "-no", "SOURCE"], text=True).strip()
        if not a or not b or a == b:
            raise ValueError("SD2 não está montado separadamente")
    return base

def rom_filename(url):
    """Nome seguro, igual para inspeção, download e exclusão."""
    url = safe_url(url, allow_http=True)
    basename = urllib.parse.unquote(urllib.parse.urlsplit(url).path.rsplit("/", 1)[-1])
    basename = re.sub(r"[^a-zA-Z0-9_. ()-]", "_", basename).strip(" .")[:160]
    if basename in ("", ".", ".."):
        raise ValueError("Nome de ROM inválido")
    return basename


def rom_destination(url, category, sd):
    folder = category_name(category)
    if folder == "ALL":
        raise ValueError("Categoria inválida")
    base = target_root(sd)
    dest = os.path.join(base, folder)
    if os.path.islink(dest):
        raise ValueError("Pasta de ROM é um link simbólico")
    basename = rom_filename(url)
    final = os.path.join(dest, basename)
    if os.path.commonpath([os.path.abspath(final), os.path.abspath(base)]) != os.path.abspath(base):
        raise ValueError("Destino fora do cartão")
    return folder, dest, basename, final


def load_manifests():
    path = os.path.join(STATE, "roms_downloads.json")
    try:
        with open(path, encoding="utf-8") as file:
            records = json.load(file)
            return records if isinstance(records, list) else []
    except (OSError, ValueError):
        return []


def inspect_rom(url, category, sd):
    url = safe_url(url, allow_http=True)
    folder, dest, basename, final = rom_destination(url, category, sd)
    if os.path.lexists(final) and (os.path.islink(final) or not os.path.isfile(final)):
        raise ValueError("Destino ocupado por um item incompatível")
    found = os.path.isfile(final)
    managed = any(isinstance(d, dict) and d.get("game_path")==url and
                  d.get("card")==sd and d.get("category")==folder and
                  d.get("filename")==basename for d in load_manifests())
    status("done", "ROM já existe" if found else "Local livre", task="inspect",
           exists=found, managed=managed, filename=basename, card=sd)


def remove_rom(url, category, sd, filename):
    """Exclusão só de ROM registrada no histórico; jamais apaga saves/pastas."""
    url=safe_url(url, allow_http=True)
    folder, dest, basename, final=rom_destination(url, category, sd)
    if filename != basename:
        raise ValueError("Nome da ROM não corresponde ao registro")
    records=load_manifests()
    matches=[d for d in records if isinstance(d,dict) and
             d.get("game_path")==url and d.get("card")==sd and
             d.get("category")==folder and d.get("filename")==basename]
    if len(matches)!=1:
        raise ValueError("Exclusão permitida apenas para ROM gerenciada")
    record=matches[0]
    if os.path.islink(dest) or os.path.islink(final):
        raise ValueError("Links não são removidos")
    if os.path.lexists(final):
        if not os.path.isfile(final):
            raise ValueError("O destino não é um arquivo regular")
        expected_size=record.get("size")
        if isinstance(expected_size,int) and os.path.getsize(final)!=expected_size:
            raise ValueError("Arquivo alterado desde o download; exclusão bloqueada")
        digest=record.get("sha256")
        if isinstance(digest,str) and re.fullmatch(r"[a-fA-F0-9]{64}",digest):
            sha=hashlib.sha256()
            with open(final,"rb") as stream:
                for block in iter(lambda:stream.read(1024*1024),b""):
                    sha.update(block)
            if sha.hexdigest().lower()!=digest.lower():
                raise ValueError("Conteúdo alterado; exclusão bloqueada")
        os.unlink(final)
    kept=[d for d in records if d is not record]
    save_json(os.path.join(STATE,"roms_downloads.json"),kept)
    status("done", "ROM removida do cartão e do histórico", task="remove", card=sd)


def download(url, category, sd, name, checksum="", overwrite="0"):
    url = safe_url(url, allow_http=True)
    folder, dest, basename, final = rom_destination(url, category, sd)
    replace = overwrite == "1"
    if overwrite not in ("0", "1"):
        raise ValueError("Permissão de sobrescrita inválida")
    if os.path.lexists(final):
        if os.path.islink(final) or not os.path.isfile(final):
            raise ValueError("O destino não é um arquivo regular")
        if not replace:
            raise ValueError("Arquivo já existe: confirme a sobrescrita no aplicativo")
    os.makedirs(dest, exist_ok=True)
    if checksum and not re.fullmatch(r"[a-fA-F0-9]{64}", checksum):
        raise ValueError("SHA-256 inválido")
    temp = os.path.join(dest, f".roms-{os.getpid()}-{basename}.part")
    if os.path.lexists(temp):
        raise ValueError("Download temporário já existe")
    digest = hashlib.sha256()
    count = 0
    try:
        status("downloading", f"Baixando {name[:60]} para {sd.upper()}", task="download")
        req = urllib.request.Request(url, headers={"User-Agent": "R36S-ROMs-Store/0.2.3"})
        with OPENER.open(req, timeout=40) as response:
            expected = int(response.headers.get("Content-Length") or 0)
            if expected > MAX_DOWNLOAD:
                raise ValueError("Arquivo excede o limite")
            with open(temp, "xb") as out:
                while True:
                    block = response.read(256 * 1024)
                    if not block:
                        break
                    count += len(block)
                    if count > MAX_DOWNLOAD:
                        raise ValueError("Download grande demais")
                    out.write(block)
                    digest.update(block)
                    if count % (1024*1024) < len(block):
                        status("downloading", f"Baixando {name[:60]}", task="download",
                               downloaded=count, expected=expected)
                out.flush()
                os.fsync(out.fileno())
        if count == 0 or (expected and expected != count):
            raise ValueError("Download vazio ou incompleto")
        actual = digest.hexdigest()
        if checksum and actual.lower() != checksum.lower():
            raise ValueError("SHA-256 não confere")
        # Substituição somente após confirmação explícita no aplicativo.
        # A transferência ocorre em arquivo temporário e é validada antes da troca.
        if os.path.lexists(final):
            if os.path.islink(final) or not os.path.isfile(final) or not replace:
                raise ValueError("Destino ocupado ou sobrescrita não autorizada")
        os.replace(temp, final)
        # Manifesto propio da ROM para identificar SD1/SD2 em Favoritos.
        manifest = os.path.join(STATE, "roms_downloads.json")
        records = load_manifests()
        records = [item for item in records if not
                   (isinstance(item,dict) and item.get("game_path") == url and item.get("card") == sd)]
        records.append({"name": name[:160], "category": folder,
                        "game_path": url, "card": sd, "filename": basename,
                        "sha256": actual, "size": count, "time": int(time.time())})
        save_json(manifest, records[-2000:])
        status("done", f"Salvo em {folder}/{basename} ({sd.upper()})",
               task="download", downloaded=count, sha256=actual,
               verified=bool(checksum))
    finally:
        if os.path.exists(temp):
            os.remove(temp)


def covers(source="games"):
    """Cache opt-in de imagens do catalogo sem bloquear o fluxo de downloads."""
    data_path = os.path.join(STATE, "gamestore_search.json" if source == "search" else "gamestore_games.json")
    try:
        with open(data_path, encoding="utf-8") as f:
            records = json.load(f).get("games", [])
    except (OSError, ValueError):
        return
    folder = os.path.join(STATE, "covers")
    os.makedirs(folder, exist_ok=True)
    for record in records[:10]:
        url = str(record.get("image_url") or "")
        cover_id = str(record.get("cover_id") or "")
        if not re.fullmatch(r"[a-f0-9]{40}", cover_id):
            continue
        if hashlib.sha1(url.encode("utf-8")).hexdigest() != cover_id:
            continue
        path = os.path.join(folder, cover_id + ".img")
        if os.path.isfile(path):
            continue
        temp = path + ".tmp." + str(os.getpid())
        try:
            safe_url(url, allow_http=True)
            req = urllib.request.Request(url,
                  headers={"User-Agent": "Mozilla/5.0 (R36S ROMS STORE cover cache)"})
            with OPENER.open(req, timeout=7) as response:
                data = response.read(MAX_COVER_BYTES + 1)
            # Love2D aceita JPEG/PNG; nunca carregamos outros formatos como imagem.
            if (len(data) < 30 or len(data) > MAX_COVER_BYTES or
                not (data.startswith(b"\x89PNG\r\n\x1a\n") or
                     data.startswith(b"\xff\xd8\xff"))):
                continue
            with open(temp, "xb") as out:
                out.write(data)
            os.replace(temp, path)
        except (OSError, ValueError, urllib.error.URLError):
            pass
        finally:
            if os.path.exists(temp):
                os.remove(temp)

def run(args):
    os.makedirs(STATE, exist_ok=True)
    if args and args[0] == "covers":
        # Capa é cache opcional, não utiliza lock/status do download.
        covers(args[1] if len(args)>1 else "games")
        return
    os.mkdir(LOCK)
    try:
        if args[0] == "categories":
            status("loading", "Consultando categorias", task="categories")
            categories()
        elif args[0] == "games":
            status("loading", "Consultando jogos", task="games")
            games(args[1], args[2])
        elif args[0] == "search":
            status("loading", "Pesquisando ROMs", task="search")
            search_games(args[1], args[2])
        elif args[0] == "download":
            download(*args[1:])
        elif args[0] == "inspect":
            inspect_rom(*args[1:])
        elif args[0] == "remove":
            remove_rom(*args[1:])
        else:
            raise ValueError("Comando não identificado")
    finally:
        os.rmdir(LOCK)

if __name__ == "__main__":
    try:
        run(sys.argv[1:])
    except Exception as exc:
        status("error", str(exc)[:220], task=sys.argv[1] if len(sys.argv)>1 else "")
        sys.exit(1)
