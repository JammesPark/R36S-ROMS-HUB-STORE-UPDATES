#!/usr/bin/env python3
"""Testes OTA: pacote de oito arquivos validado pelo cliente v0.4.1 e cliente novo.
Instalação e rollback reais sobre diretório temporário. Sem internet e sem console.
"""
from pathlib import Path
import importlib.util
import json
import shutil
import tempfile
import zipfile

root=Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text().strip()
update=root/'build'/f'R36S_ROMS_STORE_v{version}_UPDATE.zip'
app='r36s-roms-store'

def getmod(name,p):
 spec=importlib.util.spec_from_file_location(name,p)
 m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 return m

new=getmod('new',root/'port'/app/'bin/store_updater.py')
old=getmod('old',root/'tests/legacy_store_updater_041.py')
paths=new.safe_zip(update,version)
expected=8 if version=='0.4.4-beta' else 12
assert len(paths)==expected, f'Esperados {expected} arquivos no pacote'
if expected==8:
 assert paths==old.safe_zip(update,version), 'Pacote OTA incompatível com atualizador de 0.4.1'
manifest=json.loads(zipfile.ZipFile(update).read('update_manifest.json'))
assert len(manifest['files'])==expected
assert all('/state/' not in e['path'] and '/conf/' not in e['path'] for e in manifest['files'])
feed=json.loads((root/'build/update.json').read_text())
assert new.validate_feed(feed,'0.4.1-beta')['version']==version
assert new.validate_feed(feed,version) is None
assert new.validate_feed(feed,'0.3.1-beta')['version']==version
with tempfile.TemporaryDirectory(prefix='roms-ota-test-') as tmp:
 ports=Path(tmp)/'ports';base=ports/app; (base/'bin').mkdir(parents=True)
 (base/'state').mkdir()
 # Simula instalação anterior que já tinha os binários conhecidos.
 with zipfile.ZipFile(root/'build'/f'R36S_ROMS_STORE_v{version}_TESTE.zip') as z:
  for rel in paths:
   target=ports/rel; target.parent.mkdir(parents=True,exist_ok=True)
   target.write_bytes(z.read(rel))
 previous='0.4.1-beta' if expected==8 else '0.4.4-beta'
 (base/'VERSION').write_text(previous+'\n')
 (base/'state/user_data.json').write_text('{"favorites":[3]}')
 updater=(old if expected==8 else new).Updater(base)
 updater.work.mkdir(parents=True)
 target=updater.work/update.name
 shutil.copy2(update,target)
 updater.publish('ready',version=version,sha256=new.filehash(update),size=update.stat().st_size,
                 filename=update.name)
 old.atomic_json(updater.request,{'version':version,'sha256':new.filehash(update)})
 assert updater.apply()
 assert (base/'VERSION').read_text().strip()==version
 assert (base/'state/user_data.json').read_text()=='{"favorites":[3]}'
 assert (base/'bin/store_updater.py').read_text()==(root/'port'/app/'bin/store_updater.py').read_text()
 with zipfile.ZipFile(base/'game.love') as game:
  for n in ['bundled/es_theme_manager.py','bundled/es_themes_seed.json','bundled/fetch.sh','bundled/7zzs']:
   assert game.getinfo(n).file_size>100
 assert updater.pending.exists()
 assert updater.rollback()
 assert (base/'VERSION').read_text().strip()=='0.4.1-beta'
 assert (base/'state/user_data.json').read_text()=='{"favorites":[3]}'
print('PASS OTA: '+ ('0.4.1-beta' if expected==8 else '0.4.4-beta')+' -> '+version+'; SHA, manifest, app state, rollback')

# Regressão: o motor novo permite o formato COMPLETO com 12 arquivos e
# conserva rollback, mesmo que 0.4.4 seja distribuído na ponte de oito.
import io
import hashlib
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED
full=sorted(new.ALLOWED)
with TemporaryDirectory(prefix='roms-future-ota-') as td:
 temp=Path(td);out=temp/'full-update.zip'
 future='0.4.5-beta'
 with zipfile.ZipFile(root/'port'/app/'game.love') as z:
  old_contents=[(i.filename,z.read(i.filename)) for i in z.infolist() if not i.is_dir()]
 love_stream=io.BytesIO()
 with zipfile.ZipFile(love_stream,'w',compression=ZIP_DEFLATED) as z:
  for rel,data in old_contents:
   z.writestr(rel, future.encode() + b'\n' if rel=='VERSION' else data)
 members=[]
 for rel in full:
  if rel==app+'/VERSION': data=(future+'\n').encode()
  elif rel==app+'/game.love': data=love_stream.getvalue()
  else:data=(root/'port'/rel).read_bytes()
  members.append((rel,data))
 manifest={'app':app,'version':future,'files':[
   {'path':rel,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()} for rel,data in members]}
 with zipfile.ZipFile(out,'w',compression=ZIP_DEFLATED) as z:
  for rel,data in members:z.writestr(rel,data)
  z.writestr('update_manifest.json',json.dumps(manifest))
 assert new.safe_zip(out,future)==frozenset(full)
 base=temp/'ports'/app; (base/'bin').mkdir(parents=True);(base/'state').mkdir()
 (base/'VERSION').write_text('0.4.4-beta\n')
 (base/'state/favorites.json').write_text('user data')
 n=new.Updater(base); n.work.mkdir(parents=True)
 target=n.work/('R36S_ROMS_STORE_v'+future+'_UPDATE.zip');shutil.copy2(out,target)
 n.publish('ready',version=future,sha256=new.filehash(out),size=out.stat().st_size,filename=target.name)
 new.atomic_json(n.request,{'version':future,'sha256':new.filehash(out)})
 assert n.apply()
 assert (base/'VERSION').read_text().strip()==future
 assert (base/'bin/es_theme_manager.py').is_file()
 assert (base/'bin/fetch.sh').stat().st_mode&0o111
 assert (base/'bin/7zzs').stat().st_mode&0o111
 assert (base/'state/favorites.json').read_text()=='user data'
 assert n.rollback()
 assert not (base/'bin/es_theme_manager.py').exists()
 assert (base/'VERSION').read_text().strip()=='0.4.4-beta'
 assert (base/'state/favorites.json').read_text()=='user data'
 print('PASS future full OTA (12 files): backup, exec perms, rollback and state')
