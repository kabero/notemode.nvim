local M = {}

function M.setup(opts)
  require("notemode.config").setup(opts)
  require("notemode.notes").invalidate()
end

--- statusline 用: ノートモード中なら "NOTE" を返す
function M.statusline()
  return require("notemode.mode").active() and "NOTE" or ""
end

M.enter = function()
  return require("notemode.mode").enter()
end
M.leave = function()
  return require("notemode.mode").leave()
end
M.toggle = function()
  return require("notemode.mode").toggle()
end

return M
