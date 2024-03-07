print("hello")

local function browse()
  local result = vim.fn.system("vault kv list /foy/secrets")
  local _, count = string.gsub(result, '\n', '\n')
  vim.api.nvim_buf_set_text(0, count, 0, count, 0, {result})
end

return {
  browse = browse
}
