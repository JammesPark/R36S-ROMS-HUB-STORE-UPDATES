-- Central unificada de transferencias da ROMS STORE.
-- Os trabalhos continuam nos motores originais: aqui apenas lemos estados e
-- registramos resultados. Nao move arquivos, nao baixa em dobro e nao instala.
local json=require('json')
local M={active={},history={},rows={},seen={},scroll=0}
local path
local function read(p)
  local f=io.open(p,'rb');if not f then return nil end
  local s=f:read('*a');f:close();return s
end
local function serialize(rows)
  local function quote(v)
    return '"'..tostring(v or ''):gsub('\\','\\\\'):gsub('"','\\"'):gsub('[\n\r\t]', ' ')..'"'
  end
  local output={}
  for _,r in ipairs(rows) do
    output[#output+1]='{'..table.concat({
      '"id":'..quote(r.id),'"kind":'..quote(r.kind),'"name":'..quote(r.name),
      '"phase":'..quote(r.phase),'"detail":'..quote(r.detail),
      '"time":'..tostring(math.floor(tonumber(r.time) or 0))},',')..'}'
  end
  return '['..table.concat(output,',')..']'
end
local function save()
  if not path then return end
  local text=serialize(M.history)
  local f=io.open(path..'.tmp','wb')
  if f then f:write(text);f:close();os.rename(path..'.tmp',path) end
end
local function add(record)
  if not record.id or M.seen[record.id] then return end
  M.seen[record.id]=true
  M.history[#M.history+1]=record
  while #M.history>40 do table.remove(M.history,1) end
  save()
end
local function num(n) return math.max(0,tonumber(n) or 0) end
local function job(kind,name,phase,done,total,id,detail)
  return {kind=kind,name=tostring(name or kind),phase=phase or 'downloading',done=num(done),total=num(total),
    id=tostring(id or ''),detail=tostring(detail or ''),time=os.time()}
end
local LABEL={
 pt={rom='ROM',bios='BIOS',theme='TEMA',update='LOJA',working='Em andamento',download='Baixando',source='Consultando',verify='Verificando',downloading='Baixando',
   verifying='Verificando',extracting='Extraindo',done='Concluído',error='Falha',ready='Pronto para instalar',
   empty='Nenhuma transferência registrada',ongoing='EM ANDAMENTO',recent='ATIVIDADE RECENTE'},
 en={rom='ROM',bios='BIOS',theme='THEME',update='STORE',working='Working',download='Downloading',source='Checking',verify='Verifying',downloading='Downloading',
   verifying='Verifying',extracting='Extracting',done='Completed',error='Failed',ready='Ready to install',
   empty='No transfers recorded',ongoing='IN PROGRESS',recent='RECENT ACTIVITY'},
 es={rom='ROM',bios='BIOS',theme='TEMA',update='TIENDA',working='En curso',download='Descargando',source='Consultando',verify='Verificando',downloading='Descargando',
   verifying='Verificando',extracting='Extrayendo',done='Completado',error='Fallido',ready='Listo para instalar',
   empty='Sin transferencias',ongoing='EN CURSO',recent='ACTIVIDAD RECIENTE'},
 ru={rom='ROM',bios='BIOS',theme='ТЕМА',update='МАГАЗИН',working='В процессе',download='Загрузка',source='Проверка',verify='Проверка',downloading='Загрузка',
   verifying='Проверка',extracting='Распаковка',done='Готово',error='Ошибка',ready='Готово к установке',
   empty='Нет загрузок',ongoing='ЗАГРУЗКИ',recent='ИСТОРИЯ'}
}
function M.label(lang,key)
  return (LABEL[lang] or LABEL.pt)[key] or LABEL.pt[key] or key
end
function M.init(home)
  path=home..'/state/roms_transfer_log.json'
  M.history={};M.seen={}
  local obj=json.decode(read(path) or '')
  if type(obj)=='table' then
    for _,r in ipairs(obj) do
      if type(r)=='table' and type(r.id)=='string' and type(r.kind)=='string' then
        M.history[#M.history+1]=r;M.seen[r.id]=true
      end
    end
  end
end
function M.poll(rom,bios,es,updater,romhistory)
  local active={}
  if rom and rom.activeDownload and (rom.pending=='download' or rom.phase=='error') then
    local n=rom.activeDownload
    active[#active+1]=job('rom',n.name or 'ROM',rom.error and 'error' or 'downloading',
      rom.downloaded,rom.expected,'rom-live-'..tostring(n.name),n.card==2 and 'SD2' or 'SD1')
  end
  local b=bios and bios.job and bios.job() or nil
  if type(b)=='table' and b.op=='download' then
    local state=b.state=='running' and (b.phase or 'downloading') or b.state
    local id='bios-'..tostring(b.t0 or 0)
    local entry=job('bios','Pacote BIOS',state,b.done,b.total,id)
    if b.state=='running' then active[#active+1]=entry
    elseif b.state=='done' or b.state=='error' or b.state=='cancelled' then
      entry.phase=b.state=='done' and 'done' or 'error'; add(entry)
    end
  end
  local t=es and es.transfer and es.transfer() or nil
  if type(t)=='table' and t.task=='install' and t.job_id then
    local phase=t.phase or 'working'
    local entry=job('theme',t.name or 'Tema EmulationStation',phase,t.downloaded,t.total,
      'theme-'..tostring(t.job_id),t.message)
    if phase=='working' or phase=='downloading' or phase=='extracting' then
      active[#active+1]=entry
    elseif phase=='done' or phase=='error' then add(entry) end
  end
  local s=updater and updater.status or {}
  if s.phase=='downloading' or s.phase=='verifying' or s.phase=='ready' then
    local entry=job('update','R36S ROMS STORE '..tostring(s.version or ''),s.phase,
      s.downloaded,s.expected,'update-'..tostring(s.version or ''),s.message)
    if s.phase=='ready' then entry.phase='done';add(entry)
    else active[#active+1]=entry end
  end
  local rows={}
  for _,entry in ipairs(active) do rows[#rows+1]=entry end
  for i=#M.history,1,-1 do rows[#rows+1]=M.history[i] end
  for i=#(romhistory or {}),1,-1 do
    local r=romhistory[i]
    rows[#rows+1]=job('rom',r.name or 'ROM','done',0,0,'history-rom-'..i,
      (r.card or ''):upper())
  end
  M.active=active;M.rows=rows
  M.scroll=math.max(0,math.min(M.scroll,math.max(0,#rows-6)))
end
function M.count() return #M.rows end
function M.maxScroll() return math.max(0,#M.rows-6) end
function M.move(delta) M.scroll=math.max(0,math.min(M.maxScroll(),M.scroll+delta)) end
function M.entries() return M.rows end
return M
