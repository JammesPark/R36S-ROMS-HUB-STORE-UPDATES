-- Simulação da Loja de Temas, quatro idiomas, resolução e confirmação, sem rede.
package.path = './src/?.lua;./src/?/init.lua;'..package.path
local mockui={}
function mockui.text() end
function mockui.rect() end
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
m.change_size(1)
assert(m.size()=='854x480')
assert(m.key('b')==false)
print('PASS ES themes UI simulated, 4 languages, 640x480, modal and resolution')
