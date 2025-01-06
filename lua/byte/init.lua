#!/usr/bin/env lua

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

local _H = {}
local M = {
  _H = _H,
  _orig_mappings = {},
  _is_mappings_on = false,
  _match_ids = {},
  cmd = {},
}

M.append_plain_sep = function()
  vim.api.nvim_put({ "｜" }, "c", true, true)
end
M.append_switch_sep = function()
  vim.api.nvim_put({ "【｜】" }, "c", true, true)
end

M.new_section = function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local section
  for i = #lines, 1, -1 do
    section = lines[i]:match "^# (%d+)"
    if section ~= nil then
      section = tonumber(section); break
    end
  end
  if section == nil then section = 0 end

  vim.api.nvim_buf_set_lines(0, -1, -1, false, {
    "",
    string.format("# %d", section + 1),
    "",
    "## 人工英文转写结果",
    "",
    "## 人工英文断句结果",
    "",
    "## 人工同传中文结果",
    "",
    "## 人工同传中文断句结果",
    "",
    "## 人工英文顺滑结果",
    "",
    "## 人工英文顺滑断句结果",
    "",
  })
  vim.fn.cursor(#lines + 4, 1)
end

M.prev_para = function()
  vim.fn.search("^## ", "bW")
  vim.fn.search("^## ", "bW")
  vim.fn.search("^[^#]", "W")
end
M.next_para = function()
  vim.fn.search("^## ", "W")
  vim.fn.search("^[^#]", "W")
end
M.prev_section = function()
  vim.fn.search("^# ", "bW")
end

M.next_section = function()
  vim.fn.search("^# ", "W")
end

-- Returns the lines of the current section.
M.get_section_lines = function()
  local lines = {}
  local curr_lineno = vim.api.nvim_win_get_cursor(0)[1]
  local line
  for i = curr_lineno, 1, -1 do
    line = vim.fn.getline(i)
    if line:match "^# " then break end
    if line ~= "" then table.insert(lines, 1, line) end
  end
  for i = curr_lineno + 1, vim.fn.line "$" do
    line = vim.fn.getline(i)
    if line:match "^# " then break end
    if line ~= "" then table.insert(lines, line) end
  end
  return lines
end

---Diff two lines in two splits.
---@param line1 string
---@param line2 string
---@param bufname1 string
---@param bufname2 string
M.diff_lines = function(line1, line2, bufname1, bufname2)
  vim.cmd [[belowright split]]
  local buf1 = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf1, bufname1)
  vim.bo[buf1].bufhidden = "wipe"
  vim.bo[buf1].buftype = "nowrite"
  vim.api.nvim_buf_set_lines(buf1, 0, -1, true, { line1 })
  vim.api.nvim_set_current_buf(buf1)
  vim.cmd [[diffthis]]

  vim.cmd [[belowright vsplit]]
  local buf2 = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf2, bufname2)
  vim.bo[buf2].bufhidden = "wipe"
  vim.bo[buf2].buftype = "nowrite"
  vim.api.nvim_buf_set_lines(buf2, 0, -1, true, { line2 })
  vim.api.nvim_set_current_buf(buf2)
  vim.cmd [[diffthis]]
end
M.diff_orig_smth = function()
  local line_orig, line_smooth
  local found_orig = false
  local found_smooth = false
  local section_lines = M.get_section_lines()
  for i = 2, #section_lines do
    if not found_orig and section_lines[i - 1]:match "^## 人工英文转写结果" then
      line_orig = section_lines[i]
      found_orig = true
    end
    if not found_smooth and section_lines[i - 1]:match "^## 人工英文顺滑结果" then
      line_smooth = section_lines[i]
      found_smooth = true
    end
  end
  M.diff_lines(line_orig, line_smooth, "人工英文转写结果", "人工英文顺滑结果")
end

_H.warn_invalid_sep = function(on)
  if on then
    local color, pat
    if #M._match_ids ~= 0 then return end
    for _, color_pat in ipairs {
      { "ItColor84", [[\v【?｜】?]] }, -- green, correct sep, not preceded by whitespace
      { "ItColor125", [[\v【?丨】?]] }, -- red, error for wrong sep
      { "ItColor173",
        "\\v[[:blank:]]%(【?｜】?)@=|%([[:punct:][:alnum:]]【?｜】?)@<=[[:alnum:]]|%([，。？！”’—…]【?｜】?)@<=[[:blank:]]" } -- yellow, warning for correct sep but preceded by whitespace or not followed by whitespace in English or followed by whitespace in Chinese
    } do
      color, pat = unpack(color_pat)
      table.insert(M._match_ids, vim.fn.matchadd(color, pat))
    end
  else
    for _, id in ipairs(M._match_ids) do vim.fn.matchdelete(id) end
  end
end

---@param key string
---@param mode string|string[]
---@return nil
_H.store_orig_mapping = function(key, mode)
  if type(mode) == "string" then
    table.insert(M._orig_mappings, vim.fn.maparg(key, mode, false, true))
  else
    for _, m in ipairs(mode) do
      table.insert(M._orig_mappings, vim.fn.maparg(key, m, false, true))
    end
  end
end

M.config = {
  keymaps = {
    { "n", "<bar>", M.append_plain_sep, { buffer = true } },
    { "n", "<c-bar>", M.append_switch_sep, { buffer = true } },
    { "n", "<c-n>", M.new_section, { buffer = true } },
    { "n", "{", M.prev_para, { buffer = true } },
    { "n", "}", M.next_para, { buffer = true } },
    { "n", "[[", M.prev_section, { buffer = true } },
    { "n", "]]", M.next_section, { buffer = true } },
    { "n", "<c-t>", M.diff_orig_smth, { buffer = true, desc = "Diff between en original and en smooth" } }
  }
}

M.cmd.enable_keybindings = function()
  if M._is_mappings_on then
    vim.notify "Keybindings already on, nothing to do"
    return
  end
  if M.config.keymaps == nil then return end

  local mode, lhs, rhs, opts
  for _, entry in ipairs(M.config.keymaps) do
    mode, lhs, rhs, opts = unpack(entry)
    _H.store_orig_mapping(lhs, mode)
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  vim.notify "Keybindings on"
  M._is_mappings_on = true
  _H.warn_invalid_sep(true)
end

M.cmd.disable_keybindings = function()
  if not M._is_mappings_on then
    vim.notify "Keybindings already off, nothing to do"
    return
  end

  if M.config.keymaps ~= nil then
    local mode, lhs, _
    for _, entry in ipairs(M.config.keymaps) do
      mode, lhs, _, _ = unpack(entry)
      pcall(vim.api.nvim_buf_del_keymap, 0, mode, lhs)
    end
  end
  for _, mapargs in ipairs(M._orig_mappings) do
    if next(mapargs) ~= nil then
      mapargs.buffer = true
      vim.fn.mapset(mapargs)
    end
  end
  vim.notify "Keybindings off"
  M._is_mappings_on = false
  M._orig_mappings = {}

  _H.warn_invalid_sep(false)
end

---Converts the n-th section to into dict. Converts all sections if n <= 0 or n > last_section.
---@param n string
_H.section2dict = function(n)
  ---@type string
  if n == nil then
    local section_lineno = vim.fn.search("^# ", "bWn")
    n = vim.fn.getline(section_lineno):match "^# (%d+)"
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local data = {}
  local section, _section, subsection, _subsection
  for _, line in ipairs(lines) do
    repeat
      -- skip empty lines
      if line == "" then break end -- continue
      _section = line:match "^# (%d+)"
      if _section ~= nil then
        section = _section
        data[section] = {}
        break -- continue
      end
      _subsection = line:match "^## (%S+)"
      if _subsection ~= nil then
        subsection = _subsection
        data[section][subsection] = ""
        break -- continue
      end

      data[section][subsection] = line
    until true
  end

  if data[n] ~= nil then
    data = { [n] = data[n] }
  end
  return data
end

M.cmd.start_server = vim.fn["ByteStartServer"]
M.cmd.stop_server = vim.fn["ByteStopServer"]
M.cmd.send_data = function(n)
  vim.fn["ByteSendData"](_H.section2dict(n))
end

vim.api.nvim_create_user_command("B", function(a)
  ---@type string[]
  local actions = a.fargs
  local cmd = M.cmd[actions[1]]
  if cmd ~= nil then
    table.remove(actions, 1)
    return cmd(unpack(actions))
  end
end, {
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    if vim.tbl_count(args) > 2 then
      return
    end
    table.remove(args, 1)
    ---@type string
    local prefix = table.remove(args, 1)
    if prefix and line:sub(-1) == " " then
      return
    end
    return vim.tbl_filter(
      function(key)
        return not prefix or key:find(prefix, 1, true) == 1
      end,
      vim.tbl_keys(M.cmd)
    )
  end,
  nargs = "*"
})

return M
