-- Telemetria local: Wi-Fi, relogio e bateria no Linux do console.
-- Nenhum serviço remoto é acessado aqui; ausência de sensor = --.
local M={elapsed=999,info={wifi=false,battery=nil,time='--:--'}}
local function read(path)
  local f=io.open(path,'r')
  if not f then return nil end
  local s=f:read('*a');f:close()
  return s and s:gsub('%s+$','')
end
local function battery()
  for _,device in ipairs({'battery','Battery','axp20x-battery','rk817-battery',
    'rk818-battery','adc-battery','cw2015-battery'}) do
    local root='/sys/class/power_supply/'..device..'/'
    local s=read(root..'capacity')
    local number=tonumber(s)
    if number and number>=0 and number<=100 then return number end
  end
  -- Outros nomes são descobertos pelo subsistema do kernel; sem inventar porcentagem.
  local pipe=io.popen('find /sys/class/power_supply -maxdepth 2 -name capacity -type f 2>/dev/null','r')
  if pipe then
    for path in pipe:lines() do
      local number=tonumber(read(path))
      if number and number>=0 and number<=100 then pipe:close();return number end
    end
    pipe:close()
  end
  return nil
end
local function wifi()
  local data=read('/proc/net/wireless')
  for _,dev in ipairs({'wlan0','wlan1','wl0'}) do
    local state=read('/sys/class/net/'..dev..'/operstate')
    if state=='up' then return true end
    -- CFWs sem operstate confiavel: exige sinal de link, nao so uma interface.
    if not state and data then
      local quality=data:match(dev..':%s*%S+%s+([%d%.]+)')
      if tonumber(quality) and tonumber(quality)>0 then return true end
    end
  end
  return false
end
function M.update(dt,force)
  M.elapsed=M.elapsed+(tonumber(dt) or 0)
  if force or M.elapsed>=8 then
    M.elapsed=0
    M.info.wifi=wifi()
    M.info.battery=battery()
  end
  -- Hora real local, sem misturar com o tempo de jogo.
  M.info.time=os.date('%H:%M')
end
function M.get() return M.info end
return M
