-- Renderizador alternativo Studio para LÖVE 11.5 / 640x480.
-- Nao baixa nem instala arquivos: reutiliza o estado e os controladores existentes.
-- O tema classico continua inteiramente separado.
local U=require('ui')
local T=require('theme')
local S={hits={},canvas=nil}
local function R(x,y,w,h,color,r,border,a) U.rect(x,y,w,h,color,r or 0,border,a) end
local function tx(text,x,y,size,color,w,center)
 U.text(text or '',x,y,size or 11,color or T.text,w,center)
end
local function panel(x,y,w,h,chosen)
 R(x,y,w,h,chosen and T.highlight or T.panel,10,chosen and T.accent or T.border)
end
local function tap(x,y,w,h,kind,value,more)
 S.hits[#S.hits+1]={x=x,y=y,w=w,h=h,kind=kind,value=value,more=more}
end
local function button(title,x,y,w,h,kind,value,primary)
 R(x,y,w,h,primary and T.accent or T.panel2,8,primary and T.accent or T.border)
 tx(title,x+4,y+math.max(3,(h-13)/2),11,primary and T.bg or T.text,w-8,true)
 if kind then tap(x,y,w,h,kind,value) end
end
local function short(s,n) return U.ellipsize(tostring(s or ''),n or 22) end
local function t(c,key) return c.tr and c.tr(key) or key end
local function poster(c,g,x,y,w,h,i)
 panel(x-2,y-2,w+4,h+4,false)
 if g and c.cover then c.cover(g,x,y,w,h,i or 1)
 else U.poster(x,y,w,h,'?',i or 1) end
end
local function title(c,eyebrow,heading)
 tx(string.upper(eyebrow or ''),15,119,9,T.low,605)
 if heading then tx(heading,15,141,16,T.text,585) end
end
local function top(c)
 R(0,0,640,480,T.bg)
 R(0,0,640,60,T.sidebar)
 R(8,7,45,44,T.panel2,9,T.border)
 U.drawLogo(10,7,41,42)
 tx('R36S ROMS STORE STUDIO',63,15,10,T.muted,360)
 local heading=t(c,c.screen=='home' and 'title_home' or c.screen)
 if c.screen=='es_themes' then heading=t(c,'es_themes')
 elseif c.screen=='layout_choice' then heading=t(c,'layouts')
 elseif c.screen=='themes' then heading=t(c,'themes')
 elseif c.screen=='bios' then heading=t(c,'bios')
 elseif c.screen=='settings' then heading=t(c,'title_settings') end
 tx(heading,63,31,15,T.text,400)
 local status=c.device or {}
 U.color(status.wifi and T.green or T.low);love.graphics.circle('fill',561,21,2.5)
 tx(status.wifi and 'ONLINE' or 'OFFLINE',569,15,9,T.muted,55)
 tx(status.time or '--:--',528,36,10,T.muted,56)
 local batt=tonumber(status.battery)
 tx(batt and tostring(batt)..'%' or '--',589,36,9,T.muted,38,true)
 R(0,59,640,1,T.border)
 R(0,61,640,48,T.sidebar)
 for i,route in ipairs(c.nav) do
  local x=(i-1)*64
  local active=route==(c.screen=='search_results' and 'catalog' or c.screen)
  local focused=c.navFocus and c.navIndex==i
  if active or focused then
   R(x+6,63,52,43,T.panel2,8,focused and T.accent or T.border)
   R(x+8,106,48,2,T.accent)
  end
  U.menuIcon(route,x+23,69,active and T.accent or T.muted)
  tx(t(c,route),x+1,91,9,active and T.text or T.muted,62,true)
  tap(x,61,64,49,'nav',route)
 end
 R(0,109,640,1,T.border)
 R(0,445,640,1,T.border)
 R(0,446,640,34,T.sidebar)
 for i,p in ipairs({{'A','Selecionar'},{'B','Voltar'},{'X','Opções'},{'Y','Ações'}}) do
  local x=32+(i-1)*155
  R(x,455,18,18,T.panel2,4,T.border)
  tx(p[1],x+2,458,10,T.accent,14,true)
  tx(p[2],x+23,459,9,T.muted,102)
 end
end
local function home(c)
 title(c,'PÁGINA INICIAL / SUA BIBLIOTECA')
 panel(15,137,610,68)
 tx('TRANSFERÊNCIA AO VIVO',27,149,9,T.low,300)
 local now=c.current
 tx(short(now and now.name or 'Tudo pronto para jogar',42),27,166,12,T.text,365)
 if now then
  local done,total=tonumber(now.done) or 0,tonumber(now.total) or 0
  local pct=total>0 and math.min(100,done/total*100) or 0
  local description=total>0 and string.format('%d%%  ·  ',math.floor(pct)) or ''
  description=description..c.rate(now)..'  ·  '..c.eta(now)
  tx(description,27,184,9,T.muted,350)
  R(506,153,107,5,T.border,3)
  R(506,153,107*pct/100,5,T.accent,3)
 else
  tx('Nenhuma transferência em andamento',27,184,9,T.muted,355)
 end
 button('Ver fila',504,168,109,25,'nav','downloads',false)
 tx('Em destaque',15,215,14,T.text,360)
 button('Explorar ROMs',531,214,94,24,'nav','catalog',false)
 local games=c.games or {}
 local selected=math.max(1,math.min(#games,tonumber(c.featuredIndex) or 1))
 local first=math.max(1,math.min(selected-1,math.max(1,#games-2)))
 for k=1,3 do
  local idx=first+k-1
  local x=15+(k-1)*207
  local g=games[idx]
  local active=(idx==selected and c.homeFocus=='featured' and c.focus=='content')
  panel(x,247,197,119,active)
  if g then
   poster(c,g,x+8,256,66,101,idx)
   tx(short(g.name,17),x+83,292,11,T.text,107)
   tx(short(g.category or '',15):upper(),x+83,341,9,T.muted,110)
   tx(string.format('%02d',idx),x+170,256,9,T.accent,20)
   tap(x,247,197,119,'game',idx)
  else
   tx('—',x+82,289,14,T.low,105,true)
  end
 end
 local metrics={
  {tostring(c.totalRoms or #games),t(c,'catalog'), 'catalog'},
  {tostring(#(c.downloads or {})),t(c,'installed'),'installed'},
  {tostring(#(c.favorites or {})),t(c,'favorites'),'favorites'}
 }
 for i,m in ipairs(metrics) do
  local x=15+(i-1)*207
  panel(x,376,197,42,c.homeFocus=='overview' and c.homeStatIndex==i)
  tx(short(m[1],8),x+10,382,17,T.accent,53)
  tx(short(m[2],20)..' ›',x+69,391,10,T.muted,115)
  tap(x,376,197,42,'nav',m[3])
 end
end
local function catalog(c,search)
 title(c,search and 'PESQUISA / RESULTADOS' or 'EXPLORAR JOGOS / CATÁLOGO')
 tx(search and 'Resultados da pesquisa' or 'ESCOLHA A PLATAFORMA',15,146,11,T.accent,325)
 button('⌕ Buscar',538,138,87,29,'goto','search',false)
 if not search then
  local cats=c.categories or {}
  local index=math.max(1,math.min(#cats,tonumber(c.categoryIndex) or 1))
  local first=math.max(1,math.min(index-2,math.max(1,#cats-5)))
  for slot=1,math.min(6,#cats) do
   local i=first+slot-1
   local cat=cats[i]
   if cat then
    local key=tostring(cat.category or 'ALL')
    local name=short((c.platformTitle and c.platformTitle(key)) or key,12)
    local x=15+(slot-1)*101
    button(name,x,173,96,25,'category',i,key==c.category)
    if c.focus=='sidebar' and index==i then
     U.stroke(x,173,96,25,T.accent,7,2)
    end
   end
  end
 end
 local list=search and (c.results or {}) or (c.games or {})
 local sel=math.max(1,math.min(#list,search and (c.searchIndex or 1) or (c.gameIndex or 1)))
 local topY=search and 180 or 210
 local visible=4
 local start=math.max(1,math.min(sel-1,math.max(1,#list-visible+1)))
 for i=start,math.min(#list,start+visible-1) do
  local g=list[i];local y=topY+(i-start)*58
  panel(15,y,402,55,sel==i)
  poster(c,g,23,y+6,28,42,i)
  tx(short(g.name,29),60,y+10,12,T.text,337)
  tx(short(g.category or 'ROM',20):upper(),60,y+33,9,T.muted,319)
  tap(15,y,402,55,'game',i)
 end
 local game=list[sel]
 if game then
  poster(c,game,468,211,116,175,sel)
  button('Ver detalhes ›',447,403,160,30,'game',sel,true)
 else
  tx(t(c,'no_results'),70,290,14,T.muted,320,true)
 end
end
local function detail(c)
 title(c,'JOGO / DETALHES')
 local g=c.selectedGame
 panel(15,148,610,275)
 if not g then tx(t(c,'invalid'),200,260,13,T.muted,275);return end
 poster(c,g,33,162,143,215,c.gameIndex or 1)
 tx(short(g.name,38),196,169,19,T.text,413)
 tx(short(g.category or 'ROM',26):upper(),196,211,11,T.accent,390)
 tx('SD: '..(c.gameLocation and c.gameLocation(g) or t(c,'not_downloaded')),196,242,11,T.muted,369)
 button('Adicionar / remover favorito',196,277,381,35,'key','y',false)
 button('Baixar ROM ›',196,329,381,41,'key','a',true)
end
local function confirm(c)
 title(c,'ROM / DOWNLOAD','Escolha o cartão de destino')
 panel(15,185,610,204)
 tx(short(c.selectedGame and c.selectedGame.name or 'ROM',46),33,207,15,T.text,548)
 local card=c.selectedCard or 1
 button('SD1',35,250,267,63,'card',1,card==1)
 button('SD2',338,250,267,63,'card',2,card==2)
 button('Confirmar download',35,338,570,36,'key','a',true)
end
local function downloads(c)
 title(c,'CENTRAL / DOWNLOADS')
 tx('Transferências e fila de downloads',15,143,12,T.text,460)
 local list=c.transfers or {}
 local selected=c.transferSelected or 1
 local first=math.max(1,math.min(selected-2,math.max(1,#list-4)))
 for i=first,math.min(#list,first+4) do
  local item=list[i]
  local y=172+(i-first)*47
  panel(15,y,610,43,selected==i)
  tx(short(item.name or item.kind or 'ROM',46),25,y+4,11,T.text,380)
  tx(short(item.phase or '',17),480,y+4,10,T.accent,125,true)
  tx(c.rate(item)..'  ·  '..c.eta(item),26,y+24,9,T.muted,280)
  local done,total=tonumber(item.done) or 0,tonumber(item.total) or 0
  if total>0 then
   R(358,y+29,238,3,T.border,2)
   R(358,y+29,238*math.min(1,done/total),3,T.accent,2)
  end
  tap(15,y,610,43,'transfer',i)
 end
 if #list==0 then tx(t(c,'download_ready'),60,259,13,T.muted,514,true) end
end
local function listPage(c,kind)
 title(c,kind=='installed' and 'JOGOS / INSTALADOS' or 'COLEÇÃO / FAVORITOS')
 local list=kind=='installed' and (c.downloads or {}) or (c.favorites or {})
 if #list==0 then
  panel(15,164,610,218)
  tx(kind=='installed' and t(c,'no_installed') or t(c,'no_favorites'),28,245,14,T.muted,584,true)
  return
 end
 local idx=kind=='installed' and (c.installIndex or 1) or (c.favoriteIndex or 1)
 local first=math.max(1,math.min(idx-2,math.max(1,#list-4)))
 for i=first,math.min(#list,first+4) do
  local item=list[i];local y=162+(i-first)*53
  local active=(kind=='installed' and c.installIndex==i) or (kind=='favorites' and c.favoriteIndex==i)
  panel(15,y,610,49,active)
  if kind=='favorites' then poster(c,item,23,y+3,29,43,i) end
  tx(short(item.name,44),kind=='favorites' and 62 or 26,y+7,12,T.text,454)
  tx(short((item.category or '')..'  ·  '..(item.card or ''),40),
    kind=='favorites' and 62 or 26,y+29,9,T.muted,455)
  tap(15,y,610,49,kind=='favorites' and 'favorite' or 'installed',i)
 end
end
local function settings(c)
 title(c,'CONFIGURAÇÕES / PREFERÊNCIAS')
 local values={
  {'Idioma',c.languageName or '', 'languages'},
  {'Tema da interface',c.layout=='studio' and 'Studio' or 'Clássico','layout_choice'},
  {'Cor do tema',c.colorName or '', 'themes'},
  {'Tamanho da letra',t(c,'font_'..(c.font_size or 'medium')),'font_size'},
  {'Armazenamento','SD1 / SD2','storage'},
  {'Rede e catálogo',c.networkState or '—','network'},
  {'Atualizações',c.version or '','updates'},
  {'Ajuda','A / B / X / Y','help'}
 }
 for i,v in ipairs(values) do
  local y=132+(i-1)*38
  panel(15,y,610,35,i==c.settingsIndex)
  tx(v[1],27,y+4,11,T.text,359)
  tx(short(v[2],35)..'  ›',392,y+7,10,T.muted,215,true)
  tap(15,y,610,35,'goto',v[3])
 end
end
local function layoutChoice(c)
 title(c,'CONFIGURAÇÕES / LAYOUT DA LOJA')
 tx('Escolha um layout. Ambos preservam as mesmas funções e dados.',15,152,11,T.muted,607)
 local choices={
  {name='Clássico',desc='Menu lateral e interface original',id='classic'},
  {name='Studio',desc='Menu superior, cartões e cores completas',id='studio'}
 }
 for i,p in ipairs(choices) do
  local x=15+(i-1)*307
  local selected=c.layout==p.id
  panel(x,197,297,155,selected)
  R(x+12,210,273,74,T.sidebar,7,T.border)
  if i==1 then
   R(x+19,216,55,62,T.panel2,4)
   for k=1,3 do R(x+28,224+(k-1)*16,37,5,T.accent,2) end
   R(x+81,216,193,62,T.panel,4)
  else
   R(x+19,216,258,11,T.accent,4)
   for k=1,3 do R(x+21+(k-1)*86,236,78,39,T.highlight,4) end
  end
  tx(p.name,x+17,299,15,T.text,242)
  tx(p.desc,x+17,325,10,T.muted,258)
  if selected then tx('✓',x+260,297,16,T.accent,25) end
  tap(x,197,297,155,'layout',p.id)
 end
end
local function colors(c)
 title(c,'CONFIGURAÇÕES / CORES DA INTERFACE')
 tx('No Studio, cada cor altera fundo, painéis, menus, botões e textos.',15,146,11,T.muted,605)
 local palette={
  {key='ocean',label='Oceano',hex={.43,.68,1}},
  {key='emerald',label='Esmeralda',hex={.35,.89,.70}},
  {key='violet',label='Violeta',hex={.77,.71,1}},
  {key='amber',label='Âmbar',hex={.97,.75,.47}},
  {key='slate',label='Ardósia',hex={.68,.79,.89}}
 }
 for i,p in ipairs(palette) do
  local x=15+((i-1)%3)*207
  local y=190+math.floor((i-1)/3)*98
  panel(x,y,197,91,c.color==p.key)
  R(x+8,y+8,181,47,T.sidebar,5,T.border)
  R(x+15,y+15,99,14,T.panel2,3,T.border)
  R(x+117,y+29,62,18,p.hex,4)
  tx(p.label,x+8,y+63,12,T.text,151)
  if c.color==p.key then tx('✓',x+168,y+63,12,T.accent,22) end
  tap(x,y,197,91,'color',p.key)
 end
end
local function storage(c)
 title(c,'SISTEMA / ARMAZENAMENTO')
 for i=1,2 do
  local y=165+(i-1)*132
  panel(15,y,610,112)
  local entry=c.storage and c.storage[i] or nil
  tx('SD'..i,28,y+16,20,T.text,80)
  if entry then
   local total,free=tonumber(entry.total) or 0,tonumber(entry.free) or 0
   tx(string.format('Disponível %.1f GB de %.1f GB',free/1073741824,total/1073741824),140,y+19,12,T.muted,470)
   R(28,y+71,580,9,T.border,5)
   if total>0 then R(28,y+71,580*math.max(0,math.min(1,(total-free)/total)),9,T.accent,5) end
  else tx(t(c,'not_mounted'),140,y+23,12,T.muted,445) end
 end
end
local function network(c)
 title(c,'SISTEMA / REDE')
 panel(15,165,610,224)
 tx('STATUS DA CONEXÃO',34,193,10,T.muted,544)
 tx(c.networkState or '—',34,246,20,T.accent,544,true)
 button('Atualizar catálogo',36,331,569,39,'key','a',true)
end
local function fallback(c,legacy)
 -- BIOS, temas EmulationStation, OTA, modais e estados especiais continuam
 -- com a logica Lua original. Captura somente o conteudo; o Studio desenha
 -- header, navegacao e rodape novos usando a paleta escolhida.
 if not legacy then
  title(c,'SISTEMA / '..string.upper(c.screen or ''),'Conteúdo disponível no tema Clássico')
  return
 end
 local g=love.graphics
 local prepared,prepErr=pcall(function()
  if not S.canvas then
   S.canvas=g.newCanvas(640,480,{format='normal',msaa=0})
   S.canvas:setFilter('linear','linear')
  end
  if not S.quad then S.quad=g.newQuad(179,85,441,330,640,480) end
 end)
 if not prepared then
  -- Drivers sem Canvas continuam com acesso aos motores pelas teclas.
  print('[STUDIO] canvas indisponivel: '..tostring(prepErr):sub(1,140))
  title(c,'SISTEMA / '..string.upper(c.screen or ''), 'Modo seguro')
  tx('Interface clássica disponível em Configurações > Tema da interface.',
    25,236,11,T.muted,588,true)
  return
 end
 -- push/pop permanece equilibrado mesmo se o corpo legado falhar.
 g.push('all')
 local ok,err=pcall(function()
  g.setCanvas(S.canvas)
  g.origin()
  g.clear(0,0,0,0)
  legacy()
 end)
 g.pop()
 if ok then
  panel(90,112,460,331)
  U.color({1,1,1})
  g.draw(S.canvas,S.quad,99,114)
 else
  print('[STUDIO] erro no corpo: '..tostring(err):sub(1,180))
  title(c,'SISTEMA / '..string.upper(c.screen or ''), 'Modo seguro')
  tx('Pressione B para voltar. Seus dados não foram alterados.',
     25,238,11,T.muted,588,true)
 end
 -- Mapeia a area antiga de clique para o conteudo centralizado.
 tap(99,114,441,330,'legacy',nil,{sourceX=179,sourceY=85})
end
function S.draw(c,legacy)
 S.hits={}
 local screen=c.screen
 if screen=='startup' or screen=='first_language' or screen=='disclaimer' then
  -- Antes da tela inicial, reaproveitar a tela oficial e paleta completa.
  if legacy then legacy() end
  return
 end
 top(c)
 if screen=='home' or screen=='exit_confirm' then home(c)
 elseif screen=='catalog' then catalog(c,false)
 elseif screen=='search_results' then catalog(c,true)
 elseif screen=='detail' then detail(c)
 elseif screen=='confirm' then confirm(c)
 elseif screen=='downloads' or screen=='transferring' or screen=='success' then downloads(c)
 elseif screen=='installed' or screen=='favorites' then listPage(c,screen)
 elseif screen=='settings' then settings(c)
 elseif screen=='layout_choice' then layoutChoice(c)
 elseif screen=='themes' then colors(c)
 elseif screen=='storage' then storage(c)
 elseif screen=='network' then network(c)
 else fallback(c,legacy) end
 if c.notice and c.notice~='' and c.noticeTime and c.noticeTime>0 then
  R(15,414,610,28,T.panel2,7,T.accent)
  tx(short(c.notice,75),25,420,11,T.text,587)
 end
end
function S.click(x,y)
 for i=#S.hits,1,-1 do
  local h=S.hits[i]
  if x>=h.x and x<h.x+h.w and y>=h.y and y<h.y+h.h then
   if h.kind=='legacy' then
    return {kind='legacy',x=h.more.sourceX+(x-h.x),y=h.more.sourceY+(y-h.y)}
   end
   return {kind=h.kind,value=h.value}
  end
 end
end
return S
