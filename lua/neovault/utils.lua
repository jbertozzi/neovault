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

--- normalize yaml "key: value"
---@param raw string
---@param opts NeoVaultCopyOpts|nil
---@return string
function M.normalize_value(raw, opts)
  opts = opts or {}
  local strip_quotes        = (opts.strip_quotes ~= false)          -- default: true
  local strip_inline_comment= (opts.strip_inline_comment ~= false)  -- default: true

  -- trim
  local v = raw:gsub('^%s+', ''):gsub('%s+$', '')

  -- if value start with quote, we don't cut on '#'
  local starts_with_quote = v:match("^['\"]")
  if strip_inline_comment and not starts_with_quote then
    -- remove " # ...", if any
    v = v:gsub('%s+#.*$', '')
    v = v:gsub('%s+$', '')
  end

  -- remove quotes
  if strip_quotes and #v >= 2 then
    local first, last = v:sub(1,1), v:sub(-1)
    if (first == '"' and last == '"') or (first == "'" and last == "'") then
      v = v:sub(2, -2)
    end
  end

  return v
end

--- extract value from YAML line "key: value"
---@param line string
---@param opts NeoVaultCopyOpts|nil
---@return string|nil errmsg
function M.extract_value_from_line(line, opts)
  if line:match('^%s*$') then
    return nil, "empty"
  end
  if line:match('^%s*#') then
    return nil, "comment"
  end

  -- first ':' occurence
  local colon_pos = line:find(':')
  if not colon_pos then
    return nil, "format not correct"
  end

  local raw_value = line:sub(colon_pos + 1)
  local value = M.normalize_value(raw_value, opts)

  if value == '' then
    return nil, "empty value"
  end

  return value, nil
end

--- copy value in a register (degfault to '+')
---@param opts NeoVaultCopyOpts|nil
function M.copy_value_under_cursor(opts)
  opts = opts or {}
  local reg = opts.register or '+'
  local line = vim.api.nvim_get_current_line()

  local value, err = M.extract_value_from_line(line, opts)
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
