local M = {}

--- 1 行分のタスク状態を切り替える
---   "- [ ] a" -> "- [x] a" -> "- [ ] a"
---   "- a"     -> "- [ ] a"
---   "a"       -> "- [ ] a"
function M.toggle_line(line)
  local indent, bullet, rest = line:match("^(%s*)([-*+]%s+)(.*)$")
  if not indent then
    indent, bullet, rest = line:match("^(%s*)(%d+[.)]%s+)(.*)$")
  end
  if bullet then
    local mark, body = rest:match("^%[(.)%]%s?(.*)$")
    if mark then
      return indent .. bullet .. "[" .. (mark == " " and "x" or " ") .. "] " .. body
    end
    return indent .. bullet .. "[ ] " .. rest
  end
  local ind, body = line:match("^(%s*)(.*)$")
  return ind .. "- [ ] " .. body
end

function M.toggle(first, last)
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  for i, l in ipairs(lines) do
    lines[i] = M.toggle_line(l)
  end
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
end

return M
