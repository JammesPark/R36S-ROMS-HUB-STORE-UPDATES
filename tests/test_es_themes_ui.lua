-- Simulação da Loja de Temas, quatro idiomas, resolução e confirmação, sem rede.
package.path = './src/?.lua;./src/?/init.lua;'..package.path
local mockui={}
function mockui.text() end
local imageRects={}
function mockui.rect(x,y,w,h)
 if x==380 and y==173 then imageRects[#imageRects+1]={x=x,y=y,w=w,h=h} end
end
function mockui.panel() end
function mockui.ellipsize(s,n) return tostring(s):sub(1,n) end
package.preload.ui=function() return mockui end
local fakeTheme={accent={1,0,0},panel={0,0,0},panel2={0,0,0},muted={0,0,0},text={1,1,1},border={0,0,0},low={0,0,0},error={1,0,0},green={0,1,0},bg={0,0,0}}
package.preload.theme=function() return fakeTheme end
love={filesystem={read=function(name)
  if name=='es_themes_seed.json' then
    return [[{"themes":[{"id":"test-theme","name":"Teste","folder":"test-theme","author":"Comunidade","resolution":"640x480","project_url":"https://github.com/owner/test-theme"}]}]]
  end
end}}
local m=require('es_theme_ui')
m.init('/tmp')
assert(m.size()=='640x480')
for _,language in ipairs({'pt','en','es','ru'}) do
  m.draw(function(eyebrow,title) assert(type(eyebrow)=='string' and type(title)=='string') end,language)
  m.key('a')
  assert(m.hasModal())
  m.draw(function() end,language)
  m.key('b')
  assert(not m.hasModal())
end
assert(#imageRects==8,'uma capa por desenho, sem miniaturas')
for _,r in ipairs(imageRects) do
 assert(r.w==230 and r.h==171,'capa ampliada')
end
assert(m.mouse(415,373)==true,'botao instalar clicavel')
assert(m.hasModal(),'clique abre confirmacao')
local original=os.execute
local command
os.execute=function(s) command=s;return true end
m.key('a')
os.execute=original
assert(command and command:find('es_theme_manager.py',1,true)
 and command:find('install',1,true) and command:find('test-theme',1,true),'instala tema selecionado')
m.busy=false
m.change_size(1)
assert(m.size()=='854x480')
assert(m.key('b')==false)
print('PASS themes: capa ampliada, sem miniaturas e Instalar funcional')
