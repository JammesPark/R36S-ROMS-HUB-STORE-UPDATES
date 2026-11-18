-- Renderer da identidade visual R36S ROMS STORE, adaptado do conceito HTML 640x480.
local theme=require('theme')
local U={}
local fonts={}
local fallbackFont=nil
local fontData=nil
local fontScale=1
local brandImage=nil
local assets={}
local function asset(name) return assets[name] end
local sizeOptions={small=0.91,medium=1.0,large=1.18}
function U.setFontSize(key)
  fontScale=sizeOptions[key] or 1
end
local function loadSystemFont()
  for _,path in ipairs({
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/TTF/DejaVuSans.ttf',
    '/usr/share/fonts/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
    '/usr/share/fonts/opentype/noto/NotoSans-Regular.ttf'
  }) do
    local file=io.open(path,'rb')
    if file then
      local bytes=file:read('*a');file:close()
      if bytes and #bytes<4*1024*1024 then
        local ok,data=pcall(love.filesystem.newFileData,bytes,'ui-system.ttf')
        if ok then return data end
      end
    end
  end
end
function U.init()
  -- Imagem da marca aprovada (PNG com transparencia) incluída no .love.
  local ok,img=pcall(love.graphics.newImage,'assets/logo.png')
  if ok and img then brandImage=img end
  -- Imagens do usuario, bandeiras PNG e icones Lucide (ISC), sempre locais.
  local names={'logo_dev','telegram_icon','qr_telegram','qr_livepix',
    'flag_pt','flag_en','flag_es','flag_ru'}
  for _,k in ipairs(names) do
    local valid,resource=pcall(love.graphics.newImage,'assets/'..k..'.png')
    if valid and resource then assets[k]=resource end
  end
  local glyphs={'house','library-big','download','hard-drive','heart','settings','info','log-out',
    'gamepad-2','joystick','disc-3','monitor','tablet','cpu','disc','circuit-board','gamepad','search',
    'languages','palette','type','wifi','circle-help'}
  for _,k in ipairs(glyphs) do
    local valid,resource=pcall(love.graphics.newImage,'assets/icons/'..k..'.png')
    if valid and resource then assets['ico_'..k]=resource end
  end
  fontData=loadSystemFont()
  for _,size in ipairs({9,10,11,12,13,14,15,16,17,18,19,20,22,24,26,27,28}) do
    local ok,font=pcall(function()
      return fontData and love.graphics.newFont(fontData,size) or love.graphics.newFont(size)
    end)
    if ok then fonts[size]=font
    else fonts[size]=love.graphics.newFont(size) end
  end
  fallbackFont=fonts[12]
end
function U.font(size)
  local value=math.max(8,math.min(32,math.floor((size or 12)*fontScale+0.5)))
  if not fonts[value] then
    local ok,resource=pcall(function()
      return fontData and love.graphics.newFont(fontData,value) or love.graphics.newFont(value)
    end)
    fonts[value]=(ok and resource) or fallbackFont
  end
  return fonts[value] or fallbackFont
end
function U.color(c,alpha)
  love.graphics.setColor(c[1],c[2],c[3],alpha or c[4] or 1)
end
function U.rect(x,y,w,h,c,r,stroke,alpha)
  if w<=0 or h<=0 then return end
  U.color(c,alpha)
  love.graphics.rectangle('fill',x,y,w,h,r or 0,r or 0)
  if stroke then U.color(stroke);love.graphics.rectangle('line',x+.5,y+.5,w-1,h-1,r or 0,r or 0) end
end
function U.stroke(x,y,w,h,c,r,width)
  U.color(c);love.graphics.setLineWidth(width or 1)
  love.graphics.rectangle('line',x+.5,y+.5,w-1,h-1,r or 0,r or 0)
  love.graphics.setLineWidth(1)
end
function U.text(s,x,y,size,color,maxwidth,center)
  s=tostring(s or '')
  if color then U.color(color) else U.color(theme.text) end
  local f=U.font(size or 12);love.graphics.setFont(f)
  if maxwidth then
    -- Evita que fonte Grande quebre titulos/cartoes em uma segunda linha.
    if type(f.getWidth)=='function' and f:getWidth(s)>maxwidth then
      local original=s
      local n=#original
      repeat
        n=n-1
        s=U.ellipsize(original,n)
      until n<=1 or f:getWidth(s)<=maxwidth
    end
    love.graphics.printf(s,x,y,maxwidth,center and 'center' or 'left')
  else
    love.graphics.print(s,x,y)
  end
end
-- Textos longos sem ellipsis: usam a quebra real do LÖVE e alinham a esquerda.
-- Retorna o proximo y para distribuir textos sem sobreposicao.
function U.paragraph(s,x,y,width,size,color,extraSpacing)
  local f=U.font(size or 12)
  U.color(color or theme.text)
  love.graphics.setFont(f)
  local lines
  if type(f.getWrap)=='function' then
    local ok,_,wrapped=pcall(function() return f:getWrap(tostring(s or ''),width) end)
    if ok and type(wrapped)=='table' and #wrapped>0 then lines=wrapped end
  end
  if not lines then lines={tostring(s or '')} end
  local increment=(type(f.getHeight)=='function' and f:getHeight() or (size or 12)*1.15)+(extraSpacing or 2)
  for i,line in ipairs(lines) do
    love.graphics.printf(line,x,y+(i-1)*increment,width,'left')
  end
  return y+#lines*increment
end

function U.ellipsize(s,n)
  s=tostring(s or '')
  if #s<=n then return s end
  -- nao quebra codepoints UTF-8 ao cortar nomes de ROMs
  local i=1;local count=0;local last=1
  while i<=#s and count<n do
    local b=s:byte(i)
    local step=b<128 and 1 or b<224 and 2 or b<240 and 3 or 4
    last=i+step-1;i=i+step;count=count+1
  end
  if i>#s then return s end
  return s:sub(1,last)..'…'
end
function U.shadow(x,y,w,h)
  U.rect(x+2,y+4,w,h,{0,0,0},10,nil,.21)
end
function U.panel(x,y,w,h,chosen)
  U.rect(x,y,w,h,chosen and theme.panel2 or theme.panel,9,chosen and theme.accent or theme.border)
end
function U.layout(leftMode,selection)
  U.rect(0,0,640,480,theme.bg)
  U.rect(0,0,158,480,theme.sidebar)
  U.rect(157,0,1,480,theme.border)
  -- sombreado geometrico suave de cantos como no HTML
  U.color(theme.accent,.045)
  love.graphics.circle('fill',615,10,138)
  U.color(theme.accent,.022)
  love.graphics.circle('fill',525,57,105)
  U.rect(158,436,482,44,{.035,.080,.13})
  U.rect(158,435,482,1,theme.border)
  U.drawLogo(14,6,133,76)
  -- bottom sidebar
  U.rect(12,442,134,1,theme.border)
  U.color(theme.green);love.graphics.circle('fill',20,460,3)
end
function U.pill(text,x,y,w,active)
  U.rect(x,y,w,24,active and theme.panel2 or theme.panel,7,active and theme.accent or theme.border)
  U.text(text,x+9,y+5,10,active and theme.accent or theme.muted,w-18)
end
function U.kicker(text,x,y)
  U.color(theme.accent);love.graphics.circle('fill',x+3,y+7,2.6)
  U.text(string.upper(text),x+13,y,11,theme.accent,400)
end
-- Botões do controle (cores dos botões reais do console).
function U.buttonHint(x,y,key,label,maxwidth)
  local colors={A={.95,.30,.50},B={.98,.77,.23},X={.30,.66,.97},Y={.37,.80,.55}}
  local c=colors[key] or theme.accent
  local textOffset=23
  if key=='A' or key=='B' or key=='X' or key=='Y' then
    U.color(c)
    love.graphics.circle('fill',x+9,y+9,9)
    U.text(key,x+3,y+2,11,theme.bg,13,true)
  elseif key=='START' then
    -- START verde solido, no mesmo estilo dos botoes coloridos A/B.
    -- Area generosa para o texto completo inclusive com fonte Grande.
    local startGreen={.29,.91,.55}
    U.rect(x,y,64,20,startGreen,10)
    U.text('START',x+5,y+4,9,theme.bg,54,true)
    textOffset=68
  else
    U.rect(x,y,42,18,theme.panel2,7,c)
    U.text(key,x+3,y+3,9,c,36,true)
    textOffset=46
  end
  if label and label~='' and (maxwidth==nil or maxwidth>0) then
    U.text(label,x+textOffset,y+3,10,theme.muted,maxwidth or 76)
  end
end
function U.footer(a,b,c)
  -- Duas ou três colunas proporcionais; nenhuma legenda invade a seguinte.
  if c then
    U.buttonHint(183,448,'A',a or 'OK',95)
    U.buttonHint(311,448,'B',b or 'VOLTAR',95)
    U.buttonHint(454,448,'START',c,102)
  else
    U.buttonHint(185,448,'A',a or 'OK',132)
    U.buttonHint(405,448,'B',b or 'VOLTAR',164)
  end
end
local coverPalettes={
  {{.08,.10,.35},{.42,.17,.55},{1,.68,.48}},
  {{.13,.05,.24},{.53,.22,.30},{1,.72,.55}},
  {{.02,.26,.42},{.07,.48,.57},{.97,.92,.47}},
  {{.08,.14,.38},{.16,.45,.78},{.62,.90,.98}},
  {{.32,.13,.29},{.66,.36,.28},{1,.87,.56}},
  {{.06,.19,.22},{.16,.42,.48},{.60,.98,.79}},
  {{.29,.13,.20},{.65,.31,.22},{1,.86,.60}}
}
function U.poster(x,y,w,h,name,index,showName)
  local p=coverPalettes[(index-1)%#coverPalettes+1]
  U.rect(x,y,w,h,p[1],7)
  U.color(p[2],.93)
  love.graphics.polygon('fill',x,y+h,x+w*.44,y+h*.15,x+w,y+h)
  U.color(p[3],.34)
  love.graphics.circle('fill',x+w*.76,y+h*.16,w*.27)
  U.color({.01,.04,.13},.58)
  love.graphics.polygon('fill',x,y+h*.95,x+w*.25,y+h*.46,x+w*.46,y+h*.82,x+w*.78,y+h*.26,x+w,y+h)
  U.rect(x+8,y+8,27,3,p[3],1)
  if showName then
    local name1=tostring(name or '?'):upper()
    local n=U.ellipsize(name1,16)
    U.rect(x,y+h-31,w,31,{.015,.030,.075},0,nil,.75)
    U.text(n,x+8,y+h-26,12,theme.text,w-16)
  end
end
-- Mantém a capa inteira dentro do espaço, sem recortar as extremidades.
function U.imageContain(image,x,y,w,h)
  local iw,ih=image:getDimensions()
  if iw<=0 or ih<=0 then return end
  local factor=math.min(w/iw,h/ih)
  local fw,fh=iw*factor,ih*factor
  U.color({1,1,1})
  love.graphics.draw(image,x+(w-fw)/2,y+(h-fh)/2,0,factor,factor)
end

-- Logo vetorial integrada ao app, sem depender de PNG ou internet.
-- Indicadores visuais; dados são consultados localmente em sysfs/proc.
function U.statusBar(data)
  data=data or {}
  -- Alinhamento comum dos centros em y=18: Wi-Fi | hora | bateria.
  U.rect(437,5,191,26,theme.sidebar,7,theme.border,.96)
  U.rect(478,10,1,16,theme.border,0)
  U.rect(541,10,1,16,theme.border,0)
  local wifi=data.wifi and theme.green or theme.low
  U.color(wifi)
  love.graphics.setLineWidth(1.9)
  love.graphics.line(449,16,456,11,463,16)
  love.graphics.line(452,19,456,16,460,19)
  love.graphics.circle('fill',456,22,1.6)
  love.graphics.setLineWidth(1)
  U.text(data.time or '--:--',483,11,11,theme.text,55,true)
  local p=tonumber(data.battery)
  local fill=p and (p<=15 and theme.error or theme.green) or theme.low
  U.rect(552,12,24,12,theme.panel,2,theme.muted)
  U.rect(576,16,2,4,theme.muted,1)
  if p then
    U.rect(555,15,math.max(0,18*math.min(100,math.max(0,p))/100),6,fill,1)
  end
  U.text(p and (tostring(math.floor(p+0.5))..'%') or '--%',582,11,10,theme.text,42,true)
end
-- Icones vetoriais de 17x17 para preservar legibilidade em 640x480.
function U.searchIcon(x,y,c)
  U.color(c);love.graphics.setLineWidth(2)
  love.graphics.circle('line',x+7,y+7,5)
  love.graphics.line(x+11,y+11,x+16,y+16)
  love.graphics.setLineWidth(1)
end
-- Icones oficiais Lucide obtidos da internet, convertidos em PNG para LÖVE.
local navIcons={home='house',catalog='library-big',downloads='download',installed='hard-drive',
  favorites='heart',bios='chip',es_themes='layers',settings='settings',about='info',exit='log-out'}
local categoryKinds={all='library-big',nes='gamepad',snes='gamepad-2',n64='gamepad-2',
  gb='tablet',gbc='tablet',gba='tablet',nds='tablet',n3ds='tablet',
  psx='disc-3',ps1='disc-3',ps2='disc',psp='tablet',ps3='disc',
  megadrive='gamepad-2',genesis='gamepad-2',mastersystem='gamepad',gamegear='tablet',
  saturn='disc-3',dreamcast='disc',mame='joystick',neogeo='joystick',
  atari2600='joystick',pcengine='circuit-board',amigacd32='monitor',
  wii='gamepad-2',gamecube='gamepad',ports='cpu',pico8='cpu',dos='monitor'}
local platformShort={nes='N',snes='SN',n64='64',gb='GB',gbc='GC',gba='GA',nds='DS',
 psx='PS',ps1='P1',ps2='P2',psp='PP',mame='AR',neogeo='NG',wii='W',
 megadrive='MD',genesis='MD',saturn='SS',dreamcast='DC',ports='HB'}
function U.icon(name,x,y,w,h,color)
  local image=asset('ico_'..name)
  if image then
    U.color(color or theme.text)
    local iw,ih=image:getDimensions()
    love.graphics.draw(image,x,y,0,(w or 18)/iw,(h or 18)/ih)
    U.color({1,1,1})
    return true
  end
  return false
end
function U.drawAsset(name,x,y,w,h,stretch)
  local image=asset(name)
  if not image then return false end
  if stretch then
    local iw,ih=image:getDimensions()
    U.color({1,1,1});love.graphics.draw(image,x,y,0,w/iw,h/ih)
  else U.imageContain(image,x,y,w,h) end
  return true
end
-- Ícones estáveis do menu principal: traçados Lua/LÖVE independentes de PNG.
-- Todos ocupam a mesma caixa 18x18 e usam a mesma largura de traço.
-- A cor é fornecida pela sidebar: tema.accent quando ativo, tema.muted quando inativo.
function U.menuIcon(kind,x,y,c)
  local shape=navIcons[kind] or 'info'
  local S=18/24
  local LG=love.graphics
  local function p(v) return v*S end
  local function line(...)
    local coords={...}
    for i=1,#coords,2 do
      coords[i]=x+p(coords[i])
      coords[i+1]=y+p(coords[i+1])
    end
    LG.line((table.unpack or unpack)(coords))
  end
  local function rect(a,b,w,h)
    LG.rectangle('line',x+p(a),y+p(b),p(w),p(h))
  end
  local function circ(a,b,r)
    LG.circle('line',x+p(a),y+p(b),p(r))
  end
  U.color(c or theme.text)
  LG.setLineWidth(1.8)
  if shape=='house' then
    -- Início: casa, telhado e porta.
    line(3,11,12,3,21,11)
    line(5,10,5,21,19,21,19,10)
    line(10,21,10,14,14,14,14,21)
  elseif shape=='library-big' then
    -- Catálogo: livros em prateleira.
    rect(3,4,6,17)
    rect(10,3,5,18)
    line(16,5,20,4,23,19,19,20,16,5)
    line(4,17,8,17)
  elseif shape=='download' then
    -- Downloads: seta de entrada e bandeja.
    line(12,3,12,16)
    line(6,10,12,16,18,10)
    line(3,16,3,21,21,21,21,16)
  elseif shape=='hard-drive' then
    -- Instalados: cartão SD com marca de confirmação.
    line(5,3,15,3,21,9,21,21,5,21,5,3)
    line(14,3,14,10,21,10)
    line(9,15,12,18,17,12)
  elseif shape=='heart' then
    -- Favoritos: coração.
    line(12,21,4,13,2,10,2,7,5,4,9,4,12,7,15,4,19,4,22,7,22,10,20,13,12,21)
  elseif shape=='chip' then
    -- BIOS: circuito integrado com pinos, sem reutilizar o ícone de informações.
    rect(6,6,12,12)
    line(9,2,9,6)
    line(15,2,15,6)
    line(9,18,9,22)
    line(15,18,15,22)
    line(2,9,6,9)
    line(2,15,6,15)
    line(18,9,22,9)
    line(18,15,22,15)
    rect(10,10,4,4)
  elseif shape=='layers' then
    -- Temas: tres camadas simetricas, legiveis a 18x18 em 640x480.
    line(12,3,22,9,12,15,2,9,12,3)
    line(2,13,12,19,22,13)
    line(2,17,12,23,22,17)
  elseif shape=='settings' then
    -- Configurações: engrenagem com centro e oito dentes.
    circ(12,12,7)
    circ(12,12,2.5)
    line(12,1,12,5)
    line(12,19,12,23)
    line(1,12,5,12)
    line(19,12,23,12)
    line(4,4,7,7)
    line(17,17,20,20)
    line(4,20,7,17)
    line(17,7,20,4)
  elseif shape=='info' then
    -- Sobre: informação.
    circ(12,12,9)
    LG.circle('fill',x+p(12),y+p(7),p(1.2))
    line(12,11,12,17)
  elseif shape=='log-out' then
    -- Sair: porta e seta de saída.
    line(10,3,5,3,5,21,10,21)
    line(9,12,22,12)
    line(17,7,22,12,17,17)
  end
  LG.setLineWidth(1)
  return shape
end
function U.platformIcon(category,x,y,c)
  local id=tostring(category or 'ALL'):lower()
  if id=='all' then return U.icon('library-big',x,y,19,19,c) end
  local kind=categoryKinds[id] or (id:find('playstation',1,true) and 'disc-3')
    or (id:find('gameboy',1,true) and 'tablet') or 'gamepad-2'
  local used=U.icon(kind,x,y,19,19,c)
  -- Pequenissimo identificador para diferenciar plataformas da mesma familia.
  if not used then U.rect(x+3,y+3,13,13,c,2) end
  -- Ícone sem siglas sobrepostas, como pedido para plataformas.
end
function U.catalogFooter(selectText,backText,searchText,favoriteText)
  U.rect(158,436,482,44,{.035,.080,.13})
  U.rect(158,435,482,1,theme.border)
  -- Quatro botões diferentes, sem o antigo Y Atualizar ou START Buscar.
  U.buttonHint(169,448,'A',selectText,61)
  U.buttonHint(285,448,'B',backText,61)
  U.buttonHint(396,448,'X',searchText,63)
  U.buttonHint(505,448,'Y',favoriteText,97)
end
function U.drawLogo(x,y,w,h)
  if brandImage then
    U.imageContain(brandImage,x,y,w,h)
    return true
  end
  -- Degradação graciosa se o arquivo de imagem for apagado.
  U.text('R36S ROMS STORE',x,y+math.max(0,h/2-12),16,theme.accent,w,true)
  return false
end
function U.brandLogo(x,y,scale)
  scale=scale or 1
  local function p(v) return v*scale end
  U.rect(x,y,p(86),p(76),theme.panel2,p(17),theme.accent)
  U.color(theme.accent,.12)
  love.graphics.circle('fill',x+p(43),y+p(38),p(34))
  -- Silhueta de portátil com visor e controles.
  U.rect(x+p(13),y+p(16),p(60),p(44),theme.sidebar,p(9),theme.accent)
  U.rect(x+p(21),y+p(22),p(44),p(22),theme.panel,p(4),theme.border)
  U.rect(x+p(25),y+p(26),p(36),p(14),theme.accent,p(2),nil,.17)
  U.rect(x+p(25),y+p(49),p(15),p(3),theme.accent,p(1))
  U.rect(x+p(31),y+p(43),p(3),p(16),theme.accent,p(1))
  U.color(theme.green)
  love.graphics.circle('fill',x+p(60),y+p(49),p(3))
  U.color(theme.accent)
  love.graphics.circle('fill',x+p(54),y+p(54),p(2.5))
end
function U.brandLockup(x,y)
  U.brandLogo(x,y,1)
  U.text('R36S',x+102,y+1,28,theme.text)
  U.rect(x+102,y+38,183,2,theme.accent,1)
  U.text('ROMS STORE',x+102,y+45,20,theme.accent)
end
function U.flag(code,x,y,w,h)
  -- Bandeiras reais: PNGs coloridos do conjunto de emojis de bandeiras.
  local img=asset('flag_'..tostring(code))
  U.rect(x-2,y-1,w+4,h+2,theme.border,3)
  if img then
    U.imageContain(img,x,y,w,h)
  else
    U.text(tostring(code):upper(),x,y+2,11,theme.text,w,true)
  end
end
function U.imageStretch(image,x,y,w,h)
  if not image then return end
  local iw,ih=image:getDimensions()
  if iw<1 or ih<1 then return end
  U.color({1,1,1});love.graphics.draw(image,x,y,0,w/iw,h/ih)
end
function U.imageCrop(image,x,y,w,h)
  local iw,ih=image:getDimensions()
  if iw<=0 or ih<=0 then return end
  local scale=math.max(w/iw,h/ih)
  local drawX=x+(w-iw*scale)/2
  local drawY=y+(h-ih*scale)/2
  local sx,sy,sw,sh=love.graphics.getScissor()
  love.graphics.setScissor(x,y,w,h)
  U.color({1,1,1})
  love.graphics.draw(image,drawX,drawY,0,scale,scale)
  if sx then love.graphics.setScissor(sx,sy,sw,sh) else love.graphics.setScissor() end
end
return U
