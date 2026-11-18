-- Cores aprovadas no conceito HTML de 19 telas da R36S ROMS STORE.
local T={}
T.options={
  {key='ocean',name='theme_blue',hex='#44D1FF'},
  {key='violet',name='theme_violet',hex='#B698FF'},
  {key='emerald',name='theme_green',hex='#54E1B1'},
  {key='amber',name='theme_amber',hex='#FFB768'},
  {key='rose',name='theme_rose',hex='#FF88C2'},
  {key='ruby',name='theme_red',hex='#FF7C85'},
  {key='ice',name='theme_ice',hex='#CADFEE'}
}
function T.hex(v)
  v=v:gsub('#','')
  return {tonumber(v:sub(1,2),16)/255,tonumber(v:sub(3,4),16)/255,tonumber(v:sub(5,6),16)/255}
end
local H=T.hex
T.bg=H('#080E1A')
T.sidebar=H('#0C1627')
T.panel=H('#111D30')
T.panel2=H('#14243A')
T.border=H('#243A55')
T.text=H('#EAF4FF')
T.muted=H('#91A7BB')
T.low=H('#7187A1')
T.error=H('#FF808C')
T.green=H('#69EAC9')
function T.set(key)
  T.current='ocean'
  for _,o in ipairs(T.options) do
    if o.key==key then T.current=key;T.accent=T.hex(o.hex);return end
  end
  T.accent=T.hex('#44D1FF')
end
T.set('ocean')
return T
