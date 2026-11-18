#!/usr/bin/env python3
"""Gera TESTE/FONTE/UPDATE+manifesto OTA com listas fechadas.

A versão 0.4.4-beta é propositalmente ponte para clientes <=0.4.1-beta.
Versões seguintes passam a atualizar todos os binários autorizados.
"""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'
APP='r36s-roms-store'
VERSION=(ROOT/'VERSION').read_text(encoding='utf-8').strip()
assert VERSION == (ROOT/'port'/APP/'VERSION').read_text(encoding='utf-8').strip()
assert VERSION == (ROOT/'src/VERSION').read_text(encoding='utf-8').strip()

BASE=(
    'R36S ROMS STORE.sh',
    APP+'/game.love', APP+'/bin/gamestore_source.py',
    APP+'/bin/store_updater.py', APP+'/LICENSE',
    APP+'/THIRD_PARTY_NOTICES.txt', APP+'/VERSION',
)
BRIDGE=BASE+(APP+'/bin/bios_manager.py',)
FULL=BRIDGE+(
    APP+'/bin/es_theme_manager.py',APP+'/bin/es_themes_seed.json',
    APP+'/bin/fetch.sh',APP+'/bin/7zzs',
)
ALL=BRIDGE if VERSION=='0.4.4-beta' else FULL
assert len(ALL)==len(set(ALL))

def pack(target, paths, base):
    with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as z:
        for rel in paths:
            file=base/rel
            assert file.is_file() and not file.is_symlink(),rel
            zip_info=zipfile.ZipInfo(rel, (2025,1,1,0,0,0))
            zip_info.compress_type=zipfile.ZIP_DEFLATED
            zip_info.external_attr=(0o100755 if (rel.endswith('.sh') or rel.endswith('/bin/7zzs')) else 0o100644)<<16
            z.writestr(zip_info,file.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=6)

BUILD.mkdir(exist_ok=True)
update=BUILD/f'R36S_ROMS_STORE_v{VERSION}_UPDATE.zip'
installer=BUILD/f'R36S_ROMS_STORE_v{VERSION}_TESTE.zip'
source=BUILD/f'R36S_ROMS_STORE_v{VERSION}_FONTE.zip'
with zipfile.ZipFile(ROOT/'port'/APP/'game.love') as love:
    assert love.read('VERSION').decode().strip()==VERSION
    assert len(love.read('bundled/es_theme_manager.py'))>1000
    assert len(love.read('bundled/es_themes_seed.json'))>1000
    assert len(love.read('bundled/fetch.sh'))>100
    assert len(love.read('bundled/7zzs'))>100000

# Pacote de instalação completo com auxiliares e sem state/conf.
pack(installer, ['R36S ROMS STORE.sh']+[f'{APP}/'+str(p.relative_to(ROOT/'port'/APP)).replace('\\','/') for p in sorted((ROOT/'port'/APP).rglob('*')) if p.is_file()], ROOT/'port')

man={"app":APP,"version":VERSION,"files":[]}
with zipfile.ZipFile(update,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for rel in ALL:
        path=ROOT/'port'/rel
        data=path.read_bytes()
        man['files'].append({'path':rel,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        obj=zipfile.ZipInfo(rel,(2025,1,1,0,0,0));obj.compress_type=zipfile.ZIP_DEFLATED
        obj.external_attr=(0o100755 if (rel.endswith('.sh') or rel.endswith('/bin/7zzs')) else 0o100644)<<16
        z.writestr(obj,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=6)
    z.writestr('update_manifest.json',json.dumps(man,ensure_ascii=False,indent=2).encode('utf-8'))
# Fonte completa: exclui build, logs, caches, caches Python; inclui workflow de publicação.
paths=sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file() and
    '.git' not in p.relative_to(ROOT).parts and 'build' not in p.relative_to(ROOT).parts and
    '__pycache__' not in p.relative_to(ROOT).parts and not p.name.endswith(('.pyc','.pyo')))
pack(source, paths,ROOT)

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(131072),b''):h.update(chunk)
 return h.hexdigest()

# Verifica com o próprio atualizador que será distribuído.
spec=importlib.util.spec_from_file_location('updater',ROOT/'port'/APP/'bin/store_updater.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
assert mod.safe_zip(update,VERSION)==frozenset(ALL)

notes=(f'R36S ROMS STORE {VERSION}\n'
       '- Atualizador OTA compatível com versões 0.4.1-beta e 0.4.3-beta.\n'
       '- BIOS e Loja de Temas permanecem no menu principal.\n'
       '- Bootstrap seguro de módulos no game.love; backup e rollback mantidos.\n'
       '- O download depende de confirmação do usuário.\n')
repo='https://github.com/JammesPark/R36S-ROMS-STORE-UPDATES/releases/download/roms-v'+VERSION+'/'
feed={"app":APP,"channel":"beta","status":"published","version":VERSION,
      "url":repo+update.name,"sha256":sha(update),"size":update.stat().st_size,"notes":notes,
      "installer_url":repo+installer.name,"installer_sha256":sha(installer),
      "source_url":repo+source.name,"source_sha256":sha(source)}
(BUILD/'update.json').write_text(json.dumps(feed,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('OTA format:',len(ALL),'files', '(legacy bridge)' if ALL==BRIDGE else '(full)')
for f in (update,installer,source,BUILD/'update.json'):
 print(f.name, f.stat().st_size, sha(f))
