-- Smoke-test real src/main.lua (no LÖVE device needed), Classic and Studio.
-- This catches interaction failures missed by compiling bytecode alone.
package.path='./src/?.lua;'..package.path
local realGetenv=os.getenv
local root='/tmp/r36s_main_runtime_smoke'
os.execute('mkdir -p '..root..'/state')
os.getenv=function(key)
 if key=='R36S_STORE_HOME' then return root end
 if key=='R36S_STORE_OFFLINE_TEST' then return '1' end
 return realGetenv(key)
end
local f=assert(io.open(root..'/state/roms_settings.json','w'))
f:write('{"language":"pt","theme":"ocean","font_size":"medium","layout":"classic","language_chosen":true}')
f:close()
local gfx={}
setmetatable(gfx,{__index=function() return function() end end})
function gfx.getDimensions() return 640,480 end
function gfx.newCanvas(w,h)
 assert(w==640 and h==480)
 return {setFilter=function() end}
end
function gfx.newQuad(x,y,w,h,iw,ih)
 assert(iw==640 and ih==480)
 return {x=x,y=y,w=w,h=h}
end
love={graphics=gfx,window={getDesktopDimensions=function() return 640,480 end},
 filesystem={read=function(_,name) return '0.4.16-beta' end},
 event={quit=function() end}}
local ui={}
setmetatable(ui,{__index=function() return function() end end})
ui.ellipsize=function(s,n) return tostring(s or ''):sub(1,tonumber(n) or 80) end
ui.font=function(size)
 return {getHeight=function() return size or 12 end,
  getWrap=function(self,str,width) return width,{tostring(str or '')} end}
end
ui.paragraph=function(s,x,y) return (tonumber(y) or 0)+20 end
package.loaded.ui=ui
local games={
 {name='ROM de teste 1',category='psx',game_path='https://example.org/1',cover_id=''},
 {name='ROM de teste 2',category='snes',game_path='https://example.org/2',cover_id=''},
 {name='ROM de teste 3',category='gba',game_path='https://example.org/3',cover_id=''}
}
local ext={games=games,searchResults=games,categories={{category='ALL',count=3},{category='psx',count=1}},
 category='ALL',page=1,totalPages=1,total=3,searchPage=1,searchTotalPages=1,searchTotal=3,
 searchQuery='teste',pending=nil,phase='idle',error=false,refreshes=0}
function ext.init() end
function ext.update() end
function ext.enter() end
function ext.totalCatalog() return 3 end
function ext.networkState() return 'offline' end
function ext.busy() return false end
function ext.refresh() ext.refreshes=ext.refreshes+1;return true end
function ext.categoryChange(category) ext.category=category;return true end
function ext.search() return true end
function ext.inspect() return false end
function ext.remove() return false end
function ext.loadNext() return false end
function ext.searchPageChange() return false end
package.loaded.external=ext
local updater={status={phase='idle'},pending=false,offered=true}
for _,k in ipairs({'init','tick','run','refreshBackups','refreshLocal','deleteBackup'}) do
 updater[k]=function() end
end
updater.tr=function(_,key) return key end
updater.backups=function() return {} end
updater.history=function() return {} end
updater.localPackages=function() return {} end
updater.downloadLocal=function() return false end
updater.requestRestore=function() return false end
updater.install=function() return false end
package.loaded.store_update=updater
local bios={init=function() end,tick=function() end}
package.loaded.bios_manager=bios
local function passive()
 return {init=function() end,update=function() end,enter=function() end,
  draw=function() end,key=function() return true end,
  mouse=function() return true end,hasModal=function() return false end}
end
package.loaded.bios_enhanced_ui=passive()
package.loaded.es_theme_ui=passive()
package.loaded.device_status={update=function() end,get=function()
 return {wifi=true,battery=93,time='10:00'} end}
package.loaded.music={init=function() end,updateRoute=function() end,stop=function() end}
local transfers={active={},items={},rows={},scroll=0,selected=1}
transfers.init=function() end;transfers.poll=function() end
transfers.current=function() return nil end
transfers.entries=function() return transfers.rows end
transfers.selectedItem=function() return nil end
transfers.label=function(_,key) return key or '?' end
transfers.rateText=function() return '1 MB/s' end
transfers.etaText=function() return '00:20' end
transfers.formatProgress=function() return '0/1',0 end
transfers.move=function(d) transfers.selected=math.max(1,transfers.selected+d) end
package.loaded.download_center=transfers
local queue={items={},init=function() end,visible=function() return {} end,
 tick=function() end,enqueue=function() return true end,handle=function() return true end}
package.loaded.transfer_queue=queue
assert(loadfile('src/main.lua'))()
assert(type(love.draw)=='function' and type(love.keypressed)=='function')
assert(pcall(love.load),'main.lua love.load deve iniciar sem falha')
local function upvalue(fn,name)
 for i=1,180 do
  local n,value=debug.getupvalue(fn,i)
  if not n then break end
  if n==name then return i,value end
 end
 error('Nao encontrei upvalue '..name)
end
local bodyIndex,updateBody=upvalue(love.update,'updateBody')
local id=upvalue(updateBody,'screen')
local settingsId,settings=upvalue(love.keypressed,'settings')
local function screen(s) debug.setupvalue(updateBody,id,s) end
local function currentScreen() return select(2,upvalue(updateBody,'screen')) end
local keyWrapper=select(2,upvalue(love.keypressed,'safeHandleKey'))
local keyHandler=select(2,upvalue(keyWrapper,'handleKey'))
local navFlagIndex=upvalue(keyHandler,'studioNavFocus')
local function clearNavFocus() debug.setupvalue(keyHandler,navFlagIndex,false) end
local allScreens={
 'startup','first_language','disclaimer','home','catalog','search_results','search',
 'detail','confirm','downloads','transferring','success','history','installed','favorites',
 'bios','es_themes','settings','layout_choice','languages','font_size','themes',
 'storage','network','updates','update_backups','update_history','update_local',
 'about','help','offline','exit_confirm'
}
local count=0
for _,layout in ipairs({'classic','studio'}) do
 settings.layout=layout
 require('theme').setLayout(layout)
 for _,s in ipairs(allScreens) do
  screen(s)
  local ok,err=pcall(love.draw)
  assert(ok,layout..' screen='..s..' render: '..tostring(err))
  count=count+1
 end
 -- Matriz de teclas reais, incluindo menu, catálogo, configurações e OTA.
 -- Uma exceção silenciosamente recuperada também é detectada pelo log.
 local logPath=root..'/state/ui_last_error.log'
 local clean=assert(io.open(logPath,'wb'));clean:close()
 local gamepadKeys={'a','b','x','y','dpup','dpdown','dpleft','dpright','start','back'}
 for _,route in ipairs(allScreens) do
  if route~='about' then -- A abre QR modal persistente; testado isoladamente
   for _,button in ipairs(gamepadKeys) do
    settings.layout=layout;require('theme').setLayout(layout)
    clearNavFocus()
    screen(route)
    local ok,err=pcall(love.gamepadpressed,nil,button)
    assert(ok,layout..' route='..route..' button='..button..' threw: '..tostring(err))
   end
  end
 end
 local log=assert(io.open(logPath,'r'))
 local logContent=log:read('*a');log:close()
 assert(logContent=='' ,layout..' generated unexpected UI errors during gamepad matrix: '..logContent:sub(1,250))
 for _,s in ipairs({'network','offline'}) do
  clearNavFocus()
  screen(s)
  local before=ext.refreshes
  local ok,err=pcall(love.gamepadpressed,nil,'a')
  assert(ok,layout..' network handler crash: '..tostring(err))
  assert(ext.refreshes==before+1,'A deveria atualizar o catalogo')
  local save=ext.refresh
  ext.refresh=function() error('simulated offline IO') end
  ok,err=pcall(love.gamepadpressed,nil,'y')
  assert(ok,layout..' unavailable backend crash: '..tostring(err))
  ext.refresh=save
 end
 -- Verify global input error guard works for errors outside refreshCatalog.
 screen('update_local')
 local saved=updater.localPackages
 updater.localPackages=function() error('INJECTED_REAL_INPUT_ERROR') end
 local ok,err=pcall(love.gamepadpressed,nil,'a')
 assert(ok,layout..' unhandled input error: '..tostring(err))
 updater.localPackages=saved
 local current=currentScreen()
 assert(current=='home','after backend error should return Home')
 local log=assert(io.open(root..'/state/ui_last_error.log','r'))
 local text=log:read('*a');log:close()
 assert(text:find('INJECTED_REAL_INPUT_ERROR',1,true),'real traceback must be persisted')
 assert(text:find('stack traceback',1,true))
end
-- Executa eventos de update e draw com falhas reais injetadas.
screen('home')
local ok,err=pcall(love.update,0.016)
assert(ok,'update sem erro: '..tostring(err))
local deviceModule=package.loaded.device_status
local savedUpdate=deviceModule.update
deviceModule.update=function() error('INJECTED_UPDATE_FAILURE') end
ok,err=pcall(love.update,0.016)
assert(ok,'update falho nao deve gerar tela azul: '..tostring(err))
deviceModule.update=savedUpdate
assert(currentScreen()=='home')
local latest=assert(io.open(root..'/state/ui_last_error.log','r'))
local raw=latest:read('*a');latest:close()
assert(raw:find('INJECTED_UPDATE_FAILURE',1,true),'update deve gravar erro')
-- Frame renderizado nunca deve propaguar erro, inclusive no Clássico.
settings.layout='classic';require('theme').setLayout('classic')
screen('settings')
local panelOld=ui.panel
ui.panel=function() error('INJECTED_DRAW_FAILURE') end
ok,err=pcall(love.draw)
assert(ok,'draw falho deve recuperar: '..tostring(err))
ui.panel=panelOld
assert(currentScreen()=='home','erro de desenho deve voltar ao Inicio')
latest=assert(io.open(root..'/state/ui_last_error.log','r'))
raw=latest:read('*a');latest:close()
assert(raw:find('INJECTED_DRAW_FAILURE',1,true),'draw deve gravar erro')
-- Clique no tema Clássico também deve ser recuperado.
local display=require('display_resolution')
local pointerOld=display.pointer
display.pointer=function() error('INJECTED_MOUSE_FAILURE') end
ok,err=pcall(love.mousepressed,200,200,1)
assert(ok,'mouse no Clássico nao deve gerar tela azul')
display.pointer=pointerOld
latest=assert(io.open(root..'/state/ui_last_error.log','r'))
raw=latest:read('*a');latest:close()
assert(raw:find('INJECTED_MOUSE_FAILURE',1,true),'mouse deve gravar erro')
os.getenv=realGetenv
print('PASS runtime main: '..count..' route renders; guarded refresh, update, draw and mouse in LuaJIT/Lua53')
