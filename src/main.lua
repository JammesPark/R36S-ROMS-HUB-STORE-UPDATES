-- R36S ROMS STORE | Tema de 19 telas (conceito HTML 640x480) aplicado em Lua/LÖVE.
-- Catálogo real: GameStoreBR; nenhum jogo demonstrativo é distribuído.
local json=require('json')
local external=require('external')
local ui=require('ui')
local theme=require('theme')
local i18n=require('i18n')
local legal=require('legal_text')
local device=require('device_status')
local music=require('music')
local storeUpdater=require('store_update')
local biosManager=require('bios_manager') -- legado: importacao local preservada
local biosUI=require('bios_enhanced_ui') -- layout nativo + motor de BIOS GPL-3.0
local esUI=require('es_theme_ui') -- temas ES: catálogo ThemeMaster/OGA e instalador isolado
local transferCenter=require('download_center') -- ROM, BIOS, temas e atualização OTA
local transferQueue=require('transfer_queue') -- fila persistente; motores mantem validacoes
local display=require('display_resolution') -- tela fisica + viewport 640x480
local HOME=os.getenv('R36S_STORE_HOME') or '/roms/ports/r36s-roms-store'
local STATE=HOME..'/state'
local mainPages={'home','catalog','bios','es_themes','downloads','installed','favorites','settings','about'}
local menuPages={'home','catalog','bios','es_themes','downloads','installed','favorites','settings','about','exit'}
local screen='startup'
local stack={}
local settings={language='pt',theme='ocean',font_size='medium'}
local languageChosen=false -- salvo apenas depois da escolha inicial do usuario
local aboutScroll=0
local aboutMaxScroll=0
local qrModal=nil -- 'telegram' ou 'livepix'
local qrExpanded=false
local storeUpdateModal=false
local updateConfirm=nil -- {kind, backup}: confirmação de restauração/exclusão
local exitChoice=2 -- 1 Sim, 2 Não
local pendingDelete=nil
local duplicateModal=false
local awaitInspect=false
local awaitDelete=false
local autoListNext=false
local autoSearchNext=false
local favorites={}
local downloads={}
local focus='sidebar'; local menuIndex=1;local categoryIndex=1;local gameIndex=1
local favIndex=1;local installIndex=1;local historyIndex=1;local updateBackupIndex=1;local updateHistoryScroll=0;local updateLocalIndex=1;local settingsIndex=1;local downloadScroll=0
local languageIndex=1;local themeIndex=1;local fontSizeIndex=2;local searchIndex=1;local query='';local searchResultIndex=1
local selectedGame=nil
local lastStatus='';local lastManifest='';local coverImages={};local coverSeen={}
local clock=0;local startupTime=0;local notice='';local noticeTime=0
local selectedCard=1;local transferHandled=false
local homeFocus='explore';local homeSlideIndex=1;local homeOverviewIndex=1;local homeSlideClock=0
local storageInfo={};local storageLast=-999
local suboptions={'languages','themes','font_size','storage','network','updates','help'}
local fontSizes={'small','medium','large'}
local keyboard={'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','SPACE','DEL','CLEAR','OK'}
-- Versão exibida obtida do arquivo VERSION incluído no game.love.
local cachedAppVersion
local function appVersion()
  if cachedAppVersion then return cachedAppVersion end
  cachedAppVersion='indisponível'
  if love and love.filesystem and type(love.filesystem.read)=='function' then
    local ok,raw=pcall(love.filesystem.read,'VERSION')
    if ok and type(raw)=='string' then
      local value=raw:match('^%s*(.-)%s*$')
      if value and value:match('^%d+%.%d+%.%d+') then cachedAppVersion=value end
    end
  end
  return cachedAppVersion
end
local function tr(key) return i18n.get(settings.language,key) end
local function txt(s,x,y,sz,c,w,center) ui.text(s,x,y,sz,c,w,center) end
local function R(x,y,w,h,c,round,border,a) ui.rect(x,y,w,h,c,round,border,a) end
local function panel(x,y,w,h,active) ui.panel(x,y,w,h,active) end
local function read(path)
  local f=io.open(path,'rb');if not f then return nil end
  local s=f:read('*a');f:close();return s
end
local function write(path,value)
  local f=io.open(path,'wb');if not f then return false end
  f:write(value);f:close();return true
end
local function encodeString(s)
  local replacements={['\\']='\\\\',['"']='\\"',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
  return '"'..tostring(s or ''):gsub('[\\"\n\r\t]',replacements)..'"'
end
local function saveSettings()
  return write(STATE..'/roms_settings.json',string.format('{"language":%s,"theme":%s,"font_size":%s,"language_chosen":%s}',
    encodeString(settings.language),encodeString(settings.theme),encodeString(settings.font_size),tostring(languageChosen)))
end
local function saveFavorites()
  local items={}
  for _,g in ipairs(favorites) do
    local pairs={}
    for _,k in ipairs({'name','category','game_path','image_url','cover_id'}) do
      if type(g[k])=='string' then pairs[#pairs+1]=encodeString(k)..':'..encodeString(g[k]) end
    end
    items[#items+1]='{'..table.concat(pairs,',')..'}'
  end
  write(STATE..'/roms_favorites.json','['..table.concat(items,',')..']')
end
local function loadData()
  local c=json.decode(read(STATE..'/roms_settings.json') or '')
  if type(c)=='table' then
    languageChosen=(c.language_chosen==true)
    for i,l in ipairs(i18n.languages) do if l.code==c.language then settings.language=l.code;languageIndex=i end end
    for _,t in ipairs(theme.options) do if t.key==c.theme then settings.theme=t.key end end
    for idx,v in ipairs(fontSizes) do
      if v==c.font_size then settings.font_size=v;fontSizeIndex=idx end
    end
  end
  local f=json.decode(read(STATE..'/roms_favorites.json') or '')
  if type(f)=='table' then
    for _,v in ipairs(f) do
      if type(v)=='table' and type(v.game_path)=='string' and type(v.name)=='string' then
        favorites[#favorites+1]=v
      end
    end
  end
  theme.set(settings.theme)
  ui.setFontSize(settings.font_size)
end
local function reloadDownloads()
  local s=read(STATE..'/roms_downloads.json')
  if not s or s==lastManifest then return end
  local list=json.decode(s)
  if type(list)=='table' then downloads=list;lastManifest=s end
end
local function favoriteIdx(g)
  if not g or not g.game_path then return nil end
  for i,item in ipairs(favorites) do
    if item.game_path==g.game_path then return i end
  end
end
local function toggleFavorite(g)
  if not g then return end
  local index=favoriteIdx(g)
  if index then table.remove(favorites,index);notice='★ '..tr('favorites')..': -'
  else favorites[#favorites+1]={name=g.name,category=g.category,game_path=g.game_path,
    image_url=g.image_url or '',cover_id=g.cover_id or ''}
    notice='★ '..tr('favorites')..': +'
  end
  saveFavorites();noticeTime=2.4
end
local function exists(path)
  local f=io.open(path,'rb');if not f then return false end
  f:close();return true
end
local function sdLocation(game)
  local a,b=false,false
  if not game then return tr('not_downloaded') end
  for _,d in ipairs(downloads) do
    if d.game_path==game.game_path and type(d.filename)=='string' and
       type(d.category)=='string' and d.filename:find('/',1,true)==nil and
       d.category:match('^[a-z0-9_%-]+$') then
      local path=(d.card=='sd2' and '/roms2/' or '/roms/')..d.category..'/'..d.filename
      if exists(path) then if d.card=='sd2' then b=true else a=true end end
    end
  end
  if a and b then return tr('both') end
  if a then return 'SD1' end
  if b then return 'SD2' end
  return tr('not_downloaded')
end
local function currentGames()
  if screen=='favorites' then return favorites end
  if screen=='search_results' then return external.searchResults end
  return external.games
end
local function dfUsage(path)
  local pipe=io.popen('df -Pk '..path..' 2>/dev/null','r')
  if not pipe then return nil end
  local line
  for v in pipe:lines() do line=v end
  pipe:close()
  if not line then return nil end
  local tokens={}
  for tok in line:gmatch('%S+') do tokens[#tokens+1]=tok end
  if #tokens<5 then return nil end
  local total,available=tonumber(tokens[2]),tonumber(tokens[4])
  if not total or total<=0 or not available then return nil end
  return {total=total*1024,free=math.max(0,available)*1024}
end
local function mountSource(path)
  local cmd='findmnt -T '..path..' -no SOURCE 2>/dev/null'
  local pipe=io.popen(cmd,'r')
  if not pipe then return nil end
  local src=pipe:read('*l');pipe:close()
  return src and src~='' and src or nil
end
local function refreshStorage()
  local sd1=mountSource('/roms')
  local sd2=mountSource('/roms2')
  storageInfo[1]=dfUsage('/roms')
  -- SD2 não pode mostrar o espaço do SD1 ou da raiz quando não montado.
  storageInfo[2]=(sd1 and sd2 and sd1~=sd2) and dfUsage('/roms2') or nil
  storageLast=clock
end
local function formatBytes(bytes)
  if not bytes then return tr('unavailable') end
  local gb=bytes/1073741824
  if gb>=1 then return string.format('%.1f GB',gb) end
  return string.format('%.0f MB',bytes/1048576)
end

local function navigate(route)
  if screen~=route then stack[#stack+1]=screen end
  screen=route
  if route=='exit_confirm' then exitChoice=2 end
  if route=='bios' then biosUI.enter() end
  if route=='es_themes' then esUI.enter() end
  music.updateRoute(screen)
  if route=='storage' then refreshStorage() end
  if route=='font_size' then
    for idx,v in ipairs(fontSizes) do if v==settings.font_size then fontSizeIndex=idx end end
  end
end
local function mainRoute(route)
  if route=='about' then aboutScroll=0 end
  screen=route;stack={};focus=route=='home' and 'sidebar' or 'grid'
  if route=='home' then homeFocus='explore';homeOverviewIndex=1 end
  for i,k in ipairs(mainPages) do if k==route then menuIndex=i end end
  if route=='catalog' then external.enter() end
  if route=='bios' then biosUI.enter() end
  if route=='es_themes' then esUI.enter() end
  music.updateRoute(screen)
end
local function back()
  if #stack>0 then screen=table.remove(stack)
  elseif screen~='home' then mainRoute('home') end
  music.updateRoute(screen)
end
local function selectedFromGames()
  local list=currentGames()
  return list[screen=='search_results' and searchResultIndex or gameIndex]
end
local function enterGame(g)
  if not g then return end
  selectedGame=g
  navigate('detail')
end
local function chooseCategory()
  local cat=external.categories[categoryIndex]
  if cat then
    external.categoryChange(cat.category)
    gameIndex=1;focus='grid'
  end
end
local function cachedImage(game)
  if not game or not game.cover_id or game.cover_id=='' then return nil end
  local id=game.cover_id
  if coverImages[id] then return coverImages[id] end
  if coverSeen[id] and clock-coverSeen[id]<3 then return nil end
  coverSeen[id]=clock
  local bytes=read(STATE..'/covers/'..id..'.img')
  if not bytes or #bytes>700*1024 then return nil end
  local ok,im=pcall(function()
    local file=love.filesystem.newFileData(bytes,'rom-cover.png')
    return love.graphics.newImage(file)
  end)
  if ok and im then
    local count=0
    for _ in pairs(coverImages) do count=count+1 end
    if count>14 then coverImages={} end
    coverImages[id]=im
    return im
  end
end
local function cover(game,x,y,w,h,index)
  ui.poster(x,y,w,h,game and game.name or '?',index or 1)
  local img=cachedImage(game)
  if img then
    R(x,y,w,h,theme.panel,4)
    ui.imageContain(img,x+2,y+2,w-4,h-4)
  end
end
local function coverStretch(game,x,y,w,h,index)
  local img=cachedImage(game)
  if img then
    ui.imageStretch(img,x,y,w,h)
  else
    cover(game,x,y,w,h,index)
  end
end
local function platformTitle(code)
  code=tostring(code or '')
  if code=='ALL' then return tr('all') end
  if code:lower()=='ports' then return 'Homebrew' end
  local aliases={nes='NES',snes='SNES',psx='PSX',ps1='PS1',ps2='PS2',psp='PSP',
    gba='GBA',gb='GB',gbc='GBC',nds='NDS',n64='N64',n3ds='3DS',mame='MAME',
    nintendo64='Nintendo 64',megadrive='Mega Drive',genesis='Genesis',
    dreamcast='Dreamcast',saturn='Saturn',wii='Wii',gamecube='GameCube'}
  local raw=code:lower()
  if aliases[raw] then return aliases[raw] end
  return raw:gsub('(%a)([%w]*)',function(c,rest) return c:upper()..rest end)
end
local function sideItem(name,y,active,index,count,compact)
  local h=compact and 29 or 34
  local inner=compact and 6 or 9
  if active then
    R(13,y,134,h,theme.panel2,8,theme.accent)
    R(13,y+7,3,h-14,theme.accent,1)
  end
  -- Navegação principal: 10 opções em 640x480, sem cortar a barra inferior.
  local iconColor=active and theme.accent or theme.muted
  if screen=='catalog' or screen=='search_results' then
    local c=external.categories[index]
    ui.platformIcon(c and c.category or 'ALL',26,y+inner,iconColor)
  else
    ui.menuIcon(menuPages[index] or 'home',26,y+inner,iconColor)
  end
  txt(ui.ellipsize(name,17),47,y+inner,11,active and theme.text or theme.muted,83)
  if count then txt(tostring(count),131,y+inner+1,9,theme.accent,13) end
end
local function sidebar()
  local isCatalog=screen=='catalog' or screen=='search_results'
  local isCategory=isCatalog
  ui.layout(isCatalog,focus)
  if isCategory then
    txt(tr('platforms'),27,89,10,theme.low)
    local top=121
    local total=#external.categories
    local scroll=math.max(1,math.min(categoryIndex-4,total-7))
    for idx=scroll,math.min(total,scroll+7) do
      local cat=external.categories[idx]
      local name=platformTitle(cat.category)
      sideItem(name,top+(idx-scroll)*37,cat.category==external.category,idx)
      if focus=='sidebar' and idx==categoryIndex then ui.stroke(16,top+(idx-scroll)*37+2,128,30,theme.accent,7,2) end
    end
  else
    txt(tr('navigation'),27,89,10,theme.low)
    for i,route in ipairs(menuPages) do
      local y=114+(i-1)*31
      sideItem(tr(route),y,menuIndex==i,i,nil,true)
      if screen=='home' and focus=='sidebar' and menuIndex==i then
        ui.stroke(15,y+1,130,27,theme.accent,7,2)
      end
    end
  end
  txt('●',20,449,11,theme.green)
  txt('ROMS STORE',30,449,10,theme.muted)
  txt('v'..appVersion(),30,465,9,theme.low,125)
end
local function header(eyebrow,title,right)
  ui.kicker(eyebrow,179,23)
  txt(title,179,42,24,theme.text,440)
  if right then ui.pill(right,548,15,78,false) end
end
local function footer(phrase)
  if screen=='catalog' or screen=='search_results' then
    ui.catalogFooter(tr('select'),tr('back'),tr('search_short'),tr('favorites'))
  else
    ui.footer(tr('select'),tr('back'))
  end
  -- A versão fica na barra lateral; a área do rodapé é reservada aos controles.
end
local function card(game,x,y,w,h,idx,active,badge)
  panel(x,y,w,h,active)
  -- A imagem inteira fica visível; texto isolado numa faixa inferior.
  local coverH=h-34
  cover(game,x+3,y+3,w-6,coverH-4,idx)
  if badge then
    R(x+7,y+coverH-19,w-14,17,theme.sidebar,4,nil,.93)
    txt(ui.ellipsize(badge,18),x+10,y+coverH-16,10,theme.accent,w-20)
  end
  txt(ui.ellipsize(game.name or '?',26),x+7,y+h-29,10,theme.text,w-14)
  if active then ui.stroke(x,y,w,h,theme.accent,9,2) end
end
local function centerEmpty(text,sub)
  panel(180,135,439,243)
  txt(text,201,213,15,theme.text,400,true)
  if sub then txt(sub,201,246,12,theme.muted,400,true) end
end
local function totalRoms()
  return external.totalCatalog()
end

local function homePage()
  header(tr('welcome'),tr('title_home'))
  -- Painel superior: o download real substitui o texto promocional anterior.
  -- Usa o mesmo estado do backend que alimenta a tela Downloads.
  panel(179,103,441,87,focus=='content' and homeFocus=='explore')
  ui.kicker(tr('current_download'),194,111)
  local current=transferCenter.current()
  if current then
    local kind=transferCenter.label(settings.language,current.kind)
    txt(ui.ellipsize(current.name or kind,34),194,132,12,theme.text,263)
    local tag=current.kind=='rom' and tostring(current.detail or 'SD1') or kind
    txt(ui.ellipsize(tag,6),459,132,10,theme.accent,29,true)
    local expected=math.max(0,tonumber(current.total) or 0)
    local downloaded=math.max(0,tonumber(current.done) or 0)
    local percent=expected>0 and math.max(0,math.min(1,downloaded/expected)) or nil
    R(194,155,258,9,theme.border,4)
    if percent and percent>0 then R(194,155,258*percent,9,theme.green,4) end
    txt(percent and string.format('%d%%',math.floor(percent*100+.5)) or '—',458,152,11,theme.text,29,true)
    -- A mesma velocidade/ETA da Central de Downloads aparece no Inicio.
    -- Tres areas separadas, sem invadir o botao Downloads em x=495.
    local sizeText
    if expected>0 then
      sizeText=string.format('%.1f / %.1f MB',downloaded/1048576,expected/1048576)
    elseif downloaded>0 then
      sizeText=string.format('%.1f MB',downloaded/1048576)
    else
      sizeText=transferCenter.label(settings.language,current.phase)
    end
    txt(ui.ellipsize(sizeText,30),194,173,9,theme.muted,141)
    local rate=transferCenter.rateText(current)
    local eta=transferCenter.etaText(current)
    if rate~='—' then txt(rate,338,173,9,theme.accent,90,true) end
    if eta~='—' then txt(eta,432,173,9,theme.muted,55,true) end
  else
    txt(tr('no_current_download'),194,138,12,theme.muted,287)
  end
  -- Botão abre a área Downloads, também pelo botão A quando o painel tem foco.
  local actionX,actionY,actionW,actionH=495,147,112,32
  R(actionX,actionY,actionW,actionH,theme.panel2,7,theme.accent)
  if focus=='content' and homeFocus=='explore' then
    ui.stroke(actionX,actionY,actionW,actionH,theme.text,7,2)
  end
  txt(tr('view_downloads'),actionX+4,actionY+9,10,theme.accent,actionW-8,true)
  -- Os titulos compartilham a mesma altura, mas o destaque e centralizado
  -- pelo retangulo REAL do slide para evitar deslocamentos visuais.
  local sectionTitleY=209
  local slideX,slideY,slideW,slideH=428,237,166,187
  txt(tr('overview'),180,sectionTitleY,12,theme.text,190)
  txt(tr('featured'),slideX,sectionTitleY,12,theme.text,slideW,true)
  local count=totalRoms()
  local stats={{tr('catalog_games'),count and tostring(count) or '—'},
    {tr('installed_games'),tostring(#downloads)},
    {tr('favorites'),tostring(#favorites)}}
  for i,item in ipairs(stats) do
    local y=237+(i-1)*64
    panel(180,y,190,57,focus=='content' and homeFocus=='overview' and homeOverviewIndex==i)
    txt(ui.ellipsize(item[1],23),191,y+6,11,theme.muted,166)
    txt(item[2],191,y+27,19,theme.accent,162)
  end
  -- Area visual limpa: so capa + indicadores (sem nomes de ROMs).
  panel(slideX,slideY,slideW,slideH,focus=='content' and homeFocus=='featured')
  local total=#external.games
  if total==0 then
    txt(tr('loading'),slideX+8,299,11,theme.muted,slideW-16,true)
  else
    homeSlideIndex=math.max(1,math.min(total,homeSlideIndex))
    local game=external.games[homeSlideIndex]
    -- A capa ocupa o cartao quase inteiro; o rodape reserva apenas as bolinhas.
    -- ui.poster e chamado sem showName no fallback offline.
    coverStretch(game,slideX+6,slideY+6,slideW-12,slideH-32,homeSlideIndex)
    if total>1 then
      local shown=math.min(5,total)
      local first=math.max(1,math.min(homeSlideIndex-math.floor(shown/2),total-shown+1))
      local step=11
      local dotCenterX=slideX+slideW/2
      local firstDotX=dotCenterX-(shown-1)*step/2
      for n=0,shown-1 do
        local dotIndex=first+n
        ui.color(dotIndex==homeSlideIndex and theme.accent or theme.low)
        love.graphics.circle('fill',firstDotX+n*step,slideY+slideH-10,dotIndex==homeSlideIndex and 2.9 or 1.9)
      end
    end
  end
  footer()
end
-- Lista de ROMs e preview grande da capa do item em foco.
local function gameList(items,chosen)
  local total=#items
  if total==0 then
    centerEmpty(external.error and tr('network_error') or tr('loading'),tr('press_sync'))
    return
  end
  -- Rolagem contínua: viewport de 6 itens acompanha a seleção na lista inteira.
  local first=math.max(1,math.min(chosen-2,math.max(1,total-5)))
  local last=math.min(total,first+5)
  for i=first,last do
    local row=i-first;local y=128+row*47
    local active=chosen==i and focus~='sidebar'
    panel(180,y,237,42,active)
    R(188,y+12,3,18,active and theme.accent or theme.border,1)
    txt(ui.ellipsize(items[i].name or '?',27),197,y+7,12,active and theme.text or theme.muted,185)
    if favoriteIdx(items[i]) then txt('♥',396,y+9,13,theme.green,17,true) end
    txt(string.format('%02d',i),197,y+26,9,active and theme.accent or theme.low,45)
  end
  local selected=items[math.max(1,math.min(total,chosen))]
  panel(428,128,191,289,true)
  -- Apenas a capa do jogo selecionado: amplia até preencher, sem títulos extras.
  coverStretch(selected,434,134,179,277,chosen)
  ui.stroke(431,131,185,283,theme.accent,7,1)
end
local function catalogPage()
  header(tr('library'),tr('title_catalog'))
  R(578,56,41,29,theme.panel,8,theme.border)
  ui.searchIcon(591,63,theme.accent)
  txt(ui.ellipsize(platformTitle(external.category),18),180,102,12,theme.muted,220)
  txt('• '..(external.total>0 and external.total or #external.games)..' '..tr('games'),352,103,11,theme.accent,119)
  gameList(external.games,gameIndex)
  txt(tostring(#external.games)..' / '..tostring(external.total or #external.games),478,420,10,theme.muted,135)
  footer()
end
local function searchResultsPage()
  header(tr('search'),tr('search_results'))
  ui.searchIcon(590,66,theme.accent)
  txt(ui.ellipsize(external.searchQuery,20),180,103,12,theme.accent,232)
  txt(tostring(external.searchTotal)..' '..tr('games'),443,103,11,theme.muted,165)
  if external.busy() and external.pending=='search' then
    centerEmpty(tr('loading'),tr('search'))
  elseif external.error then
    centerEmpty(tr('network_error'),external.message)
  elseif #external.searchResults==0 then
    centerEmpty(tr('no_results'),tr('search'))
  else
    gameList(external.searchResults,searchResultIndex)
  end
  txt(tostring(#external.searchResults)..' / '..tostring(external.searchTotal or 0),475,420,10,theme.muted,138)
  footer()
end
local function detailsPage()
  local g=selectedGame or external.games[1]
  header(tr('game'),tr('detail'))
  if not g then centerEmpty(tr('invalid'));footer();return end
  panel(179,113,441,260)
  cover(g,192,129,171,201,gameIndex)
  txt(ui.ellipsize(g.name,32),376,138,17,theme.text,228)
  txt(tostring(g.category or ''):upper(),376,183,12,theme.accent,228)
  txt('● '..sdLocation(g),376,211,11,theme.muted,220)
  txt('★ '..(favoriteIdx(g) and tr('favorites') or tr('favorite_toggle')),376,240,11,theme.muted,215)
  R(376,282,227,35,theme.accent,8)
  txt(tr('download')..' ›',395,293,13,theme.bg,205)
  R(179,382,441,36,theme.panel,7,theme.border)
  txt(tr('favorite_toggle'),190,393,11,theme.accent,402)
  footer()
end
local function searchPage()
  header(tr('search'),tr('search_results'))
  panel(179,102,441,47,true)
  txt(ui.ellipsize(query,44)..(math.floor(clock*2)%2==0 and '|' or ''),194,117,15,theme.text,405)
  txt(tr('search_hint'),187,155,10,theme.low,430)
  for i,key in ipairs(keyboard) do
    local x=180+((i-1)%10)*44;local y=185+math.floor((i-1)/10)*51
    panel(x,y,39,43,searchIndex==i)
    txt(key=='SPACE' and '_' or key=='CLEAR' and 'CLR' or key=='DEL' and '←' or key,
      x+3,y+12,10,searchIndex==i and theme.accent or theme.text,33,true)
  end
  txt(tr('select')..': A    '..tr('search')..': START',187,371,11,theme.muted,430)
  footer()
end
local function confirmPage()
  header(tr('confirm'),tr('choose_sd'))
  local g=selectedGame
  if not g then centerEmpty(tr('invalid'));footer();return end
  panel(180,113,440,95)
  cover(g,188,120,104,80,gameIndex)
  txt(ui.ellipsize(g.name,27),308,140,16,theme.text,295)
  txt(tostring(g.category or ''):upper(),308,177,11,theme.muted,290)
  for n=1,2 do
    local x=180+(n-1)*226
    panel(x,228,213,103,selectedCard==n)
    txt('SD'..n,x+18,240,26,selectedCard==n and theme.accent or theme.text)
    txt(n==1 and '/roms/' or '/roms2/',x+18,284,11,theme.muted)
  end
  R(180,350,440,47,theme.accent,9)
  txt(tr('confirm_download')..'  •  SD'..selectedCard,193,366,14,theme.bg,412,true)
  footer()
end
local function transfersPage()
  header(tr('downloads'),tr('title_downloads'))
  local lang=settings.language
  local entries=transferCenter.entries()
  txt(transferCenter.label(lang,'ongoing')..': '..tostring(#transferCenter.active),183,96,12,theme.accent,239)
  txt(transferCenter.label(lang,'queued')..': '..tostring(#transferQueue.items),429,96,10,theme.muted,187,true)
  if #entries==0 then
    panel(180,139,440,270)
    txt(transferCenter.label(lang,'empty'),196,255,12,theme.muted,407,true)
  else
    for slot=1,math.min(6,#entries-transferCenter.scroll) do
      local item=entries[transferCenter.scroll+slot]
      local y=122+(slot-1)*49
      panel(180,y,440,45,transferCenter.selected==transferCenter.scroll+slot)
      local kind=transferCenter.label(lang,item.kind)
      R(188,y+8,4,28,item.phase=='error' and theme.error or item.phase=='done' and theme.green or theme.accent,2)
      txt(kind,200,y+5,10,theme.accent,57)
      txt(ui.ellipsize(tostring(item.name or item.kind or ''),39),257,y+5,11,theme.text,320)
      local phase=transferCenter.label(lang,item.phase or 'done')
      -- O historico antigo pode nao ter done/total; nao causar tela azul.
      local progress,percent=transferCenter.formatProgress(item)
      txt(phase,201,y+24,9,item.phase=='error' and theme.error or item.phase=='done' and theme.green or theme.muted,107)
      local details=progress or ''
      if item.phase=='download' or item.phase=='downloading' then
        local rate=transferCenter.rateText(item)
        local eta=transferCenter.etaText(item)
        if rate~='—' then details=details..'  '..rate end
        if eta~='—' then details=details..'  '..eta end
      end
      txt(ui.ellipsize(details,51),311,y+24,9,theme.muted,277)
      if item.phase~='done' and item.phase~='error' then
        R(201,y+40,394,2,theme.border,1)
        if percent and percent>0 then R(201,y+40,394*percent/100,2,theme.accent,1) end
      end
    end
    if #entries>6 then
      txt(string.format('▲▼  %d-%d / %d',transferCenter.scroll+1,
        math.min(#entries,transferCenter.scroll+6),#entries),450,424,9,theme.muted,162,true)
    end
  end
  local selected=transferCenter.selectedItem()
  local paused=selected and selected.phase=='paused'
  local options={
    pt={pause='Pausar',resume='Retomar',cancel='Cancelar',history='Histórico',back='Voltar'},
    en={pause='Pause',resume='Resume',cancel='Cancel',history='History',back='Back'},
    es={pause='Pausar',resume='Reanudar',cancel='Cancelar',history='Historial',back='Volver'},
    ru={pause='Пауза',resume='Продолжить',cancel='Отмена',history='История',back='Назад'}
  }
  local label=options[lang] or options.pt
  ui.buttonHint(177,448,'A',paused and label.resume or label.pause,69)
  ui.buttonHint(286,448,'X',label.cancel,79)
  ui.buttonHint(403,448,'Y',label.history,72)
  ui.buttonHint(531,448,'B',label.back,51)
end
local function historyPage()
  header(tr('downloads'),tr('history'))
  if #downloads==0 then centerEmpty(tr('history_empty'));footer();return end
  local first=math.max(1,historyIndex-4)
  for idx=first,math.min(#downloads,first+4) do
    local d=downloads[#downloads-idx+1]
    local y=124+(idx-first)*55
    panel(180,y,440,49,idx==historyIndex)
    txt(ui.ellipsize(d.name or '?',38),190,y+6,12,theme.text,330)
    txt((d.card or '?'):upper()..' · '..tostring(d.category or ''),190,y+28,10,theme.muted,340)
  end
  footer()
end
local function installedPage()
  header(tr('manage'),tr('title_installed'))
  local n=#downloads
  txt(tr('files')..': '..n,181,107,12,theme.accent)
  if n==0 then centerEmpty(tr('no_installed'));footer();return end
  local list={}
  for _,d in ipairs(downloads) do list[#list+1]={name=d.name,subtitle=(d.card or ''):upper()..' / '..(d.category or '')} end
  for i=math.max(1,installIndex-5),math.min(#list,math.max(1,installIndex-5)+5) do
    local d=list[i];local y=130+(i-math.max(1,installIndex-5))*46
    panel(180,y,440,42,i==installIndex)
    txt(ui.ellipsize(d.name,39),190,y+6,12,theme.text,415)
    txt(d.subtitle,190,y+23,10,theme.muted,415)
  end
  txt(tr('delete_rom_hint'),183,414,10,theme.accent,422)
  footer()
end
local function favoritesPage()
  header(tr('personalize'),tr('title_favorites'))
  if #favorites==0 then centerEmpty(tr('no_favorites'),tr('favorite_toggle'));footer();return end
  local first=math.floor((favIndex-1)/6)*6+1
  for i=first,math.min(#favorites,first+5) do
    local g=favorites[i]; local slot=i-first
    local x=180+(slot%3)*149;local y=130+math.floor(slot/3)*143
    card(g,x,y,140,133,i,favIndex==i,sdLocation(g))
  end
  footer()
end
local function settingsPage()
  header(tr('personalize'),tr('title_settings'))
  local lang=settings.language
  local values={tr('language'),tr('theme'),tr('font_size'),tr('storage'),tr('network'),
    storeUpdater.tr(lang,'title'),tr('help')}
  local up=storeUpdater.status
  local detail=(up.phase=='available' or up.phase=='ready') and ('v'..tostring(up.version or '?'))
    or storeUpdater.tr(lang,up.phase or 'checking')
  local shown={i18n.languages[1].name,tr('theme_blue'),tr('font_'..settings.font_size),
    tr('free_space')..' / '..tr('total_space'),tr('status'),detail,'A / B / X / Y'}
  for _,o in ipairs(i18n.languages) do if o.code==settings.language then shown[1]=o.name end end
  for _,o in ipairs(theme.options) do if o.key==settings.theme then shown[2]=tr(o.name) end end
  local symbols={'languages','palette','type','hard-drive','wifi','download','circle-help'}
  for i,label in ipairs(values) do
    local y=100+(i-1)*40
    panel(180,y,440,37,i==settingsIndex)
    R(191,y+7,24,24,theme.sidebar,6,theme.border)
    ui.icon(symbols[i],195,y+10,17,17,i==settingsIndex and theme.accent or theme.muted)
    txt(ui.ellipsize(label,38),224,y+2,11,theme.text,354)
    txt(ui.ellipsize(shown[i],56),224,y+21,9,theme.muted,359)
    txt('›',590,y+4,16,theme.accent)
  end
  footer()
end
local function fontSizePage()
  header(tr('personalize'),tr('font_size'))
  txt(tr('font_size_note'),183,104,11,theme.muted,428)
  for i,key in ipairs(fontSizes) do
    local y=146+(i-1)*78
    panel(180,y,440,68,fontSizeIndex==i)
    txt(tr('font_'..key),200,y+12,16,theme.text,309)
    txt('Aa 123',200,y+38,12,theme.muted,272)
    if settings.font_size==key then txt('✓',581,y+22,19,theme.accent) end
  end
  footer()
end
local function languagesPage()
  header(tr('personalize'),tr('languages'))
  txt(tr('language_note'),182,98,11,theme.muted,431)
  for i,lang in ipairs(i18n.languages) do
    local y=123+(i-1)*72
    local active=settings.language==lang.code
    panel(180,y,440,62,languageIndex==i)
    R(193,y+13,42,35,theme.panel2,7,active and theme.accent or theme.border)
    ui.flag(lang.code,198,y+20,32,21)
    txt(lang.name,247,y+20,15,theme.text,290)
    if active then txt('✓',583,y+20,16,theme.accent) end
  end
  footer()
end
local function themesPage()
  header(tr('personalize'),tr('themes'))
  txt(tr('theme_note'),182,96,11,theme.muted,436)
  for i,opt in ipairs(theme.options) do
    local x=180+((i-1)%3)*149;local y=126+math.floor((i-1)/3)*94
    local active=theme.current==opt.key
    panel(x,y,140,86,themeIndex==i)
    R(x+13,y+10,112,30,theme.hex(opt.hex),8)
    txt(ui.ellipsize(tr(opt.name),14),x+9,y+50,11,theme.text,122)
    if active then txt('✓',x+110,y+13,16,theme.bg) end
  end
  footer()
end
local function storagePage()
  header(tr('manage'),tr('storage'))
  for n=1,2 do
    local y=125+(n-1)*146
    panel(180,y,440,130)
    txt('SD'..n,199,y+16,23,theme.text)
    local entry=storageInfo[n]
    if entry then
      txt(tr('free_space')..': '..formatBytes(entry.free),298,y+17,15,theme.accent,292)
      txt(tr('total_space')..': '..formatBytes(entry.total),199,y+53,12,theme.muted,400)
      R(200,y+88,399,11,theme.border,5)
      local used=math.max(0,math.min(1,(entry.total-entry.free)/entry.total))
      if used>0 then R(200,y+88,399*used,11,theme.accent,5) end
    else
      txt(tr('not_mounted'),298,y+25,13,theme.muted,290)
    end
  end
  footer()
end
local function networkPage()
  header(tr('info'),tr('network'))
  panel(180,116,440,279)
  local state=external.networkState()
  local color=state=='online' and theme.green or state=='offline' and theme.error or theme.accent
  local label=state=='online' and tr('online') or state=='offline' and tr('offline') or
    state=='maintenance' and tr('maintenance') or tr('syncing')
  txt(tr('connection_status'),202,158,14,theme.muted,373)
  R(202,216,396,63,theme.panel2,10,theme.border)
  ui.color(color);love.graphics.circle('fill',233,248,11)
  ui.color(color,.18);love.graphics.circle('fill',233,248,17)
  txt(label,260,234,18,theme.text,300)
  R(202,320,396,45,theme.accent,8)
  ui.stroke(202,320,396,45,theme.text,8,1)
  txt(tr('refresh'),213,332,14,theme.bg,370,true)
  footer()
end
-- Atualização online do aplicativo, em canal separado dos outros projetos.
-- Gerenciador de BIOS integrado ao layout oficial da ROMS STORE.
local function biosPage() biosUI.draw(header,settings.language) end
local function esThemesPage() esUI.draw(header,settings.language) end
local function storeUpdatesPage()
  local lang=settings.language
  header(tr('manage'),storeUpdater.tr(lang,'title'))
  panel(180,108,440,303)
  txt(storeUpdater.tr(lang,'current')..': v'..appVersion(),201,124,14,theme.text,400)
  local info=storeUpdater.status
  local phase=info.phase or 'idle'
  local heading=storeUpdater.tr(lang,phase)
  txt(heading,201,169,14,phase=='error' and theme.error or theme.accent,394)
  if info.version and (phase=='available' or phase=='ready' or phase=='downloading' or phase=='verifying') then
    txt(storeUpdater.tr(lang,'latest')..': v'..tostring(info.version),201,194,12,theme.text,396)
  end
  if phase=='downloading' then
    local fraction=math.max(0,math.min(1,(tonumber(info.downloaded) or 0)/math.max(1,tonumber(info.expected) or 1)))
    R(204,231,389,12,theme.border,6)
    R(204,231,389*fraction,12,theme.accent,6)
    txt(string.format('%d%%',math.floor(fraction*100+0.5)),203,254,11,theme.text,390,true)
  elseif phase=='error' then
    txt(ui.ellipsize(info.message or '',66),201,226,11,theme.muted,396)
  elseif phase=='available' or phase=='ready' then
    ui.paragraph(tostring(info.notes or ''):sub(1,260),202,223,394,11,theme.muted,3)
  end
  local action=phase=='available' and storeUpdater.tr(lang,'download')
    or phase=='ready' and storeUpdater.tr(lang,'install')
    or (phase=='checking' or phase=='downloading' or phase=='verifying') and heading
    or storeUpdater.tr(lang,'check')
  R(202,333,397,40,theme.accent,8)
  txt(action,208,345,13,theme.bg,384,true)
  txt(storeUpdater.tr(lang,'no_auto'),183,386,10,theme.muted,430,true)
  txt(storeUpdater.tr(lang,'updates_hint'),183,403,10,theme.accent,430,true)
  footer()
end
local function storeUpdateBackupsPage()
  local lang=settings.language
  local list=storeUpdater.backups()
  header(tr('manage'),storeUpdater.tr(lang,'backups'))
  panel(180,108,440,303)
  if #list==0 then
    txt(storeUpdater.tr(lang,'no_backups'),194,232,13,theme.muted,410,true)
  else
    local first=math.max(1,math.min(updateBackupIndex-3,math.max(1,#list-5)))
    for slot=1,math.min(6,#list-first+1) do
      local idx=first+slot-1
      local v=list[idx]
      local y=124+(slot-1)*43
      panel(191,y,415,40,idx==updateBackupIndex)
      txt(ui.ellipsize(tostring(v.from or '?')..' → '..tostring(v.to or '?'),35),203,y+6,12,idx==updateBackupIndex and theme.accent or theme.text,365)
      txt(ui.ellipsize(tostring(v.id or ''),48),203,y+24,9,theme.muted,374)
    end
  end
  txt(storeUpdater.tr(lang,'backups_hint'),190,400,10,theme.accent,421,true)
  footer()
end
local function storeUpdateHistoryPage()
  local lang=settings.language
  local list=storeUpdater.history()
  header(tr('manage'),storeUpdater.tr(lang,'history_title'))
  panel(180,108,440,303)
  if #list==0 then txt(storeUpdater.tr(lang,'no_history'),193,236,13,theme.muted,410,true)
  else
    local count=math.min(6,math.max(0,#list-updateHistoryScroll))
    for row=1,count do
      local entry=list[#list-updateHistoryScroll-row+1]
      local y=121+(row-1)*43
      panel(191,y,417,40)
      txt(ui.ellipsize(tostring(entry.event or '')..'  '..tostring(entry.target or entry.version or ''),44),202,y+6,11,theme.text,390)
      txt(ui.ellipsize(tostring(entry.backup or entry.package or entry.source or ''),54),202,y+24,9,theme.muted,389)
    end
  end
  txt('▲▼  '..tostring(math.min(#list,updateHistoryScroll+1))..' / '..tostring(#list)..'      B  '..tr('back'),190,402,10,theme.accent,423,true)
  footer()
end
local function storeUpdateLocalPage()
  local lang=settings.language
  local list=storeUpdater.localPackages()
  header(tr('manage'),storeUpdater.tr(lang,'local_title'))
  panel(180,108,440,303)
  if #list==0 then
    ui.paragraph(storeUpdater.tr(lang,'no_local'),199,190,401,12,theme.muted,3)
  else
    for i=1,math.min(6,#list) do
      local v=list[i]
      local y=127+(i-1)*42
      panel(191,y,417,38,i==updateLocalIndex)
      txt(ui.ellipsize(tostring(v.name or ''),50),204,y+11,11,i==updateLocalIndex and theme.accent or theme.text,385)
    end
  end
  txt(storeUpdater.tr(lang,'local_hint'),190,399,10,theme.accent,423,true)
  footer()
end
local function storeUpdateConfirmPage()
  if not updateConfirm then return end
  R(0,0,640,480,{0,0,0},0,nil,.8)
  panel(143,142,356,192,true)
  local key=updateConfirm.kind=='restore' and 'restore_question' or 'delete_question'
  txt(storeUpdater.tr(settings.language,key),158,177,16,theme.text,326,true)
  txt(ui.ellipsize(updateConfirm.backup.id,42),165,223,11,theme.accent,306,true)
  ui.buttonHint(162,288,'A',tr('confirm'),145)
  ui.buttonHint(354,288,'B',tr('cancel'),130)
end
local function storeUpdateOfferPage()
  -- Popup centralizado com versão atual, nova versão e resumo de novidades.
  local lang=settings.language
  local info=storeUpdater.status
  R(0,0,640,480,{0,0,0},0,nil,.79)
  R(107,94,426,294,theme.panel,13,theme.accent)
  R(113,100,414,282,theme.panel2,10,theme.border)
  ui.color(theme.green);love.graphics.circle('fill',130,128,7)
  txt(storeUpdater.tr(lang,'notice'),145,117,17,theme.text,360)
  R(126,155,390,51,theme.panel,8,theme.border)
  txt(storeUpdater.tr(lang,'current'),137,161,10,theme.muted,164)
  txt('v'..appVersion(),137,178,13,theme.text,173)
  txt(storeUpdater.tr(lang,'latest'),325,161,10,theme.muted,179)
  txt('v'..tostring(info.version or '?'),325,178,13,theme.green,179)
  txt(storeUpdater.tr(lang,'changes')..':',129,222,12,theme.accent,363)
  local summary=tostring(info.notes or '')
  summary=summary:gsub('^R36S ROMS STORE[^\n]*\n*',''):gsub('[\r\n]+',' ')
  if summary=='' then summary=storeUpdater.tr(lang,'available') end
  love.graphics.setScissor(126,244,386,58)
  ui.paragraph(summary,130,245,380,10,theme.text,1)
  love.graphics.setScissor()
  R(125,326,391,1,theme.border)
  ui.buttonHint(130,343,'A',storeUpdater.tr(lang,'open'),124)
  ui.buttonHint(358,343,'B',storeUpdater.tr(lang,'later'),116)
end
-- Renderizador de parágrafos: não usa ui.text, que trunca textos longos.
local function legalParagraph(content,x,y,width,size,color,lineHeight,alignment)
  local f=ui.font(size)
  ui.color(color)
  love.graphics.setFont(f)
  love.graphics.printf(content,x,y,width,alignment or 'left')
  local lines=1
  if type(f.getWrap)=='function' then
    local _,result=f:getWrap(content,width)
    if type(result)=='table' then lines=math.max(1,#result) end
  else
    -- Fallback apenas para os testes que usam fontes simuladas.
    lines=math.max(1,math.ceil(#tostring(content)*size*.54/width))
  end
  local h=(type(f.getHeight)=='function' and f:getHeight() or size*1.3)
  return y+math.max(h*lines,lineHeight or 0)
end
local function fullScreenBackground()
  R(0,0,640,480,theme.bg)
  ui.color(theme.accent,.055);love.graphics.circle('fill',555,75,120)
  ui.color(theme.accent,.045);love.graphics.circle('fill',85,450,185)
end
local function firstLanguagePage()
  fullScreenBackground()
  panel(65,48,510,386,true)
  ui.drawLogo(238,53,164,85)
  local wording=legal.get(settings.language)
  txt(wording.languageTitle,103,143,21,theme.text,434,true)
  txt(wording.languageHint,108,172,11,theme.muted,424,true)
  for i,lang in ipairs(i18n.languages) do
    local y=207+(i-1)*45
    R(109,y,421,39,i==languageIndex and theme.panel2 or theme.panel,7,i==languageIndex and theme.accent or theme.border)
    ui.flag(lang.code,124,y+9,31,21)
    txt(lang.name,171,y+10,14,i==languageIndex and theme.accent or theme.text,288)
    if i==languageIndex then txt('✓',493,y+9,15,theme.accent) end
  end
  R(0,442,640,38,theme.sidebar)
  txt('↑ ↓',140,454,12,theme.accent)
  txt(wording.choose,198,454,12,theme.text,340)
  txt('A',106,452,14,theme.accent)
end
local function disclaimerPage()
  local wording=legal.get(settings.language)
  fullScreenBackground()
  ui.drawLogo(20,11,110,63)
  txt(wording.welcome,136,30,21,theme.text,486)
  R(27,84,586,1,theme.border)
  local y=106
  for _,p in ipairs(wording.notice) do
    y=legalParagraph(p,39,y,562,12,theme.text,17,'justify')+12
  end
  txt(wording.community,38,380,15,theme.accent,563,true)
  R(150,412,340,42,theme.accent,9)
  txt('A  —  '..wording.continue,161,424,13,theme.bg,319,true)
end
local function aboutPage()
  header(tr('info'),tr('title_about'))
  panel(180,95,440,339)
  local copy=legal.get(settings.language)
  -- Cabecalho com duas marcas laterais e cartao central inspirado na referencia.
  local aboutHeadX,aboutHeadW=181,438
  R(aboutHeadX,103,aboutHeadW,86,theme.panel2,9,theme.border)
  ui.drawLogo(191,111,88,70)
  -- O cartão central está rigorosamente centrado no cabeçalho.
  local cardW=232
  local cardX=aboutHeadX+(aboutHeadW-cardW)/2
  R(cardX,107,cardW,76,theme.panel,8,theme.accent)
  ui.drawAsset('telegram_icon',cardX+8,115,38,38)
  txt(settings.language=='pt' and 'CANAL DA COMUNIDADE' or 'COMMUNITY CHANNEL',cardX+51,114,10,theme.text,174)
  txt('@r36sportsbr',cardX+51,133,10,theme.accent,171)
  -- Grupos alinhados dentro do cartao. START tem 56px e nunca corta.
  ui.buttonHint(cardX+14,157,'A',settings.language=='pt' and 'Canal' or 'Channel',47)
  ui.buttonHint(cardX+91,157,'START','LivePix',67)
  ui.drawAsset('logo_dev',518,103,101,83)
  txt('R36S ROMS STORE',197,192,10,theme.accent,403)
  local y=208-aboutScroll
  love.graphics.setScissor(191,201,418,226)
  txt(copy.aboutHeading,197,y,13,theme.accent,407)
  y=y+28
  for _,p in ipairs(copy.aboutIntro) do
    y=legalParagraph(p,198,y,402,12,theme.text,17)+12
  end
  txt(copy.aboutSlogan,198,y,11,theme.accent,405)
  y=y+31
  R(197,y,405,1,theme.border)
  y=y+15
  txt(copy.warningTitle,198,y,14,theme.accent,402)
  y=y+24
  for _,p in ipairs(copy.aboutWarnings) do
    y=legalParagraph(p,198,y,402,12,theme.muted,17)+13
  end
  aboutMaxScroll=math.max(0,math.ceil((y+aboutScroll)-425))
  love.graphics.setScissor()
  if aboutMaxScroll>0 then
    R(610,205,4,213,theme.border,2)
    local bar=math.max(34,213*(213/(213+aboutMaxScroll)))
    R(610,205+(213-bar)*aboutScroll/aboutMaxScroll,4,bar,theme.accent,2)
  end
  ui.buttonHint(183,448,'A','Canal',70)
  ui.buttonHint(318,448,'START','LivePix',74)
  ui.buttonHint(486,448,'B',tr('back'),72)
  txt('↑↓',596,451,10,theme.accent,28)
end
local function qrPage()
  local telegram=qrModal=='telegram'
  local asset=telegram and 'qr_telegram' or 'qr_livepix'
  local link=telegram and 't.me/R36SPORTSBR' or 'livepix.gg/jammespark'
  if qrExpanded then
    -- Tela em fundo claro e QR centralizado, conforme fotos do console.
    R(0,0,640,480,{.97,.96,1})
    ui.drawAsset(asset,147,45,346,346)
    txt('James Park  ·  '..link,90,403,13,{.19,.18,.26},460,true)
    ui.paragraph(telegram and
      'Aponte a câmera do celular para o QR Code. A/B: voltar' or
      'QR do site LivePix (não é código Pix bancário). A/B: voltar',
      65,430,510,10,{.38,.37,.46},2)
    return
  end
  -- Modal legível na resolução física 640x480. Fundo do Sobre fica visível.
  R(0,0,640,480,{0,0,0},0,nil,.70)
  local border=telegram and {.98,.35,.76} or {1,.82,.22}
  local boxX,boxY,boxW,boxH=61,60,518,366
  R(boxX,boxY,boxW,boxH,theme.panel,12,border)
  R(boxX+5,boxY+5,boxW-10,boxH-10,theme.panel2,10)
  if telegram then ui.drawAsset('telegram_icon',85,83,31,31) end
  local title=telegram and 'SIGA NOSSO CANAL NO TELEGRAM' or 'APOIE O PROJETO'
  txt(title,telegram and 124 or 87,88,telegram and 13 or 16,border,424)
  R(83,143,204,204,{1,1,1},4)
  ui.drawAsset(asset,88,148,194,194)
  local x,w=305,249
  txt('James Park',x,145,14,theme.text,w)
  txt(link,x,168,11,theme.accent,w)
  -- Área de mensagens não invade as legendas dos botões no rodapé.
  love.graphics.setScissor(x,190,w,178)
  if telegram then
    ui.paragraph('Escaneie para seguir nosso canal no Telegram.',x,212,w,11,theme.text,3)
  else
    local y=194
    y=ui.paragraph('Esta loja é gratuita. Se ela ajudou você, considere apoiar o desenvolvimento da R36S ROMS STORE.',x,y,w,10,theme.text,2)+6
    y=ui.paragraph('Leia o QR Code com a câmera do celular para abrir livepix.gg/jammespark. Escolha o valor e conclua o apoio no site. Este não é um código Pix de pagamento direto.',x,y,w,9,theme.muted,2)+7
    txt('Obrigado pelo apoio!',x,math.min(347,y),11,border,w)
  end
  love.graphics.setScissor()
  R(77,378,485,1,theme.border)
  ui.buttonHint(83,391,'A','Ampliar QR Code',140)
  ui.buttonHint(453,391,'B','Fechar',72)
end
local function helpPage()
  header(tr('info'),tr('help'))
  panel(180,115,440,292)
  local pairs={
    {'A',tr('select')},{'B',tr('back')},{'L/R',tr('tabs')},
    {'X',tr('search')},{'Y',tr('favorites')},
    {'START',tr('confirm')}
  }
  for i,pair in ipairs(pairs) do
    local x=201+((i-1)%2)*210;local y=140+math.floor((i-1)/2)*69
    R(x,y,57,31,theme.panel2,7,theme.border)
    txt(pair[1],x+8,y+8,12,theme.accent,42,true)
    txt(pair[2],x+66,y+8,11,theme.text,133)
  end
  footer()
end
local function offlinePage()
  header(tr('info'),tr('offline'))
  panel(180,120,440,269)
  txt('!',391,147,28,theme.error)
  txt(tr('network_error'),204,214,15,theme.text,391,true)
  txt(tr('loading_note'),204,253,12,theme.muted,391,true)
  R(201,327,397,39,theme.accent,8)
  txt(tr('try_again'),210,339,13,theme.bg,375,true)
  footer()
end
local function splashPage()
  -- Tela de entrada exclusiva, sem menu lateral, com a logo vetorial da loja.
  R(0,0,640,480,theme.bg)
  ui.color(theme.accent,.065);love.graphics.circle('fill',344,205,220)
  ui.color(theme.accent,.035);love.graphics.circle('fill',344,205,285)
  R(102,100,438,256,theme.panel,20,theme.border)
  R(102,100,438,5,theme.accent,3)
  ui.drawLogo(160,116,320,168)
  txt(tr('startup_note'),135,287,12,theme.muted,370,true)
  R(168,331,304,8,theme.border,4)
  local progress=math.max(0,math.min(1,startupTime/1.2))
  R(168,331,304*progress,8,theme.accent,4)
  txt(tr('loading'),135,352,10,theme.accent,370,true)
  txt('R36S ROMS STORE  •  LÖVE 11.5',172,409,10,theme.low,296,true)
end
local function exitDialog()
  R(0,0,640,480,{0,0,0},0,nil,.80)
  panel(143,137,356,208,true)
  txt(tr('exit_question'),169,164,20,theme.text,306,true)
  txt(tr('exit_note'),170,210,12,theme.muted,301,true)
  -- A confirma a seleção; B cancela. Setas alternam Sim/Não.
  R(166,276,142,43,exitChoice==1 and theme.accent or theme.panel2,8,exitChoice==1 and theme.text or theme.border)
  txt(tr('confirm_yes_short'),169,290,12,exitChoice==1 and theme.bg or theme.text,136,true)
  R(334,276,142,43,exitChoice==2 and theme.accent or theme.panel2,8,exitChoice==2 and theme.text or theme.border)
  txt(tr('cancel'),339,290,12,exitChoice==2 and theme.bg or theme.text,132,true)
  txt('← / →  '..tr('select')..'   A  '..tr('confirm')..'   B  '..tr('back'),172,329,9,theme.low,296,true)
end
local function overwriteDialog()
  R(0,0,640,480,{0,0,0},0,nil,.76)
  panel(150,139,350,206,true)
  txt(tr('rom_exists')..' SD'..tostring(selectedCard),167,159,16,theme.text,320,true)
  txt(tr('replace_note'),173,203,12,theme.muted,308,true)
  txt(tr('replace_warn'),172,228,11,theme.error,307,true)
  ui.buttonHint(172,282,'A',tr('overwrite'),131)
  ui.buttonHint(360,282,'B',tr('cancel'),120)
end
local function deleteDialog()
  if not pendingDelete then return end
  R(0,0,640,480,{0,0,0},0,nil,.76)
  panel(145,136,355,212,true)
  txt(tr('delete_rom_question'),157,156,16,theme.text,335,true)
  txt(ui.ellipsize(pendingDelete.name or '?',42),167,202,12,theme.accent,320,true)
  txt((pendingDelete.card or ''):upper()..'  ·  '..tostring(pendingDelete.category or ''),169,227,11,theme.muted,312,true)
  ui.buttonHint(171,284,'A',tr('remove_rom'),110)
  ui.buttonHint(361,284,'B',tr('cancel'),106)
end
function love.load()
  love.graphics.setDefaultFilter('linear','linear')
  display.init() -- identifica tela real e cria canvas apenas quando necessario
  ui.init();loadData()
  storeUpdater.init(HOME,STATE)
  biosManager.init(HOME)
  biosUI.init(HOME)
  esUI.init(HOME)
  if os.getenv('R36S_STORE_OFFLINE_TEST')~='1' then storeUpdater.run('check') end
  external.init(HOME,STATE)
  reloadDownloads()
  transferCenter.init(HOME)
  transferQueue.init(HOME)
  device.update(0,true)
  music.init()
  screen='startup'
  if os.getenv('R36S_STORE_OFFLINE_TEST')~='1' then external.enter() end
end
function love.update(dt)
  clock=clock+dt
  device.update(dt)
  if screen=='storage' and clock-storageLast>30 then refreshStorage() end
  external.update(dt)
  storeUpdater.tick()
  biosManager.tick()
  biosUI.update()
  esUI.update(dt)
  -- Registra primeiro o resultado final antes de iniciar a proxima tarefa.
  transferCenter.poll(external,biosUI,esUI,storeUpdater,downloads,clock,transferQueue.visible())
  transferQueue.tick(external,biosUI,esUI)
  if screen=='home' and storeUpdater.status.phase=='available' and not storeUpdater.offered then
    storeUpdater.offered=true
    storeUpdateModal=true
  end
  if awaitInspect and not external.busy() then
    awaitInspect=false
    if external.inspectResult then
      if external.inspectResult.exists then duplicateModal=true
      else
        local ok=transferQueue.enqueue('rom',{
          game_path=selectedGame.game_path,category=selectedGame.category,
          name=selectedGame.name or 'ROM',sha256=selectedGame.sha256 or '',
          card=selectedCard,overwrite=false})
        if ok then navigate('downloads') end
      end
    else
      notice=external.message or tr('network_error');noticeTime=3
    end
  end
  if awaitDelete and not external.busy() then
    awaitDelete=false
    if external.removed then
      reloadDownloads()
      installIndex=math.min(installIndex,math.max(1,#downloads))
      notice=tr('rom_removed');noticeTime=2.5
    else notice=external.message or tr('rom_remove_fail');noticeTime=3 end
  end
  if autoListNext and not external.busy() then
    autoListNext=false
    gameIndex=math.min(#external.games,gameIndex+1)
  end
  if autoSearchNext and not external.busy() then
    autoSearchNext=false
    searchResultIndex=math.min(#external.searchResults,searchResultIndex+1)
  end
  if screen=='home' and not (focus=='content' and homeFocus=='featured') and #external.games>1 then
    homeSlideClock=homeSlideClock+dt
    if homeSlideClock>5 then
      homeSlideClock=0
      homeSlideIndex=homeSlideIndex%#external.games+1
    end
  end
  if screen=='startup' then
    startupTime=startupTime+dt
    if startupTime>1.2 then screen=languageChosen and 'disclaimer' or 'first_language' end
  end
  music.updateRoute(screen)
  noticeTime=math.max(0,noticeTime-dt)
  if math.floor(clock*2)~=math.floor((clock-dt)*2) then
    reloadDownloads()
  end
  if external.phase=='done' and lastStatus~='done' and not external.busy() then
    if screen=='transferring' then screen='success' end
  end
  if external.error and screen=='transferring' then screen='downloads' end
  lastStatus=external.phase
end
local function drawVirtual()
  if screen=='startup' then splashPage();ui.statusBar(device.get());return end
  if screen=='first_language' then firstLanguagePage();return end
  if screen=='disclaimer' then disclaimerPage();return end
  sidebar()
  if screen=='home' or screen=='exit_confirm' then homePage()
  elseif screen=='catalog' then catalogPage()
  elseif screen=='search_results' then searchResultsPage()
  elseif screen=='search' then searchPage()
  elseif screen=='detail' then detailsPage()
  elseif screen=='confirm' then confirmPage()
  elseif screen=='downloads' or screen=='transferring' or screen=='success' then transfersPage(screen)
  elseif screen=='history' then historyPage()
  elseif screen=='installed' then installedPage()
  elseif screen=='favorites' then favoritesPage()
  elseif screen=='settings' then settingsPage()
  elseif screen=='languages' then languagesPage()
  elseif screen=='font_size' then fontSizePage()
  elseif screen=='themes' then themesPage()
  elseif screen=='storage' then storagePage()
  elseif screen=='network' then networkPage()
  elseif screen=='bios' then biosPage()
  elseif screen=='es_themes' then esThemesPage()
  elseif screen=='updates' then storeUpdatesPage()
  elseif screen=='update_backups' then storeUpdateBackupsPage()
  elseif screen=='update_history' then storeUpdateHistoryPage()
  elseif screen=='update_local' then storeUpdateLocalPage()
  elseif screen=='about' then aboutPage()
  elseif screen=='help' then helpPage()
  elseif screen=='offline' then offlinePage()
  else homePage() end
  if noticeTime>0 then
    R(180,401,440,30,theme.panel2,7,theme.accent)
    txt(ui.ellipsize(notice,60),190,409,11,theme.text,420)
  end
  ui.statusBar(device.get())
  if screen=='exit_confirm' then exitDialog() end
  if qrModal then qrPage() end
  if duplicateModal then overwriteDialog() end
  if pendingDelete then deleteDialog() end
  if storeUpdateModal then storeUpdateOfferPage() end
  if updateConfirm then storeUpdateConfirmPage() end
end
function love.draw()
  local inCanvas=display.beginFrame()
  drawVirtual()
  display.endFrame(inCanvas)
end
function love.resize(w,h)
  display.resize(w,h)
end
local function changeTheme()
  local o=theme.options[themeIndex];if not o then return end
  settings.theme=o.key;theme.set(o.key);saveSettings()
  notice=tr('theme')..': '..tr(o.name);noticeTime=2.0
end
local function changeFontSize()
  local size=fontSizes[fontSizeIndex]
  if size then
    settings.font_size=size
    ui.setFontSize(size)
    saveSettings()
    notice=tr('font_size')..': '..tr('font_'..size)
    noticeTime=2
  end
end
local function changeLanguage()
  local o=i18n.languages[languageIndex];if not o then return end
  settings.language=o.code;saveSettings();notice=tr('language')..': '..o.name;noticeTime=2.0
end
local function moveGrid(dx,dy)
  local n=#external.games
  if n==0 then return end
  local next=gameIndex+dx+dy*3
  if dx==-1 and ((gameIndex-1)%3)==0 then focus='sidebar';return end
  if dx==1 and (gameIndex%3)==0 then return end
  gameIndex=math.max(1,math.min(n,next))
end
local function refreshCatalog()
  if external.busy() then
    notice=tr('syncing');noticeTime=2
    return false
  end
  if external.refresh() then
    notice=tr('syncing');noticeTime=2
    return true
  end
  notice=tr('network_error');noticeTime=2.5
  return false
end
-- Modal separado para nao ultrapassar o limite de 60 upvalues do LuaJIT.
local function handleGlobalModal(key)
  if updateConfirm then
    if key=='b' then updateConfirm=nil
    elseif key=='a' then
      local action=updateConfirm
      updateConfirm=nil
      if action.kind=='delete' then
        storeUpdater.deleteBackup(action.backup.id)
      elseif action.kind=='restore' then
        if storeUpdater.requestRestore(action.backup.id) then love.event.quit() end
      end
    end
    return
  end
  if storeUpdateModal then
    if key=='a' then storeUpdateModal=false;navigate('updates')
    elseif key=='b' then storeUpdateModal=false end
    return true
  end
  if qrModal then
    if qrExpanded then
      if key=='a' or key=='b' or key=='start' then qrExpanded=false end
    elseif key=='a' then qrExpanded=true
    elseif key=='b' or key=='start' then qrModal=nil end
    return true
  end
  if duplicateModal then
    if key=='a' then
      duplicateModal=false
      local ok=transferQueue.enqueue('rom',{
          game_path=selectedGame.game_path,category=selectedGame.category,
          name=selectedGame.name or 'ROM',sha256=selectedGame.sha256 or '',
          card=selectedCard,overwrite=true})
        if ok then navigate('downloads')
        else notice='Falha ao colocar ROM na fila';noticeTime=3 end
    elseif key=='b' then duplicateModal=false end
    return true
  end
  if pendingDelete then
    if key=='a' then
      local d=pendingDelete;pendingDelete=nil
      if external.remove(d) then awaitDelete=true
      else notice=tr('rom_remove_fail');noticeTime=3 end
    elseif key=='b' then pendingDelete=nil end
    return true
  end
  return false
end
-- Entrada da tela inicial isolada para caber no limite de upvalues do LuaJIT.
local function handleHomeInput(key)
    -- B na tela inicial sempre abre a confirmação de saída.
    if key=='b' then navigate('exit_confirm');return end
    -- D-pad escolhe item e região; somente A abre o item em foco.
    if focus=='sidebar' then
      if key=='up' then menuIndex=math.max(1,menuIndex-1)
      elseif key=='down' then menuIndex=math.min(#menuPages,menuIndex+1)
      elseif key=='right' then focus='content';homeFocus='explore'
      elseif key=='a' then
        local route=menuPages[menuIndex]
        if route=='home' then focus='content';homeFocus='explore'
        elseif route=='exit' then navigate('exit_confirm')
        elseif route then mainRoute(route) end
      elseif key=='y' then external.refresh() end
    else
      if key=='up' then
        if homeFocus=='featured' then homeFocus='explore'
        elseif homeFocus=='overview' then homeOverviewIndex=math.max(1,homeOverviewIndex-1) end
      elseif key=='down' then
        if homeFocus=='explore' then homeFocus='featured'
        elseif homeFocus=='overview' then homeOverviewIndex=math.min(3,homeOverviewIndex+1) end
      elseif key=='left' then
        if homeFocus=='featured' then homeFocus='overview'
        elseif homeFocus=='explore' then focus='sidebar'
        elseif homeFocus=='overview' then focus='sidebar' end
      elseif key=='right' then
        if homeFocus=='overview' then homeFocus='featured'
        elseif homeFocus=='explore' then homeFocus='featured'
        elseif homeFocus=='featured' and #external.games>1 then
          homeSlideIndex=homeSlideIndex%#external.games+1;homeSlideClock=0
        end
      elseif key=='a' then
        if homeFocus=='featured' then
          enterGame(external.games[homeSlideIndex])
        elseif homeFocus=='overview' then
          local targets={'catalog','installed','favorites'}
          mainRoute(targets[homeOverviewIndex])
        else
          mainRoute('downloads')
        end
      elseif key=='y' then external.refresh() end
    end
    return
end
local function handleKey(key)
  if handleGlobalModal(key) then return end
  if screen=='startup' then return end
  if screen=='first_language' then
    if key=='up' then languageIndex=math.max(1,languageIndex-1)
    elseif key=='down' then languageIndex=math.min(#i18n.languages,languageIndex+1)
    elseif key=='a' then
      local lang=i18n.languages[languageIndex]
      if lang then
        settings.language=lang.code
        languageChosen=true
        if saveSettings() then screen='disclaimer' end
      end
    end
    return
  end
  if screen=='disclaimer' then
    if key=='a' then mainRoute('home') end
    return
  end
  if screen=='exit_confirm' then
    if key=='left' or key=='up' then exitChoice=1
    elseif key=='right' or key=='down' then exitChoice=2
    elseif key=='a' then
      if exitChoice==1 then love.event.quit() else back() end
    elseif key=='b' or key=='x' then back() end
    return
  end
  -- R1/L1 movimentam a seleção na lista contínua, sem trocar páginas.
  if (screen=='catalog' or screen=='search_results') and (key=='l' or key=='r') then
    local isSearch=screen=='search_results'
    local list=isSearch and external.searchResults or external.games
    local current=isSearch and searchResultIndex or gameIndex
    if key=='l' then
      current=math.max(1,current-5)
    elseif #list>0 then
      current=math.min(#list,current+5)
    end
    if isSearch then
      searchResultIndex=current
      if current>=#list and external.searchPage<external.searchTotalPages then
        autoSearchNext=external.searchPageChange(1)
      end
    else
      gameIndex=current
      if current>=#list and external.page<external.totalPages then
        autoListNext=external.loadNext()
      end
    end
    return
  end
  if screen=='catalog' then
    if key=='x' then navigate('search');searchIndex=1;return end
    if key=='y' then toggleFavorite(selectedFromGames());return end
    if focus=='sidebar' then
      if key=='up' then categoryIndex=math.max(1,categoryIndex-1)
      elseif key=='down' then categoryIndex=math.min(#external.categories,categoryIndex+1)
      elseif key=='right' then focus='grid'
      elseif key=='a' then chooseCategory()
      elseif key=='b' then
        -- Com o foco nas categorias, B pode voltar ao Inicio; o primeiro B
        -- vindo da lista vai para as categorias, sem sair do catalogo.
        mainRoute('home') end
      return
    end
    if key=='left' then focus='sidebar';return end
    if key=='right' then return end
    if key=='up' then gameIndex=math.max(1,gameIndex-1);return end
    if key=='down' then
      if gameIndex<#external.games then gameIndex=gameIndex+1
      elseif external.page<external.totalPages then autoListNext=external.loadNext() end
      return
    end
    if key=='a' then enterGame(selectedFromGames());return end
    if key=='b' then focus='sidebar';return end
  elseif screen=='search_results' then
    if key=='y' then toggleFavorite(selectedFromGames());return end
    if key=='b' or key=='x' then back();return end
    if key=='up' then searchResultIndex=math.max(1,searchResultIndex-1)
    elseif key=='down' then
      if searchResultIndex<#external.searchResults then searchResultIndex=searchResultIndex+1
      elseif external.searchPage<external.searchTotalPages then
        autoSearchNext=external.searchPageChange(1)
      end
    elseif key=='a' then enterGame(selectedFromGames())
    end
    return
  elseif screen=='search' then
    if key=='b' then back();return end
    if key=='left' then searchIndex=math.max(1,searchIndex-1)
    elseif key=='right' then searchIndex=math.min(#keyboard,searchIndex+1)
    elseif key=='up' then searchIndex=math.max(1,searchIndex-10)
    elseif key=='down' then searchIndex=math.min(#keyboard,searchIndex+10)
    elseif key=='x' then query=query:sub(1,-2)
    elseif key=='y' then query=''
    elseif key=='start' then
      if #query>=2 and external.search(query,1) then
        searchResultIndex=1
        navigate('search_results')
      else
        notice=(#query<2 and tr('search_hint') or tr('network_error'))
        noticeTime=2.5
      end
    elseif key=='a' then
      local value=keyboard[searchIndex]
      if value=='SPACE' then query=query..' '
      elseif value=='DEL' then query=query:sub(1,-2)
      elseif value=='CLEAR' then query=''
      elseif value=='OK' then handleKey('start')
      else query=query..value end
    end
    return
  elseif screen=='detail' then
    if key=='a' then selectedCard=1;navigate('confirm')
    elseif key=='x' or key=='y' then toggleFavorite(selectedGame)
    elseif key=='b' then back() end
    return
  elseif screen=='confirm' then
    if key=='left' or key=='right' or key=='x' then selectedCard=3-selectedCard
    elseif key=='a' then
      if external.pending=='download' then
        -- O adaptador atende um pedido por vez. Enfileirar sem sobreescrita
        -- permite adicionar ROMs enquanto outro download esta em andamento.
        -- Se ja existe, a validacao do motor rejeita e protege o arquivo.
        local g=selectedGame
        local ok=g and transferQueue.enqueue('rom',{
          game_path=g.game_path,category=g.category,name=g.name or 'ROM',
          sha256=g.sha256 or '',card=selectedCard,overwrite=false})
        if ok then navigate('downloads')
        else notice=tr('download_failed');noticeTime=3 end
      elseif external.inspect(selectedGame,selectedCard) then awaitInspect=true
      else notice=tr('download_failed');noticeTime=3 end
    elseif key=='b' then back() end
    return
  elseif screen=='downloads' or screen=='transferring' or screen=='success' then
    if key=='up' then transferCenter.move(-1)
    elseif key=='down' then transferCenter.move(1)
    elseif key=='y' then navigate('history')
    elseif key=='a' or key=='x' then
      local item=transferCenter.selectedItem()
      if item and (item.queued or transferCenter.selected<=#transferCenter.active) then
        local action=key=='x' and 'cancel' or item.phase=='paused' and 'resume' or 'pause'
        if not transferQueue.handle(item,action,external,biosUI,esUI) then
          notice=transferCenter.label(settings.language,'unsupported')
          noticeTime=2
        end
      end
    elseif key=='b' then
      if screen=='downloads' then mainRoute('home') else mainRoute('downloads') end
    end
    return
  elseif screen=='history' then
    if key=='up' then historyIndex=math.max(1,historyIndex-1)
    elseif key=='down' then historyIndex=math.min(#downloads,historyIndex+1)
    elseif key=='b' then back() end
    return
  elseif screen=='installed' then
    if key=='up' then installIndex=math.max(1,installIndex-1)
    elseif key=='down' then installIndex=math.min(#downloads,installIndex+1)
    elseif key=='x' then
      local d=downloads[installIndex]
      if d then pendingDelete=d end
    elseif key=='b' then mainRoute('home') end
    return
  elseif screen=='favorites' then
    if key=='left' then favIndex=math.max(1,favIndex-1)
    elseif key=='right' then favIndex=math.min(#favorites,favIndex+1)
    elseif key=='up' then favIndex=math.max(1,favIndex-3)
    elseif key=='down' then favIndex=math.min(#favorites,favIndex+3)
    elseif key=='a' then enterGame(favorites[favIndex])
    elseif key=='x' then toggleFavorite(favorites[favIndex]);favIndex=math.max(1,math.min(favIndex,#favorites))
    elseif key=='b' then mainRoute('home') end
    return
  elseif screen=='settings' then
    if key=='up' then settingsIndex=math.max(1,settingsIndex-1)
    elseif key=='down' then settingsIndex=math.min(#suboptions,settingsIndex+1)
    elseif key=='a' then navigate(suboptions[settingsIndex])
    elseif key=='b' then mainRoute('home') end
    return
  elseif screen=='languages' then
    if key=='up' then languageIndex=math.max(1,languageIndex-1)
    elseif key=='down' then languageIndex=math.min(#i18n.languages,languageIndex+1)
    elseif key=='a' then changeLanguage()
    elseif key=='b' then back() end
    return
  elseif screen=='font_size' then
    if key=='up' then fontSizeIndex=math.max(1,fontSizeIndex-1)
    elseif key=='down' then fontSizeIndex=math.min(3,fontSizeIndex+1)
    elseif key=='a' then changeFontSize()
    elseif key=='b' then back() end
    return
  elseif screen=='themes' then
    if key=='left' then themeIndex=math.max(1,themeIndex-1)
    elseif key=='right' then themeIndex=math.min(#theme.options,themeIndex+1)
    elseif key=='up' then themeIndex=math.max(1,themeIndex-3)
    elseif key=='down' then themeIndex=math.min(#theme.options,themeIndex+3)
    elseif key=='a' then changeTheme()
    elseif key=='b' then back() end
    return
  elseif screen=='storage' then
    if key=='b' then back() end
    return
  elseif screen=='bios' then
    if not biosUI.key(key) then back() end
    return
  elseif screen=='es_themes' then
    if not esUI.key(key) then back() end
    return
  elseif screen=='updates' then
    if key=='x' then
      storeUpdater.refreshBackups();updateBackupIndex=1;navigate('update_backups')
    elseif key=='y' then
      updateHistoryScroll=0;navigate('update_history')
    elseif key=='start' then
      storeUpdater.refreshLocal();updateLocalIndex=1;navigate('update_local')
    elseif key=='a' and not storeUpdater.pending then
      local phase=storeUpdater.status.phase
      if phase=='available' then storeUpdater.run('download')
      elseif phase=='ready' then
        if storeUpdater.install() then love.event.quit() end
      else storeUpdater.run('check') end
    elseif key=='b' then back() end
    return
  elseif screen=='update_backups' then
    local backups=storeUpdater.backups()
    if key=='up' then updateBackupIndex=math.max(1,updateBackupIndex-1)
    elseif key=='down' then updateBackupIndex=math.min(#backups,updateBackupIndex+1)
    elseif (key=='a' or key=='x') and backups[updateBackupIndex] then
      updateConfirm={kind=key=='a' and 'restore' or 'delete',backup=backups[updateBackupIndex]}
    elseif key=='b' then back() end
    return
  elseif screen=='update_history' then
    local count=#storeUpdater.history()
    if key=='up' then updateHistoryScroll=math.min(math.max(0,count-6),updateHistoryScroll+1)
    elseif key=='down' then updateHistoryScroll=math.max(0,updateHistoryScroll-1)
    elseif key=='b' then back() end
    return
  elseif screen=='update_local' then
    local packages=storeUpdater.localPackages()
    if key=='up' then updateLocalIndex=math.max(1,updateLocalIndex-1)
    elseif key=='down' then updateLocalIndex=math.min(#packages,updateLocalIndex+1)
    elseif key=='a' and packages[updateLocalIndex] then
      if storeUpdater.downloadLocal(packages[updateLocalIndex].name) then navigate('updates') end
    elseif key=='b' then back() end
    return
  elseif screen=='network' or screen=='offline' then
    if key=='a' or key=='y' then refreshCatalog()
    elseif key=='b' then back() end
    return
  elseif screen=='about' or screen=='help' then
    if screen=='about' then
      if key=='a' then qrModal='telegram';return
      elseif key=='start' then qrModal='livepix';return
      elseif key=='up' then aboutScroll=math.max(0,aboutScroll-47)
      elseif key=='down' then aboutScroll=math.min(aboutMaxScroll,aboutScroll+47)
      elseif key=='b' then back() end
    elseif key=='b' then back() end
    return
  elseif screen=='home' then
    handleHomeInput(key)
    return
  end
  if key=='b' then back() end
end
function love.keypressed(key,scancode,isrepeat)
  if isrepeat then return end
  -- Teclado para testes no PC. No console, SDL2 envia gamepadpressed.
  local keys={['return']='a',kpenter='a',escape='b',backspace='b',
    up='up',down='down',left='left',right='right',
    pageup='l',pagedown='r',f5='y',y='y',x='x',tab='start'}
  handleKey(keys[key] or key)
end
function love.gamepadpressed(_,button)
  -- Mapeamento SDL2 unico: direcional, face buttons, L1/R1 e START.
  local keys={a='a',b='b',x='x',y='y',dpup='up',dpdown='down',dpleft='left',dpright='right',
    leftshoulder='l',rightshoulder='r',start='start'}
  if keys[button] then handleKey(keys[button]) end
end
function love.textinput(t)
  if screen=='search' and #query<60 and not t:find('[\r\n]') then query=query..t end
end
function love.mousepressed(x,y,button)
  if button~=1 then return end
  x,y=display.pointer(x,y)
  if not x then return end -- toque nas margens pretas nao ativa menus
  if screen=='bios' and biosUI.hasModal() then
    biosUI.mouse(x,y)
    return
  end
  if screen=='es_themes' and esUI.hasModal() then
    esUI.mouse(x,y)
    return
  end
  if storeUpdateModal then
    if y>252 and x<345 then handleKey('a') else handleKey('b') end
    return
  end
  if qrModal then
    if qrExpanded then qrExpanded=false
    elseif x<325 and y>365 then qrExpanded=true
    else qrModal=nil end
    return
  end
  if duplicateModal then if x<323 then handleKey('a') else handleKey('b') end;return end
  if pendingDelete then if x<323 then handleKey('a') else handleKey('b') end;return end
  if screen=='startup' then return end
  if screen=='first_language' then
    if x>=109 and x<=530 and y>=207 and y<388 then
      local i=math.floor((y-207)/45)+1
      if i18n.languages[i] then languageIndex=i;handleKey('a') end
    end
    return
  end
  if screen=='disclaimer' then
    if x>=150 and x<=490 and y>=412 and y<=456 then handleKey('a') end
    return
  end
  if screen=='exit_confirm' then
    if y>=275 and y<=320 then
      if x>=166 and x<310 then exitChoice=1;handleKey('a')
      elseif x>=334 and x<480 then exitChoice=2;handleKey('a') end
    end
    return
  end
  if x<158 and y>=114 and y<424 then
    if screen=='catalog' then
      if y<121 then return end
      local total=#external.categories
      local scroll=math.max(1,math.min(categoryIndex-4,total-7))
      local idx=scroll+math.floor((y-121)/37)
      if idx<scroll+8 and external.categories[idx] then categoryIndex=idx;chooseCategory() end
    else
      local idx=math.floor((y-114)/31)+1
      if menuPages[idx] then
        menuIndex=idx
        if menuPages[idx]=='exit' then navigate('exit_confirm')
        else mainRoute(menuPages[idx]) end
      end
    end
  elseif screen=='catalog' or screen=='search_results' then
    local isSearch=screen=='search_results'
    local list=isSearch and external.searchResults or external.games
    local selected=isSearch and searchResultIndex or gameIndex
    if x>=180 and x<=417 and y>=128 and y<410 then
      local row=math.floor((y-128)/47)
      local first=math.max(1,math.min(selected-2,math.max(1,#list-5)))
      local idx=first+row
      if list[idx] then
        if isSearch then searchResultIndex=idx else gameIndex=idx end
        focus='grid'
      end
    elseif x>=428 and x<=620 and y>=128 and y<=417 then
      enterGame(list[selected])
    elseif y>=56 and y<=85 and x>=578 and x<=619 then
      if isSearch then back() else navigate('search');searchIndex=1 end
    end
  elseif screen=='settings' then
    local idx=math.floor((y-100)/40)+1
    if y>=100 and y<420 and suboptions[idx] then settingsIndex=idx;navigate(suboptions[idx]) end
  elseif screen=='font_size' then
    local idx=math.floor((y-146)/78)+1
    if y>=146 and fontSizes[idx] then fontSizeIndex=idx;changeFontSize() end
  elseif screen=='themes' then
    local col=math.floor((x-180)/149)
    local row=math.floor((y-126)/94)
    local idx=row*3+col+1
    if theme.options[idx] then themeIndex=idx;changeTheme() end
  elseif screen=='languages' then
    local idx=math.floor((y-123)/72)+1
    if i18n.languages[idx] then languageIndex=idx;changeLanguage() end
  elseif screen=='about' then
    if y>=103 and y<=189 then
      if x>=280 and x<=519 then qrModal='telegram'
      elseif x>=525 and x<=614 then qrModal='livepix' end
    end
  elseif screen=='updates' then
    if x>=202 and x<=599 and y>=333 and y<=373 then handleKey('a') end
  elseif screen=='bios' then
    if not biosUI.mouse(x,y) then handleKey('b') end
  elseif screen=='es_themes' then
    -- A legenda B da barra inferior tambem funciona com clique, sem afetar o restante.
    if y>=440 and x>=525 and not esUI.hasModal() then handleKey('b')
    else esUI.mouse(x,y) end
  elseif screen=='network' then
    if x>=202 and x<=598 and y>=320 and y<=365 then refreshCatalog() end
  elseif screen=='offline' then
    if x>=201 and x<=598 and y>=327 and y<=366 then refreshCatalog() end
  elseif screen=='home' then
    if x>=495 and x<=607 and y>=147 and y<=179 then
      focus='content';homeFocus='explore';mainRoute('downloads')
    elseif x>=428 and x<=594 and y>=227 and y<=424 then
      focus='content';homeFocus='featured';enterGame(external.games[homeSlideIndex])
    elseif x>=180 and x<=370 and y>=237 and y<=422 then
      local index=math.floor((y-237)/64)+1
      if index>=1 and index<=3 then
        homeFocus='overview';homeOverviewIndex=index
        local targets={'catalog','installed','favorites'};mainRoute(targets[index])
      end
    end
  elseif screen=='detail' then if y>=280 then handleKey('a') end
  elseif screen=='confirm' then
    if y>228 and y<332 then selectedCard=x<406 and 1 or 2
    elseif y>350 then handleKey('a') end
  end
end

function love.wheelmoved(x,y)
  if screen=='about' then
    aboutScroll=math.max(0,math.min(aboutMaxScroll,aboutScroll-y*36))
  end
end
