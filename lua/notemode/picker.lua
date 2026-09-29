local config = require("notemode.config")
local notes = require("notemode.notes")

local M = {}

local function select()
  vim.ui.select(notes.list(), {
    prompt = "Notes",
    format_item = function(n)
      return n.rel
    end,
  }, function(n)
    if n then
      notes.open(n.path)
    end
  end)
end

local backends = {
  telescope = function(dir)
    require("telescope.builtin").find_files({ cwd = dir, prompt_title = "Notes" })
  end,
  ["fzf-lua"] = function(dir)
    require("fzf-lua").files({ cwd = dir, prompt = "Notes> " })
  end,
}

local modules = { telescope = "telescope.builtin", ["fzf-lua"] = "fzf-lua" }

function M.find()
  local choice = config.options.picker
  if choice == "auto" then
    for _, name in ipairs({ "telescope", "fzf-lua" }) do
      if pcall(require, modules[name]) then
        choice = name
        break
      end
    end
  end
  if backends[choice] then
    return backends[choice](config.dir())
  end
  select()
end

return M
