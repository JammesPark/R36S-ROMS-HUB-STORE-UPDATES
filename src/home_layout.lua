-- Geometria do conceito HTML aprovado: retratos acima das contagens.
-- Coordenadas em pixels virtuais de 640x480; nao interfere no OTA.
local H={}
H.titleY=208
H.tileY=230
H.tileH=150
H.tileW=140
H.tileX={180,329,478}
H.coverW=76
H.coverH=114
H.coverY=235
H.statsY=386
H.statsH=43
function H.window(total,selected)
 total=math.max(0,math.floor(tonumber(total) or 0))
 if total==0 then return 1,0 end
 selected=math.max(1,math.min(total,math.floor(tonumber(selected) or 1)))
 local first=math.max(1,math.min(selected-1,math.max(1,total-2)))
 return first,math.min(total,first+2)
end
function H.featureAt(x,y,total,selected)
 if type(x)~='number' or type(y)~='number' then return nil end
 if y<H.tileY or y>=H.tileY+H.tileH then return nil end
 local first,last=H.window(total,selected)
 for column=1,3 do
  local sx=H.tileX[column]
  if x>=sx and x<sx+H.tileW then
   local index=first+column-1
   if index<=last then return index end
  end
 end
 return nil
end
function H.statAt(x,y)
 if type(x)~='number' or type(y)~='number' then return nil end
 if y<H.statsY or y>=H.statsY+H.statsH then return nil end
 for i=1,3 do
  local sx=H.tileX[i]
  if x>=sx and x<sx+H.tileW then return i end
 end
 return nil
end
return H
