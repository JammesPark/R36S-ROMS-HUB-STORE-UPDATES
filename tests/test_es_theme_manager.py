"""Offline regression checks for theme gallery parsing, install and ZIP safety."""
import sys, os, io, zipfile, tempfile, json, importlib.util
from pathlib import Path
SOURCE=Path(__file__).resolve().parents[1] / 'port/r36s-roms-store/bin/es_theme_manager.py'
spec=importlib.util.spec_from_file_location('es_theme_manager',SOURCE)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
assert mod.parse_gallery('''| Theme Name | Preview |480x320|640x480|854x480|960x544|720x720|
| --- | --- | --- | --- | --- | --- | --- |
| [Demo](https://github.com/Jetup13/es-theme-demo) | ![](https://example.org/preview.png) | No | Yes | Untested | No | No |
''')[0]['res']['640x480']=='yes'
with tempfile.TemporaryDirectory() as td:
    root=Path(td)/'themes';root.mkdir()
    app=Path(td)/'app'; (app/'state').mkdir(parents=True)
    item={'id':'owner-example','name':'Example','project_url':'https://github.com/Owner/example',
          'download_url':'https://github.com/Owner/example/archive/refs/heads/main.zip','folder':'example',
          'res':{'640x480':'yes'}}
    mod.APP=app;mod.STATE=app/'state';mod.CACHE=app/'state/es_theme_catalog.json';mod.RESULT=app/'state/es_theme_status.json'
    mod.CACHE.write_text(json.dumps({'themes':[item]}))
    mod.roots=lambda:[str(root)]
    theme=root/'example';theme.mkdir();(theme/'theme.xml').write_text('old version')
    def fake_download(url, dest, limit):
        with zipfile.ZipFile(dest,'w') as z:
            z.writestr('example-main/nes/theme.xml','<theme/>')
            z.writestr('example-main/graphics/file.txt','data')
        return dest.stat().st_size
    mod.download_to_file=fake_download
    result=mod.install('owner-example','640x480')
    assert (root/'example/nes/theme.xml').is_file()
    assert result['backup'] and Path(result['backup']).is_dir()
    assert (Path(result['backup'])/'theme.xml').read_text()=='old version'
    try:mod.install('owner-example','720x720')
    except ValueError:pass
    else:raise AssertionError('unknown resolution not rejected')
    assert mod.github_info('http://evil.com/bad') is None
    bad=zipfile.ZipInfo('../outside.txt');bad.file_size=100
    try:mod.safe_entries([bad])
    except ValueError:pass
    else:raise AssertionError('unsafe ZIP path accepted')
print('PASS Theme Manager offline: 640x480 gallery, streaming install, backups, invalid resolution, ZIP paths')
