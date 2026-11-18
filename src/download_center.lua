-- Central unificada de transferencias da ROMS STORE.
-- Os trabalhos continuam nos motores originais: aqui apenas lemos estados e
-- registramos resultados. Nao move arquivos, nao baixa em dobro e nao instala.
local json=require('json')
local M={active={},history={},rows={},seen={},scroll=0,selected=1,metrics={}}
local path
local function read(p)
  local f=io.open(p,'rb');if not f then return nil end
  local s=f:read('*a');f:close();return s
end
-- Entradas antigas nao incluem done/total. Nunca confiar em numeros vindos do JSON.
local function num(n)
  local value=tonumber(n) or 0
  if value~=value or value==math.huge or value==-math.huge or value<0 then return 0 end
  return value
end
local function humanRate(bps)
 bps=num(bps)
 if bps>=1048576 then return string.format('%.2f MB/s',bps/1048576) end
 return string.format('%.0f KB/s',bps/1024)
end
function M.rateText(item)
 local bps=item and num(item.speed) or 0
 return bps>0 and humanRate(bps) or '—'
end
function M.etaText(item)
 local seconds=item and num(item.eta) or 0
 if seconds<=0 or seconds>604800 then return '—' end
 seconds=math.ceil(seconds)
 if seconds>=3600 then return string.format('%dh %02dm',math.floor(seconds/3600),math.floor(seconds%3600/60)) end
 return string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
end
local function measure(entry,now,speedOverride)
 if entry.phase~='download' and entry.phase~='downloading' then return end
 local id=entry.id
 local sample=M.metrics[id]
 if not sample or now<sample.at or entry.done<sample.bytes then
  sample={at=now,bytes=entry.done,speed=0}
  M.metrics[id]=sample
 end
 local dt=now-sample.at
 if dt>=0.5 then
  local delta=entry.done-sample.bytes
  if delta>0 then
   local measured=delta/dt
   sample.speed=sample.speed>0 and sample.speed*.45+measured*.55 or measured
  elseif dt>=3 then
   sample.speed=0
  end
  sample.bytes=entry.done;sample.at=now
 end
 entry.speed=num(speedOverride)>0 and num(speedOverride) or sample.speed
 if entry.total>entry.done and entry.speed>0 then
  entry.eta=(entry.total-entry.done)/entry.speed
 end
end
function M.formatProgress(record)
  record=type(record)=='table' and record or {}
  local done,total=num(record.done),num(record.total)
  if total>0 then
    local percent=math.floor(math.min(100,(done/total)*100)+0.5)
    return string.format('%d%%  %.1f / %.1f MB',percent,done/1048576,total/1048576),percent
  end
  if done>0 then return string.format('%.1f MB',done/1048576),nil end
  return tostring(record.detail or ''),nil
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
      '"done":'..tostring(math.floor(num(r.done))),'"total":'..tostring(math.floor(num(r.total))),
      '"time":'..tostring(math.floor(num(r.time)))},',')..'}'
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
local function job(kind,name,phase,done,total,id,detail)
  return {kind=kind,name=tostring(name or kind),phase=phase or 'downloading',done=num(done),total=num(total),
    id=tostring(id or ''),detail=tostring(detail or ''),time=os.time()}
end
local LABEL={
 pt={rom='ROM',bios='BIOS',theme='TEMA',update='LOJA',working='Em andamento',download='Baixando',source='Consultando',verify='Verificando',downloading='Baixando',
   verifying='Verificando',extracting='Extraindo',done='Concluído',error='Falha',ready='Pronto para instalar',queued='Na fila',paused='Pausado',cancelled='Cancelado',
   empty='Nenhuma transferência registrada',unsupported='Controle indisponível nesta transferência',ongoing='EM ANDAMENTO',recent='ATIVIDADE RECENTE'},
 en={rom='ROM',bios='BIOS',theme='THEME',update='STORE',working='Working',download='Downloading',source='Checking',verify='Verifying',downloading='Downloading',
   verifying='Verifying',extracting='Extracting',done='Completed',error='Failed',ready='Ready to install',queued='Queued',paused='Paused',cancelled='Cancelled',
   empty='No transfers recorded',unsupported='Action unavailable for this transfer',ongoing='IN PROGRESS',recent='RECENT ACTIVITY'},
 es={rom='ROM',bios='BIOS',theme='TEMA',update='TIENDA',working='En curso',download='Descargando',source='Consultando',verify='Verificando',downloading='Descargando',
   verifying='Verificando',extracting='Extrayendo',done='Completado',error='Fallido',ready='Listo para instalar',queued='En cola',paused='Pausado',cancelled='Cancelado',
   empty='Sin transferencias',unsupported='Acción no disponible',ongoing='EN CURSO',recent='ACTIVIDAD RECIENTE'},
 ru={rom='ROM',bios='BIOS',theme='ТЕМА',update='МАГАЗИН',working='В процессе',download='Загрузка',source='Проверка',verify='Проверка',downloading='Загрузка',
   verifying='Проверка',extracting='Распаковка',done='Готово',error='Ошибка',ready='Готово к установке',queued='В очереди',paused='Пауза',cancelled='Отменено',
   empty='Нет загрузок',unsupported='Действие недоступно',ongoing='ЗАГРУЗКИ',recent='ИСТОРИЯ'}
}
function M.label(lang,key)
  return (LABEL[lang] or LABEL.pt)[key] or LABEL.pt[key] or key
end
function M.init(home)
  path=home..'/state/roms_transfer_log.json'
  M.history={};M.seen={};M.metrics={};M.selected=1;M.scroll=0
  local obj=json.decode(read(path) or '')
  if type(obj)=='table' then
    for _,r in ipairs(obj) do
      if type(r)=='table' and type(r.id)=='string' and type(r.kind)=='string' then
        M.history[#M.history+1]={id=r.id,kind=r.kind,
          name=type(r.name)=='string' and r.name or r.kind,
          phase=type(r.phase)=='string' and r.phase or 'done',
          detail=type(r.detail)=='string' and r.detail or '',
          done=num(r.done),total=num(r.total),time=num(r.time)}
        M.seen[r.id]=true
      end
    end
  end
end
function M.poll(rom,bios,es,updater,romhistory,now,queued)
  local currentSelection=M.rows[M.selected]
  local selectedId=currentSelection and currentSelection.id
  local active={}
  now=tonumber(now) or os.time()
  if rom and rom.activeDownload and (rom.pending=='download' or rom.phase=='error') then
    local n=rom.activeDownload
    active[#active+1]=job('rom',n.name or 'ROM',rom.error and 'error' or rom.phase=='paused' and 'paused' or 'downloading',
      rom.downloaded,rom.expected,'rom-live-'..tostring(n.name),n.card==2 and 'SD2' or 'SD1')
  end
  if rom and type(rom.lastDownload)=='table' then
    local r=rom.lastDownload
    add(job('rom',r.name,r.phase,r.done,r.total,
      'rom-failed-'..tostring(r.t0 or 0)..'-'..tostring(r.name or ''),r.message))
  end
  local b=bios and bios.job and bios.job() or nil
  if type(b)=='table' and b.op=='download' then
    local state=b.state=='running' and (b.phase or 'downloading') or b.state
    local id='bios-'..tostring(b.t0 or 0)
    local entry=job('bios','Pacote BIOS',state,b.done,b.total,id)
    if b.state=='running' then entry._speed=b.speed;active[#active+1]=entry
    elseif b.state=='done' or b.state=='error' or b.state=='cancelled' then
      entry.phase=b.state=='done' and 'done' or 'error'; add(entry)
    end
  end
  local t=es and es.transfer and es.transfer() or nil
  if type(t)=='table' and t.task=='install' and t.job_id then
    local phase=t.phase or 'working'
    local entry=job('theme',t.name or 'Tema EmulationStation',phase,t.downloaded,t.total,
      'theme-'..tostring(t.job_id),t.message)
    if phase=='working' or phase=='downloading' or phase=='extracting' or phase=='paused' then
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
  for _,entry in ipairs(active) do
    measure(entry,now,entry._speed)
    rows[#rows+1]=entry
  end
  M.queued=type(queued)=='table' and queued or {}
  for _,entry in ipairs(M.queued) do rows[#rows+1]=entry end
  for i=#M.history,1,-1 do rows[#rows+1]=M.history[i] end
  for i=#(romhistory or {}),1,-1 do
    local r=romhistory[i]
    rows[#rows+1]=job('rom',r.name or 'ROM','done',0,0,'history-rom-'..i,
      tostring(r.card or ''):upper())
  end
  M.active=active;M.rows=rows
  if selectedId then
    local found=false
    for i,item in ipairs(rows) do
      if item.id==selectedId then M.selected=i;found=true;break end
    end
    if not found then M.selected=math.max(1,math.min(M.selected,#rows)) end
  end
  M.selected=math.max(1,math.min(M.selected,math.max(1,#rows)))
  M.scroll=math.max(0,math.min(M.scroll,math.max(0,#rows-6)))
end
-- Uma mesma fonte alimenta Downloads e o painel da tela Início.
-- Prioriza a primeira transferência em curso, ignorando falhas concluídas.
function M.current()
 for _,item in ipairs(M.active) do
  if item.phase~='error' and item.phase~='done' and item.phase~='cancelled' then return item end
 end
 return nil
end
function M.count() return #M.rows end
function M.maxScroll() return math.max(0,#M.rows-6) end
function M.move(delta)
 M.selected=math.max(1,math.min(math.max(1,#M.rows),M.selected+delta))
 if M.selected<=M.scroll then M.scroll=M.selected-1 end
 if M.selected>M.scroll+6 then M.scroll=M.selected-6 end
 M.scroll=math.max(0,math.min(M.maxScroll(),M.scroll))
end
function M.selectedItem() return M.rows[M.selected] end
function M.entries() return M.rows end
return M
