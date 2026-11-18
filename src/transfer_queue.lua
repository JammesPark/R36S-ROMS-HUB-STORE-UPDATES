-- Fila de transferencias da R36S ROMS STORE. Nunca instala arquivos nem altera OTA.
-- Agenda somente ROM, BIOS e tema; os motores existentes continuam validando tudo.
local json=require('json')
local Q={items={},current=nil,serial=0,limit=20}
local path
local function quote(s)
 return '"'..tostring(s or ''):gsub('\\','\\\\'):gsub('"','\\"'):gsub('[\n\r\t]',' ')..'"'
end
local function safe_text(s,n)
 return type(s)=='string' and #s<=n and s:sub(1,1)~='' and not s:find('[\r\n%z]') 
end
local function validate(kind,p)
 if type(p)~='table' then return nil end
 if kind=='rom' then
  if not safe_text(p.game_path,2048) or not safe_text(p.category,100) or
     not safe_text(p.name,160) or (p.card~=1 and p.card~=2) then return nil end
  local sha=tostring(p.sha256 or '')
  if sha~='' and not sha:match('^[a-fA-F0-9]+$') then return nil end
  if #sha~=0 and #sha~=64 then return nil end
  return {game_path=p.game_path,category=p.category,name=p.name,card=p.card,
          sha256=sha,overwrite=p.overwrite==true}
 elseif kind=='bios' then
  if not safe_text(p.name,200) or type(p.size)~='number' or p.size<=0 then return nil end
  return {name=p.name,size=math.floor(p.size)}
 elseif kind=='theme' then
  if not safe_text(p.id,130) or not p.id:match('^[%w._%-]+$') or
     not safe_text(p.name,150) or not safe_text(p.resolution,20) or
     not p.resolution:match('^%d+x%d+$') then return nil end
  return {id=p.id,name=p.name,resolution=p.resolution}
 end
end
local function save()
 if not path then return end
 local records={}
 for _,t in ipairs(Q.items) do
  local p=t.payload
  local fields={'"id":'..quote(t.id),'"kind":'..quote(t.kind),
    '"name":'..quote(t.name),'"state":'..quote(t.state),'"payload":{'}
  local props={}
  for _,k in ipairs({'game_path','category','name','card','sha256','overwrite','size','id','resolution'}) do
   local value=p[k]
   if type(value)=='string' then props[#props+1]=quote(k)..':'..quote(value)
   elseif type(value)=='number' then props[#props+1]=quote(k)..':'..tostring(value)
   elseif type(value)=='boolean' then props[#props+1]=quote(k)..':'..tostring(value) end
  end
  records[#records+1]='{'..table.concat(fields,',')..table.concat(props,',')..'}}'
 end
 local f=io.open(path..'.tmp','wb')
 if f then f:write('['..table.concat(records,',')..']');f:close();os.rename(path..'.tmp',path) end
end
function Q.init(home)
 path=home..'/state/roms_download_queue.json'
 Q.items={};Q.current=nil;Q.serial=0
 local f=io.open(path,'rb')
 if not f then return end
 local raw=f:read('*a');f:close()
 local obj=json.decode(raw)
 if type(obj)~='table' then return end
 for _,t in ipairs(obj) do
  if type(t)=='table' and type(t.id)=='string' and
     (t.kind=='rom' or t.kind=='bios' or t.kind=='theme') then
   local payload=validate(t.kind,t.payload)
   if payload and #Q.items<Q.limit then
    Q.items[#Q.items+1]={id=t.id,kind=t.kind,payload=payload,
       name=payload.name,state=t.state=='queued' and 'queued' or 'paused'}
   end
  end
 end
end
function Q.enqueue(kind,payload)
 local p=validate(kind,payload)
 if not p then return false,'invalid' end
 if #Q.items>=Q.limit then return false,'full' end
 Q.serial=Q.serial+1
 local item={id='queue-'..tostring(os.time())..'-'..Q.serial,kind=kind,payload=p,
   name=p.name or kind,state='queued'}
 Q.items[#Q.items+1]=item
 save()
 return true,item.id
end
local function engineBusy(rom,bios,es)
 if rom and rom.busy and rom.busy() then return true end
 local b=bios and bios.job and bios.job() or nil
 if b and b.state=='running' then return true end
 return es and es.busy==true or false
end
local function engineState(task,rom,bios,es)
 if task.kind=='rom' then
  if rom and rom.pending=='download' then return 'running' end
  return rom and (rom.phase=='done' and 'done' or rom.phase=='cancelled' and 'cancelled') or 'error'
 elseif task.kind=='bios' then
  local j=bios and bios.job and bios.job()
  if j and j.op=='download' and j.state=='running' then return 'running' end
  return j and (j.state=='done' and 'done' or j.state=='cancelled' and 'cancelled') or 'error'
 elseif task.kind=='theme' then
  if es and es.busy then return 'running' end
  return es and es.transferState and es.transferState.phase=='done' and 'done' or 'error'
 end
 return 'error'
end
function Q.tick(rom,bios,es)
 if Q.current then
  if engineState(Q.current,rom,bios,es)~='running' then Q.current=nil end
 end
 if Q.current or engineBusy(rom,bios,es) then return end
 for i,t in ipairs(Q.items) do
  if t.state=='queued' then
   local p=t.payload
   local ok=false
   if t.kind=='rom' then
    ok=rom and rom.download and rom.download({game_path=p.game_path,category=p.category,
        name=p.name,sha256=p.sha256},p.card,p.overwrite)
   elseif t.kind=='bios' then
    ok=bios and bios.queueDownload and bios.queueDownload(p.name,p.size)
   elseif t.kind=='theme' then
    ok=es and es.queueInstall and es.queueInstall(p.id,p.resolution)
   end
   if ok then
    Q.current=t
    table.remove(Q.items,i);save()
   else
    -- Motor indisponivel: a tarefa fica na fila para nova tentativa.
   end
   return
  end
 end
end
function Q.visible()
 local entries={}
 for _,t in ipairs(Q.items) do
  entries[#entries+1]={id=t.id,kind=t.kind,name=t.name,phase=t.state,done=0,total=0,
    detail=t.state=='paused' and 'A retomar' or 'Aguardando na fila',queued=true}
 end
 return entries
end
function Q.handle(item,action,rom,bios,es)
 if not item or (action~='pause' and action~='resume' and action~='cancel') then return false end
 for i,t in ipairs(Q.items) do
  if t.id==item.id then
   if action=='cancel' then table.remove(Q.items,i)
   elseif action=='pause' then t.state='paused'
   else t.state='queued' end
   save()
   return true
  end
 end
 if item.kind=='rom' and rom then
  local op=rom[action];return type(op)=='function' and op() or false
 elseif item.kind=='bios' and bios then
  local op=bios[action];return type(op)=='function' and op() or false
 elseif item.kind=='theme' and es then
  local op=es[action];return type(op)=='function' and op() or false
 end
 return false
end
return Q
