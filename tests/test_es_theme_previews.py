"""No internet: check the preview whitelist, image signatures, file size, cache."""
from pathlib import Path
import importlib.util, json, tempfile
spec=importlib.util.spec_from_file_location('theme_test','src/bundled/es_theme_manager.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
assert m.preview_url_allowed('https://raw.githubusercontent.com/Jetup13/repo/main/a.png')
assert not m.preview_url_allowed('http://raw.githubusercontent.com/x.png')
assert not m.preview_url_allowed('https://127.0.0.1/bios.png')
assert not m.preview_url_allowed('https://example.org/preview.png')
assert m.preview_key('theme-test')=='theme-test'
try:m.preview_key('../evil')
except ValueError:pass
else:raise AssertionError('invalid theme preview id accepted')
with tempfile.TemporaryDirectory() as d:
 p=Path(d)
 m.COVERS=p/'covers';m.COVER_STATUS=p/'status.json';m.CACHE=p/'cache.json'
 m.CACHE.write_text(json.dumps({'themes':[{'id':'test-theme','preview':'https://raw.githubusercontent.com/user/repo/main/preview.png'}]}))
 # Minimal PNG signature is enough for preview-cache test, without invoking a decoder.
 raw=b'\x89PNG\r\n\x1a\n'+b'\0'*30
 class Response:
  def __enter__(self):return self
  def __exit__(self,*a):return None
  def read(self,n):return raw
 class Opener:
  def open(self,request,timeout):return Response()
 m.urllib.request.build_opener=lambda *a:Opener()
 m.fetch_previews(['test-theme'])
 assert m.preview_cached_path('test-theme').read_bytes()==raw
 assert json.loads(m.COVER_STATUS.read_text())['phase']=='done'
print('PASS theme preview cover whitelist, cache, signatures, local status')
