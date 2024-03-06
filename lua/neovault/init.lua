print("hello")

local function browse()
  local result = vim.fn.system("vault kv list /kv")
  for k,v in pairs({result}) do
    vim.api.nvim_buf_set_text(k, 0, k, 0, 0, {v})
  end
  print(result)
end

return {
  browse = browse
}
