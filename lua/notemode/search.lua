local notes = require("notemode.notes")

local M = {}

--- 全ノートを走査する。matcher(line, in_code) は一致した列 (1-based) の配列か nil を返す
function M.scan(matcher, opts)
  opts = opts or {}
  local loaded = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" then
        loaded[require("notemode.config").real(name)] = b
      end
    end
  end

  local items = {}
  for _, n in ipairs(notes.list()) do
    if n.path ~= opts.exclude then
      local lines
      if loaded[n.path] then
        lines = vim.api.nvim_buf_get_lines(loaded[n.path], 0, -1, false)
      else
        local ok, res = pcall(vim.fn.readfile, n.path)
        lines = ok and res or {}
      end
      local in_code = false
      for lnum, line in ipairs(lines) do
        local fence = line:match("^%s*```") or line:match("^%s*~~~")
        if fence then
          in_code = not in_code
        end
        local cols = not fence and matcher(line, in_code)
        for _, col in ipairs(cols or {}) do
          table.insert(items, { filename = n.path, lnum = lnum, col = col, text = line })
        end
      end
    end
  end
  return items
end

function M.to_qf(items, title)
  vim.fn.setqflist({}, " ", { title = title, items = items })
  if #items == 0 then
    vim.notify("notemode: " .. title .. " — 見つかりませんでした", vim.log.levels.INFO)
    return
  end
  vim.cmd("botright copen")
end

--- Vim の正規表現で全ノートを検索する
function M.grep(pattern)
  local ok, re = pcall(vim.regex, pattern)
  if not ok then
    vim.notify("notemode: 不正なパターン: " .. pattern, vim.log.levels.ERROR)
    return
  end
  local items = M.scan(function(line)
    local s = re:match_str(line)
    return s and { s + 1 } or nil
  end)
  M.to_qf(items, "Note grep: " .. pattern)
end

-- タグを終わらせる全角記号
local stops = { "、", "。", "，", "．", "！", "？", "「", "」", "（", "）", "・", "　" }

--- 行中の #tag を { {col, tag}, ... } で返す
function M.extract_tags(line)
  local out = {}
  for pos, tag in (" " .. line):gmatch("[%s%(]()#([%w_\128-\255][%w_%-/\128-\255]*)") do
    for _, p in ipairs(stops) do
      local i = tag:find(p, 1, true)
      if i then
        tag = tag:sub(1, i - 1)
      end
    end
    if tag ~= "" and not tag:match("^%d+$") then
      table.insert(out, { pos - 1, tag })
    end
  end
  return out
end

function M.tag_counts()
  local counts = {}
  M.scan(function(line, in_code)
    if not in_code then
      for _, t in ipairs(M.extract_tags(line)) do
        counts[t[2]] = (counts[t[2]] or 0) + 1
      end
    end
  end)
  return counts
end

function M.tag(tag)
  tag = tag:gsub("^#", "")
  local items = M.scan(function(line, in_code)
    if in_code then
      return nil
    end
    local cols
    for _, t in ipairs(M.extract_tags(line)) do
      if t[2] == tag then
        cols = cols or {}
        table.insert(cols, t[1])
      end
    end
    return cols
  end)
  M.to_qf(items, "#" .. tag)
end

function M.tags()
  local counts = M.tag_counts()
  local list = vim.tbl_keys(counts)
  if #list == 0 then
    vim.notify("notemode: タグがありません", vim.log.levels.INFO)
    return
  end
  table.sort(list, function(a, b)
    if counts[a] ~= counts[b] then
      return counts[a] > counts[b]
    end
    return a < b
  end)
  vim.ui.select(list, {
    prompt = "Tags",
    format_item = function(t)
      return ("#%s (%d)"):format(t, counts[t])
    end,
  }, function(choice)
    if choice then
      M.tag(choice)
    end
  end)
end

return M
