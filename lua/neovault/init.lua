local function browse()
  local result = vim.fn.system("vault kv list /foy/secrets")
  local _, count = string.gsub(result, '\n', '\n')
  vim.api.nvim_buf_set_lines(0, 0, 0, true, result)
end

-- local bufnr = vim.api.nvim_get_current_buf()
-- local bufnr = 8
-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {"rte"})
--
local function deeper()
  local current_line_number = vim.api.nvim_win_get_cursor(0)[1]
  local current_line_content = vim.api.nvim_buf_get_lines(0, current_line_number - 1, current_line_number, false)[1]
  local element = string.match(current_line_content, "^- ([A-Za-z0-9_-]+/?)$")
  print(element)
  local result = ""
  if element then
    if string.sub(element, -1) == "/" then
      result = vim.fn.system("vault kv list -format=yaml " .. CWD .. element)
      CWD = CWD .. element
    else
      result = vim.fn.system("vault kv get -format=yaml " .. CWD .. element)
    end
  end
  -- local _, count = string.gsub(result, '\n', '\n')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(result, '\n'))

  print("go deep")
end

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
    vim.api.nvim_buf_set_keymap(buf_tmp_nr, "n", "<cr>", ":lua require('neovault').deeper()<cr>", {noremap = true})
    vim.api.nvim_set_current_buf(buf_tmp_nr)
  end
  return buf_tmp_nr
end

CWD = "/kv/"
BUFTMP = rand_buf_name(10)

local function main()
  local buf_tmp_nr = open_tmp_buf()
  local result = vim.fn.system("vault kv list -format=yaml " .. CWD)
  -- local _, count = string.gsub(result, '\n', '\n')
  vim.api.nvim_buf_set_lines(buf_tmp_nr, 0, -1, false, vim.split(result, '\n'))
end

return {
  main = main,
  deeper = deeper
}
