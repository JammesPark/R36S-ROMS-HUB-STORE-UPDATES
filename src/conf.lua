function love.conf(t)
  t.identity = "r36s-roms-store"
  t.version = "11.5"
  t.window.title = "R36S ROMS STORE"
  t.window.width = 640
  t.window.height = 480
  -- Permite testar redimensionamento no PC; no console o modo e definido no boot.
  t.window.resizable = true
  t.window.vsync = 1
  t.modules.physics = false
end
