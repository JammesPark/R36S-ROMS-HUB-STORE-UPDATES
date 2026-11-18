-- Teste offline: o bootstrap reconstitui auxiliares a partir do pacote validado.
local root=os.getenv('TEST_ROOT') or '.'
local tmp=os.tmpname()
os.remove(tmp)
local home=tmp..'/r36s-roms-store'
os.execute("mkdir -p '"..home:gsub("'","'\\''").."/bin'")
local function read(p)
 local f=assert(io.open(p,'rb'));local b=f:read('*a');f:close();return b
end
love={filesystem={read=function(path) return read(root..'/src/'..path) end}}
package.path=root..'/src/?.lua;'..package.path
local bootstrap=require('ota_bootstrap')
assert(bootstrap.run(home))
for _,name in ipairs({'es_theme_manager.py','es_themes_seed.json','fetch.sh','7zzs'}) do
 assert(#read(home..'/bin/'..name)>100)
end
assert(bootstrap.run(home)) -- idempotente
os.execute("rm -rf '"..tmp:gsub("'","'\\''").."'")
print('PASS OTA bootstrap: helpers and idempotency')
