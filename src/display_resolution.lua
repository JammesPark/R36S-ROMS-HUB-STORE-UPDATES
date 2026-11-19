-- R36S ROMS STORE: deteccao de tela fisica e viewport 640x480 seguro.
-- Preserva coordenadas originais e evita distorcer capas, textos e botoes.
local V={baseW=640,baseH=480,nativeW=640,nativeH=480,
  width=640,height=480,scale=1,x=0,y=0,
  source='fallback',canvas=nil,usingCanvas=false,fullscreen=false}
local function valid(w,h)
  w,h=tonumber(w),tonumber(h)
  if not w or not h or w~=w or h~=h then return false end
  if w<240 or h<240 or w>7680 or h>4320 then return false end
  if w%1~=0 or h%1~=0 then return false end
  return true
end
function V.fit(w,h)
  if not valid(w,h) then w,h=640,480 end
  local scale=math.min(w/V.baseW,h/V.baseH)
  local x=(w-V.baseW*scale)/2
  local y=(h-V.baseH*scale)/2
  return {width=w,height=h,scale=scale,x=x,y=y,
    contentW=V.baseW*scale,contentH=V.baseH*scale}
end
local function dimensions(method,obj,...)
  if not obj or type(obj[method])~='function' then return nil end
  local ok,w,h=pcall(obj[method],...)
  if ok and valid(w,h) then return w,h end
  return nil
end
function V.detect()
  -- getDesktopDimensions consulta a saida selecionada pelo SDL2, ao contrario
  -- do tamanho da janela inicial definido em conf.lua (640x480).
  local w,h=dimensions('getDesktopDimensions',love and love.window,1)
  if w then return w,h,'SDL2 desktop real' end
  -- Se a CFW nao expor o modo fisico, use a superficie corrente.
  w,h=dimensions('getDimensions',love and love.graphics)
  if w then return w,h,'renderizacao atual' end
  return 640,480,'fallback 640x480'
end
function V.apply(w,h)
  local fit=V.fit(w,h)
  V.width,V.height,V.scale,V.x,V.y=fit.width,fit.height,fit.scale,fit.x,fit.y
  return fit
end
local function makeCanvas()
  V.canvas=nil;V.usingCanvas=false
  if V.width==V.baseW and V.height==V.baseH then return true end
  local gfx=love and love.graphics
  if not gfx or type(gfx.newCanvas)~='function' then return false end
  local ok,canvas=pcall(gfx.newCanvas,V.baseW,V.baseH,{format='normal',msaa=0})
  if not ok or not canvas then
    ok,canvas=pcall(gfx.newCanvas,V.baseW,V.baseH)
  end
  if not ok or not canvas then return false end
  V.canvas=canvas;V.usingCanvas=true
  if type(canvas.setFilter)=='function' then pcall(canvas.setFilter,canvas,'linear','linear') end
  return true
end
local function fallbackCanvas()
  if makeCanvas() then return end
  -- Sem framebuffer off-screen, NAO escala desenho com scissor errado.
  -- Tenta recuperar o modo original seguro de 640x480 do aplicativo.
  local win=love and love.window
  if win and type(win.setMode)=='function' then
    pcall(win.setMode,640,480,{fullscreen=false,resizable=false,vsync=1})
  end
  -- Sem canvas, as telas sao desenhadas diretamente em coordenadas 640x480.
  -- Mesmo que SDL2 nao consiga trocar o modo, o mouse continua correto.
  V.apply(640,480)
  V.source=V.source..' (render direto 640x480 sem canvas)'
  V.canvas=nil;V.usingCanvas=false
end
function V.init()
  local w,h,source=V.detect()
  V.nativeW,V.nativeH,V.source=w,h,source
  -- Apenas PortMaster/no console: nao forcamos fullscreen ao testar no PC.
  local root=os.getenv('R36S_STORE_HOME') or ''
  local console=root:match('^/roms/') or root:match('^/roms2/')
  local win=love and love.window
  if console and win and type(win.setMode)=='function' and
     source=='SDL2 desktop real' then
    local ok,res=pcall(win.setMode,w,h,{
      fullscreen=true,fullscreentype='desktop',resizable=false,
      vsync=1,highdpi=false})
    V.fullscreen=ok and res~=false
  end
  local actualW,actualH=dimensions('getDimensions',love and love.graphics)
  V.apply(actualW or w,actualH or h)
  fallbackCanvas()
  print(string.format('[DISPLAY] detectado=%dx%d (%s); viewport=%dx%d escala=%.4f offset=%.1f,%.1f',
    V.nativeW,V.nativeH,V.source,V.width,V.height,V.scale,V.x,V.y))
  return V
end
function V.resize(w,h)
  local previousW,previousH=V.width,V.height
  V.apply(w,h)
  if previousW~=V.width or previousH~=V.height then fallbackCanvas() end
  return V.fit(V.width,V.height)
end
function V.pointer(x,y)
  x,y=tonumber(x),tonumber(y)
  if not x or not y then return nil end
  if x<V.x or y<V.y or x>=V.x+V.baseW*V.scale or
     y>=V.y+V.baseH*V.scale then return nil end
  return (x-V.x)/V.scale,(y-V.y)/V.scale
end
function V.beginFrame()
  if not V.usingCanvas then
    -- Em drivers sem canvas, limpar as bordas alem da area virtual 640x480.
    local g=love and love.graphics
    if g and type(g.clear)=='function' then
      local w,h=dimensions('getDimensions',g)
      if w and (w>V.baseW or h>V.baseH) then g.clear(0,0,0,1) end
    end
    return false
  end
  local g=love.graphics
  g.push('all')
  local ok,err=pcall(function()
    g.setCanvas(V.canvas)
    g.origin()
    g.setScissor()
    g.clear(0,0,0,1)
  end)
  if not ok then
    -- Erro de OpenGL ES no meio do frame nao deixa o stack grafico aberto.
    pcall(g.pop)
    V.usingCanvas=false;V.canvas=nil
    V.apply(640,480)
    print('[DISPLAY] Canvas desabilitado apos erro de GPU: '..tostring(err))
    return false
  end
  return true
end
function V.endFrame(inCanvas)
  if not inCanvas then return end
  local g=love.graphics
  g.pop()
  g.push('all')
  local ok,err=pcall(function()
    g.origin()
    g.setScissor()
    g.clear(0,0,0,1)
    g.setColor(1,1,1,1)
    g.draw(V.canvas,V.x,V.y,0,V.scale,V.scale)
  end)
  g.pop()
  if not ok then
    V.usingCanvas=false;V.canvas=nil
    V.apply(640,480)
    print('[DISPLAY] Escala desabilitada apos erro de GPU: '..tostring(err))
  end
end
return V
