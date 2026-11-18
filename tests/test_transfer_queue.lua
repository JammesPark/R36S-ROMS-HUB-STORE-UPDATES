-- Fila real sem rede: persistencia, ordem, pausa/retomada e cancelamento.
package.path='./src/?.lua;'..package.path
local Q=require('transfer_queue')
local tmp=os.tmpname();os.remove(tmp);assert(os.execute('mkdir -p '..tmp..'/state'))
Q.init(tmp)
local game={game_path='https://example.org/test.zip',category='nes',name='Teste ROM',card=1,sha256='',overwrite=false}
assert(Q.enqueue('rom',game))
assert(Q.enqueue('bios',{name='bios.zip',size=500}))
assert(Q.enqueue('theme',{id='test-theme',name='Tema teste',resolution='640x480'}))
assert(#Q.items==3)
local id=Q.items[1].id
assert(Q.handle({id=id},'pause'))
assert(Q.items[1].state=='paused')
assert(Q.handle({id=id},'resume'))
assert(Q.items[1].state=='queued')
Q.init(tmp)
assert(#Q.items==3 and Q.items[1].payload.game_path==game.game_path,'fila persistida com segurança')
local rom={pending=nil,phase='idle'}
local rom_started=0
function rom.busy() return rom.pending~=nil end
function rom.download(g,card,overwrite)
 assert(g.game_path==game.game_path and card==1 and overwrite==false)
 rom_started=rom_started+1;rom.pending='download';rom.phase='downloading';return true
end
local current
local bios={queueDownload=function(name,size)
 assert(name=='bios.zip' and size==500)
 current={op='download',state='running'};return true
end,job=function() return current end}
local theme={busy=false,queueInstall=function(id,res)
 assert(id=='test-theme' and res=='640x480')
 theme.busy=true;return true
end}
Q.tick(rom,bios,theme)
assert(rom_started==1 and #Q.items==2 and Q.current.kind=='rom')
Q.tick(rom,bios,theme)
assert(#Q.items==2,'nao lancar duas transferencias simultaneas')
rom.pending=nil;rom.phase='done'
Q.tick(rom,bios,theme)
assert(Q.current.kind=='bios' and #Q.items==1)
current.state='done'
Q.tick(rom,bios,theme)
assert(Q.current.kind=='theme' and #Q.items==0 and theme.busy)
theme.busy=false;theme.transferState={phase='done'}
Q.tick(rom,bios,theme)
assert(Q.current==nil)
assert(Q.enqueue('bios',{name='bios-agendada.zip',size=123}))
local waiting=Q.visible()[1]
assert(waiting.kind=='bios' and waiting.phase=='queued' and waiting.queued)
assert(Q.handle(waiting,'cancel') and #Q.items==0)
assert(not Q.enqueue('theme',{id='../escape',name='Ataque',resolution='640x480'}))
assert(not Q.enqueue('bios',{name='../foo',size=0}))
print('PASS persistent queue: FIFO, pause/resume, cancel, validation and engine handoff')
