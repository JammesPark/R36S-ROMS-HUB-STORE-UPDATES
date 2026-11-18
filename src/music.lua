-- Música fornecida pelo usuário: três trilhas .ogg por contexto.
-- Falha no áudio nunca pode impedir a loja de abrir.
local M={}
local tracks={}
local current=nil
local enabled=true
local volumes={principal=.24,navegacao=.20,download=.23}
local paths={principal='assets/music/tema_principal.ogg',navegacao='assets/music/tema_navegacao.ogg',download='assets/music/tema_download.ogg'}
function M.init()
  if not (love and love.audio and love.audio.newSource) then return end
  for name,file in pairs(paths) do
    local ok,src=pcall(love.audio.newSource,file,'stream')
    if ok and src then
      src:setLooping(true)
      src:setVolume(volumes[name] or .2)
      tracks[name]=src
    end
  end
end
local function target(route)
  if route=='transferring' or route=='downloads' or route=='confirm' or route=='success' then
    return 'download'
  elseif route=='startup' or route=='first_language' or route=='disclaimer' then
    return nil -- sem musica durante o carregamento/aviso
  elseif route=='home' then return 'principal'
  else return 'navegacao' end
end
function M.updateRoute(route)
  local nextTrack=enabled and target(route) or nil
  if nextTrack==current then return end
  if current and tracks[current] then pcall(tracks[current].stop,tracks[current]) end
  current=nextTrack
  local src=tracks[nextTrack]
  if src then pcall(src.play,src) end
end
function M.stop()
  if current and tracks[current] then pcall(tracks[current].stop,tracks[current]) end
  current=nil
end
return M
