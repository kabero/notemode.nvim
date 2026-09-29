local M = {}

M.defaults = {
  -- ノートを置くディレクトリ
  dir = "~/notes",
  -- :Note で最初に開くもの: "index" | "daily" | "inbox"
  start = "index",
  index = "index.md",
  inbox = "inbox.md",
  daily_dir = "daily",
  daily_format = "%Y-%m-%d",
  -- 編集するたびに自動保存する
  autosave = true,
  -- :Note find で使うピッカー: "auto" | "telescope" | "fzf-lua" | "select"
  picker = "auto",
  -- テンプレート中の {{title}} {{date}} {{time}} が置換される
  templates = {
    note = "# {{title}}\n\n",
    daily = "# {{title}}\n\n## Todo\n\n- [ ] \n\n## Memo\n\n",
    index = "# Index\n\n",
    inbox = "# Inbox\n\n",
  },
  -- キャプチャした各行の先頭につける文字列
  capture_prefix = "- ",
  -- ノートバッファ内のキーマップ (false で無効化)
  mappings = {
    follow = "<CR>",
    goto_file = "gf",
    back = "<BS>",
    next_link = "<Tab>",
    prev_link = "<S-Tab>",
    toggle_task = "<C-Space>",
    complete = "[[",
    backlinks = "<LocalLeader>b",
    find = "<LocalLeader>f",
    new = "<LocalLeader>n",
    daily = "<LocalLeader>d",
    grep = "<LocalLeader>g",
    tags = "<LocalLeader>t",
    capture = "<LocalLeader>c",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  opts = opts or {}
  if opts.mappings == false then
    opts.mappings = vim.tbl_map(function()
      return false
    end, M.defaults.mappings)
  end
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
end

--- パスを正規化する (シンボリックリンクは解決。ファイルが未作成なら親ディレクトリで解決)
function M.real(path)
  path = vim.fs.normalize(vim.fn.expand(path))
  local real = vim.uv.fs_realpath(path)
  if real then
    return real
  end
  local parent = vim.uv.fs_realpath(vim.fs.dirname(path))
  return parent and (parent .. "/" .. vim.fs.basename(path)) or path
end

function M.dir()
  return M.real(M.options.dir)
end

return M
