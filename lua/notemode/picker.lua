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
  snacks = function(dir)
    require("snacks").picker.files({
      cwd = dir,
      title = "Notes",
      ft = "md",
      actions = {
        notemode_delete = function(picker)
          local paths = vim.tbl_map(require("snacks").picker.util.path, picker:selected({ fallback = true }))
          picker.preview:reset()
          if notes.delete(paths) then
            picker:find()
          end
        end,
      },
      -- <c-d> は snacks 既定の list_scroll_down を上書きする (このピッカーでだけ)。
      -- 既定と違うキーなので、入力欄の下に常に出しておく
      win = {
        input = {
          keys = {
            ["<c-d>"] = { "notemode_delete", mode = { "n", "i" }, desc = "削除" },
            ["<Tab>"] = { "select_and_next", mode = { "n", "i" }, desc = "複数選択" },
          },
          footer_keys = { "<c-d>", "<Tab>" },
        },
        list = {
          keys = {
            ["<c-d>"] = { "notemode_delete", desc = "削除" },
            ["dd"] = { "notemode_delete", desc = "削除" },
          },
        },
      },
    })
  end,
}

local modules = { telescope = "telescope.builtin", ["fzf-lua"] = "fzf-lua", snacks = "snacks" }

function M.find()
  local choice = config.options.picker
  if choice == "auto" then
    for _, name in ipairs({ "snacks", "telescope", "fzf-lua" }) do
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
