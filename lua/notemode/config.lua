local M = {}

M.defaults = {
  -- ノートを置くディレクトリ
  dir = "~/notes",
  -- :Note で開くノート
  index = "index.md",
  -- 編集するたびに自動保存する
  autosave = true,
  -- 新しく開くノートの中身。{{title}} {{date}} {{time}} が置換される
  templates = {
    note = "# {{title}}\n\n",
    index = "# Index\n\n",
  },
  -- ノートバッファ内のキーマップ (false で無効化)
  mappings = {
    goto_file = "gf",
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
