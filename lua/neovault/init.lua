local function browse()
  local result = vim.fn.system("vault kv list /foy/secrets")
  local _, count = string.gsub(result, '\n', '\n')
  vim.api.nvim_buf_set_lines(0, 0, 0, true, result)
end

-- local bufnr = vim.api.nvim_get_current_buf()
-- local bufnr = 8
-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {"rte"})

local function rand_buf_name(lenght)
  local s = ""
  for i = 0, lenght do
    local randlowercase = string.char(math.random(97, 97 + 25))
    s = s .. randlowercase
    i = i + 1
  end
  return "/tmp/neovault_" .. s
end

local function open_tmp_buf()
  -- check if temporary buffer is open
  local buf_tmp_nr = vim.fn.bufnr(BUFTMP)
  if buf_tmp_nr == -1 then -- tmp buffer not open
    buf_tmp_nr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(buf_tmp_nr, BUFTMP)
    vim.api.nvim_buf_set_lines(buf_tmp_nr, 0, -1, false, {"hello"})
    vim.api.nvim_set_current_buf(buf_tmp_nr)
  end
  return buf_tmp_nr
end

BUFTMP = rand_buf_name(10)

local function main()
  local buf_tmp_nr = open_tmp_buf()
  local result = vim.fn.system("vault kv list /kv")
  -- local _, count = string.gsub(result, '\n', '\n')
  vim.api.nvim_buf_set_lines(buf_tmp_nr, 0, -1, false, vim.split(result, '\n'))
end

return {
  main = main
}
