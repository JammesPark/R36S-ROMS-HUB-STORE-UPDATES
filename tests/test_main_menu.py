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
assert "bios='chip',es_themes='layers'" in ui
assert "elseif shape=='chip'" in ui and "elseif shape=='layers'" in ui
assert "local current=transferCenter.current()" in s, "Inicio must track BIOS/ROM/themes OTA"
# HTML aprovado (retrato 2:3, Em destaque e contagens na parte inferior).
home_geometry=(root/'src/home_layout.lua').read_text(encoding='utf8')
home=s.split("local function homePage()",1)[1].split("local function ",1)[0]
assert "local homeLayout=require('home_layout')" in s
assert "txt(tr('featured'),180,homeLayout.titleY" in home
assert "for slot=1,3 do" in home
assert "cover(game,px,homeLayout.coverY,homeLayout.coverW,homeLayout.coverH,index)" in home
assert home.index("txt(tr('featured')") < home.index("local stats=")
assert "homeLayout.statsY" in home
assert "homeLayout.featureAt(x,y,#external.games,homeSlideIndex)" in s
assert "homeLayout.statAt(x,y)" in s
assert "cover(selected,443,137,160,240,chosen)" in s
assert "cover(g,201,130,150,225,gameIndex)" in s
assert "cover(game,cx,y+4,coverW,coverH,idx)" in s
assert "H.tileX={180,329,478}" in home_geometry
assert "H.statsY=386" in home_geometry
assert "featured='Em destaque'" in i18n
assert "header(tr('welcome'),tr('home'))" in home
assert "coverStretch(" not in s, "Cover preview should never stretch portrait ROM art"
assert "ui.imageContain(img,x+2,y+2,w-4,h-4)" in s
assert "local count=totalRoms()" in home
assert "{tr('installed'),tostring(#downloads)}" in home
assert "{tr('favorites'),tostring(#favorites)}" in home
# Resolução física: todas as telas continuam usando coordenadas virtuais de 640x480.
conf=(root/'src/conf.lua').read_text(encoding='utf8')
display=(root/'src/display_resolution.lua').read_text(encoding='utf8')
assert 't.window.width = 640' in conf and 't.window.height = 480' in conf
assert "local display=require('display_resolution')" in s
assert "display.init()" in s and "function love.resize(w,h)" in s
assert "local function drawVirtual()" in s
assert "display.beginFrame()" in s and "display.endFrame(inCanvas)" in s
assert "x,y=display.pointer(x,y)" in s, "Mouse must map to virtual 640x480"
assert "getDesktopDimensions" in display and "fallback 640x480" in display
assert "fullscreen=true" in display and "getDimensions" in display
assert "src/display_resolution.lua" not in str(root/'src/store_update.lua'), "OTA unaffected"

home=s.split("local function homePage()",1)[1].split("local function ",1)[0]
assert "transferCenter.rateText(current)" in home, "Home must show the same live speed as Downloads"
assert "transferCenter.etaText(current)" in home, "Home must show the same ETA as Downloads"
assert "txt(rate,338,173,9,theme.accent,90,true)" in home
assert "txt(eta,432,173,9,theme.muted,55,true)" in home
assert 432+55 < 495, "Home ETA must not overlap the Downloads button"
assert "local idx=math.floor((y-114)/31)+1" in s
for lang in ('pt','en','es','ru'):
    assert re.search(r'\b'+lang+r'=\{[^\n]*es_themes=',i18n)
assert "tr('es_themes'),storeUpdater" not in s
print('PASS menu 640x480: BIOS and Theme Store are both main items, four languages')
