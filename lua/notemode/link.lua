local notes = require("notemode.notes")

local M = {}

M.pattern = "()%[%[(.-)%]%]()"

--- line 中で col (1-based) を含むマッチのキャプチャを返す
local function find_around(line, col, pat)
  for s, cap, e in line:gmatch(pat) do
    if col >= s and col < e then
      return cap
    end
  end
end

--- "name#heading|alias" を分解する
function M.parse(inner)
  local name = vim.trim(inner:match("^[^|#]*") or "")
  local heading = inner:match("#([^|]*)")
  return name, heading and vim.trim(heading) or nil
end

function M.open(inner)
  local name, heading = M.parse(inner)
  if name == "" then
    return
  end
  notes.open(notes.target(name), "note", name)
  if heading and heading ~= "" then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.fn.search("^#\\+\\s\\+\\V" .. vim.fn.escape(heading, "\\") .. "\\m\\s*$", "cW")
  end
end

--- カーソル下のリンクをたどる。リンクがなければ通常の <CR> と同じ動き
function M.follow()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  local inner = find_around(line, col, M.pattern)
  if inner then
    return M.open(inner)
  end

  local target = find_around(line, col, "()%[[^%]]*%]%(([^%)]+)%)()")
  if target then
    if target:match("^%a[%w+.-]*://") then
      return vim.ui.open(target)
    end
    target = target:gsub("#.*$", "")
    local base = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
    return notes.open(vim.fs.normalize(vim.fs.joinpath(base, target)), "note")
  end

  local url = find_around(line, col, "()(https?://[^%s%)>%]]+)()")
  if url then
    return vim.ui.open(url)
  end

  vim.cmd.normal({ args = { vim.v.count1 .. "+" }, bang = true })
end

--- ビジュアル選択を [[リンク]] にしてたどる
function M.link_selection()
  local s = vim.fn.getpos("v")
  local e = vim.fn.getpos(".")
  vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  if s[2] ~= e[2] then
    vim.notify("notemode: 複数行の選択はリンクにできません", vim.log.levels.WARN)
    return
  end
  local line = vim.api.nvim_get_current_line()
  local scol, ecol = math.min(s[3], e[3]), math.max(s[3], e[3])
  ecol = ecol + vim.str_utf_end(line, ecol)
  local text = line:sub(scol, ecol)
  vim.api.nvim_set_current_line(line:sub(1, scol - 1) .. "[[" .. text .. "]]" .. line:sub(ecol + 1))
  M.open(text)
end

function M.jump(backward)
  local pos = vim.fn.search("\\[\\[", backward and "bw" or "w")
  if pos > 0 then
    local cur = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_set_cursor(0, { cur[1], cur[2] + 2 })
  end
end

--- path へのリンクを持つ行 (quickfix の item 形式)
function M.backlink_items(path)
  local keys = {
    [vim.fs.basename(path):gsub("%.md$", ""):lower()] = true,
    [notes.rel(path):gsub("%.md$", ""):lower()] = true,
  }
  return require("notemode.search").scan(function(line)
    local cols
    for s, inner in line:gmatch(M.pattern) do
      if keys[M.parse(inner):lower()] then
        cols = cols or {}
        table.insert(cols, s)
      end
    end
    return cols
  end, { exclude = require("notemode.config").real(path) })
end

--- 現在のノートへのリンクを持つ行
function M.backlinks()
  local path = vim.api.nvim_buf_get_name(0)
  if not notes.is_note(path) then
    vim.notify("notemode: ノートではありません", vim.log.levels.WARN)
    return
  end
  require("notemode.search").to_qf(M.backlink_items(path), "Backlinks: " .. notes.rel(path))
end

function M.omnifunc(findstart, base)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  if findstart == 1 then
    local before = line:sub(1, cursor[2])
    local last
    local i = 1
    while true do
      local s = before:find("[[", i, true)
      if not s then
        break
      end
      last, i = s, s + 1
    end
    if not last or before:find("]]", last, true) then
      return -3
    end
    return last + 1
  end

  local close = line:sub(cursor[2] + 1, cursor[2] + 2) == "]]" and "" or "]]"
  local items = {}
  base = base:lower()
  for _, n in ipairs(notes.list()) do
    if base == "" or n.stem:lower():find(base, 1, true) or n.rel:lower():find(base, 1, true) then
      local dir = vim.fs.dirname(n.rel)
      table.insert(items, {
        word = n.stem .. close,
        abbr = n.stem,
        menu = dir ~= "." and dir or nil,
      })
    end
  end
  return items
end

return M
