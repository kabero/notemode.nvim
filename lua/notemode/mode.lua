local config = require("notemode.config")
local notes = require("notemode.notes")

local M = {}

--- ノートモードのタブを探す
function M.tab()
  for _, tp in ipairs(vim.api.nvim_list_tabpages()) do
    local ok, v = pcall(vim.api.nvim_tabpage_get_var, tp, "notemode")
    if ok and v then
      return tp
    end
  end
end

function M.active()
  return M.tab() == vim.api.nvim_get_current_tabpage()
end

-- `nvim +Note` のように何も開いていないタブならそのまま使う
local function blank_tab()
  local wins = vim.tbl_filter(function(w)
    return vim.api.nvim_win_get_config(w).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
  if #wins ~= 1 then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(wins[1])
  return vim.api.nvim_buf_get_name(buf) == ""
    and vim.bo[buf].buftype == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

--- ノートモードに入る。fn を渡すとモードに入ったあとで実行する (なければ start ページを開く)
function M.enter(fn)
  local tp = M.tab()
  if tp then
    vim.api.nvim_set_current_tabpage(tp)
  else
    if not blank_tab() then
      vim.cmd("tabnew")
    end
    vim.t.notemode = true
    local dir = config.dir()
    vim.fn.mkdir(dir, "p")
    vim.cmd.tcd(vim.fn.fnameescape(dir))
    if not fn then
      notes.start()
    end
  end
  if fn then
    fn()
  end
end

function M.leave()
  local tp = M.tab()
  if not tp then
    return
  end
  require("notemode.buffer").save_all()
  if #vim.api.nvim_list_tabpages() == 1 then
    vim.cmd("confirm qall")
  else
    vim.api.nvim_set_current_tabpage(tp)
    vim.cmd("tabclose")
  end
end

function M.toggle()
  if M.active() then
    M.leave()
  else
    M.enter()
  end
end

return M
