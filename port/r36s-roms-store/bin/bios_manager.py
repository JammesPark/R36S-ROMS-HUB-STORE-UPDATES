#!/usr/bin/env python3
"""Independent BIOS file manager for R36S ROMS STORE.

No BIOS binaries, license-restricted assets or downloads are distributed.
Only reads local user-provided files and recognized BIOS names. Backups and
safe, confirmed installation are handled under the application's state.
Python 3.8+; does not import code from R36S PORT HUB.
"""
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import time
import zipfile
from pathlib import Path, PurePosixPath

APP_NAME = 'r36s-roms-store'
MAX_FILE_SIZE = 32 * 1024 * 1024
MAX_TOTAL_SIZE = 128 * 1024 * 1024
MAX_ARCHIVE_MEMBERS = 512

# File names that are commonly referenced by emulator documentation. Presence
# alone is not proof of authenticity or entitlement to use a firmware image.
BIOS_GROUPS = (
    ('PlayStation', 'any', ('scph5500.bin', 'scph5501.bin', 'scph5502.bin', 'psxonpsp660.bin')),
    ('Game Boy Advance', 'any', ('gba_bios.bin',)),
    ('Neo Geo', 'any', ('neogeo.zip',)),
    ('Sega CD', 'any', ('bios_CD_U.bin', 'bios_CD_E.bin', 'bios_CD_J.bin')),
    ('Dreamcast', 'all', ('dc/boot.bin', 'dc/flash.bin')),
    ('PC Engine CD', 'any', ('syscard3.pce',)),
    ('Nintendo DS', 'all', ('bios7.bin', 'bios9.bin', 'firmware.bin')),
    ('Amiga', 'any', ('kick34005.A500', 'kick40068.A1200', 'kick40063.A600')),
    ('Atari ST', 'any', ('tos.img',)),
    ('ColecoVision', 'any', ('coleco.rom',)),
    ('3DO', 'any', ('panafz1.bin', 'panafz10.bin')),
)
KNOWN = {name.lower(): name for _, _, members in BIOS_GROUPS for name in members}


def sha256(blob):
    return hashlib.sha256(blob).hexdigest()


def hash_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(131072), b''):
            h.update(block)
    return h.hexdigest()


def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp.' + str(os.getpid()))
    with temp.open('w', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(str(temp), str(path))


def load_json(path):
    try:
        with Path(path).open('r', encoding='utf-8') as stream:
            return json.load(stream)
    except (OSError, ValueError):
        return None


def safe_filename(name):
    if not isinstance(name, str) or not name or '\\' in name or '\x00' in name:
        raise ValueError('Nome de BIOS inválido')
    p = PurePosixPath(name)
    if p.is_absolute() or any(part in ('.', '..') for part in name.split('/')):
        raise ValueError('Caminho de pacote inseguro')
    if len(p.parts) > 2 or ':' in name:
        raise ValueError('Pasta de origem não reconhecida')
    # Allow a single parent folder for unstructured user archives, except
    # canonical dc/ paths which must remain two-part names.
    key = name.lower()
    if key in KNOWN:
        return KNOWN[key]
    if len(p.parts) == 2 and p.parts[1].lower() in KNOWN:
        return KNOWN[p.parts[1].lower()]
    return None


def no_symlinks(path, stop):
    path, stop = Path(path), Path(stop)
    p = path
    while True:
        if p.is_symlink():
            raise ValueError('Link simbólico não permitido: ' + str(p))
        if p == stop:
            break
        if p == p.parent:
            raise ValueError('Destino fora da pasta autorizada')
        p = p.parent


class BIOSManager:
    def __init__(self, app=None, bios_dir=None, cfg_paths=None):
        self.app = Path(app or Path(__file__).resolve().parents[1])
        self.state = self.app / 'state' / 'bios_manager'
        self.import_dir = self.app / 'state' / 'bios_import'
        self.backups = self.state / 'backups'
        self.status = self.state / 'status.json'
        self.journal = self.state / 'pending.json'
        self.last = self.state / 'last_backup.json'
        self._overridden = bios_dir is not None
        self.bios_dir = Path(bios_dir) if bios_dir is not None else self.detect_dir(cfg_paths)

    def detect_dir(self, cfg_paths=None):
        home = Path(os.environ.get('HOME') or '/home/ark')
        config_files = cfg_paths if cfg_paths is not None else (
            home / '.config/retroarch/retroarch.cfg',
            home / '.config/retroarch32/retroarch.cfg',
            Path('/home/ark/.config/retroarch/retroarch.cfg'),
        )
        guesses = []
        for conf in config_files:
            try:
                contents = Path(conf).read_text(encoding='utf-8', errors='replace')
            except OSError:
                continue
            match = re.search(r'^\s*system_directory\s*=\s*["\']?([^\n"\']+)', contents, re.M)
            if match:
                value = match.group(1).strip()
                if value.startswith('/'):
                    guesses.append(Path(value))
        if str(self.app).startswith('/roms2/'):
            guesses.extend((Path('/roms2/bios'), Path('/roms/bios')))
        else:
            guesses.extend((Path('/roms/bios'), Path('/roms2/bios')))
        for guess in guesses:
            # Scope writes strictly to the console's BIOS folders.
            if not str(guess).startswith(('/roms/', '/roms2/')) or guess.name != 'bios':
                continue
            if guess.is_dir() and not guess.is_symlink():
                return guess
        return None

    def output(self, phase, **data):
        save_json(self.status, dict(phase=phase, **data))

    def root(self):
        if self.bios_dir is None or not self.bios_dir.is_dir():
            raise ValueError('A pasta de BIOS do console não foi encontrada')
        if self.bios_dir.is_symlink():
            raise ValueError('A pasta de BIOS é um link simbólico')
        if not self._overridden and (str(self.bios_dir) not in ('/roms/bios', '/roms2/bios')):
            raise ValueError('Diretório de BIOS fora do cartão SD')
        return self.bios_dir

    def target(self, rel):
        root = self.root()
        if rel not in KNOWN.values():
            raise ValueError('Destino de BIOS não reconhecido: ' + str(rel))
        dest = root.joinpath(*PurePosixPath(rel).parts)
        no_symlinks(dest, root)
        return dest

    def scan(self):
        root = self.root()
        rows = []
        for group, mode, choices in BIOS_GROUPS:
            present = []
            for rel in choices:
                path = self.target(rel)
                if path.is_file() and path.stat().st_size > 0:
                    present.append(rel)
            has = bool(present)
            complete = has if mode == 'any' else len(present) == len(choices)
            rows.append({'name': group, 'expected': len(choices), 'found': len(present),
                         'status': 'present' if complete else 'partial' if has else 'missing',
                         'files': present})
        result = {'directory': str(root), 'systems': rows,
                  'present': sum(1 for r in rows if r['status'] == 'present'),
                  'missing': sum(1 for r in rows if r['status'] != 'present'),
                  'note': 'Arquivo encontrado não significa BIOS autêntica ou licenciada.'}
        self.output('done', action='scan', **result)
        return result

    def collect_files(self):
        if not self.import_dir.is_dir() or self.import_dir.is_symlink():
            raise ValueError('Coloque arquivos próprios na pasta state/bios_import')
        files = {}
        total = 0
        for src in sorted(self.import_dir.iterdir()):
            if src.is_symlink():
                raise ValueError('Origem com link simbólico não permitida')
            if not src.is_file():
                continue
            if src.suffix.lower() == '.zip' and src.name.lower() not in KNOWN:
                with zipfile.ZipFile(src) as z:
                    entries = z.infolist()
                    if len(entries) > MAX_ARCHIVE_MEMBERS:
                        raise ValueError('Pacote de BIOS contém arquivos demais')
                    for item in entries:
                        if item.is_dir():
                            continue
                        raw = item.filename
                        # Reject unsafe paths even when they would be ignored.
                        if '\\' in raw or raw.startswith('/') or '..' in raw.split('/'):
                            raise ValueError('Pacote contém caminho inseguro')
                        if stat.S_ISLNK((item.external_attr >> 16) & 0o170000):
                            raise ValueError('Pacote contém links simbólicos')
                        canonical = safe_filename(raw)
                        if canonical is None:
                            continue
                        if item.file_size > MAX_FILE_SIZE:
                            raise ValueError('Arquivo de BIOS grande demais')
                        with z.open(item) as f:
                            blob = f.read(MAX_FILE_SIZE + 1)
                        if len(blob) != item.file_size or len(blob) > MAX_FILE_SIZE:
                            raise ValueError('Arquivo incompleto')
                        if canonical.lower() in files:
                            raise ValueError('BIOS duplicada no pacote')
                        total += len(blob)
                        files[canonical.lower()] = (canonical, blob)
            else:
                canonical = safe_filename(src.name)
                if canonical is None:
                    continue
                if src.stat().st_size > MAX_FILE_SIZE:
                    raise ValueError('Arquivo de BIOS grande demais')
                blob = src.read_bytes()
                if canonical.lower() in files:
                    raise ValueError('BIOS duplicada na importação')
                total += len(blob)
                files[canonical.lower()] = (canonical, blob)
            if total > MAX_TOTAL_SIZE:
                raise ValueError('Importação excede 128 MB')
        if not files:
            raise ValueError('Nenhum arquivo de BIOS reconhecido na pasta de importação')
        return list(files.values())

    def rollback_journal(self):
        meta = load_json(self.journal)
        if not meta:
            return False
        backup = self.backups / meta['id']
        for rel in meta['old']:
            src = backup.joinpath(*PurePosixPath(rel).parts)
            dst = self.target(rel)
            if not src.is_file() or src.is_symlink():
                raise ValueError('Backup de BIOS incompleto')
            if hash_file(src) != meta['old'][rel]:
                raise ValueError('Backup de BIOS alterado')
            dst.parent.mkdir(parents=True, exist_ok=True)
            temp = dst.with_name(dst.name + '.restore-temp')
            shutil.copyfile(src, temp)
            os.replace(str(temp), str(dst))
        for rel in meta['added']:
            self.target(rel).unlink(missing_ok=True)
        self.journal.unlink(missing_ok=True)
        return True

    def install(self):
        if self.journal.exists():
            self.rollback_journal()
        candidates = self.collect_files()
        root = self.root()
        changes = []
        for rel, blob in candidates:
            dst = self.target(rel)
            if dst.exists() and not dst.is_file():
                raise ValueError('Destino da BIOS não é um arquivo')
            if dst.is_file() and hash_file(dst) == sha256(blob):
                continue
            changes.append((rel, blob, dst))
        if not changes:
            self.output('done', action='import', directory=str(root), count=0, note='BIOS idênticas já presentes')
            return 0
        self.backups.mkdir(parents=True, exist_ok=True)
        ident = str(time.time_ns()) + '-' + str(os.getpid())
        backup = self.backups / ident
        backup.mkdir(parents=False, exist_ok=False)
        meta = {'id': ident, 'old': {}, 'added': [], 'installed': {}}
        for rel, blob, dst in changes:
            if dst.exists():
                old = backup.joinpath(*PurePosixPath(rel).parts)
                old.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dst, old)
                meta['old'][rel] = hash_file(old)
            else:
                meta['added'].append(rel)
            meta['installed'][rel] = sha256(blob)
        # Journal written before first replacement protects interrupted imports.
        save_json(self.journal, meta)
        try:
            for rel, blob, dst in changes:
                no_symlinks(dst, root)
                dst.parent.mkdir(parents=True, exist_ok=True)
                no_symlinks(dst, root)
                temp = dst.with_name(dst.name + '.romstore-temp')
                with temp.open('wb') as stream:
                    stream.write(blob)
                    stream.flush()
                    os.fsync(stream.fileno())
                os.replace(str(temp), str(dst))
                if hash_file(dst) != meta['installed'][rel]:
                    raise ValueError('Falha na verificação após instalação')
            save_json(self.last, meta)
            self.journal.unlink(missing_ok=True)
            self.output('done', action='import', directory=str(root), count=len(changes),
                        note='Backup criado; autenticidade dos arquivos não verificada')
            return len(changes)
        except Exception:
            self.rollback_journal()
            raise

    def restore(self):
        if self.journal.exists():
            self.rollback_journal()
        meta = load_json(self.last)
        if not meta:
            raise ValueError('Nenhum backup anterior encontrado')
        for rel, want in meta['installed'].items():
            dst = self.target(rel)
            if not dst.is_file() or hash_file(dst) != want:
                raise ValueError('BIOS modificada depois da instalação; restauração bloqueada')
        save_json(self.journal, meta)
        self.rollback_journal()
        self.last.unlink(missing_ok=True)
        self.output('done', action='restore', count=len(meta['installed']), directory=str(self.root()))
        return len(meta['installed'])


def main(args):
    if len(args) != 2 or args[1] not in ('scan', 'import', 'restore'):
        raise SystemExit('Uso: bios_manager.py scan|import|restore')
    app = Path(__file__).resolve().parents[1]
    mgr = BIOSManager(app)
    mgr.output('working', action=args[1])
    try:
        # Se o console perdeu energia durante uma importação, recuperar primeiro.
        if mgr.journal.exists():
            mgr.rollback_journal()
        if args[1] == 'scan':
            mgr.scan()
        elif args[1] == 'import':
            count = mgr.install()
            if count:
                mgr.scan()
                mgr.output('done', action='import', directory=str(mgr.root()), count=count,
                           systems=load_json(mgr.status).get('systems', []))
        else:
            count = mgr.restore()
            mgr.scan()
            mgr.output('done', action='restore', directory=str(mgr.root()), count=count,
                       systems=load_json(mgr.status).get('systems', []))
        return 0
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError) as exc:
        mgr.output('error', action=args[1], message=str(exc)[:220])
        print('BIOS:', str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
