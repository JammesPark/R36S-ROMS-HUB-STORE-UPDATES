-- A regressao da tela azul na linha main.lua:1743 surgiu ao atualizar catálogo.
-- Executa o corpo real de refreshCatalog com backend simulado e sem IO/rede.
local f=assert(io.open('src/main.lua','rb'))
local source=f:read('*a');f:close()
local block=assert(source:match('(local function refreshCatalog%(%).-\nend)\n%-%- Modal separado'),'bloco nao localizado')
local function make(external)
 local pre='return function(external)\nlocal notice,noticeTime\nlocal function tr(k) return k end\n'
 local post='\nreturn function() local ok,result=pcall(refreshCatalog);return ok,result,notice,noticeTime end end'
 local compile,err=load(pre..block..post,'refresh_test')
 assert(compile,err)
 return compile()(external)
end
local ok,result,notice,duration=make({busy=function() return false end,refresh=function() return true end})()
assert(ok and result and notice=='syncing' and duration==2)
ok,result,notice=make({busy=function() return true end,refresh=function() error('should not start') end})()
assert(ok and not result and notice=='syncing')
ok,result,notice=make({busy=function() error('sysfs error') end,refresh=function() return true end})()
assert(ok and not result and notice=='network_error')
ok,result,notice=make({busy=function() return false end,refresh=function() error('helper failed') end})()
assert(ok and not result and notice=='network_error')
ok,result,notice=make({busy=function() return false end,refresh=function() return false end})()
assert(ok and not result and notice=='network_error')
print('PASS catalog refresh: successful, busy, missing backend and exceptions never crash UI')
