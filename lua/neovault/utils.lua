-- lua/neovault/buf.lua
local M = {}

function M.set_explorer_buffer_opts(buf)
  vim.bo[buf].bufhidden  = 'hide'
  vim.bo[buf].buftype    = 'nofile'
  vim.bo[buf].filetype   = 'neovault-explorer'
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly   = true
  vim.bo[buf].swapfile   = false
end

function M.set_yaml_buffer_opts(buf)
  vim.bo[buf].bufhidden  = 'hide'
  vim.bo[buf].buflisted  = false
  vim.bo[buf].buftype    = 'acwrite'
  vim.bo[buf].filetype   = 'yaml'
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly   = false
  vim.bo[buf].swapfile   = false
end

function M.ensure_trailing_slash(str)
  if not str:match('/$') then
    return str .. '/'
  end
  return str
end

---@class NeoVaultCopyOpts
---@field register string?    target register (default: '+')
---@field notify boolean?     display notification (default: true)
---@field strip_quotes boolean?  remove quotes (default: true)
---@field strip_inline_comment boolean?  remove inline comment " # ... " if not quoted

--- Normalize YAML value (trim, handle block scalars)
---@param value string
---@param opts NeoVaultCopyOpts|nil
---@return string
function M.normalize_value(value, opts)
  value = value or ''
  value = value:gsub('^%s+', ''):gsub('%s+$', '')

  -- Handle block scalar indicators
  if value == '|' or value == '>' then
    -- Remove the first line (| or >) and keep indented lines
    local lines = vim.api.nvim_buf_get_lines(0, vim.fn.line('.') , -1, false)
    local indent = lines[1]:match('^(%s*)') or ''
    local block_lines = {}

    for _, l in ipairs(lines) do
      if l:match('^' .. indent .. '%s+') then
        table.insert(block_lines, l)
      else
        break
      end
    end

    value = table.concat(block_lines, value == '>' and ' ' or '\n')
  end

  return value
end

--- Copy YAML value under cursor, including multiline
---@param opts NeoVaultCopyOpts|nil
function M.copy_value_under_cursor(opts)
  opts = opts or {}
  local reg = opts.register or '+'
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]

  local value, err = M.extract_multiline_value(line_nr, opts)
  if not value then
    if opts.notify ~= false then
      vim.notify(err or "no value to copy", vim.log.levels.WARN)
    end
    return
  end

  vim.fn.setreg(reg, value)
  if opts.notify ~= false then
    vim.notify("value copied", vim.log.levels.INFO)
  end
end


--- create a buffer mapping with CR
---@param bufnr integer    target buffer (0 = current buffer)
---@param opts NeoVaultCopyOpts|nil
function M.map_copy_value_cr(bufnr, opts)
  vim.keymap.set('n', '<CR>', function()
    M.copy_value_under_cursor(opts)
  end, {
    buffer = bufnr or 0,
    silent = true,
    noremap = true,
    desc = 'NeoVault: copy current value',
  })
end

--- Extract multiline value from YAML starting at current line
---@param start_line integer
---@param opts NeoVaultCopyOpts|nil
---@return string|nil errmsg
function M.extract_multiline_value(start_line, opts)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, -1, false)
  if #lines == 0 then return nil, "empty" end

  local first_line = lines[1]
  if first_line:match('^%s*$') then return nil, "empty" end
  if first_line:match('^%s*#') then return nil, "comment" end

  local colon_pos = first_line:find(':')
  if not colon_pos then return nil, "format not correct" end

  local raw_value = first_line:sub(colon_pos + 1)
  local indent = first_line:match('^(%s*)') or ''
  local value_lines = { raw_value }

  for i = 2, #lines do
    local line = lines[i]
    if line:match('^%s*$') then break end
    if not line:match('^' .. indent .. '%s+') then break end
    table.insert(value_lines, line)
  end

  local full_value = table.concat(value_lines, '\n')
  local value = M.normalize_value(full_value, opts)

  if value == '' then return nil, "empty value" end
  return value, nil
end

function M.to_yaml_lines(tbl)
    local out = {}

    local function split_lines(s)
      -- normalize CRLF -> LF then split
      s = tostring(s):gsub('\r\n', '\n')
      local t = {}
      for line in s:gmatch('([^\n]*)\n?') do
        table.insert(t, line)
      end
      -- remove last line if because of split
      if #t > 0 and t[#t] == '' then
        table.remove(t)
      end
      return t
    end

    for k, v in pairs(tbl or {}) do
      if type(v) == 'string' and v:find('\n') then
        -- YAML block scalar
        table.insert(out, string.format('%s: |', k))
        for _, l in ipairs(split_lines(v)) do
          table.insert(out, '  ' .. l) -- indent
        end
      else
        table.insert(out, string.format('%s: %s', k, tostring(v)))
      end
    end

    if #out == 0 then
      out = { '# (empty)' }
    end
    return out
  end

return M
