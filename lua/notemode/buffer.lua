local config = require("notemode.config")
local notes = require("notemode.notes")

local M = {}

local ns = vim.api.nvim_create_namespace("notemode")
local group = vim.api.nvim_create_augroup("notemode_buffer", { clear = true })
local attached = {}

--- [[link]] と #tag をハイライトする (treesitter と共存できるよう decoration provider で描画)
vim.api.nvim_set_decoration_provider(ns, {
  on_win = function(_, _, buf)
    return attached[buf] == true
  end,
  on_line = function(_, _, buf, row)
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    if not line or line == "" then
      return
    end
    for s, inner, e in line:gmatch(require("notemode.link").pattern) do
      local name = require("notemode.link").parse(inner)
      local hl = notes.resolve(name) and "NotemodeLink" or "NotemodeLinkMissing"
      vim.api.nvim_buf_set_extmark(buf, ns, row, s - 1, { end_col = e - 1, hl_group = hl, ephemeral = true })
    end
    for _, t in ipairs(require("notemode.search").extract_tags(line)) do
      vim.api.nvim_buf_set_extmark(buf, ns, row, t[1] - 1, {
        end_col = t[1] + #t[2],
        hl_group = "NotemodeTag",
        ephemeral = true,
      })
    end
    local done = line:match("^%s*[-*+]%s+%[[xX]%]()")
    if done then
      vim.api.nvim_buf_set_extmark(buf, ns, row, done - 1, { end_col = #line, hl_group = "NotemodeTaskDone", ephemeral = true })
    end
  end,
})

local function map(buf, modes, name, rhs, desc)
  local lhs = config.options.mappings[name]
  if lhs then
    -- nowait: グローバルに <leader>fb などがあっても <leader>f を即座に発火させる
    vim.keymap.set(modes, lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = "notemode: " .. desc })
  end
end

local function cmd(sub)
  return function()
    vim.cmd("Note " .. sub)
  end
end

function M.is_attached(buf)
  return attached[buf] == true
end

function M.maybe_attach(buf)
  if notes.is_note(vim.api.nvim_buf_get_name(buf)) then
    M.attach(buf)
  end
end

function M.attach(buf)
  attached[buf] = true
  vim.b[buf].notemode = true
  vim.bo[buf].omnifunc = "v:lua.require'notemode.link'.omnifunc"
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win][0].wrap = true
    vim.wo[win][0].linebreak = true
  end

  local link = require("notemode.link")
  map(buf, "n", "follow", link.follow, "follow link")
  map(buf, "x", "follow", link.link_selection, "make link from selection")
  map(buf, "n", "back", "<C-o>", "go back")
  map(buf, "n", "next_link", function()
    link.jump(false)
  end, "next link")
  map(buf, "n", "prev_link", function()
    link.jump(true)
  end, "previous link")
  map(buf, "n", "toggle_task", function()
    local l = vim.api.nvim_win_get_cursor(0)[1]
    require("notemode.task").toggle(l, l + vim.v.count1 - 1)
  end, "toggle task")
  map(buf, "x", "toggle_task", function()
    local a, b = vim.fn.line("v"), vim.fn.line(".")
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
    require("notemode.task").toggle(math.min(a, b), math.max(a, b))
  end, "toggle tasks")
  map(buf, "i", "complete", "[[<C-x><C-o>", "complete link")
  map(buf, "n", "backlinks", cmd("backlinks"), "backlinks")
  map(buf, "n", "find", cmd("find"), "find note")
  map(buf, "n", "new", cmd("new"), "new note")
  map(buf, "n", "daily", cmd("daily"), "daily note")
  map(buf, "n", "grep", cmd("grep"), "grep notes")
  map(buf, "n", "tags", cmd("tags"), "tags")
  map(buf, "n", "capture", cmd("capture"), "capture to inbox")

  vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    buffer = buf,
    callback = function(args)
      vim.fn.mkdir(vim.fs.dirname(args.match), "p")
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = buf,
    callback = function(args)
      notes.add(args.match)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      attached[buf] = nil
    end,
  })
  if config.options.autosave then
    vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "BufLeave", "FocusLost" }, {
      group = group,
      buffer = buf,
      callback = function()
        M.save(buf)
      end,
    })
  end
end

function M.save(buf)
  if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == "" then
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent! update")
    end)
  end
end

function M.save_all()
  for buf in pairs(attached) do
    M.save(buf)
  end
end

return M
