-- Gerenciador INDEPENDENTE de BIOS da ROMS STORE: apenas arquivos locais do usuário.
-- Nunca baixa, distribui ou fornece imagens de BIOS. Python faz a validação.
local json=require('json')
local M={status={phase='idle',systems={}},pending=false,selected=1}
local home,state,last
local function shq(s) return "'"..tostring(s):gsub("'","'\\''").."'" end
local function read(p)
  local f=io.open(p,'rb');if not f then return nil end
  local data=f:read('*a');f:close();return data
end
function M.init(app)
  home=app;state=home..'/state/bios_manager/status.json'
  local v=json.decode(read(state) or '')
  if type(v)=='table' then M.status=v end
end
-- Compatibilidade OTA: o pacote legado não aceita o oitavo arquivo.
-- O backend fica embutido no game.love validado pelo checksum da Release.
local function ensureBackend(path)
  local existing=io.open(path,'rb')
  if existing then existing:close();return true end
  if not (love and love.filesystem and love.filesystem.read) then return false end
  local data=love.filesystem.read('bundled/bios_manager.py')
  if type(data)~='string' or #data<1000 then return false end
  local temp=path..'.new-bios-manager'
  local f=io.open(temp,'wb')
  if not f then return false end
  local ok=f:write(data)
  f:close()
  if not ok then os.remove(temp);return false end
  if not os.rename(temp,path) then os.remove(temp);return false end
  return true
end
function M.run(action)
  if M.pending or (action~='scan' and action~='import' and action~='restore') then return false end
  if not home then return false end
  local path=home..'/bin/bios_manager.py'
  if not ensureBackend(path) then
    M.status={phase='error',message='Componente BIOS indisponível. Reinstale o pacote completo.'}
    return false
  end
  M.pending=true;M.status={phase='working',action=action,systems=M.status.systems or {}}
  last=nil
  os.remove(state)
  local ok=os.execute('python3 '..shq(path)..' '..action..' >/dev/null 2>&1 </dev/null &')
  if not ok then M.pending=false;M.status={phase='error',message='Python 3 não disponível'};return false end
  return true
end
function M.tick()
  if not state then return end
  local txt=read(state)
  if not txt or txt==last then return end
  local info=json.decode(txt)
  if type(info)~='table' or type(info.phase)~='string' then return end
  last=txt;M.status=info
  if info.phase~='working' then M.pending=false end
end
function M.t(lang,key)
  local labels={
   pt={title='BIOS do sistema',scan='Verificar BIOS',import='Importar BIOS',restore='Restaurar backup',
     hint='Use somente BIOS que você tem direito de utilizar.',source='Pasta do console',
     importpath='Copie BIOS ou ZIP para:',working='Verificando arquivos...',done='Verificação concluída',
     error='Ocorreu um erro',missing='Ausente',partial='Parcial',present='Presente',
     choose='Confirma a operação?',yes='Sim',no='Não',scan_hint='A Verificar   X Importar   Y Backup   B Voltar',
     disclaimer='Arquivo encontrado não confirma autenticidade.',no_dir='Pasta de BIOS indisponível',
     import_note='Arquivos locais reconhecidos; cópias anteriores serão preservadas.',
     restore_note='Restaurar o último backup criado pela loja?'},
   en={title='System BIOS',scan='Scan BIOS',import='Import BIOS',restore='Restore backup',
     hint='Use only BIOS files you are entitled to use.',source='BIOS folder',importpath='Copy BIOS or ZIP files to:',
     working='Checking files...',done='Scan finished',error='Operation failed',missing='Missing',partial='Partial',present='Present',
     choose='Confirm operation?',yes='Yes',no='No',scan_hint='A Scan   X Import   Y Backup   B Back',
     disclaimer='Presence does not verify authenticity.',no_dir='BIOS folder unavailable',
     import_note='Local recognized files; old files will be backed up.',restore_note='Restore the previous store backup?'},
   es={title='BIOS del sistema',scan='Verificar BIOS',import='Importar BIOS',restore='Restaurar respaldo',
     hint='Use solo BIOS que tiene derecho a utilizar.',source='Carpeta BIOS',importpath='Copie BIOS o ZIP en:',
     working='Comprobando archivos...',done='Verificación terminada',error='Error de operación',missing='Ausente',partial='Parcial',present='Presente',
     choose='¿Confirmar operación?',yes='Sí',no='No',scan_hint='A Revisar   X Importar   Y Copia   B Volver',
     disclaimer='La presencia no confirma autenticidad.',no_dir='Carpeta BIOS no disponible',
     import_note='Archivos locales; se hará una copia de seguridad.',restore_note='¿Restaurar la copia de seguridad?'},
   ru={title='Системные BIOS',scan='Проверить BIOS',import='Импорт BIOS',restore='Восстановить резервную копию',
     hint='Используйте только законно полученные BIOS.',source='Папка BIOS',importpath='Скопируйте BIOS или ZIP сюда:',
     working='Проверка файлов...',done='Проверка завершена',error='Ошибка операции',missing='Отсутствует',partial='Частично',present='Есть',
     choose='Подтвердить действие?',yes='Да',no='Нет',scan_hint='A Проверка  X Импорт  Y Резерв  B Назад',
     disclaimer='Наличие не подтверждает подлинность.',no_dir='Папка BIOS недоступна',
     import_note='Локальные файлы; будут сохранены копии.',restore_note='Восстановить предыдущую резервную копию?'}
  }
  return (labels[lang] or labels.pt)[key] or labels.pt[key] or key
end
return M
