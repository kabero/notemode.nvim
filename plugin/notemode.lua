if vim.g.loaded_notemode then
  return
end
vim.g.loaded_notemode = true

vim.api.nvim_create_user_command("Note", function()
  require("notemode.mode").toggle()
end, { desc = "notemode.nvim: toggle note mode" })

-- ノートディレクトリ配下の markdown を開いたら自動でノート用バッファにする
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("notemode", { clear = true }),
  pattern = "markdown",
  callback = function(args)
    require("notemode.buffer").maybe_attach(args.buf)
  end,
})
