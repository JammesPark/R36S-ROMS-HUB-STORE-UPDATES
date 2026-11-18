"""Static regression test for R36S menu options, input alignment and 640x480 bounds."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
s=(root/'src/main.lua').read_text(encoding='utf8')
ui=(root/'src/ui.lua').read_text(encoding='utf8')
i18n=(root/'src/i18n.lua').read_text(encoding='utf8')
nav=re.search(r'local menuPages=\{([^}]+)\}',s)
assert nav
pages=re.findall(r"'([^']+)'",nav.group(1))
assert pages==['home','catalog','bios','es_themes','downloads','installed','favorites','settings','about','exit'],pages
assert 114+31*(len(pages)-1)+29 <= 424
assert "local suboptions={'languages','themes','font_size','storage','network','updates','help'}" in s
assert "if route=='es_themes' then esUI.enter() end" in s
assert "elseif screen=='es_themes' then esThemesPage()" in s
assert "es_themes='palette'" in ui
assert "local idx=math.floor((y-114)/31)+1" in s
for lang in ('pt','en','es','ru'):
    assert re.search(r'\b'+lang+r'=\{[^\n]*es_themes=',i18n)
assert "tr('es_themes'),storeUpdater" not in s
print('PASS menu 640x480: BIOS and Theme Store are both main items, four languages')
