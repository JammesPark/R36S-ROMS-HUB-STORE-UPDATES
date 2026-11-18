-- Atualizações da R36S ROMS STORE: consultas automáticas, confirmação manual.
-- A aplicação não substitui seus próprios arquivos enquanto o LÖVE está aberto.
local json=require('json')
local M={status={phase='idle'},pending=false,offered=false}
local home,state,seen
local function quote(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function read(path)
  local f=io.open(path,'rb')
  if not f then return nil end
  local data=f:read('*a');f:close()
  return data
end
function M.init(app,statepath)
  home,state=app,statepath
  local parsed=json.decode(read(state..'/store_update_status.json') or '')
  if type(parsed)=='table' then M.status=parsed end
end
function M.run(action)
  if M.pending or action~='check' and action~='download' then return false end
  if not home or not state then return false end
  local path=home..'/bin/store_updater.py'
  M.pending=true
  M.status={phase=action=='check' and 'checking' or 'downloading'}
  seen=nil
  os.remove(state..'/store_update_status.json')
  local cmd='python3 '..quote(path)..' '..action..' >/dev/null 2>&1 </dev/null &'
  local ok=os.execute(cmd)
  if ok==false or ok==nil then
    M.pending=false
    M.status={phase='error',message='Python 3 indisponível'}
    return false
  end
  return true
end
function M.tick()
  if not state then return end
  local raw=read(state..'/store_update_status.json')
  if not raw or raw==seen then return end
  local parsed=json.decode(raw)
  if type(parsed)~='table' or type(parsed.phase)~='string' then return end
  seen=raw
  M.status=parsed
  if parsed.phase~='checking' and parsed.phase~='downloading' and parsed.phase~='verifying' then
    M.pending=false
  end
end
function M.install()
  if M.status.phase~='ready' or type(M.status.sha256)~='string'
    or type(M.status.version)~='string' then return false end
  local f=io.open(state..'/store_update_apply.request','wb')
  if not f then return false end
  f:write(string.format('{"version":%q,"sha256":%q}',
    M.status.version,M.status.sha256))
  f:close()
  return true
end
function M.backups()
  local t=json.decode(read(state..'/updates/backups.json') or '')
  return type(t)=='table' and t or {}
end
function M.history()
  local t=json.decode(read(state..'/updates/history.json') or '')
  return type(t)=='table' and t or {}
end
function M.localPackages()
  local t=json.decode(read(state..'/updates/local_packages.json') or '')
  return type(t)=='table' and t or {}
end
local function command(action,arg,background)
  if not home then return false end
  local cmd='python3 '..quote(home..'/bin/store_updater.py')..' '..action
  if arg then cmd=cmd..' '..quote(arg) end
  cmd=cmd..' >/dev/null 2>&1 </dev/null'..(background and ' &' or '')
  local ret=os.execute(cmd)
  return ret~=false and ret~=nil
end
function M.refreshBackups() return command('list') end
function M.refreshLocal() return command('scan_local') end
function M.deleteBackup(id)
  if type(id)~='string' or not id:match('^backup%-%d+%-%d+$') then return false end
  local ok=command('delete',id)
  M.refreshBackups()
  return ok
end
function M.downloadLocal(name)
  if M.pending or type(name)~='string' or not name:match('^R36S_ROMS_STORE_v[%w%.%-]+_UPDATE%.zip$') then return false end
  M.pending=true;M.status={phase='checking'}
  seen=nil
  os.remove(state..'/store_update_status.json')
  if not command('local',name,true) then M.pending=false;return false end
  return true
end
function M.requestRestore(id)
  if type(id)~='string' or not id:match('^backup%-%d+%-%d+$') then return false end
  local f=io.open(state..'/store_update_apply.request','wb')
  if not f then return false end
  f:write(string.format('{"action":"restore","backup":%q}',id));f:close()
  return true
end
local texts={
 pt={backups='Backups',history_title='Histórico de atualizações',local_title='Atualização local',restore='Restaurar',delete_backup='Excluir backup',restore_question='Restaurar esta versão?',delete_question='Excluir este backup?',no_backups='Nenhum backup disponível.',no_history='Nenhuma atualização no histórico.',no_local='Copie um UPDATE.zip para state/updates/inbox.',local_hint='A Preparar  B Voltar',backups_hint='A Restaurar  X Excluir  B Voltar',updates_hint='X Backups  Y Histórico  START Local',title='Atualizações da loja',current='Versão atual',latest='Nova versão disponível',
   idle='Pronto para verificar.',no_release='Nenhuma atualização publicada neste canal.',checking='Verificando atualizações...',uptodate='Você está usando a versão mais recente.',
   available='Nova atualização encontrada.',downloading='Baixando atualização...',
   verifying='Verificando integridade do pacote...',ready='Atualização verificada. Pronta para instalar.',
   error='Falha ao verificar ou baixar atualização.',installed='Atualização instalada.',
   rolled_back='A versão anterior foi restaurada.',check='Verificar novamente',
   download='Baixar atualização',install='Instalar e reiniciar',back='Voltar',
   no_auto='A loja verifica automaticamente, mas a instalação exige confirmação.',
   notice='Atualização disponível',changes='Novidades',open='Ver atualização',later='Depois'},
 en={backups='Backups',history_title='Update history',local_title='Local update',restore='Restore',delete_backup='Delete backup',restore_question='Restore this version?',delete_question='Delete this backup?',no_backups='No backups available.',no_history='No update history.',no_local='Copy an UPDATE.zip to state/updates/inbox.',local_hint='A Stage  B Back',backups_hint='A Restore  X Delete  B Back',updates_hint='X Backups  Y History  START Local',title='Store updates',current='Current version',latest='New version available',
   idle='Ready to check.',no_release='No update published on this channel.',checking='Checking for updates...',uptodate='You have the latest version.',
   available='New update found.',downloading='Downloading update...',
   verifying='Checking package integrity...',ready='Update verified. Ready to install.',
   error='Update check/download failed.',installed='Update installed.',
   rolled_back='Previous version restored.',check='Check again',download='Download update',
   install='Install and restart',back='Back',
   no_auto='The store checks automatically, but installation requires confirmation.',
   notice='Update available',changes="What's new",open='View update',later='Later'},
 es={backups='Copias',history_title='Historial de actualizaciones',local_title='Actualización local',restore='Restaurar',delete_backup='Eliminar copia',restore_question='¿Restaurar esta versión?',delete_question='¿Eliminar esta copia?',no_backups='No hay copias disponibles.',no_history='No hay historial.',no_local='Copia un UPDATE.zip a state/updates/inbox.',local_hint='A Preparar  B Volver',backups_hint='A Restaurar  X Borrar  B Volver',updates_hint='X Copias  Y Historial  START Local',title='Actualizaciones',current='Versión actual',latest='Nueva versión disponible',
   idle='Listo para buscar.',no_release='No hay actualizaciones publicadas.',checking='Buscando actualizaciones...',uptodate='Tienes la versión más reciente.',
   available='Nueva actualización encontrada.',downloading='Descargando...',
   verifying='Verificando el paquete...',ready='Actualización lista para instalar.',
   error='Error al buscar o descargar.',installed='Actualización instalada.',
   rolled_back='Versión anterior restaurada.',check='Buscar nuevamente',
   download='Descargar',install='Instalar y reiniciar',back='Volver',
   no_auto='Búsqueda automática, instalación solo con confirmación.',
   notice='Actualización disponible',changes='Novedades',open='Ver actualización',later='Después'},
 ru={backups='Копии',history_title='История обновлений',local_title='Локальное обновление',restore='Восстановить',delete_backup='Удалить копию',restore_question='Восстановить версию?',delete_question='Удалить копию?',no_backups='Нет резервных копий.',no_history='Нет истории.',no_local='Скопируйте UPDATE.zip в state/updates/inbox.',local_hint='A Выбрать  B Назад',backups_hint='A Вернуть  X Удалить  B Назад',updates_hint='X Копии  Y История  START Локально',title='Обновления магазина',current='Текущая версия',latest='Доступна новая версия',
   idle='Готово к проверке.',no_release='В канале пока нет обновлений.',checking='Проверка обновлений...',uptodate='Установлена последняя версия.',
   available='Доступно новое обновление.',downloading='Загрузка обновления...',
   verifying='Проверка пакета...',ready='Обновление готово к установке.',
   error='Ошибка проверки или загрузки.',installed='Обновление установлено.',
   rolled_back='Восстановлена предыдущая версия.',check='Проверить снова',
   download='Скачать',install='Установить и перезапустить',back='Назад',
   no_auto='Проверка автоматическая, установка требует подтверждения.',
   notice='Доступно обновление',changes='Что нового',open='Посмотреть',later='Позже'}
}
function M.tr(lang,key)
  return ((texts[lang] or texts.pt)[key] or texts.pt[key] or key)
end
return M
