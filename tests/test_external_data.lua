-- Nao renderizar bytes malformados recebidos do catalogo/cache como ROMs.
package.path='./src/?.lua;'..package.path
local dir='/tmp/r36s_external_cache_safety'
os.execute('mkdir -p '..dir..'/state')
local state=dir..'/state'
local function save(name,json)
 local f=assert(io.open(state..'/'..name,'wb'))
 f:write(json);f:close()
end
save('gamestore_categories.json',[[{"categories":[4,"bad",{"category":"ALL","count":0},{"category":"psx","count":2},{"category":3}]}]])
save('gamestore_games.json',[[{"category":"ALL","page":1,"total":4,"total_pages":2,"games":[5,{"name":13,"game_path":"bad"},{"name":"Game One","game_path":"rom1","category":"psx","cover_id":24},{"name":"Game Two","game_path":"rom2","cover_id":{"bad":true}},{"game_path":"no-name"}]}]])
save('gamestore_search.json',[[{"query":"Game","page":1,"total":3,"total_pages":1,"games":[8,{"name":"Search","game_path":"romS","category":5},{"name":22,"game_path":"bad"},{"name":"Search2","game_path":"romS2"}]}]])
local E=require('external')
E.init(dir,state)
assert(#E.categories==2 and E.categories[1].category=='ALL')
assert(#E.games==2 and E.games[1].name=='Game One')
assert(E.games[1].cover_id==nil and E.games[2].cover_id==nil)
assert(#E.searchResults==2 and E.searchResults[1].category=='')
assert(E.totalCatalog()==2)
-- Paginação conserva entradas anteriores e descarta inválidas.
E.appendGames=true
save('gamestore_games.json',[[{"category":"ALL","page":2,"total":4,"total_pages":2,"games":[{"name":"Game One","game_path":"rom1"},{"name":"Game Three","game_path":"rom3"},{"name":false,"game_path":"bad"}]}]])
assert(E.loadGames() and #E.games==3)
assert(E.games[3].name=='Game Three')
-- Status malformado nao deve deixar a renderização instável.
E.pending='categories'
save('gamestore_status.json',[[{"task":"categories","phase":"error","message":404}]])
local ok,err=pcall(E.update)
assert(ok,tostring(err))
assert(E.message=='404' and E.error==true and E.pending==nil)
print('PASS cache data: malformed categories, games, search, pagination and status cannot crash main.lua')
