-- nvim --headless -u NONE -l tests/run.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd("filetype plugin on")
vim.cmd("runtime plugin/notemode.lua")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
dir = vim.uv.fs_realpath(dir)
require("notemode").setup({ dir = dir })

local failed, passed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL " .. name .. ": " .. tostring(err))
  end
end
local function eq(a, b)
  if not vim.deep_equal(a, b) then
    error(vim.inspect(a) .. " ~= " .. vim.inspect(b), 2)
  end
end
local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

test(":Note enters note mode on blank tab", function()
  vim.cmd("Note")
  eq(#vim.api.nvim_list_tabpages(), 1)
  eq(vim.t.notemode, true)
  eq(vim.fn.getcwd(), vim.fs.normalize(dir))
  eq(vim.api.nvim_buf_get_name(0), vim.fs.normalize(dir) .. "/index.md")
  eq(lines(), { "# Index", "" })
  eq(vim.bo.modified, false)
  eq(vim.b.notemode, true)
  eq(vim.uv.fs_stat(dir .. "/index.md"), nil)
end)

test("autosave writes", function()
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Project Plan" })
  vim.cmd("doautocmd TextChanged")
  eq(vim.fn.readfile(dir .. "/index.md"), { "# Index", "", "Project Plan" })
end)

test("gf opens the note named on the line", function()
  local gf = require("notemode.gf")
  eq(gf.line_name("- [ ] Project Plan"), "Project Plan")
  eq(gf.line_name("  1. foo.md "), "foo.md")
  vim.fn.writefile({ "# Project Plan" }, dir .. "/Project Plan.md")
  require("notemode.notes").invalidate()
  local from = dir .. "/gf.md"
  local function gf_on(text, col)
    vim.fn.writefile({ text }, from)
    vim.cmd("edit! " .. vim.fn.fnameescape(from))
    vim.api.nvim_win_set_cursor(0, { 1, col or 0 })
    vim.cmd("normal gf")
    return vim.fn.expand("%:p")
  end
  -- 空白を含む名前も、拡張子なしでも、大文字小文字違いでも行全体で引ける
  eq(gf_on("- project plan", 4), dir .. "/Project Plan.md")
  eq(gf_on("Project Plan.md"), dir .. "/Project Plan.md")
  -- 行全体では引けなくても、カーソル下のファイル名で引ける
  eq(gf_on("see ./index.md here", 5), dir .. "/index.md")
  -- 見つからなければ行の名前で新しいノート (保存するまでファイルは作らない)
  eq(gf_on("* Brand New"), dir .. "/Brand New.md")
  eq(lines(), { "# Brand New", "" })
  eq(vim.uv.fs_stat(dir .. "/Brand New.md"), nil)
  vim.cmd("bwipeout! " .. vim.fn.fnameescape(from))
  vim.fn.delete(from)
  require("notemode.notes").invalidate()
end)

test("resolve is case-insensitive and finds subdirs", function()
  local notes = require("notemode.notes")
  vim.fn.mkdir(dir .. "/sub", "p")
  vim.fn.writefile({ "# Deep" }, dir .. "/sub/Deep.md")
  notes.invalidate()
  eq(notes.resolve("project plan"), vim.fs.normalize(dir) .. "/Project Plan.md")
  eq(notes.resolve("Deep"), vim.fs.normalize(dir) .. "/sub/Deep.md")
  eq(notes.resolve("sub/Deep"), vim.fs.normalize(dir) .. "/sub/Deep.md")
end)

test(":Note toggles the note tab", function()
  vim.cmd("tabnew")
  vim.cmd("edit " .. vim.fn.tempname())
  vim.cmd("Note")
  eq(vim.t.notemode, true)
  eq(#vim.api.nvim_list_tabpages(), 2)
  eq(require("notemode").statusline(), "NOTE")
  vim.cmd("Note")
  eq(#vim.api.nvim_list_tabpages(), 1)
  eq(vim.t.notemode, nil)
end)

test("leaving the last tab keeps nvim open", function()
  vim.cmd("enew")
  local cwd = vim.fn.getcwd()
  vim.cmd("Note")
  eq(#vim.api.nvim_list_tabpages(), 1)
  eq(vim.fn.getcwd(), dir)
  -- -l で走るテストは VimEnter 前なので、起動後に <leader>mm で入った状態にする
  vim.t.notemode_quit = false
  vim.cmd("Note")
  eq(#vim.api.nvim_list_tabpages(), 1)
  eq(vim.t.notemode, nil)
  eq(vim.api.nvim_buf_get_name(0), "")
  eq(vim.fn.getcwd(), cwd)
end)

print(("%d passed, %d failed"):format(passed, failed))
vim.fn.delete(dir, "rf")
os.exit(failed == 0 and 0 or 1)
