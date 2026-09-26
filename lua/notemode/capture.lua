local config = require("notemode.config")

local M = {}

local function inbox_path()
  vim.fn.mkdir(config.dir(), "p")
  return config.dir() .. "/" .. config.options.inbox
end

--- inbox に行を追記する
function M.append(lines)
  lines = vim.tbl_filter(function(l)
    return vim.trim(l) ~= ""
  end, lines)
  if #lines == 0 then
    return
  end
  local prefix = config.options.capture_prefix
  local out = {}
  for i, l in ipairs(lines) do
    out[i] = (i == 1 and prefix or string.rep(" ", vim.fn.strdisplaywidth(prefix))) .. l
  end

  local path = inbox_path()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local bufnr
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and require("notemode.notes").is_note(vim.api.nvim_buf_get_name(b))
      and config.real(vim.api.nvim_buf_get_name(b)) == path then
      bufnr = b
    end
  end
  if bufnr then
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, out)
    require("notemode.buffer").save(bufnr)
  else
    if not vim.uv.fs_stat(path) then
      local header = require("notemode.notes").render(config.options.templates.inbox, { title = "Inbox" })
      local head = vim.split(header, "\n", { plain = true })
      if head[#head] == "" then
        table.remove(head)
      end
      vim.fn.writefile(head, path)
    end
    vim.fn.writefile(out, path, "a")
  end
  vim.notify("notemode: inbox に追加しました", vim.log.levels.INFO)
end

--- フローティングウィンドウでさっとメモを取る
function M.open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "notemode://capture")

  local width = math.min(80, vim.o.columns - 4)
  local height = 8
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " Capture → " .. config.options.inbox .. " ",
    title_pos = "center",
    footer = " <C-s>/:w 保存  q 破棄 ",
    footer_pos = "center",
    style = "minimal",
  })
  vim.wo[win].wrap = true

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  local function save()
    M.append(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    vim.bo[buf].modified = false
    vim.cmd.stopinsert()
    close()
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = save })
  vim.keymap.set({ "n", "i" }, "<C-s>", save, { buffer = buf })
  vim.keymap.set("n", "q", close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf })
  vim.cmd.startinsert()
end

return M
