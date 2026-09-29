local config = require("notemode.config")
local notes = require("notemode.notes")

local M = {}

local group = vim.api.nvim_create_augroup("notemode_buffer", { clear = true })
local attached = {}

function M.maybe_attach(buf)
  if notes.is_note(vim.api.nvim_buf_get_name(buf)) then
    M.attach(buf)
  end
end

function M.attach(buf)
  attached[buf] = true
  vim.b[buf].notemode = true
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win][0].wrap = true
    vim.wo[win][0].linebreak = true
  end

  local lhs = config.options.mappings.goto_file
  if lhs then
    vim.keymap.set("n", lhs, require("notemode.gf").goto_file, {
      buffer = buf,
      silent = true,
      nowait = true,
      desc = "notemode: go to note on this line",
    })
  end

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
