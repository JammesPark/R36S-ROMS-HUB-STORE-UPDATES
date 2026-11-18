-- Regressao do layout aprovado em HTML: 3 capas 2:3 e contagens abaixo.
package.path='./src/?.lua;'..package.path
local H=require('home_layout')
assert(H.titleY+15 < H.tileY)
assert(H.coverH*2==H.coverW*3,'capas devem ser retrato 2:3')
assert(H.coverY>=H.tileY and H.coverY+H.coverH<H.tileY+H.tileH)
assert(H.statsY>H.tileY+H.tileH)
assert(H.statsY+H.statsH<436,'contagens nao invadem barra de comandos')
for i,x in ipairs(H.tileX) do
 assert(x>=180 and x+H.tileW<=620,'cartoes dentro da area de conteudo')
 if i>1 then assert(H.tileX[i-1]+H.tileW<x,'cartoes sem sobreposicao') end
 assert(H.featureAt(x+H.tileW/2,H.tileY+15,3,2)==i)
 assert(H.statAt(x+H.tileW/2,H.statsY+10)==i)
end
assert(H.featureAt(177,H.tileY+5,10,1)==nil)
assert(H.featureAt(620,H.tileY+5,10,1)==nil)
assert(H.featureAt(180,H.statsY+5,10,1)==nil)
assert(H.statAt(620,H.statsY+5)==nil)
assert(H.statAt(180,H.tileY+10)==nil)
assert(H.featureAt(200,240,0,1)==nil)
for total=1,80 do
 for selected=1,total do
  local first,last=H.window(total,selected)
  assert(last-first<=2 and first>=1 and last<=total)
  assert(selected>=first and selected<=last)
  for index=first,last do
   local slot=index-first+1
   local x=H.tileX[slot]+10
   assert(H.featureAt(x,H.tileY+30,total,selected)==index,
     'capa tocada deve abrir o jogo correto')
  end
 end
end
assert(H.featureAt(200,H.tileY+4,1,1)==1)
assert(H.featureAt(H.tileX[2]+4,H.tileY+4,1,1)==nil)
assert(H.featureAt(H.tileX[3]+4,H.tileY+4,2,1)==nil)
print('PASS home: tres capas 2:3 em destaque, contagens abaixo, toque e 640x480')
