-- Unico ponto de captura de falhas Lua da interface, compativel com LuaJIT.
-- Recebe callback de log que nunca pode interromper a UI.
local M={}
local function traceback(message)
  message=tostring(message)
  if debug and type(debug.traceback)=='function' then
    return debug.traceback(message,2)
  end
  return message
end
function M.call(label,action,report)
  local ok,result=xpcall(action,traceback)
  if not ok then
    if type(report)=='function' then pcall(report,label,result) end
    return false,result
  end
  return true,result
end
return M
