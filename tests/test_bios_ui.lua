-- Teste de interface sem runtime LÖVE: valida fluxo de navegacao, idiomas e modais.
package.path = './src/?.lua;./src/?/init.lua;'..package.path
local ui={}
function ui.text() end
function ui.rect() end
function ui.panel() end
function ui.ellipsize(s,n) return tostring(s):sub(1,n) end
function ui.buttonHint() end
function ui.paragraph(s) return 100 end
package.preload.ui=function() return ui end
local theme={accent={1,0,0},panel={0,0,0},panel2={0,0,0},muted={0,0,0},text={1,1,1},border={0,0,0},low={0,0,0},error={1,0,0},green={0,1,0},bg={0,0,0}}
package.preload.theme=function() return theme end
local old={status={phase='idle',systems={}},run=function() return true end}
package.preload.bios_manager=function() return old end
package.preload['roms_bios.config']=function() return {configure=function() end} end
local calls={}
local mock={job=nil}
function mock.recover() end
function mock.scan() return {files={}} end
function mock.busy() return false end
function mock.start(op,args,cb) calls[#calls+1]=op;return true end
function mock.update() end
function mock.rows() return {{sys={name='Playstation'},state='installed',present=1,total=1,files={{path='scph.bin',state='installed'}}}} end
function mock.history() return {{op='install',time=123456,backup='20261118-010101'}} end
function mock.package() return {path='/tmp/test.zip'} end
function mock.url_ok() return false end
function mock.info() end
function mock.analysis_ready() return true end
function mock.analysis() return {pkg_name='test.zip',tmp='/tmp',items={{rel='scph.bin',md5='abcd',verified=true,kind='bios',dests={{inside=true,real=nil,special=false,target='scph.bin'}}}}} end
function mock.clean_plan() return {} end
function mock.detect_dir() return {dir='/roms/bios'} end
function mock.message() return 'Erro' end
package.preload['roms_bios.bios']=function() return mock end
local m=require('bios_enhanced_ui')
m.init('/tmp/r36sromsstore')
for _,lang in ipairs({'pt','en','es','ru'}) do
 m.tab=1;m.pkgIndex=1;m.importIndex=1;m.enter();m.draw(function() end,lang)
 m.key('a');m.draw(function() end,lang)
 m.key('b')
 m.key('r');m.draw(function() end,lang)
 m.key('down');m.key('down');m.key('a');m.draw(function() end,lang)
 m.key('y');m.key('x');assert(m.hasModal(),'expected install confirmation')
 m.key('left');m.key('a');assert(not m.hasModal())
 m.key('b')
 m.tab=3;m.draw(function() end,lang)
 m.key('a');assert(m.hasModal(),'expected restore confirmation')
 m.key('b')
 m.tab=4;m.importIndex=1;m.draw(function() end,lang)
 m.key('down');m.key('a');assert(m.hasModal(),'expected local import confirmation')
 m.key('b')
end
assert(#calls>=1)
-- O download da BIOS nao deve ser cancelado por navegacao.
local cancelled,updates=0,0
mock.job={op='download',state='running',phase='download',done=55,total=100}
mock.busy=function() return mock.job and mock.job.state=='running' end
mock.cancel=function() cancelled=cancelled+1 end
mock.update=function() updates=updates+1 end
assert(m.key('b')==false,'B deve sair mantendo o download')
assert(cancelled==0,'navegacao nao pode cancelar')
m.update()
assert(updates==1,'atualizacao em segundo plano deve continuar')
assert(m.key('x')==true and cancelled==1,'X cancela explicitamente')
assert(m.mouse(260,455)==false,'B na tela deixa o download ativo')
assert(cancelled==1)
print('PASS BIOS: download em segundo plano e cancelamento somente explicito')
