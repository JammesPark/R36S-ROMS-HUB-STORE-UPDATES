-- Diagnostico de erros de controle e rede na loja (LuaJIT/Lua 5.3).
package.path='./src/?.lua;'..package.path
local guard=require('ui_error_guard')
local reports={}
local ok,value=guard.call('sucesso',function() return 42 end,
  function() error('nao deve registrar sucesso') end)
assert(ok and value==42)
ok,value=guard.call('refreshCatalog',function() error('falha simulada do backend') end,
 function(label,trace)
  reports[#reports+1]={label=label,trace=trace}
 end)
assert(not ok)
assert(type(value)=='string' and value:find('falha simulada do backend',1,true))
assert(value:find('stack traceback',1,true),'traceback completo necessario para diagnostico')
assert(#reports==1 and reports[1].label=='refreshCatalog')
assert(reports[1].trace==value)
local attempts=0
ok,value=guard.call('arquivo sem permissao',function()
 attempts=attempts+1
 error('simulacao')
end,function() error('falha ao criar log') end)
assert(not ok and attempts==1,'falha ao escrever log nao pode derrubar interface')
ok,value=guard.call('sem callback',function() error('sem escrita') end)
assert(not ok and value:find('sem escrita',1,true))
assert(type(guard.call)=='function')
print('PASS UI error guard: traceback, falha de rede, falha de escrita e recuperacao')
