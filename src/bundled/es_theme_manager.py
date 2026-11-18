#!/usr/bin/env python3
"""R36S ROMS STORE: catálogo/instalador de temas EmulationStation.
Adaptado às fontes da galeria ThemeMaster; não executa código dos ZIPs.
Fonte: Jetup13/Emulationstation-OGA-Theme-Gallery, ThemeMaster e metadados
GPL-3.0 do projeto R36SPORTSBR STORE. Sem arquivos de BIOS/jogos incluídos.
"""
import json, os, re, sys, time, zipfile, shutil, stat, tempfile, pathlib, urllib.request

APP = pathlib.Path(os.environ.get('R36S_STORE_HOME', '/roms/ports/r36s-roms-store')).resolve()
STATE = APP / 'state'
SEED = APP / 'bin' / 'es_themes_seed.json'
CACHE = STATE / 'es_theme_catalog.json'
RESULT = STATE / 'es_theme_status.json'
GALLERY = 'https://raw.githubusercontent.com/Jetup13/Emulationstation-OGA-Theme-Gallery/main/README.md'
RES = ('480x320', '640x480', '854x480', '960x544', '720x720')
COLLECTIONS = ('Jetup13', 'CodyV59', 'farfenkugell', 'EmuELEC', 'RetroPie')
MAX_NET = 8 * 1024 * 1024
MAX_ZIP = 200 * 1024 * 1024
MAX_EXPANDED = 650 * 1024 * 1024
MAX_FILES = 20000


def read_json(path, default):
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
        return data if isinstance(data, (dict, list)) else default
    except (OSError, UnicodeError, ValueError):
        return default


def atomic_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp')
    with temp.open('w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, separators=(',', ':'))
    os.replace(temp, path)


def output(phase, message, **kwargs):
    atomic_json(RESULT, {'phase': phase, 'message': str(message)[:260], 'time': time.time(), **kwargs})


def get_url(url, limit=MAX_NET):
    req = urllib.request.Request(url, headers={'User-Agent': 'R36S-ROM-Store/0.4.3 (+ThemeMaster-gallery)', 'Accept': 'application/json,text/plain,*/*'})
    with urllib.request.urlopen(req, timeout=20) as r:
        chunks, total = [], 0
        while True:
            block = r.read(65536)
            if not block:
                break
            total += len(block)
            if total > limit:
                raise ValueError('Fonte excede limite de tamanho')
            chunks.append(block)
        return b''.join(chunks)


def download_to_file(url, dest, limit=MAX_ZIP):
    """Stream ZIP archives to disk to fit handheld devices with small RAM."""
    if not isinstance(url, str) or not url.startswith('https://'):
        raise ValueError('Download exige HTTPS')
    req = urllib.request.Request(url, headers={'User-Agent': 'R36S-ROM-Store/0.4.3 (themes)'})
    total = 0
    with urllib.request.urlopen(req, timeout=30) as response, dest.open('wb') as f:
        while True:
            chunk = response.read(64 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > limit:
                raise ValueError('ZIP de tema excede o limite de tamanho')
            f.write(chunk)
    return total


def safe_repo(owner, repo):
    return bool(re.fullmatch(r'[\w.-]{1,100}', owner, flags=re.ASCII) and
                re.fullmatch(r'[\w.-]{1,130}', repo, flags=re.ASCII) and
                owner not in ('.', '..') and repo not in ('.', '..'))


def github_info(url):
    m = re.fullmatch(r'https://github\.com/([\w.-]+)/([\w.-]+?)(?:/)?', url or '')
    if m and safe_repo(*m.groups()):
        return m.groups()
    return None


def parse_gallery(markdown):
    out = []
    for line in markdown.splitlines():
        m = re.match(r'^\|\s*\[([^\]]+)\]\(https://github\.com/([\w.-]+)/([\w.-]+)/?\)\s*\|', line)
        if not m:
            continue
        name, owner, repo = m.groups()
        if not safe_repo(owner, repo):
            continue
        cells = [v.strip() for v in line.split('|')[1:-1]]
        if len(cells) < 7:
            continue
        compat = {}
        for i, size in enumerate(RES, 2):
            value = re.sub('[^a-z]', '', cells[i].lower()) if len(cells) > i else ''
            compat[size] = value if value in ('yes', 'no', 'untested') else 'untested'
        pic = re.search(r'!\[[^\]]*\]\((https?://[^\s)]+)\)', cells[1])
        out.append({'id': owner.lower() + '-' + repo.lower(), 'name': name, 'author': owner,
                    'folder': repo, 'project_url': f'https://github.com/{owner}/{repo}',
                    'download_url': f'https://github.com/{owner}/{repo}/archive/HEAD.zip',
                    'preview': pic.group(1) if pic else '', 'res': compat, 'source': 'gallery'})
    return out


def parse_collection(data, owner):
    if not isinstance(data, list):
        return []
    out = []
    for item in data:
        repo = item.get('name', '') if isinstance(item, dict) else ''
        if not repo.lower().startswith('es-theme') or not safe_repo(owner, repo):
            continue
        if item.get('fork') or item.get('archived'):
            continue
        branch = item.get('default_branch', 'main')
        if not re.fullmatch(r'[\w./-]{1,100}', str(branch)) or '..' in branch or branch.startswith('/'):
            branch = 'main'
        out.append({'id': owner.lower() + '-' + repo.lower(), 'name': repo.replace('es-theme-', '').replace('-', ' ').title(),
                    'author': owner, 'folder': repo, 'project_url': f'https://github.com/{owner}/{repo}',
                    'download_url': f'https://github.com/{owner}/{repo}/archive/refs/heads/{branch}.zip',
                    'res': {sz: 'untested' for sz in RES}, 'source': 'collection',
                    'description': item.get('description') or ''})
    return out


def seed_themes():
    base = read_json(SEED, {})
    out = []
    for item in base.get('themes', []):
        if not isinstance(item, dict) or not github_info(item.get('project_url')):
            continue
        entry = dict(item)
        entry['res'] = {sz: 'untested' for sz in RES}
        if entry.get('resolution') in RES:
            entry['res'][entry['resolution']] = 'yes'
        entry['source'] = 'catalog'
        out.append(entry)
    return out


def merged_catalog(force=False):
    saved = read_json(CACHE, {})
    fresh = force or not saved.get('themes') or (time.time() - saved.get('time', 0) > 6*3600)
    if not fresh:
        return saved, 'cache'
    list_ = seed_themes()
    by_repo = {str(x['project_url']).lower(): x for x in list_}
    count_remote = 0
    try:
        gallery = parse_gallery(get_url(GALLERY).decode('utf-8', 'replace'))
        if not gallery:
            raise ValueError('Galeria remota vazia')
        for entry in gallery:
            key = entry['project_url'].lower()
            if key in by_repo:
                by_repo[key]['res'] = entry['res']
                by_repo[key]['preview'] = entry.get('preview') or by_repo[key].get('preview', '')
                by_repo[key]['source'] = 'catalog+gallery'
            else:
                list_.append(entry)
                by_repo[key] = entry
        count_remote += len(gallery)
    except (OSError, ValueError, TimeoutError) as e:
        errors = ['Galeria indisponível: ' + str(e)]
    else:
        errors = []
    for user in COLLECTIONS:
        try:
            url = f'https://api.github.com/users/{user}/repos?per_page=100'
            items = parse_collection(json.loads(get_url(url).decode('utf-8')), user)
            count_remote += len(items)
            for entry in items:
                if entry['project_url'].lower() not in by_repo:
                    list_.append(entry)
                    by_repo[entry['project_url'].lower()] = entry
        except (OSError, ValueError, TimeoutError) as e:
            errors.append(user + ': ' + str(e)[:70])
    if count_remote == 0 and saved.get('themes'):
        return saved, 'cache/offline'
    catalog = {'time': time.time(), 'themes': list_, 'source': 'ThemeMaster: Jetup13 + GitHub',
               'remote': count_remote, 'errors': errors[:6]}
    atomic_json(CACHE, catalog)
    return catalog, 'online' if count_remote else 'local'


def roots():
    home = pathlib.Path.home()
    candidates = [pathlib.Path('/roms/themes'), pathlib.Path('/roms2/themes'),
                  home / '.emulationstation' / 'themes',
                  pathlib.Path('/storage/.config/emulationstation/themes'),
                  pathlib.Path('/storage/.emulationstation/themes'),
                  pathlib.Path('/userdata/themes'), pathlib.Path('/etc/emulationstation/themes')]
    manual = os.environ.get('R36S_STORE_ES_THEMES_DIR', '')
    if manual:
        candidates.insert(0, pathlib.Path(manual))
    found, seen = [], set()
    for d in candidates:
        if d.is_dir():
            real = d.resolve()
            if str(real) not in seen:
                found.append(str(real))
                seen.add(str(real))
    return found


def installed():
    out = {}
    for r in roots():
        base = pathlib.Path(r)
        try:
            for item in base.iterdir():
                if item.is_dir() and not item.is_symlink() and (item/'theme.xml').is_file() or (item.is_dir() and not item.is_symlink() and any(p.is_file() for p in item.glob('*/theme.xml'))):
                    out[item.name.lower()] = str(item)
        except OSError:
            pass
    return out


def ensure_theme_url(item):
    owner, repo = github_info(item.get('project_url', '')) or ('', '')
    url = item.get('download_url', '')
    if not safe_repo(owner, repo):
        raise ValueError('Repositório de tema inválido')
    # A URL precisa corresponder ao MESMO repositório GitHub declarado no catálogo.
    prefix = f'https://github.com/{owner}/{repo}/archive/'
    if not isinstance(url, str) or not url.startswith(prefix) or not url.endswith('.zip'):
        raise ValueError('Link ZIP não corresponde ao projeto')
    if any(x in url[len(prefix):] for x in ('?', '#', '%', '\\', '..')):
        raise ValueError('Caminho ZIP inválido')
    return url


def safe_entries(entries):
    size = 0
    if len(entries) > MAX_FILES:
        raise ValueError('Tema contém arquivos demais')
    for info in entries:
        name = info.filename
        parts = pathlib.PurePosixPath(name).parts
        if not name or '\\' in name or '\x00' in name or name.startswith('/') or any(p in ('.', '..') for p in parts) or ':' in parts[0]:
            raise ValueError('ZIP contém caminho inseguro')
        mode = (info.external_attr >> 16) & 0o170000
        if mode not in (0, stat.S_IFDIR, stat.S_IFREG):
            raise ValueError('ZIP contém link ou arquivo especial')
        size += info.file_size
        if size > MAX_EXPANDED:
            raise ValueError('Tema muito grande para instalar')
    return size


def install(theme_id, size):
    catalog = read_json(CACHE, {})
    themes = catalog.get('themes') or seed_themes()
    item = next((x for x in themes if x.get('id') == theme_id), None)
    if not item:
        raise ValueError('Tema não existe no catálogo')
    if size not in RES or item.get('res', {}).get(size, 'untested') == 'no':
        raise ValueError('Tema incompatível com a resolução escolhida')
    url = ensure_theme_url(item)
    folder = item.get('folder', '')
    if not re.fullmatch(r'[A-Za-z0-9._-]{1,130}', folder) or folder in ('.', '..'):
        raise ValueError('Pasta do tema inválida')
    destinations = roots()
    if not destinations:
        raise ValueError('Pasta de temas do EmulationStation não encontrada')
    # A prioridade é o caminho configurado pelo EmulationStation do console.
    target_root = pathlib.Path(destinations[0])
    target = target_root / folder
    if target.is_symlink() or (target.exists() and not target.is_dir()):
        raise ValueError('Destino inválido (arquivo ou link)')
    tmp = pathlib.Path(tempfile.mkdtemp(prefix='.r36sroms-es-', dir=str(target_root)))
    archive = tmp/'theme.zip'
    staging = tmp/'unpack'
    backup = None
    try:
        output('downloading', 'Baixando tema ' + str(item.get('name')))
        downloaded = download_to_file(url, archive, MAX_ZIP)
        with zipfile.ZipFile(archive) as z:
            infos = z.infolist()
            expanded = safe_entries(infos)
            free = shutil.disk_usage(target_root).free
            if free < expanded + downloaded + 24 * 1024 * 1024:
                raise ValueError('Espaço insuficiente na partição de temas')
            # GitHub ZIP usa uma única pasta-repositório na raiz.
            tops = {i.filename.split('/')[0] for i in infos if i.filename}
            prefix = next(iter(tops)) + '/' if len(tops) == 1 else ''
            staging.mkdir()
            output('extracting', 'Validando e extraindo tema')
            for info in infos:
                rel = info.filename[len(prefix):] if prefix and info.filename.startswith(prefix) else info.filename
                if not rel:
                    continue
                dst = staging.joinpath(*pathlib.PurePosixPath(rel).parts)
                if info.is_dir():
                    dst.mkdir(parents=True, exist_ok=True)
                else:
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    with z.open(info) as inp, dst.open('wb') as out:
                        shutil.copyfileobj(inp, out, 128 * 1024)
        if not (staging/'theme.xml').is_file() and not any(p.is_file() for p in staging.glob('*/theme.xml')):
            raise ValueError('Tema sem theme.xml esperado pelo EmulationStation')
        if target.exists():
            backup = target_root / ('.r36sroms-backup-' + folder + '-' + time.strftime('%Y%m%d%H%M%S'))
            if backup.exists():
                raise ValueError('Já existe uma cópia de segurança com este nome')
            os.replace(target, backup)
        try:
            os.replace(staging, target)
        except BaseException:
            if backup and backup.exists() and not target.exists():
                os.replace(backup, target)
            raise
        return {'installed_path': str(target), 'backup': str(backup) if backup else '', 'name': item.get('name', folder)}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv):
    if len(argv) < 2 or argv[1] not in ('refresh', 'scan', 'install'):
        return 2
    op = argv[1]
    try:
        if op == 'install':
            if len(argv) != 4:
                raise ValueError('Selecione o tema e a resolução')
            output('working', 'Preparando instalação')
            details = install(argv[2], argv[3])
            output('done', 'Tema instalado. Ative pelo menu do EmulationStation.', **details, installed=installed())
        else:
            output('working', 'Consultando catálogo de temas')
            if op == 'scan':
                catalog, label = (read_json(CACHE, {}) or {'themes': seed_themes()}), 'cache'
            else:
                catalog, label = merged_catalog(False)
            if not catalog.get('themes'):
                catalog = {'themes': seed_themes()}
            output('done', 'Catálogo: ' + label, installed=installed(),
                   themes=catalog.get('themes', []), source=label, roots=roots(), errors=catalog.get('errors', []))
        return 0
    except Exception as exc:
        output('error', str(exc), installed=installed())
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
