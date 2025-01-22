#!/usr/bin/env lua

local M = {}

---@return string|nil
M.get_curr_section_nr = function()
  local section_lineno = vim.fn.search("^# ", "cbWn")
  if section_lineno == 0 then
    vim.notify("Not in a section!", vim.log.levels.ERROR)
    return
  end
  return vim.fn.getline(section_lineno):match "^# (%d+)"
end

---@return string|nil
M.get_curr_subsection_name = function()
  local subsection_lineno = vim.fn.search("^## ", "cbWn")
  local section_lineno = vim.fn.search("^# ", "cbWn")
  if subsection_lineno == 0 or section_lineno > subsection_lineno then
    vim.notify("Not in a subsection!", vim.log.levels.ERROR)
    return
  end
  return vim.fn.getline(subsection_lineno):match "^## (%S+)"
end

---@param lines string[]
M.lines2dict = function(lines)
  local data = {}
  local section, _section, subsection, _subsection, _key, _value
  for _, line in ipairs(lines) do
    repeat
      -- skip empty lines
      if line == "" then break end -- continue

      -- [start] xxx.xxx, [end] xxx.xxx
      _key, _value = line:match "^%[([^]]+)%]%s+(.*)$"
      if _key ~= nil and _value ~= nil then
        data[section][_key] = _value
        break
      end

      -- # 1, #2, ...
      _section = line:match "^# (%d+)"
      if _section ~= nil then
        section = _section
        data[section] = {}
        break -- continue
      end

      -- ## xxx
      _subsection = line:match "^## (%S+)"
      if _subsection ~= nil then
        subsection = _subsection
        data[section][subsection] = ""
        break -- continue
      end

      -- content line
      if data[section][subsection] == "" then
        data[section][subsection] = line
      else
        data[section][subsection] = data[section][subsection] .. (subsection:match "英文" and " " or "") .. line
      end
    until true
  end
  return data
end

---Converts the n-th section to into dict. Converts all sections if n <= 0 or n > last_section.
---@param n string|nil
M.buf2dict = function(n)
  if n == nil then
    n = M.get_curr_section_nr()
    if n == nil then return end
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local data = M.lines2dict(lines)

  if data[n] ~= nil then data = { [n] = data[n] } end
  return data
end

return M
