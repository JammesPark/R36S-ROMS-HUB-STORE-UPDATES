-- R36S ROMS STORE: interface nativa 640x480 para o motor GPL-3.0 de BIOS.
-- Mantem separado o gerenciador local da ROMS STORE, inclusive seus backups.
local ui = require('ui')
local theme = require('theme')
local legacy = require('bios_manager')
local translations = require('roms_bios.i18n')
local M = {tab=1, selected=1, pkgIndex=1, historyIndex=1, filesIndex=1, importIndex=1,
  view=nil, marked={}, confirm=nil, message=nil}
local B
local T = {
  pt={title='Gerenciador de BIOS',tabs={'SISTEMAS','PACOTES','HISTÓRICO','LOCAL'},
    scan='Verificar BIOS',download='Baixar pacote',analyze='Analisar pacote',install='Instalar marcadas',
    clean='Limpar arquivos temporários',no_url='Fonte não configurada: bios_url.txt',
    source='Pasta de BIOS',unknown='Não localizada',no_scan='Pressione A para verificar as BIOS',
    no_pkg='Nenhum pacote baixado',pkg_ready='Pacote disponível',an_ready='Análise disponível',
    no_history='Nenhum histórico registrado',confirm='Confirmar operação?',yes='SIM',no='NÃO',
    select='Selecionar',marked='Marcadas',verified='Hash confirmado',unverified='Hash não confirmado',
    protected='Sem conteúdo de BIOS incluído. Use apenas arquivos autorizados.',
    run='Em andamento',done='Concluído',cancel='Cancelar',back='Voltar',
    details='Arquivos do sistema',show='Ver arquivos',file='Arquivo',
    local_scan='Verificar BIOS locais',local_import='Importar arquivos próprios',local_restore='Restaurar backup local',
    local_tip='Cópia local: state/bios_import (ZIP ou BIOS individual)',
    retry='Operação indisponível',new='Nova',replace='Substituir (backup)',
    install_tip='Somente BIOS confirmadas por hash podem ser marcadas.',
    count='Total',none='Nenhuma BIOS confirmada disponível',
    select_tip='A marcar   X instalar   Y selecionar confirmadas   B voltar',
    select_file='Selecionar BIOS',history_tip='A restaurar backup selecionado',
    warning='As BIOS existentes serão copiadas para backup antes da troca.',
    no_backup='Registro sem backup para restaurar',
    confirm_dl='Baixar pacote da fonte configurada?',confirm_clean='Remover apenas arquivos temporários registrados?',
    confirm_import='Importar BIOS da pasta local?',confirm_restore='Restaurar o backup selecionado?',
    no_data='Dados indisponíveis',tabs_hint='L/R abas', scan_short='Verificar', open='Abrir',
    progress='Progresso',local_hint='A verificar   X importar   Y restaurar',
    status_install='Instalada',status_missing='Ausente',status_pending='Pendente',status_update='Atualização',
    status_incompatible='Incompatível',status_optional='Opcional',status_error='Erro'},
  en={title='BIOS Manager',tabs={'SYSTEMS','PACKAGES','HISTORY','LOCAL'},scan='Scan BIOS',
    download='Download package',analyze='Analyze package',install='Install selected',
    clean='Clean temporary files',no_url='Source missing: bios_url.txt',source='BIOS folder',unknown='Not found',
    no_scan='Press A to scan BIOS',no_pkg='No downloaded package',pkg_ready='Package available',
    an_ready='Analysis available',no_history='No history available',confirm='Confirm operation?',yes='YES',no='NO',
    select='Select',marked='Selected',verified='Verified hash',unverified='Unverified hash',
    protected='No BIOS files included. Use only authorized files.',run='Working',done='Completed',
    cancel='Cancel',back='Back',details='System files',show='View files',file='File',
    local_scan='Scan local BIOS',local_import='Import your BIOS files',local_restore='Restore local backup',
    local_tip='Local import: state/bios_import (ZIP or individual BIOS)',retry='Unavailable',new='New',replace='Replace (backup)',
    install_tip='Only hash-verified BIOS can be selected.',count='Total',none='No verified BIOS available',
    select_tip='A select   X install   Y select verified   B back',select_file='Choose BIOS',history_tip='A restore selected backup',
    warning='Existing BIOS files will be backed up before replacement.',no_backup='No backup in this record',
    confirm_dl='Download package from configured source?',confirm_clean='Remove registered temporary files only?',
    confirm_import='Import BIOS from local folder?',confirm_restore='Restore selected backup?',no_data='No data',
    tabs_hint='L/R tabs',scan_short='Scan',open='Open',progress='Progress',local_hint='A scan   X import   Y restore',
    status_install='Installed',status_missing='Missing',status_pending='Pending',status_update='Update',
    status_incompatible='Incompatible',status_optional='Optional',status_error='Error'},
  es={title='Gestor de BIOS',tabs={'SISTEMAS','PAQUETES','HISTORIAL','LOCAL'},scan='Verificar BIOS',
    download='Descargar paquete',analyze='Analizar paquete',install='Instalar marcadas',
    clean='Limpiar archivos temporales',no_url='Falta la fuente: bios_url.txt',source='Carpeta BIOS',unknown='No encontrada',
    no_scan='Pulse A para verificar BIOS',no_pkg='Ningún paquete descargado',pkg_ready='Paquete disponible',
    an_ready='Análisis disponible',no_history='Sin historial',confirm='¿Confirmar operación?',yes='SÍ',no='NO',
    select='Seleccionar',marked='Marcadas',verified='Hash confirmado',unverified='Hash no confirmado',
    protected='No incluye BIOS. Use solo archivos autorizados.',run='Procesando',done='Completado',
    cancel='Cancelar',back='Volver',details='Archivos del sistema',show='Ver archivos',file='Archivo',
    local_scan='Verificar BIOS locales',local_import='Importar sus BIOS',local_restore='Restaurar copia local',
    local_tip='Importación: state/bios_import (ZIP o BIOS)',retry='No disponible',new='Nuevo',replace='Sustituir (copia)',
    install_tip='Solo se pueden marcar BIOS verificadas por hash.',count='Total',none='No hay BIOS verificadas',
    select_tip='A marcar   X instalar   Y marcar verificadas   B volver',select_file='Seleccionar BIOS',
    history_tip='A restaurar copia seleccionada',warning='Se hará una copia antes de sustituir BIOS.',
    no_backup='Esta entrada no tiene copia',confirm_dl='¿Descargar paquete de la fuente configurada?',
    confirm_clean='¿Borrar solo archivos temporales registrados?',confirm_import='¿Importar BIOS de carpeta local?',
    confirm_restore='¿Restaurar la copia seleccionada?',no_data='Sin datos',tabs_hint='L/R pestañas',
    scan_short='Verificar',open='Abrir',progress='Progreso',local_hint='A revisar   X importar   Y restaurar',
    status_install='Instalada',status_missing='Ausente',status_pending='Pendiente',status_update='Actualización',
    status_incompatible='Incompatible',status_optional='Opcional',status_error='Error'},
  ru={title='Менеджер BIOS',tabs={'СИСТЕМЫ','ПАКЕТЫ','ИСТОРИЯ','ЛОКАЛЬНО'},scan='Проверить BIOS',
    download='Скачать пакет',analyze='Проверить пакет',install='Установить выбранные',
    clean='Очистить временные файлы',no_url='Источник не задан: bios_url.txt',source='Папка BIOS',unknown='Не найдена',
    no_scan='Нажмите A для проверки BIOS',no_pkg='Нет скачанного пакета',pkg_ready='Пакет доступен',
    an_ready='Анализ готов',no_history='История пуста',confirm='Подтвердить действие?',yes='ДА',no='НЕТ',
    select='Выбрать',marked='Выбрано',verified='Хеш проверен',unverified='Хеш не проверен',
    protected='BIOS не включены. Используйте законные файлы.',run='Выполняется',done='Готово',
    cancel='Отмена',back='Назад',details='Файлы системы',show='Просмотр файлов',file='Файл',
    local_scan='Проверить локальные BIOS',local_import='Импорт своих BIOS',local_restore='Восстановить копию',
    local_tip='Импорт: state/bios_import (ZIP или BIOS)',retry='Недоступно',new='Новый',replace='Замена (копия)',
    install_tip='Выбираются только BIOS с проверенным хешем.',count='Всего',none='Нет проверенных BIOS',
    select_tip='A выбор   X установка   Y выбрать все   B назад',select_file='Выбрать BIOS',
    history_tip='A восстановить резервную копию',warning='Перед заменой создается резервная копия.',
    no_backup='Нет резервной копии',confirm_dl='Скачать пакет из заданного источника?',
    confirm_clean='Удалить только временные файлы?',confirm_import='Импортировать локальные BIOS?',
    confirm_restore='Восстановить выбранную копию?',no_data='Нет данных',tabs_hint='L/R вкладки',
    scan_short='Проверить',open='Открыть',progress='Прогресс',local_hint='A проверка   X импорт   Y копия',
    status_install='Установлена',status_missing='Отсутствует',status_pending='Ожидает',status_update='Обновление',
    status_incompatible='Несовместима',status_optional='Необязательно',status_error='Ошибка'}
}
local language='pt'
local function t(k) return (T[language] or T.pt)[k] or T.pt[k] or k end
local function tx(v,x,y,size,color,w,center) ui.text(v,x,y,size,color,w,center) end
local function box(x,y,w,h,color,rad,edge) ui.rect(x,y,w,h,color,rad,edge) end
local function shell(x,y,w,h,selected) ui.panel(x,y,w,h,selected) end
local function clip(s,n) return ui.ellipsize(tostring(s or ''),n or 34) end
local function status_label(s)
  local labels={installed='install',missing='missing',pending='pending',update='update',incompatible='incompatible',optional='optional',error='error'}
  return t('status_'..(labels[s] or 'pending'))
end
local function job_start(op,args)
  if not B then return end
  local ok,err=B.start(op,args,function(j)
    if j.state=='error' then M.message=B.message(j.error_code,j.detail)
    elseif j.state=='done' then M.message=t('done')
    else M.message=j.state end
    if op=='analyze' and j.state=='done' then M.view='select';M.filesIndex=1;M.marked={} end
    if op=='scan' and j.state=='done' then M.selected=1 end
  end)
  if not ok then M.message=tostring(err or t('retry')) end
end
local function request(label,handler)
  M.confirm={label=label,run=handler,yes=false}
end
local function list_rows()
  return B and B.rows() or {}
end
local function analysis_rows()
  local a=B and B.analysis_ready() and B.analysis() or nil
  local out={}
  if not a then return out end
  for _,it in ipairs(a.items or {}) do
    if it.kind=='bios' or it.kind=='name' then
      local dests={}
      for _,d in ipairs(it.dests or {}) do
        if d.inside and not d.special and not d.no_folder and not d.same then
          -- Só arquivos confirmados pelo banco de hashes; substituição sempre exige confirmação.
          if it.verified then dests[#dests+1]=d end
        end
      end
      out[#out+1]={item=it,dests=dests,selectable=it.verified and #dests>0}
    end
  end
  return out
end
local function install_selected()
  local a=B and B.analysis_ready() and B.analysis() or nil
  if not a then M.message=t('no_pkg');return end
  local rows=analysis_rows()
  local install={}
  for _,r in ipairs(rows) do
    if M.marked[r.item.rel] and r.selectable then
      for _,d in ipairs(r.dests) do
        install[#install+1]={src=a.tmp..'/'..r.item.rel,rel=r.item.rel,md5=r.item.md5,
          target=d.target,replace=d.real~=nil}
      end
    end
  end
  if #install==0 then M.message=t('none');return end
  request(t('install')..': '..tostring(#install)..'. '..t('warning'),function()
    job_start('install',{items=install,pkg_name=a.pkg_name})
    M.view=nil;M.tab=1
  end)
end
function M.init(home)
  local config=require('roms_bios.config')
  config.configure({app_dir=home,roms_dir=(home:match('^/roms2/') and '/roms2/ports' or '/roms/ports'),
    fetch_sh=home..'/bin/fetch.sh',bundled_7z=home..'/bin/7zzs'})
  B=require('roms_bios.bios')
  local ok,why=pcall(B.recover)
  if ok and why then M.message=why elseif not ok then M.message=tostring(why) end
end
function M.enter()
  M.view=nil;M.confirm=nil;M.selected=1
  if B and not B.scan() and not B.busy() then job_start('scan') end
end
function M.update()
  if B then B.update() end
end
local function tabs()
  for i,name in ipairs(t('tabs')) do
    local x=180+(i-1)*111
    shell(x,87,106,35,M.tab==i and not M.view)
    tx(name,x+5,99,9,M.tab==i and theme.accent or theme.muted,96,true)
  end
end
local function draw_list(items,selected,render,topY,rowH,count)
  count=count or 5
  local first=math.max(1,math.min(selected-2,math.max(1,#items-count+1)))
  for i=first,math.min(#items,first+count-1) do
    local y=topY+(i-first)*rowH
    shell(191,y,417,rowH-4,i==selected)
    render(items[i],i,y)
  end
end
local function draw_systems()
  local rows=list_rows()
  if #rows==0 then
    tx(t('no_scan'),201,201,13,theme.muted,390,true)
  else
    M.selected=math.max(1,math.min(#rows,M.selected))
    draw_list(rows,M.selected,function(r,i,y)
      tx(clip(r.sys.name,27),202,y+6,12,theme.text,244)
      local color=(r.state=='installed' and theme.green) or (r.state=='missing' and theme.error) or theme.accent
      tx(status_label(r.state),451,y+5,10,color,148)
      tx(tostring(r.present or 0)..'/'..tostring(r.total or 0),558,y+20,9,theme.muted,42,true)
    end,140,41,5)
  end
  local dir=B and B.detect_dir() or {}
  tx(t('source')..': '..clip(dir.dir or t('unknown'),50),194,359,10,theme.muted,405)
  tx(t('protected'),193,385,9,theme.low,410)
end
local function draw_packages()
  local pkg=B and B.package() or nil
  local source=B and B.url_ok()
  local names={t('download'),t('analyze'),t('select_file'),t('clean')}
  local subs={source and clip((B.url()),45) or t('no_url'),pkg and (clip(pkg.path,41)) or t('no_pkg'),
    B and B.analysis_ready() and t('an_ready') or t('no_pkg'),t('clean')}
  M.pkgIndex=math.max(1,math.min(#names,M.pkgIndex))
  for i=1,#names do
    local y=142+(i-1)*57
    shell(192,y,414,51,i==M.pkgIndex)
    tx(names[i],208,y+8,13,theme.text,379)
    tx(clip(subs[i],54),208,y+29,9,i==1 and not source and theme.error or theme.muted,377)
  end
  tx(t('protected'),194,387,9,theme.low,410)
end
local function draw_analysis()
  local rows=analysis_rows()
  local a=B and B.analysis() or nil
  tx(t('select_file')..' • '..t('count')..' '..#rows,194,125,12,theme.text,392)
  local checked=0
  for _,r in ipairs(rows) do if M.marked[r.item.rel] then checked=checked+1 end end
  tx(t('marked')..': '..checked,484,127,10,theme.accent,112)
  draw_list(rows,M.filesIndex,function(r,i,y)
    local mark=M.marked[r.item.rel] and '[X]' or '[ ]'
    tx(r.selectable and mark or '[-]',198,y+9,12,r.selectable and theme.accent or theme.low,31)
    tx(clip(r.item.rel,35),232,y+5,10,theme.text,344)
    tx(r.item.verified and t('verified') or t('unverified'),234,y+21,9,
      r.item.verified and theme.green or theme.muted,350)
  end,155,42,5)
  tx(t('install_tip'),194,378,10,theme.muted,407)
end
local function draw_system_files()
  local rows=list_rows()
  local r=rows[M.selected]
  if not r then return end
  tx(clip(r.sys.name,37),194,126,15,theme.text,410)
  draw_list(r.files or {},M.filesIndex,function(f,i,y)
    tx(clip(f.path,46),204,y+8,10,theme.text,335)
    tx(status_label(f.state),469,y+9,9,f.state=='installed' and theme.green or theme.muted,128)
  end,159,42,5)
end
local function draw_history()
  local rows=B and B.history() or {}
  if #rows==0 then tx(t('no_history'),206,216,14,theme.muted,370,true);return end
  M.historyIndex=math.max(1,math.min(#rows,M.historyIndex))
  draw_list(rows,M.historyIndex,function(item,i,y)
    tx(clip(tostring(item.op or 'BIOS'):upper()..'  '..os.date('%d/%m/%Y %H:%M',item.time or 0),38),204,y+6,11,theme.text,365)
    tx(item.backup and ('Backup '..tostring(item.backup)) or (item.result or '-'),204,y+23,9,theme.muted,371)
  end,146,48,5)
  tx(t('history_tip'),194,385,10,theme.muted,410)
end
local function draw_local()
  local opts={t('local_scan'),t('local_import'),t('local_restore')}
  for i=1,#opts do
    local y=158+(i-1)*61
    shell(193,y,413,54,M.importIndex==i)
    tx(opts[i],204,y+15,14,theme.text,389)
  end
  local info=legacy.status or {}
  tx(t('local_tip'),194,348,10,theme.muted,402)
  tx(clip(info.message or info.note or (info.phase=='working' and t('run')) or '',55),194,374,10,
    info.phase=='error' and theme.error or theme.low,402)
end
local function draw_job()
  if not B or not B.job then return end
  local j=B.job
  if j.state=='running' then
    box(191,398,416,27,theme.panel2,5,theme.accent)
    local percentage=j.total and j.total>0 and math.floor(math.min(100,(j.done or 0)*100/j.total)) or nil
    tx(t('run')..': '..tostring(j.phase or j.op)..(percentage and (' '..percentage..'%') or ''),200,404,10,theme.accent,397)
  elseif j.state=='error' and M.message then
    tx(clip(M.message,58),194,406,10,theme.error,411)
  end
end
local function draw_confirm()
  if not M.confirm then return end
  box(0,0,640,480,{0,0,0},0,nil,.78)
  shell(122,130,403,222,true)
  tx(t('confirm'),145,155,17,theme.text,354,true)
  ui.paragraph(M.confirm.label,148,203,352,12,theme.muted,3)
  for i,lab in ipairs({t('yes'),t('no')}) do
    local x=i==1 and 146 or 345
    local yes=M.confirm.yes == (i==1)
    box(x,289,148,42,yes and theme.accent or theme.panel2,7,yes and theme.text or theme.border)
    tx(lab,x+10,301,13,yes and theme.bg or theme.text,129,true)
  end
end
function M.draw(header,lang)
  language=lang or 'pt'
  translations.set(language=='pt' and 'pt-BR' or language)
  header('BIOS',t('title'))
  tabs()
  shell(180,130,440,287)
  if M.view=='select' then draw_analysis()
  elseif M.view=='system_files' then draw_system_files()
  elseif M.tab==1 then draw_systems()
  elseif M.tab==2 then draw_packages()
  elseif M.tab==3 then draw_history()
  else draw_local() end
  draw_job()
  if M.message and (not B or not B.job or B.job.state~='running') then
    tx(clip(M.message,63),196,416,9,theme.accent,409)
  end
  if M.view=='select' then
    ui.buttonHint(178,447,'A',t('select'),61)
    ui.buttonHint(284,447,'X',t('install'),76)
    ui.buttonHint(457,447,'Y',t('marked'),61)
    ui.buttonHint(558,447,'B',t('back'),45)
  elseif M.view=='system_files' then
    ui.buttonHint(260,447,'B',t('back'),73)
  else
    ui.buttonHint(173,447,'L',t('tabs_hint'),67)
    ui.buttonHint(297,447,'A',t('open'),50)
    ui.buttonHint(409,447,'X',t('scan_short'),63)
    ui.buttonHint(548,447,'B',t('back'),48)
  end
  draw_confirm()
end
local function package_action()
  if M.pkgIndex==1 then
    if not B.url_ok() then M.message=t('no_url');return end
    local info=B.info()
    if not info or not info.name or not info.size or info.url~=B.url() then
      job_start('info') -- primeiro consulta nome e tamanho; nenhuma transferência é feita
      M.message=t('source')..': '..t('run')
    else
      request(t('confirm_dl')..' '..tostring(info.name),function()
        job_start('download',{name=info.name,size=info.size})
      end)
    end
  elseif M.pkgIndex==2 then
    local pkg=B.package()
    if not pkg then M.message=t('no_pkg');return end
    job_start('analyze',{pkg=pkg.path})
  elseif M.pkgIndex==3 then
    if not B.analysis_ready() then M.message=t('no_pkg');return end
    M.view='select';M.filesIndex=1;M.marked={}
  elseif M.pkgIndex==4 then
    local paths={}
    for _,item in ipairs(B.clean_plan()) do paths[#paths+1]=item.path end
    if #paths==0 then M.message=t('no_pkg');return end
    request(t('confirm_clean'),function() job_start('clean',{paths=paths}) end)
  end
end
local function select_all_verified()
  for _,r in ipairs(analysis_rows()) do
    if r.selectable then M.marked[r.item.rel]=true end
  end
end
function M.key(key)
  if M.confirm then
    if key=='left' or key=='up' then M.confirm.yes=true
    elseif key=='right' or key=='down' then M.confirm.yes=false
    elseif key=='b' then M.confirm=nil
    elseif key=='a' then
      local c=M.confirm;M.confirm=nil
      if c.yes then c.run() end
    end
    return true
  end
  if B and B.busy() then
    if key=='b' then B.cancel();return true end
    return true
  end
  if M.view=='system_files' then
    local rows=list_rows();local r=rows[M.selected]
    local len=r and #(r.files or {}) or 0
    if key=='up' then M.filesIndex=math.max(1,M.filesIndex-1)
    elseif key=='down' then M.filesIndex=math.min(len,M.filesIndex+1)
    elseif key=='b' then M.view=nil end
    return true
  elseif M.view=='select' then
    local rows=analysis_rows()
    M.filesIndex=math.max(1,math.min(math.max(1,#rows),M.filesIndex))
    if key=='up' then M.filesIndex=math.max(1,M.filesIndex-1)
    elseif key=='down' then M.filesIndex=math.min(#rows,M.filesIndex+1)
    elseif key=='a' then
      local r=rows[M.filesIndex]
      if r and r.selectable then M.marked[r.item.rel]=not M.marked[r.item.rel] end
    elseif key=='y' then select_all_verified()
    elseif key=='x' then install_selected()
    elseif key=='b' then M.view=nil end
    return true
  end
  if key=='l' then M.tab=(M.tab-2)%4+1;M.message=nil;return true end
  if key=='r' then M.tab=M.tab%4+1;M.message=nil;return true end
  if key=='b' then return false end
  if M.tab==1 then
    local rows=list_rows()
    if key=='up' then M.selected=math.max(1,M.selected-1)
    elseif key=='down' then M.selected=math.min(#rows,M.selected+1)
    elseif key=='a' then
      if #rows==0 then job_start('scan') else M.view='system_files';M.filesIndex=1 end
    elseif key=='x' or key=='y' then job_start('scan') end
  elseif M.tab==2 then
    if key=='up' then M.pkgIndex=math.max(1,M.pkgIndex-1)
    elseif key=='down' then M.pkgIndex=math.min(4,M.pkgIndex+1)
    elseif key=='a' or key=='x' then package_action() end
  elseif M.tab==3 then
    local rows=B.history()
    if key=='up' then M.historyIndex=math.max(1,M.historyIndex-1)
    elseif key=='down' then M.historyIndex=math.min(#rows,M.historyIndex+1)
    elseif key=='a' then
      local item=rows[M.historyIndex]
      if not item or not item.backup then M.message=t('no_backup');return true end
      request(t('confirm_restore')..' '..item.backup,function() job_start('restore',{backup=item.backup}) end)
    end
  else
    if key=='up' then M.importIndex=math.max(1,M.importIndex-1)
    elseif key=='down' then M.importIndex=math.min(3,M.importIndex+1)
    elseif key=='a' or key=='x' then
      if M.importIndex==1 then legacy.run('scan')
      elseif M.importIndex==2 then request(t('confirm_import'),function() legacy.run('import') end)
      else request(t('confirm_restore'),function() legacy.run('restore') end) end
    elseif key=='y' then legacy.run('scan') end
  end
  return true
end
function M.hasModal() return M.confirm~=nil end
function M.mouse(x,y)
  if M.confirm then
    if y>=287 and y<=332 then
      if x>=145 and x<=294 then M.confirm.yes=true;M.key('a')
      elseif x>=345 and x<=495 then M.confirm.yes=false;M.key('a') end
    end
    return true
  end
  if y>=87 and y<124 and x>=179 and x<=623 then
    local idx=math.floor((x-180)/111)+1
    if idx>=1 and idx<=4 then M.tab=idx;M.view=nil end
    return true
  end
  if x>=191 and x<=608 and y>=140 and y<373 then
    if M.view=='select' then
      local rows=analysis_rows();local first=math.max(1,math.min(M.filesIndex-2,math.max(1,#rows-4)))
      M.filesIndex=math.min(#rows,first+math.floor((y-155)/42))
      M.filesIndex=math.max(1,M.filesIndex)
    elseif M.view=='system_files' then
      local r=list_rows()[M.selected];local rows=r and r.files or {}
      local first=math.max(1,math.min(M.filesIndex-2,math.max(1,#rows-4)))
      M.filesIndex=math.max(1,math.min(#rows,first+math.floor((y-159)/42)))
    elseif M.tab==1 then
      local rows=list_rows();local first=math.max(1,math.min(M.selected-2,math.max(1,#rows-4)))
      M.selected=math.max(1,math.min(#rows,first+math.floor((y-140)/41)))
    elseif M.tab==2 then M.pkgIndex=math.max(1,math.min(4,math.floor((y-142)/57)+1))
    elseif M.tab==3 then
      local rows=B.history();local first=math.max(1,math.min(M.historyIndex-2,math.max(1,#rows-4)))
      M.historyIndex=math.max(1,math.min(#rows,first+math.floor((y-146)/48)))
    else M.importIndex=math.max(1,math.min(3,math.floor((y-158)/61)+1)) end
    return true
  end
  if y>=440 then
    if x>545 then return false end
    if x<282 then M.key('l')
    elseif x<408 then M.key('a')
    else M.key('x') end
    return true
  end
  return true
end
return M
