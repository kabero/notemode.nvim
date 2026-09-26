-- nvim --headless -u NONE -l tests/run.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd("filetype plugin on")
vim.cmd("runtime plugin/notemode.lua")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
dir = vim.uv.fs_realpath(dir)
require("notemode").setup({ dir = dir, picker = "select" })

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

test("task toggle", function()
  local t = require("notemode.task").toggle_line
  eq(t("- [ ] a"), "- [x] a")
  eq(t("  - [x] a"), "  - [ ] a")
  eq(t("- a"), "- [ ] a")
  eq(t("1. a"), "1. [ ] a")
  eq(t("  a"), "  - [ ] a")
  eq(t(""), "- [ ] ")
end)

test("link parse", function()
  local p = require("notemode.link").parse
  eq({ p("foo") }, { "foo" })
  eq({ p("foo#bar|baz") }, { "foo", "bar" })
end)

test("tags", function()
  local x = require("notemode.search").extract_tags
  eq(x("#todo と #日本語、それと a#b #123 (#x)"), { { 1, "todo" }, { 11, "日本語" }, { 44, "x" } })
end)

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

test("follow link creates note, autosave writes", function()
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "see [[Project Plan#Goal|plan]] here" })
  vim.cmd("doautocmd TextChanged")
  assert(vim.uv.fs_stat(dir .. "/index.md"), "index.md saved")
  vim.api.nvim_win_set_cursor(0, { 3, 8 })
  require("notemode.link").follow()
  eq(vim.fn.expand("%:t"), "Project Plan.md")
  eq(lines(), { "# Project Plan", "" })
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "## Goal", "ship it #work" })
  vim.cmd("silent write")
  vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/index.md"))
  vim.api.nvim_win_set_cursor(0, { 3, 8 })
  require("notemode.link").follow()
  eq(vim.api.nvim_win_get_cursor(0)[1], 3)
end)

test("resolve is case-insensitive and finds subdirs", function()
  local notes = require("notemode.notes")
  vim.fn.mkdir(dir .. "/sub", "p")
  vim.fn.writefile({ "# Deep", "[[project plan]]" }, dir .. "/sub/Deep.md")
  notes.invalidate()
  eq(notes.resolve("project plan"), vim.fs.normalize(dir) .. "/Project Plan.md")
  eq(notes.resolve("Deep"), vim.fs.normalize(dir) .. "/sub/Deep.md")
  eq(notes.resolve("sub/Deep"), vim.fs.normalize(dir) .. "/sub/Deep.md")
end)

test("backlinks", function()
  vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/Project Plan.md"))
  require("notemode.link").backlinks()
  local qf = vim.fn.getqflist()
  eq(#qf, 2)
  vim.cmd("cclose")
end)

test("grep and tags", function()
  require("notemode.search").grep("ship")
  eq(#vim.fn.getqflist(), 1)
  eq(require("notemode.search").tag_counts(), { work = 1 })
  vim.cmd("cclose")
end)

test("omnifunc", function()
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "x [[proj" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  local lf = require("notemode.link").omnifunc
  eq(lf(1, ""), 4)
  vim.api.nvim_win_set_cursor(0, { 1, 8 })
  local items = lf(0, "proj")
  eq(#items, 1)
  eq(items[1].word, "Project Plan]]")
  vim.cmd("silent undo")
end)

test("daily and capture", function()
  vim.cmd("Note daily -1")
  local y = os.date("%Y-%m-%d", os.time() - 86400)
  eq(vim.fn.expand("%:t"), y .. ".md")
  eq(lines()[1], "# " .. y)
  vim.cmd("Note capture buy milk")
  eq(vim.fn.readfile(dir .. "/inbox.md"), { "# Inbox", "", "- buy milk" })
end)


test("note mode tab handling", function()
  vim.cmd("tabnew")
  vim.cmd("edit " .. vim.fn.tempname())
  vim.cmd("Note")
  eq(vim.t.notemode, true)
  eq(#vim.api.nvim_list_tabpages(), 2)
  eq(require("notemode").statusline(), "NOTE")
  vim.cmd("Note quit")
  eq(#vim.api.nvim_list_tabpages(), 1)
  eq(vim.t.notemode, nil)
  vim.cmd("Note")
  eq(#vim.api.nvim_list_tabpages(), 2)
end)

print(("%d passed, %d failed"):format(passed, failed))
vim.fn.delete(dir, "rf")
os.exit(failed == 0 and 0 or 1)
