-- Studio UI tests: 640x480 routes, complete palette and pointer events, no hardware.
package.path='./src/?.lua;'..package.path
local ui={}
for _,k in ipairs({'rect','text','menuIcon','drawLogo','poster','color'}) do
 ui[k]=function(...) end
end
ui.ellipsize=function(str,n)
 str=tostring(str or '')
 return #str>n and str:sub(1,n)..'...' or str
end
package.loaded.ui=ui
love={graphics={}}
local g=love.graphics
g.circle=function() end
g.setColor=function() end
g.newCanvas=function(w,h)
 assert(w==640 and h==480)
 return {setFilter=function() end}
end
g.newQuad=function(x,y,w,h,sw,sh)
 assert(sw==640 and sh==480)
 return {x=x,y=y,w=w,h=h}
end
g.setCanvas=function() end
g.push=function() end
g.pop=function() end
g.origin=function() end
g.clear=function() end
g.draw=function() end
local T=require('theme')
local S=require('studio_ui')
local keys={'ocean','emerald','violet','amber','slate'}
local signature={}
for _,key in ipairs(keys) do
 T.setLayout('studio');T.set(key)
 assert(T.layout=='studio' and T.current==key)
 local col=function(c) return string.format('%.3f %.3f %.3f',c[1],c[2],c[3]) end
 local sig=col(T.bg)..'/'..col(T.panel)..'/'..col(T.sidebar)
 assert(not signature[sig],key..' paleta nao alterou fundo')
 signature[sig]=true
 assert(T.accent and T.text and T.highlight)
end
T.setLayout('classic')
T.set('ocean')
assert(T.layout=='classic' and T.bg[1]<.04,'classico deve manter fundo original')
local games={
 {name='Primeira ROM',category='PS1',game_path='https://example.org/a'},
 {name='Segunda ROM',category='GBA',game_path='https://example.org/b'},
 {name='Terceira ROM',category='SNES',game_path='https://example.org/c'}
}
local pages={'startup','first_language','disclaimer','home','catalog','search_results',
 'detail','confirm','downloads','transferring','success','history','installed',
 'favorites','bios','es_themes','settings','layout_choice','themes','storage',
 'network','updates','update_backups','update_history','update_local','about',
 'help','offline','exit_confirm'}
local c={
 nav={'home','catalog','bios','es_themes','downloads','installed','favorites','settings','about','exit'},
 navIndex=1,navFocus=false,featuredIndex=1,
 homeFocus='featured',focus='content',homeStatIndex=1,
 device={wifi=true,battery=97,time='12:00'},
 tr=function(s) return s end,
 games=games,results=games,categories={{category='ALL'},{category='PS1'},{category='GBA'}},
 selectedGame=games[1],selectedCard=1,
 cover=function(g,x,y,w,h) assert(g.name and w>0 and h>0) end,
 current={name='Pacote BIOS',done=100,total=800},
 rate=function() return '1.30 MB/s' end,eta=function() return '05:03' end,
 totalRoms=250,downloads={{name='Jogo baixado',category='PS1',card='SD1'}},
 favorites={games[1]},settingsIndex=2,color='ocean',layout='studio',
 colorName='Oceano',languageName='Português',font_size='medium',
 version='0.4.13-beta',installIndex=1,favoriteIndex=1,
 storage={{total=1000000,free=200000},{total=2000000,free=1500000}},
 networkState='online',gameIndex=1,searchIndex=1,category='ALL',
 transfers={{kind='rom',name='ROM',phase='downloading',done=100,total=200}},
 transferSelected=1,
 platformTitle=function(key) return key end
}
for _,screen in ipairs(pages) do
 c.screen=screen
 local ok,err=pcall(function() S.draw(c,function() end) end)
 assert(ok,'Studio nao desenhou '..screen..': '..tostring(err))
end
c.screen='home';S.draw(c)
local header=S.click(31,80)
assert(header and header.kind=='nav' and header.value=='home')
local cover=S.click(37,283)
assert(cover and cover.kind=='game' and cover.value==1)
local stat=S.click(37,391)
assert(stat and stat.kind=='nav' and stat.value=='catalog')
c.screen='layout_choice';S.draw(c)
local selected=S.click(345,220)
assert(selected and selected.kind=='layout' and selected.value=='studio')
c.screen='themes';S.draw(c)
local color=S.click(50,220)
assert(color and color.kind=='color' and color.value=='ocean')
c.screen='bios';S.draw(c,function() end)
local legacy=S.click(120,140)
assert(legacy and legacy.kind=='legacy' and legacy.x==200 and legacy.y==111)
assert(not S.click(-1,-1))
print('PASS Studio: 29 routes, original Classic, five complete palettes, nav, covers and fallback')
