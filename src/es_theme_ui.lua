-- R36S ROMS STORE: temas EmulationStation com o layout nativo (640x480).
-- Fontes: galeria OGA (Jetup13), colecoes ThemeMaster e catalogo local do HUB.
-- Nao aplica o tema automaticamente; instalacao sempre requer confirmacao.
local ui=require('ui')
local theme=require('theme')
local json=require('json')
local M={items={},all={},selected=1,sizeIndex=2,modal=nil,status='',installed={},source='local',busy=false,
  lang='pt',timer=0,seenRaw=nil,selection='themes',available=false}
local RES={'480x320','640x480','854x480','960x544','720x720'}
local T={
 pt={title='Temas EmulationStation',subtitle='TEMAS DO SISTEMA',screen='Resolução',source='Fonte',no='Nenhum tema compatível',
   browse='Temas para sua tela',installed='INSTALADO',available='DISPONÍVEL',untested='NÃO TESTADO',good='COMPATÍVEL',
   bad='NÃO FUNCIONA',author='Autor',folder='Destino',select='A instalar',refresh='Y atualizar',
   adjust='L/R resolução',back='B voltar',confirm='Instalar o tema selecionado?',replace='Uma versão existente terá backup.',
   legal='Instale apenas temas cujo uso seja permitido.',yes='A confirmar',cancel='B cancelar',
   missing='Pasta de temas não localizada',install='INSTALAR',offline='Catálogo local/offline',status='Status',
   active='O tema não será ativado automaticamente.',working='Aguardando resposta...',unknown='Não informado'},
 en={title='EmulationStation Themes',subtitle='SYSTEM THEMES',screen='Resolution',source='Source',no='No compatible themes',
   browse='Themes for your screen',installed='INSTALLED',available='AVAILABLE',untested='UNTESTED',good='COMPATIBLE',
   bad='NOT WORKING',author='Author',folder='Destination',select='A install',refresh='Y refresh',
   adjust='L/R resolution',back='B back',confirm='Install the selected theme?',replace='Existing theme will be backed up.',
   legal='Only install themes you may use.',yes='A confirm',cancel='B cancel',missing='Themes folder not found',
   install='INSTALL',offline='Offline catalog',status='Status',active='Theme is not auto-activated.',
   working='Waiting for response...',unknown='Unknown'},
 es={title='Temas EmulationStation',subtitle='TEMAS DEL SISTEMA',screen='Resolución',source='Fuente',no='Sin temas compatibles',
   browse='Temas para tu pantalla',installed='INSTALADO',available='DISPONIBLE',untested='SIN PROBAR',good='COMPATIBLE',
   bad='NO FUNCIONA',author='Autor',folder='Destino',select='A instalar',refresh='Y actualizar',
   adjust='L/R resolución',back='B volver',confirm='¿Instalar el tema seleccionado?',replace='Se guardará una copia del tema anterior.',
   legal='Instala solo temas autorizados.',yes='A confirmar',cancel='B cancelar',missing='Carpeta de temas no encontrada',
   install='INSTALAR',offline='Catálogo sin conexión',status='Estado',active='No se activa automáticamente.',
   working='Esperando respuesta...',unknown='Desconocido'},
 ru={title='Темы EmulationStation',subtitle='ТЕМЫ СИСТЕМЫ',screen='Разрешение',source='Источник',no='Совместимых тем нет',
   browse='Темы для вашего экрана',installed='УСТАНОВЛЕНО',available='ДОСТУПНО',untested='НЕ ПРОВЕРЕНО',good='СОВМЕСТИМО',
   bad='НЕ РАБОТАЕТ',author='Автор',folder='Папка',select='A установить',refresh='Y обновить',
   adjust='L/R размер',back='B назад',confirm='Установить выбранную тему?',replace='Старая версия будет сохранена.',
   legal='Устанавливайте только разрешённые темы.',yes='A подтвердить',cancel='B отмена',
   missing='Каталог тем не найден',install='УСТАНОВИТЬ',offline='Локальный каталог',status='Состояние',
   active='Тема не включается автоматически.',working='Ожидание ответа...',unknown='Неизвестно'}
}
local function t(k) return (T[M.lang] or T.pt)[k] or T.pt[k] or k end
local function txt(s,x,y,size,color,width,center) ui.text(s,x,y,size,color,width,center) end
local function rect(x,y,w,h,color,rad,edge,alpha) ui.rect(x,y,w,h,color,rad,edge,alpha) end
local function ell(s,n) return ui.ellipsize(tostring(s or ''),n or 24) end
local function file_read(path)
 local f=io.open(path,'rb');if not f then return nil end
 local s=f:read('*a');f:close();return s
end
local function file_write(path,s)
 local f=io.open(path,'wb');if not f then return false end
 f:write(s);f:close();return true
end
local function shq(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function selected_size() return RES[M.sizeIndex] end
local function compatible(item)
 local v=(item.res or {})[selected_size()] or 'untested'
 return v
end
local function installed_path(item)
 return M.installed[string.lower(item.folder or '')]
end
local function recalc()
 local prev=M.items[M.selected] and M.items[M.selected].id
 M.items={}
 for _,it in ipairs(M.all) do
  if type(it)=='table' and type(it.name)=='string' and compatible(it)~='no' then
   M.items[#M.items+1]=it
  end
 end
 local order={yes=1,untested=2}
 table.sort(M.items,function(a,b)
  local x,y=order[compatible(a)] or 4,order[compatible(b)] or 4
  if x~=y then return x<y end
  return (a.name or ''):lower()<(b.name or ''):lower()
 end)
 M.selected=1
 for i,it in ipairs(M.items) do if it.id==prev then M.selected=i;break end end
end
local function read_status()
 local raw=file_read(M.home..'/state/es_theme_status.json')
 if not raw or raw==M.seenRaw then return end
 M.seenRaw=raw
 local ok,data=pcall(json.decode,raw)
 if not ok or type(data)~='table' then return end
 if data.phase=='working' or data.phase=='downloading' or data.phase=='extracting' then
  M.busy=true
 elseif data.phase=='done' or data.phase=='error' then M.busy=false end
 M.status=tostring(data.message or '')
 if type(data.installed)=='table' then M.installed=data.installed end
 if type(data.themes)=='table' and #data.themes>0 then
  M.all=data.themes;recalc()
 end
 if type(data.roots)=='table' then M.available=#data.roots>0 end
 M.source=data.source or M.source
end
local function spawn(op,id,size)
 if M.busy then return false end
 M.busy=true;M.seenRaw=nil;M.status=t('working')
 local base=M.home..'/bin/es_theme_manager.py'
 local command='python3 '..shq(base)..' '..op
 if id then command=command..' '..shq(id)..' '..shq(size or selected_size()) end
 local shell='( '..command..' >/dev/null 2>&1 ) &'
 local result=os.execute(shell)
 if result==false then M.busy=false;M.status=t('unknown');return false end
 return true
end
function M.init(home)
 M.home=home
 local ok,why=require('ota_bootstrap').run(home)
 if not ok then M.status='OTA: '..tostring(why) end
 local preferred=file_read(home..'/state/es_theme_resolution.txt') or ''
 preferred=preferred:match('^%s*(.-)%s*$')
 if preferred=='' then
  local size=file_read('/sys/class/graphics/fb0/virtual_size') or ''
  local w,h=size:match('(%d+),(%d+)')
  if w and h then preferred=w..'x'..h end
 end
 for i,r in ipairs(RES) do if r==preferred then M.sizeIndex=i end end
 local ok,raw=pcall(love.filesystem.read,'es_themes_seed.json')
 if ok and raw then
  local parsed=json.decode(raw)
  if type(parsed)=='table' and type(parsed.themes)=='table' then
   for _,v in ipairs(parsed.themes) do
    v.res={}
    for _,sz in ipairs(RES) do v.res[sz]=(sz==v.resolution and 'yes' or 'untested') end
    M.all[#M.all+1]=v
   end
  end
 end
 recalc()
end
function M.enter()
 if not M.home then return end
 M.modal=nil;M.selected=1
 read_status()
 spawn('refresh')
end
function M.update(dt)
 M.timer=M.timer+(dt or 0)
 if M.timer>=0.6 then M.timer=0;read_status() end
end
function M.size() return selected_size() end
function M.change_size(step)
 M.sizeIndex=(M.sizeIndex-1+step+#RES)%#RES+1
 file_write(M.home..'/state/es_theme_resolution.txt',selected_size()..'\n')
 recalc()
end
function M.draw(header,lang)
 M.lang=lang or 'pt'
 header(t('subtitle'),t('title'))
 ui.panel(180,92,440,37)
 txt(t('screen')..':',193,102,11,theme.muted,90)
 txt('‹ '..selected_size()..' ›',290,100,14,theme.accent,158,true)
 txt(#M.items..' '..t('browse'),450,105,9,theme.muted,156)
 for row=0,5 do
  local first=math.max(1,math.min(M.selected-2,math.max(1,#M.items-5)))
  local i=first+row
  local it=M.items[i]
  if it then
   local y=140+row*45
   ui.panel(180,y,251,42,i==M.selected)
   txt(ell(it.name,29),191,y+5,11,theme.text,230)
   local s=installed_path(it) and t('installed') or
     (compatible(it)=='yes' and t('good') or t('untested'))
   txt(ell(it.author or it.source or '',23),191,y+25,9,theme.muted,154)
   txt(s,336,y+25,9,installed_path(it) and theme.green or theme.accent,88,true)
  end
 end
 ui.panel(440,140,180,266)
 local it=M.items[M.selected]
 if it then
  txt(ell(it.name,21),452,154,13,theme.accent,157)
  txt(t('author')..':',452,190,9,theme.low,154)
  txt(ell(it.author or t('unknown'),22),452,206,10,theme.text,154)
  txt(t('status')..':',452,237,9,theme.low,154)
  txt(compatible(it)=='yes' and t('good') or t('untested'),452,253,10,
    compatible(it)=='yes' and theme.green or theme.accent,155)
  txt(t('folder')..':',452,281,9,theme.low,154)
  txt(ell(it.folder or '?',25),452,297,9,theme.text,154)
  rect(451,345,158,38,theme.accent,7)
  txt(t('install'),456,355,12,theme.bg,146,true)
 else
  txt(t('no'),453,210,11,theme.muted,154,true)
 end
 txt(t('adjust')..'   '..t('refresh')..'   '..t('back'),183,416,10,theme.muted,435)
 if M.status~='' then txt(ell(M.status,56),184,429,9,M.busy and theme.accent or theme.low,432) end
 if M.modal then
  rect(0,0,640,480,{0,0,0},0,nil,.79)
  ui.panel(125,142,390,205,true)
  txt(t('confirm'),145,162,16,theme.text,352,true)
  txt(ell(M.modal.name,48),143,198,13,theme.accent,351,true)
  txt(t('replace'),145,224,10,theme.muted,350,true)
  txt(t('active'),145,241,9,theme.low,350,true)
  txt(t('yes')..'       '..t('cancel'),148,303,12,theme.text,346,true)
 end
end
function M.key(key)
 if M.modal then
  if key=='a' then
   local m=M.modal;M.modal=nil
   if not spawn('install',m.id,selected_size()) then M.status=t('unknown') end
  elseif key=='b' or key=='x' then M.modal=nil end
  return true
 end
 if key=='b' then return false end
 if key=='up' then M.selected=math.max(1,M.selected-1)
 elseif key=='down' then M.selected=math.min(#M.items,M.selected+1)
 elseif key=='left' or key=='l' then M.change_size(-1)
 elseif key=='right' or key=='r' then M.change_size(1)
 elseif key=='y' then spawn('refresh')
 elseif key=='a' and not M.busy then
  local it=M.items[M.selected]
  if it then M.modal={id=it.id,name=it.name} end
 end
 return true
end
function M.mouse(x,y)
 if M.modal then
  if y>=270 then if x<325 then M.key('a') else M.key('b') end end
  return true
 end
 if y>=93 and y<=133 then
  if x<291 then M.change_size(-1) elseif x<446 then M.change_size(1) end
  return true
 end
 if x>=180 and x<=430 and y>=140 and y<=408 then
  local first=math.max(1,math.min(M.selected-2,math.max(1,#M.items-5)))
  local i=first+math.floor((y-140)/45)
  if M.items[i] then M.selected=i end
  return true
 end
 if x>=451 and x<=609 and y>=345 and y<=384 then M.key('a');return true end
 return false
end
function M.hasModal() return M.modal~=nil end
return M
