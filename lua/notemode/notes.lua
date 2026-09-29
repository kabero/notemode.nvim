local config = require("notemode.config")

local M = {}

local cache -- { exact = { stem = path }, lower = { stem = path } }

local function stem_of(path)
  return (vim.fs.basename(path):gsub("%.md$", ""))
end

function M.is_note(path)
  if not path or path == "" or not path:match("%.md$") then
    return false
  end
  local root = config.dir()
  path = config.real(path)
  return path:sub(1, #root + 1) == root .. "/"
end

function M.rel(path)
  return config.real(path):sub(#config.dir() + 2)
end

local function remember(path)
  if not cache then
    return
  end
  local stem = stem_of(path)
  local rel_stem = M.rel(path):gsub("%.md$", "")
  for _, key in ipairs({ stem, rel_stem }) do
    cache.exact[key] = cache.exact[key] or path
    cache.lower[key:lower()] = cache.lower[key:lower()] or path
  end
end

--- ノート一覧 (更新日時の新しい順)
function M.list()
  local root = config.dir()
  local out = {}
  cache = { exact = {}, lower = {} }
  if vim.fn.isdirectory(root) == 0 then
    return out
  end
  local iter = vim.fs.dir(root, {
    depth = 32,
    skip = function(d)
      return not vim.fs.basename(d):match("^%.")
    end,
  })
  for name, type in iter do
    if type == "file" and name:match("%.md$") and not vim.fs.basename(name):match("^%.") then
      local path = root .. "/" .. name
      local stat = vim.uv.fs_stat(path)
      table.insert(out, {
        path = path,
        rel = name,
        stem = stem_of(name),
        mtime = stat and stat.mtime.sec or 0,
      })
    end
  end
  table.sort(out, function(a, b)
    if a.mtime ~= b.mtime then
      return a.mtime > b.mtime
    end
    return a.rel < b.rel
  end)
  -- 浅い階層を優先してリンク解決できるよう、浅い順に登録
  local by_depth = vim.list_slice(out)
  table.sort(by_depth, function(a, b)
    local _, da = a.rel:gsub("/", "")
    local _, db = b.rel:gsub("/", "")
    return da < db
  end)
  for _, n in ipairs(by_depth) do
    remember(n.path)
  end
  return out
end

function M.invalidate()
  cache = nil
end

--- 保存されたノートをキャッシュに追加する
function M.add(path)
  remember(config.real(path))
end

--- ノートを確認のうえ削除する。削除したら true
function M.delete(paths)
  paths = vim.tbl_map(config.real, paths)
  local names, refs = {}, 0
  for _, p in ipairs(paths) do
    table.insert(names, M.rel(p))
    refs = refs + #require("notemode.link").backlink_items(p)
  end
  local msg = table.concat(names, ", ") .. " を削除しますか？"
  if refs > 0 then
    msg = msg .. ("\n(ほかのノートの %d 箇所からリンクされています)"):format(refs)
  end
  if vim.fn.confirm(msg, "&Yes\n&No", 2) ~= 1 then
    return false
  end

  for _, p in ipairs(paths) do
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(b) ~= "" and config.real(vim.api.nvim_buf_get_name(b)) == p then
        -- 先に表示中のウィンドウを別のバッファに移す (bwipeout でウィンドウやタブが閉じないように)。
        -- 移る時点で autosave が走るので、ファイルを消すのはバッファを消したあと
        for _, w in ipairs(vim.fn.win_findbuf(b)) do
          vim.api.nvim_win_call(w, function()
            local alt = vim.fn.bufnr("#")
            if alt > 0 and alt ~= b and vim.fn.buflisted(alt) == 1 then
              vim.cmd.buffer(alt)
            else
              vim.cmd.enew()
            end
          end)
        end
        vim.api.nvim_buf_delete(b, { force = true })
      end
    end
    vim.fn.delete(p)
  end
  M.invalidate()
  vim.notify("notemode: " .. table.concat(names, ", ") .. " を削除しました", vim.log.levels.INFO)
  return true
end

--- リンク名からノートのパスを探す。見つからなければ nil
function M.resolve(name)
  name = vim.trim(name):gsub("%.md$", "")
  if name == "" then
    return nil
  end
  if not cache then
    M.list()
  end
  return cache.exact[name] or cache.lower[name:lower()]
end

local function sanitize(name)
  name = vim.trim(name):gsub("%.md$", "")
  name = name:gsub('[\\:%*%?"<>|]', "-")
  return name
end

--- リンク名に対応するパス (存在しなければ新規作成先)
function M.target(name)
  return M.resolve(name) or (config.dir() .. "/" .. sanitize(name) .. ".md")
end

function M.render(tpl, ctx)
  if type(tpl) == "function" then
    return tpl(ctx)
  end
  local vars = {
    title = ctx.title or "",
    date = os.date("%Y-%m-%d"),
    time = os.date("%H:%M"),
  }
  return (tpl or ""):gsub("{{(%w+)}}", function(k)
    return vars[k] or ""
  end)
end

--- ノートを開く。ファイルがなければテンプレートを流し込む (保存するまでファイルは作られない)
function M.open(path, kind, title)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  local empty = vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
  if empty and not vim.uv.fs_stat(path) then
    local text = M.render(config.options.templates[kind or "note"], { title = title or stem_of(path) })
    local lines = vim.split(text, "\n", { plain = true })
    if #lines > 1 and lines[#lines] == "" then
      table.remove(lines)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    vim.api.nvim_win_set_cursor(0, { #lines, #lines[#lines] })
  end
  return buf
end

function M.new(title)
  return M.open(M.target(title), "note", vim.trim(title))
end

function M.daily(offset)
  local t = os.date("*t")
  local time = os.time({ year = t.year, month = t.month, day = t.day + (offset or 0), hour = 12 })
  local title = os.date(config.options.daily_format, time)
  local path = config.dir() .. "/" .. config.options.daily_dir .. "/" .. title .. ".md"
  return M.open(path, "daily", title)
end

function M.index()
  return M.open(config.dir() .. "/" .. config.options.index, "index")
end

function M.inbox()
  return M.open(config.dir() .. "/" .. config.options.inbox, "inbox")
end

function M.start()
  local start = config.options.start
  if start == "daily" then
    return M.daily(0)
  elseif start == "inbox" then
    return M.inbox()
  end
  return M.index()
end

return M
