-- GameStoreBR: somente adaptador de dados. O layout pertence a main.lua.
local json=require('json')
local M={categories={{category='ALL',count=0}},games={},category='ALL',page=1,totalPages=1,total=0,
         inspectResult=nil,removed=false,appendGames=false,appendSearch=false,pending=nil,phase='idle',message='',downloaded=0,expected=0,error=false,connected=nil,maintenance=false,activeDownload=nil,searchResults={},searchQuery="",searchPage=1,searchTotalPages=1,searchTotal=0}
local home,state,lastStatus='',nil
local function read(path)
  local f=io.open(path,'rb');if not f then return nil end
  local txt=f:read('*a');f:close();return txt
end
local function quote(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function command(args)
  local argv={'python3',quote(home..'/bin/gamestore_source.py')}
  for _,v in ipairs(args) do argv[#argv+1]=quote(v) end
  local ok=os.execute(table.concat(argv,' ')..' >/dev/null 2>&1 </dev/null &')
  return ok~=nil and ok~=false
end
local function cached(path)
  local txt=read(path);if not txt then return nil end
  local parsed=json.decode(txt)
  return type(parsed)=='table' and parsed or nil
end
-- Dados cacheados chegam de JSON externo; nao deixar entradas inválidas
-- causar indexacao de numero/nil nas telas do LÖVE.
local function safeGames(raw)
  local result={}
  if type(raw)~='table' then return result end
  for _,game in ipairs(raw) do
    if type(game)=='table' and type(game.name)=='string' and
       type(game.game_path)=='string' and #game.name>0 and #game.game_path>0 then
      if type(game.category)~='string' then game.category='' end
      if type(game.cover_id)~='string' then game.cover_id=nil end
      if type(game.image_url)~='string' then game.image_url=nil end
      if type(game.sha256)~='string' then game.sha256=nil end
      result[#result+1]=game
    end
  end
  return result
end
local function safeCategories(raw)
  local result={}
  if type(raw)~='table' then return result end
  for _,item in ipairs(raw) do
    if type(item)=='table' and type(item.category)=='string' and
       #item.category>0 and #item.category<=96 then
      result[#result+1]=item
    end
  end
  return result
end
function M.loadCategories()
  local data=cached(state..'/gamestore_categories.json')
  if data and type(data.categories)=='table' then
    local valid=safeCategories(data.categories)
    if #valid>0 then M.categories=valid end
  end
end
function M.loadGames()
  local data=cached(state..'/gamestore_games.json')
  if data and type(data.games)=='table' then
    local valid=safeGames(data.games)
    local page=tonumber(data.page) or 1
    if M.appendGames and page==M.page+1 and data.category==M.category then
      local seen={}
      for _,g in ipairs(M.games) do seen[g.game_path]=true end
      for _,g in ipairs(valid) do
        if not seen[g.game_path] then M.games[#M.games+1]=g;seen[g.game_path]=true end
      end
    else
      M.games=valid
    end
    M.category=data.category or M.category
    M.page=page
    M.totalPages=math.max(1,tonumber(data.total_pages) or 1)
    M.total=math.max(0,tonumber(data.total) or #M.games)
    if M.appendGames and #valid==0 then M.totalPages=M.page end
    M.appendGames=false
    return true
  end
  M.appendGames=false
  return false
end
function M.loadSearch()
  local data=cached(state..'/gamestore_search.json')
  if data and type(data.games)=='table' then
    local page=tonumber(data.page) or 1
    if M.appendSearch and page==M.searchPage+1 and tostring(data.query or '')==M.searchQuery then
      local seen={}
      for _,g in ipairs(M.searchResults) do seen[g.game_path]=true end
      for _,g in ipairs(data.games) do
        if not seen[g.game_path] then M.searchResults[#M.searchResults+1]=g;seen[g.game_path]=true end
      end
    else M.searchResults=valid end
    M.searchQuery=tostring(data.query or M.searchQuery)
    M.searchPage=page
    M.searchTotalPages=math.max(1,tonumber(data.total_pages) or 1)
    M.searchTotal=math.max(0,tonumber(data.total) or #M.searchResults)
    if M.appendSearch and #valid==0 then M.searchTotalPages=M.searchPage end
    M.appendSearch=false
    return true
  end
  M.appendSearch=false
  return false
end
function M.search(term,page)
  term=tostring(term or ''):gsub('^%s+',''):gsub('%s+$','')
  if #term<2 or #term>80 or M.pending then return false end
  M.searchQuery=term
  M.appendSearch=false
  if (page or 1)==1 then M.searchResults={};M.searchPage=0 end
  return M.request('search',{term,tostring(page or 1)})
end
function M.searchPageChange(delta)
  if delta~=1 or M.pending or M.searchPage>=M.searchTotalPages then return false end
  M.appendSearch=true
  if M.request('search',{M.searchQuery,tostring(M.searchPage+1)}) then return true end
  M.appendSearch=false
  return false
end
function M.init(appPath, statePath)
  home,state=appPath,statePath
  M.loadCategories();M.loadGames();M.loadSearch()
end
function M.request(task,args)
  if M.pending then return false end
  args=args or {}; local cmd={task}
  for _,arg in ipairs(args) do cmd[#cmd+1]=arg end
  lastStatus='';os.remove(state..'/gamestore_status.json')
  if task=='download' then os.remove(state..'/gamestore_control.json') end
  M.pending=task;M.phase='loading';M.message='Conectando...';M.error=false;M.maintenance=false
  if not command(cmd) then
    M.pending=nil;M.phase='error';M.message='Python 3 indisponível';M.error=true
    return false
  end
  return true
end
function M.enter()
  if #M.categories<=1 then M.request('categories')
  elseif #M.games==0 then M.request('games',{M.category,tostring(M.page)}) end
end
function M.refresh()
  return M.request('categories')
end
function M.categoryChange(category)
  if M.pending then return false end
  local old=M.category
  M.category=category;M.page=0;M.games={};M.appendGames=false
  local ok=M.request('games',{category,'1'})
  if not ok then M.category=old end
  return ok
end
function M.pageChange(delta)
  -- A paginação é interna: resultados são acrescentados à lista rolável.
  if delta~=1 or M.pending or M.page>=M.totalPages then return false end
  M.appendGames=true
  if M.request('games',{M.category,tostring(M.page+1)}) then return true end
  M.appendGames=false
  return false
end
function M.loadNext() return M.pageChange(1) end
function M.inspect(g,card)
  if not g or not g.game_path or not g.category then return false end
  M.inspectResult=nil
  return M.request('inspect',{g.game_path,g.category,card==2 and 'sd2' or 'sd1'})
end
function M.remove(d)
  if not d or type(d.game_path)~='string' or type(d.filename)~='string' then return false end
  M.removed=false
  return M.request('remove',{d.game_path,d.category,d.card,d.filename})
end
function M.download(g,card,overwrite)
  if not g or not g.game_path or not g.category then return false end
  local ok=M.request('download',{g.game_path,g.category,card==2 and 'sd2' or 'sd1',g.name or 'ROM',g.sha256 or '',overwrite and '1' or '0'})
  if ok then
    M.activeDownload={name=g.name or 'ROM',card=card,t0=os.time()}
    M.downloaded=0;M.expected=0
  end
  return ok
end
local function send_control(action)
 if M.pending~='download' or not M.activeDownload then return false end
 if action=='pause' and M.phase~='downloading' then return false end
 if action=='resume' and M.phase~='paused' then return false end
 if action=='cancel' and (M.phase=='done' or M.phase=='error') then return false end
 local file=state..'/gamestore_control.json'
 local f=io.open(file..'.tmp','wb')
 if not f then return false end
 f:write('{"action":"'..action..'"}');f:close()
 return os.rename(file..'.tmp',file) and true or false
end
function M.pause() return send_control('pause') end
function M.resume() return send_control('resume') end
function M.cancel() return send_control('cancel') end
function M.update()
  local raw=read(state..'/gamestore_status.json')
  if not raw or raw==lastStatus then return end
  local s=json.decode(raw)
  if type(s)~='table' or not M.pending or (s.task and s.task~=M.pending) then return end
  lastStatus=raw
  M.phase=type(s.phase)=='string' and s.phase or 'idle'
  M.message=type(s.message)=='string' and s.message or tostring(s.message or '')
  M.downloaded=tonumber(s.downloaded) or M.downloaded or 0
  M.expected=tonumber(s.expected) or 0
  if M.phase=='cancelled' then
    if M.pending=='download' and M.activeDownload then
      M.lastDownload={name=M.activeDownload.name,card=M.activeDownload.card,
        t0=M.activeDownload.t0,phase='cancelled',done=M.downloaded,total=M.expected,
        message=s.message}
      M.activeDownload=nil
    end
    M.pending=nil
    M.message=s.message or 'Download cancelado'
  elseif M.phase=='error' then
    local task=M.pending
    if task=='download' and M.activeDownload then
      M.lastDownload={name=M.activeDownload.name,card=M.activeDownload.card,
        t0=M.activeDownload.t0,phase='error',done=M.downloaded,total=M.expected,
        message=s.message}
      M.activeDownload=nil
    end
    M.error=true;M.pending=nil
    if task=='categories' or task=='games' or task=='search' then M.connected=false end
    M.maintenance=M.message:lower():find('manuten',1,true)~=nil or M.message:lower():find('maintenance',1,true)~=nil
  elseif M.phase=='done' then
    local task=M.pending;M.pending=nil
    if task=='categories' or task=='games' or task=='search' then M.connected=true;M.maintenance=false end
    if task=='categories' then
      M.loadCategories()
      if not M.request('games',{M.category,tostring(M.page)}) then M.error=true end
    elseif task=='search' then
      M.loadSearch()
      command({'covers','search'})
    elseif task=='games' then
      M.loadGames()
      -- As capas sao opcionais: baixadas em paralelo, sem bloquear o menu.
      command({'covers'})
    elseif task=='inspect' then
      M.inspectResult={exists=s.exists==true,managed=s.managed==true,filename=s.filename,card=s.card}
    elseif task=='remove' then
      M.removed=true
    end
  end
end
function M.totalCatalog()
  -- O agregado exclui ALL para não contar todas as ROMs em duplicidade.
  local total=0;local haveCounts=false
  for _,item in ipairs(M.categories) do
    if type(item)=='table' and item.category~='ALL' then
      haveCounts=true
      total=total+math.max(0,math.floor(tonumber(item.count) or 0))
    end
  end
  if haveCounts then return total end
  return nil
end
function M.networkState()
  if M.maintenance then return 'maintenance' end
  if M.pending=='categories' or M.pending=='games' then return 'syncing' end
  if M.connected==true then return 'online' end
  if M.connected==false then return 'offline' end
  return 'syncing' -- Ainda sem uma resposta remota confirmada.
end

function M.busy() return M.pending~=nil end
function M.statePath() return state end
return M
