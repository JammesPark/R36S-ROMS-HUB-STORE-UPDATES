-- Cores aprovadas no conceito HTML de 19 telas da R36S ROMS STORE.
local T={}
T.options={
  {key='ocean',name='theme_blue',hex='#44D1FF'},
  {key='violet',name='theme_violet',hex='#B698FF'},
  {key='emerald',name='theme_green',hex='#54E1B1'},
  {key='amber',name='theme_amber',hex='#FFB768'},
  {key='rose',name='theme_rose',hex='#FF88C2'},
  {key='ruby',name='theme_red',hex='#FF7C85'},
  {key='ice',name='theme_ice',hex='#CADFEE'},
  {key='slate',name='theme_slate',hex='#AEC9E4'}
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
-- Layout Studio: paletas COMPLETAS aprovadas no HTML, nao somente cor dos icones.
-- Valores correspondentes aos tokens base/surface/raised/tile do Layout B.
local P={
 ocean={bg='#0B1728',sidebar='#0E1B2F',panel='#14243A',panel2='#1B2F48',
         border='#385877',text='#EAF4FF',muted='#A5B8D1',low='#809CBA',
         accent='#6DAEFF',green='#77E6BD',error='#F78F9C',highlight='#223A56'},
 emerald={bg='#092019',sidebar='#0D261F',panel='#13372D',panel2='#1B4538',
         border='#347A63',text='#E8FFF5',muted='#A1D2BC',low='#79B19C',
         accent='#59E4B3',green='#89EDBE',error='#F6A0A5',highlight='#225444'},
 violet={bg='#1A1726',sidebar='#201B2B',panel='#2A2438',panel2='#352D46',
         border='#66537D',text='#F6F0FF',muted='#B9ADCF',low='#9183AF',
         accent='#C5B5FF',green='#89DDB8',error='#F39EAC',highlight='#413452'},
 amber={bg='#22190F',sidebar='#2B2013',panel='#38291A',panel2='#463422',
         border='#866544',text='#FFF5E4',muted='#D8BD9C',low='#B89975',
         accent='#F8C078',green='#A4E3A2',error='#FF9B95',highlight='#533D27'},
 slate={bg='#14212B',sidebar='#1A2732',panel='#243340',panel2='#304352',
         border='#566E82',text='#F0F6FC',muted='#B4C4D3',low='#8FA5B9',
         accent='#AEC9E4',green='#8BD9BD',error='#E9A7AD',highlight='#384E5E'}
}
-- Compatibilidade de cores antigas com Layout B: sempre uma paleta completa.
P.rose=P.violet
P.ruby=P.amber
P.ice=P.slate
local classic={bg=T.bg,sidebar=T.sidebar,panel=T.panel,panel2=T.panel2,
 border=T.border,text=T.text,muted=T.muted,low=T.low,error=T.error,green=T.green}
function T.setLayout(layout)
 T.layout=(layout=='studio') and 'studio' or 'classic'
 T.set(T.current or 'ocean')
end
function T.set(key)
 local chosen=nil
 for _,o in ipairs(T.options) do if o.key==key then chosen=o;break end end
 if not chosen then chosen=T.options[1] end
 T.current=chosen.key
 if T.layout=='studio' then
  local palette=P[T.current] or P.ocean
  for field,value in pairs(palette) do T[field]=T.hex(value) end
 else
  for field,value in pairs(classic) do T[field]=value end
  T.accent=T.hex(chosen.hex)
  T.highlight=T.panel2
 end
end
T.layout='classic'
T.set('ocean')
return T
