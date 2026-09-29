local notes = require("notemode.notes")

local M = {}

--- 行からノート名を取り出す (箇条書き・番号・チェックボックスの記号は除く)
function M.line_name(line)
  local name = line:gsub("^%s*[-*+]%s+", ""):gsub("^%s*%d+[.)]%s+", ""):gsub("^%[.%]%s+", "")
  return vim.trim(name)
end

--- 行全体、<cfile> の順にノートを探して開く。
--- どれも見つからなければ行全体の名前で新しいノートを開く
function M.goto_file()
  local name = M.line_name(vim.api.nvim_get_current_line())
  local cfile = vim.fn.expand("<cfile>"):gsub("^%./", "")
  for _, n in ipairs({ name, cfile }) do
    local path = n ~= "" and notes.resolve(n)
    if path then
      return notes.open(path, "note")
    end
  end
  if name ~= "" then
    return notes.open(notes.target(name), "note", (name:gsub("%.md$", "")))
  end
end

return M
