-- Testa o estado agregado sem baixar arquivos e sem executar threads.
package.path='./src/?.lua;'..package.path
local m=require('download_center')
local tmp=os.tmpname()
os.remove(tmp);os.execute('mkdir -p '..tmp..'/state')
m.init(tmp)
local rom={pending='download',activeDownload={name='Teste ROM',card=2},downloaded=20,expected=100}
local bios={job=function() return {op='download',state='running',phase='download',done=50,total=200,t0=12} end}
local es={transfer=function() return {task='install',job_id='unit001',name='Exemplo',phase='downloading',downloaded=25,total=100} end}
local upd={status={phase='verifying',version='0.4.5-beta',downloaded=100,total=100}}
m.poll(rom,bios,es,upd,{})
assert(#m.active==4 and m.count()==4,'esperadas 4 transferências ativas')
assert(m.active[2].kind=='bios' and m.active[2].done==50)
assert(m.active[3].kind=='theme' and m.active[3].total==100)
bios={job=function() return {op='download',state='done',done=200,total=200,t0=12} end}
es={transfer=function() return {task='install',job_id='unit001',name='Exemplo',phase='done'} end}
upd={status={phase='ready',version='0.4.5-beta'}}
rom.pending=nil
m.poll(rom,bios,es,upd,{})
assert(#m.active==0 and m.count()==3,'histórico após conclusão')
m.poll(rom,bios,es,upd,{})
assert(m.count()==3,'não deve registrar históricos duplicados')
-- Regressao: historico da 0.4.5 nao possuia done/total.
local f=assert(io.open(tmp..'/state/roms_transfer_log.json','wb'))
f:write('[{"id":"old-bios","kind":"bios","name":"BIOS antiga","phase":"done","detail":"SD1","time":1234},'
 ..'{"id":"old-theme","kind":"theme","name":"Tema antigo","phase":"done","done":"100","total":"200"},'
 ..'{"id":"old-corrupt","kind":"rom","phase":"done","done":"inf","total":"bad"}]')
f:close()
m.init(tmp)
m.poll(nil,nil,nil,nil,{})
assert(m.count()==3,'historico antigo precisa carregar')
local entries=m.entries()
local summary,pct=m.formatProgress(entries[1])
assert(type(summary)=='string' and pct==nil,'historico sem total nao pode gerar erro')
summary,pct=m.formatProgress(entries[2])
assert(pct==50 and type(summary)=='string','progresso numerico em strings')
summary,pct=m.formatProgress(entries[3])
assert(pct==nil and type(summary)=='string','valor malformado nao pode gerar erro')
assert(entries[3].name=='rom','nome ausente deve ser normalizado')
m.move(1)
assert(m.count()==3)
print('PASS unified transfers: old progress fields, invalid numbers and no duplicate history')
