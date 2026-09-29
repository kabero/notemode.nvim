local M = {}

local function mode()
  return require("notemode.mode")
end
local function notes()
  return require("notemode.notes")
end

local function ask(prompt, fn)
  vim.ui.input({ prompt = prompt }, function(input)
    if input and vim.trim(input) ~= "" then
      fn(vim.trim(input))
    end
  end)
end

M.subcommands = {
  open = function()
    mode().enter()
  end,
  quit = function()
    mode().leave()
  end,
  toggle = function()
    mode().toggle()
  end,
  index = function()
    mode().enter(notes().index)
  end,
  inbox = function()
    mode().enter(notes().inbox)
  end,
  daily = function(args)
    mode().enter(function()
      notes().daily(tonumber(args[1]) or 0)
    end)
  end,
  new = function(args)
    local function create(title)
      mode().enter(function()
        notes().new(title)
      end)
    end
    if #args > 0 then
      create(table.concat(args, " "))
    else
      ask("New note: ", create)
    end
  end,
  grep = function(args)
    local function run(pat)
      mode().enter(function()
        require("notemode.search").grep(pat)
      end)
    end
    if #args > 0 then
      run(table.concat(args, " "))
    else
      ask("Grep notes: ", run)
    end
  end,
  tags = function(args)
    mode().enter(function()
      if args[1] then
        require("notemode.search").tag(args[1])
      else
        require("notemode.search").tags()
      end
    end)
  end,
  backlinks = function()
    require("notemode.link").backlinks()
  end,
  capture = function(args)
    if #args > 0 then
      require("notemode.capture").append({ table.concat(args, " ") })
    else
      require("notemode.capture").open()
    end
  end,
}

local aliases = { today = "daily", q = "quit" }

function M.run(opts)
  local args = vim.deepcopy(opts.fargs)
  local sub = table.remove(args, 1) or "open"
  sub = aliases[sub] or sub
  local fn = M.subcommands[sub]
  if not fn then
    vim.notify("notemode: 不明なサブコマンド: " .. sub, vim.log.levels.ERROR)
    return
  end
  fn(args)
end

function M.complete(arglead, cmdline)
  local parts = vim.split(cmdline, "%s+")
  if #parts <= 2 then
    local names = vim.tbl_keys(M.subcommands)
    table.sort(names)
    return vim.tbl_filter(function(n)
      return n:find(arglead, 1, true) == 1
    end, names)
  end
  if parts[2] == "tags" then
    local tags = vim.tbl_keys(require("notemode.search").tag_counts())
    table.sort(tags)
    return vim.tbl_filter(function(t)
      return t:find(arglead, 1, true) == 1
    end, tags)
  end
  return {}
end

return M
