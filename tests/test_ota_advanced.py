#!/usr/bin/env python3
"""OTA v0.4.6 regression tests with no network and no console."""
import hashlib
import importlib.util
import json
import os
import shutil
import tempfile
import zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
VERSION=(ROOT/'VERSION').read_text().strip()
source=ROOT/'port/r36s-roms-store/bin/store_updater.py'
spec=importlib.util.spec_from_file_location('roms_store_ota_advanced',source)
up=importlib.util.module_from_spec(spec);spec.loader.exec_module(up)
feed=json.loads((ROOT/'build/update.json').read_text())
assert feed['version']==VERSION
full=ROOT/'build'/f'R36S_ROMS_STORE_v{VERSION}_UPDATE.zip'
assert up.safe_zip(full,VERSION)==up.ALLOWED
assert feed['sha256']==up.filehash(full)
assert up.validate_feed(feed,'0.4.4-beta')['kind']=='full'
assert up.validate_feed(feed,VERSION) is None
assert 'full_url' in feed and feed['full_sha256']==feed['sha256']
base_version=os.environ.get('ROMS_OTA_BASELINE_VERSION')
base_zip=os.environ.get('ROMS_OTA_BASELINE_ZIP')
if base_version and base_zip:
    d=ROOT/'build'/f'R36S_ROMS_STORE_v{VERSION}_UPDATE_DELTA.zip'
    assert d.is_file() and feed['incremental_url'].endswith('_UPDATE_DELTA.zip')
    assert up.validate_feed(feed,base_version)['kind']=='incremental'
    assert up.validate_feed(feed,base_version)['sha256']==up.filehash(d)
    with zipfile.ZipFile(d) as z:
        manifest=json.loads(z.read('update_manifest.json'))
        assert manifest['type']=='incremental'
        assert manifest['min_version']==manifest['max_version']==base_version
        names=set(z.namelist())-{'update_manifest.json'}
        assert {up.APP_ID+'/VERSION',up.APP_ID+'/game.love'}<=names<=up.ALLOWED
    assert up.safe_zip(d,VERSION,installed=base_version)==frozenset(names)
    try:up.safe_zip(d,VERSION,installed='0.4.4-beta')
    except ValueError:pass
    else:raise AssertionError('Accepted delta for wrong base version')
    with tempfile.TemporaryDirectory(prefix='roms-ota-advanced-') as tmp:
        ports=Path(tmp)/'ports';app=ports/up.APP_ID
        with zipfile.ZipFile(base_zip) as z:
            for entry in z.infolist():
                if entry.is_dir():continue
                dst=ports/entry.filename
                dst.parent.mkdir(parents=True,exist_ok=True)
                dst.write_bytes(z.read(entry))
        (app/'state').mkdir(exist_ok=True)
        (app/'state/roms_favorites.json').write_text('{"my_favorites":[14]}')
        updater=up.Updater(app)
        assert updater.installed()==base_version
        updater.work.mkdir(parents=True,exist_ok=True)
        dst=updater.work/d.name;shutil.copyfile(d,dst)
        updater.publish('ready',version=VERSION,sha256=up.filehash(d),size=d.stat().st_size,
                        filename=d.name,kind='incremental')
        up.atomic_json(updater.request,{'version':VERSION,'sha256':up.filehash(d)})
        assert updater.apply() and updater.installed()==VERSION
        assert updater.pending.exists()
        assert (app/'state/roms_favorites.json').read_text()=='{"my_favorites":[14]}'
        # unchanged files from installer remain untouched, delta only changed whitelist paths
        with zipfile.ZipFile(ROOT/'build'/f'R36S_ROMS_STORE_v{VERSION}_TESTE.zip') as full_install:
            for rel in up.ALLOWED:
                assert (ports/rel).read_bytes()==full_install.read(rel),rel
        assert updater.confirm()
        assert not updater.pending.exists()
        assert {'installed','confirmed'}<={e['event'] for e in updater.history()}
        items=updater.list_backups()
        assert len(items)==1 and items[0]['from']==base_version
        backup=items[0]['id']
        # Manual restore: launcher consumes this request only after LÖVE closes.
        up.atomic_json(updater.request,{'action':'restore','backup':backup})
        assert updater.apply() and updater.installed()==base_version
        assert updater.pending.exists()
        assert (app/'state/roms_favorites.json').read_text()=='{"my_favorites":[14]}'
        assert any(e['event']=='restored' for e in updater.history())
        # Rollback of the restore returns us to the newer version.
        assert updater.rollback() and updater.installed()==VERSION
        assert not updater.pending.exists()
        assert (app/'state/roms_favorites.json').read_text()=='{"my_favorites":[14]}'
        assert updater.list_backups()
        updater.delete_backup(backup)
        assert backup not in {b['id'] for b in updater.list_backups()}
        try:updater.delete_backup('../../out')
        except ValueError:pass
        else:raise AssertionError('Unsafe backup deletion')
        # Local ZIP validation: no need for internet; staging requires user confirmation.
        inbox=updater.work/'inbox';inbox.mkdir()
        shutil.copyfile(full,inbox/full.name)
        scan=updater.scan_local()
        assert scan==[],'Already installed version must not be offered'
        assert (app/'state/roms_favorites.json').read_text()=='{"my_favorites":[14]}'
    print('PASS v0.4.6 incremental OTA; restore, rollback, history, snapshots, whitelist')
else:
    print('SKIP incremental integration (baseline not configured); full OTA validated')
