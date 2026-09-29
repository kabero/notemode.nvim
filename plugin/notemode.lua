if vim.g.loaded_notemode then
  return
end
vim.g.loaded_notemode = true

vim.api.nvim_create_user_command("Note", function(opts)
  require("notemode.command").run(opts)
end, {
  nargs = "*",
  desc = "notemode.nvim: note mode",
  complete = function(arglead, cmdline)
    return require("notemode.command").complete(arglead, cmdline)
  end,
})

local group = vim.api.nvim_create_augroup("notemode", { clear = true })

local function set_highlights()
  vim.api.nvim_set_hl(0, "NotemodeLink", { default = true, link = "Underlined" })
  vim.api.nvim_set_hl(0, "NotemodeLinkMissing", { default = true, link = "DiagnosticUnnecessary" })
  vim.api.nvim_set_hl(0, "NotemodeTaskDone", { default = true, link = "Comment" })
end
set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })

-- ノートディレクトリ配下の markdown を開いたら自動でノート用バッファにする
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "markdown",
  callback = function(args)
    require("notemode.buffer").maybe_attach(args.buf)
  end,
})
