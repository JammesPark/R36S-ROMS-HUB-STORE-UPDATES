-- Configuração isolada do gerenciador BIOS; não modifica o config.lua da ROMS STORE.
-- Fonte já definida pelo usuário na PORTS STORE. Pode ser sobrescrita em bios_url.txt.
-- A disponibilidade e o licenciamento dos arquivos na fonte não foram verificados.
local C = { configured = false, BIOS_URL = "https://archive.org/download/bios-r-36s/Bios%20r36s.rar" }
local function abspath(p)
  return type(p) == "string" and p:sub(1, 1) == "/" and p ~= "/" and not p:find("/%.%./")
end
function C.configure(opts)
  assert(type(opts) == "table", "roms_bios: configure espera uma tabela")
  assert(abspath(opts.app_dir), "roms_bios: app_dir absoluto é obrigatório")
  assert(opts.app_dir ~= "/roms" and opts.app_dir ~= "/roms2", "roms_bios: app_dir inválido")
  C.APP_DIR = opts.app_dir:gsub("/+$", "")
  C.ROMS_DIR = opts.roms_dir or "/roms"
  assert(abspath(C.ROMS_DIR), "roms_bios: roms_dir deve ser absoluto")
  C.FETCH_SH = opts.fetch_sh or (C.APP_DIR .. "/bin/fetch.sh")
  C.BUNDLED_7Z = opts.bundled_7z or (C.APP_DIR .. "/bin/7zzs")
  C.BIOS_DIR = opts.bios_dir
  if C.BIOS_DIR then assert(abspath(C.BIOS_DIR), "roms_bios: bios_dir deve ser absoluto") end
  C.BIOS_URL = opts.bios_url or C.BIOS_URL -- Só URL. Nenhum firmware é incluído no aplicativo.
  C.configured = true
  return C
end
return C
