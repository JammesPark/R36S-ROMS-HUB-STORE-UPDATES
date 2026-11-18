-- Compatibilidade OTA 0.4.1 -> 0.4.4: o zip antigo só aceita 8 arquivos.
-- Os novos auxiliares são extraídos de game.love, verificado na Release via SHA-256.
-- Nunca apaga arquivos do usuário ou modifica state/, backup/ ou conf/.
local M={}
local entries={
  {'bundled/es_theme_manager.py','bin/es_theme_manager.py',false},
  {'bundled/es_themes_seed.json','bin/es_themes_seed.json',false},
  {'bundled/fetch.sh','bin/fetch.sh',true},
  {'bundled/7zzs','bin/7zzs',true},
}
local function quote(v) return "'"..tostring(v):gsub("'","'\\''").."'" end
local function exists(p)
  local f=io.open(p,'rb')
  if f then f:close(); return true end
  return false
end
function M.run(home)
  if type(home)~='string' or home:match('/([^/]+)$')~='r36s-roms-store' then
    return false,'Diretório inesperado'
  end
  for _, item in ipairs(entries) do
    local src, dest, exec = item[1],home..'/'..item[2],item[3]
    if not exists(dest) then
      local data=love and love.filesystem and love.filesystem.read(src)
      if type(data)~='string' or #data < 100 then
        return false,'Recurso ausente: '..src
      end
      local tmp=dest..'.ota-temp'
      local f=io.open(tmp,'wb')
      if not f then return false,'Sem permissão: '..dest end
      local ok=f:write(data)
      f:close()
      if not ok then os.remove(tmp); return false,'Escrita incompleta: '..dest end
      if exec then
        local result=os.execute('chmod 755 '..quote(tmp))
        if result~=true and result~=0 then os.remove(tmp);return false,'chmod falhou' end
      end
      local renamed=os.rename(tmp,dest)
      if not renamed then os.remove(tmp);return false,'Não foi possível instalar '..dest end
    end
  end
  return true
end
return M
