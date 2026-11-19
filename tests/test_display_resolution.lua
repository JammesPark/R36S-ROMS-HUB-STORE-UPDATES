-- Testes sem GPU real da deteccao SDL2, letterbox, touch e fallback.
package.path='./src/?.lua;'..package.path
local V=require('display_resolution')
local realGetenv=os.getenv
local sizes={w=640,h=480}
local flags={}
local calls={}
local canvas={setFilter=function(self,a,b) calls.filter=(a..':'..b) end}
love={
 window={
  getDesktopDimensions=function(display) assert(display==1);return 1280,720 end,
  setMode=function(w,h,opts)
   calls.mode={w,h,opts}
   if flags.rejectMode then return false end
   sizes.w,sizes.h=w,h
   return true
  end
 },
 graphics={
  getDimensions=function() return sizes.w,sizes.h end,
  newCanvas=function(w,h,opts)
   assert(w==640 and h==480)
   if flags.failCanvas then error('no FBO support') end
   calls.canvas=(calls.canvas or 0)+1
   return canvas
  end,
  push=function(t) calls.push=(calls.push or 0)+1 end,
  pop=function() calls.pop=(calls.pop or 0)+1 end,
  setCanvas=function(x) if flags.failSetCanvas then error('GLES FBO failure') end;calls.setCanvas=x end,
  origin=function() end,
  setScissor=function() end,
  clear=function() end,
  setColor=function() end,
  draw=function(c,x,y,r,sx,sy)
   assert(c==canvas)
   if flags.failDraw then error('GLES draw failed') end
   calls.draw={x=x,y=y,sx=sx,sy=sy}
  end
 }
}
local function near(a,b) assert(math.abs(a-b)<0.0001,tostring(a)..' != '..tostring(b)) end
local cases={
 {640,480,1,0,0},       -- R36S padrao: nenhum canvas extra
 {720,720,1.125,0,90},  -- display quadrado, barras superior/inferior
 {854,480,1,107,0},    -- widescreen 16:9
 {960,544,544/480,(960-640*(544/480))/2,0},
 {1024,768,1.6,0,0},
 {1280,720,1.5,160,0},
 {320,240,.5,0,0}
}
for _,t in ipairs(cases) do
 local f=V.fit(t[1],t[2])
 near(f.scale,t[3]);near(f.x,t[4]);near(f.y,t[5])
 assert(f.x>=0 and f.y>=0)
 assert(f.contentW<=t[1]+0.001 and f.contentH<=t[2]+0.001)
 V.apply(t[1],t[2])
 local x,y=V.pointer(f.x+f.contentW/2,f.y+f.contentH/2)
 near(x,320);near(y,240)
 assert(V.pointer(f.x-.1,f.y+f.contentH/2)==nil,'margem deve ser inativa')
 assert(V.pointer(f.x+f.contentW,f.y+f.contentH/2)==nil,'borda final fora da tela')
end
assert(V.fit(nil,nil).width==640 and V.fit(0,9999).height==480)
-- Emulacao do console: SDL2 fornece tamanho fisico, nao a janela inicial.
os.getenv=function(key) if key=='R36S_STORE_HOME' then return '/roms/ports/r36s-roms-store' end end
sizes.w,sizes.h=640,480
local result=V.init()
assert(result.nativeW==1280 and result.nativeH==720)
assert(V.width==1280 and V.height==720 and V.usingCanvas)
assert(calls.mode[1]==1280 and calls.mode[2]==720 and calls.mode[3].fullscreen==true)
near(V.scale,1.5);near(V.x,160)
assert(V.pointer(159,20)==nil)
local x,y=V.pointer(160+480,360);near(x,320);near(y,240)
assert(V.beginFrame())
V.endFrame(true)
near(calls.draw.x,160);near(calls.draw.y,0)
near(calls.draw.sx,1.5);near(calls.draw.sy,1.5)
assert(calls.push==calls.pop,'render preserva estados graficos')
flags.failSetCanvas=true
assert(V.beginFrame()==false and not V.usingCanvas)
assert(calls.push==calls.pop,'stack must unwind after FBO error')
flags.failSetCanvas=false
V.apply(640,480)
V.resize(1024,768)
assert(V.usingCanvas)
flags.failDraw=true
assert(V.beginFrame()==true)
V.endFrame(true)
assert(not V.usingCanvas and calls.push==calls.pop)
flags.failDraw=false
V.apply(640,480)
V.resize(1280,720)
assert(V.usingCanvas)
-- Evento de resize do SDL2: recalcula o viewport e transforma clique.
V.resize(720,720)
near(V.scale,1.125);near(V.y,90)
local xx,yy=V.pointer(360,360);near(xx,320);near(yy,240)
assert(V.pointer(360,89)==nil)
-- Se o driver GL nao suporta canvas, volta a janela padrao.
flags.failCanvas=true
sizes.w,sizes.h=640,480
V.resize(854,480)
assert(not V.usingCanvas and V.canvas==nil)
assert(calls.mode[1]==640 and calls.mode[2]==480)
assert(V.width==640 and V.height==480)
-- KMSDRM pode recusar ate a troca de modo 640; ponteiro ainda mapeia direto.
flags.rejectMode=true
sizes.w,sizes.h=854,480
V.apply(720,720)
V.resize(854,480)
assert(V.width==640 and V.height==480 and not V.usingCanvas)
local lx,ly=V.pointer(500,230)
near(lx,500);near(ly,230)
assert(V.pointer(700,230)==nil)
assert(V.beginFrame()==false,'fallback nao usa framebuffer de GPU inexistente')
flags.rejectMode=false
-- Se SDL2 nao informa a resolucao, usar dimensoes reais da janela.
flags.failCanvas=false
love.window.getDesktopDimensions=function() error('SDL mode unavailable') end
sizes.w,sizes.h=854,480
local w,h,source=V.detect()
assert(w==854 and h==480 and source=='renderizacao atual')
love.graphics.getDimensions=function() error('no gfx') end
w,h,source=V.detect()
assert(w==640 and h==480 and source=='fallback 640x480')
os.getenv=realGetenv
print('PASS display: native SDL2, 7 aspect ratios, resized mouse, GL fallback and 640x480')
