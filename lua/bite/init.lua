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

M.prev_subsection = function()
  vim.fn.search("^## ", "bW")
  vim.fn.search("^[^#[]", "bW")
end
M.next_subsection = function()
  vim.fn.search("^## ", "W")
  vim.fn.search("^[^#[]", "W")
end
M.prev_section = function()
  vim.fn.search("^# ", "bW")
end

M.next_section = function()
  vim.fn.search("^# ", "W")
end

---Returns the lines of the current section. Metadata lines are excluded, i.e. [start], [end].
M.get_section_lines = function()
  local lines = {}
  local curr_lineno = vim.api.nvim_win_get_cursor(0)[1]
  local line
  for i = curr_lineno, 1, -1 do
    line = vim.fn.getline(i)
    if line:match "^# " then break end
    if line ~= "" and not line:match "^%[" then table.insert(lines, 1, line) end
  end
  for i = curr_lineno + 1, vim.fn.line "$" do
    line = vim.fn.getline(i)
    if line:match "^# " then break end
    if line ~= "" and not line:match "^%[" then table.insert(lines, line) end
  end
  return lines
end

---Diff two lines in two splits.
---@param line1 string
---@param line2 string
---@param bufname1 string
---@param bufname2 string
_H.diff_lines = function(line1, line2, bufname1, bufname2)
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
  _H.diff_lines(line_orig, line_smooth, "人工英文转写结果", "人工英文顺滑结果")
end

_H.warn_invalid_sep = function(on)
  if on then
    local color, pat
    if #M._match_ids ~= 0 then return end
    for _, color_pat in ipairs {
      { "ItColor84", [[\v【?｜】?]] }, -- green, correct sep, not preceded by whitespace
      { "ItColor125", [[\v【?丨】?]] }, -- red, error for wrong sep
      { "ItColor173",
        "\\v[[:blank:]]%(【?｜】?)@=|%([[:punct:][:alnum:]]【?｜】?)@<=[[:alnum:]]|%([，。？！：”’—…]【?｜】?)@<=[[:blank:]]" } -- yellow, warning for correct sep but preceded by whitespace or not followed by whitespace in English or followed by whitespace in Chinese
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

---@return string|nil
_H.get_curr_section_nr = function()
  local section_lineno = vim.fn.search("^# ", "cbWn")
  if section_lineno == 0 then
    vim.notify("Not in a section!", vim.log.levels.ERROR)
    return
  end
  return vim.fn.getline(section_lineno):match "^# (%d+)"
end

---Converts the n-th section to into dict. Converts all sections if n <= 0 or n > last_section.
---@param n string|nil
_H.buf2dict = function(n)
  if n == nil then
    n = _H.get_curr_section_nr()
    if n == nil then return end
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
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

  if data[n] ~= nil then data = { [n] = data[n] } end
  return data
end

---Converts the n-th section to into dict. Converts all sections if n <= 0 or n > last_section.
---@param n string|nil
_H.buffer2dict_slice = function(n)
  if n == nil then
    n = _H.get_curr_section_nr()
    if n == nil then return end
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
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
    until true
  end

  if data[n] ~= nil then data = { [n] = data[n] } end
  return data
end

M.cmd.start_server = vim.fn["BiteStartServer"]
M.cmd.stop_server = vim.fn["BiteStopServer"]
M.cmd.put = function(n)
  local data = _H.buf2dict(n)
  data.action = "put"
  vim.fn["BiteSendData"](data)
end
---Plays audio of the n-th section. The JS end does nothing if n is invalid.
---@param n string|nil
M.cmd.play = function(n)
  if n == nil then
    n = _H.get_curr_section_nr()
    if n == nil then return end
  end
  vim.fn["BiteSendData"] { action = "play", section = n }
end
---Turns on/off interval audio.
M.cmd.toggle = function() vim.fn["BiteSendData"] { action = "toggle" } end

M.cmd.back = function() vim.fn["BiteSendData"] { action = "back", count = vim.v.count1 } end

---应用每一节的“模型预识别文本”到“英文转写结果”框中
---JS 那边完成后会主动发一个 fetch_content 来更新当前 buffer
M.cmd.init_transcripts = function() vim.fn["BiteSendData"] { action = "init_transcripts" } end

---调整一个小节起/止时刻，参数并非时刻而是起/止边界的期望像素位置
---@param section string number-like
---@param edge string `start` | `end`
---@param x string number-like
M.cmd.push_slice = function(section, edge, x)
  local section_edge_pos = _H.buffer2dict_slice "0"

  vim.fn["BiteSendData"] { action = "push_slice", section = section, edge = edge, x = x, section_edge_pos =
      section_edge_pos }
end

_H.push_currline_slice = function()
  local line = vim.api.nvim_get_current_line()
  local section = _H.get_curr_section_nr()
  if section == nil then return end

  local edge, value = line:match "^%[([^]]+)%]%s+(.*)$"
  if edge ~= "start" and edge ~= "end" then
    vim.notify("Cursor not on a slice edge!", vim.log.levels.ERROR)
    return
  end
  M.cmd.push_slice(section, edge, value)
end

---每个区间的左右边界，会随着每次音频播放、整轴/区间轴的全屏而随机变化，所以想要在编辑器修改边界，需要先
---fetch 一下最新边界、保持音频暂停不要播放、然后才能修改再发送到浏览器。
---fetch 到的边界数据会从 Python 发给 _H.receive_slice() 处理。
M.cmd.fetch_slice = function()
  vim.fn["BiteSendData"] { action = "fetch_slice", callback = "callback_receive_slice" }
end

_H.callback_dict2buf = function(data, buf)
  if buf == nil then buf = 0 end
  local subsections = {
    "人工英文转写结果",
    "人工英文断句结果",
    "人工同传中文结果",
    "人工同传中文断句结果",
    "人工英文顺滑结果",
    "人工英文顺滑断句结果",
  }

  local lines = {}
  ---@type string[]
  local sections = vim.fn.sort(vim.tbl_keys(data), "N")
  for _, section in ipairs(sections) do
    table.insert(lines, string.format("# %s", section))
    table.insert(lines, "")
    table.insert(lines, string.format("[start] %s", data[section]["start"]))
    table.insert(lines, string.format("[end] %s", data[section]["end"]))
    table.insert(lines, "")
    for _, subsection in ipairs(subsections) do
      table.insert(lines, string.format("## %s", subsection))
      table.insert(lines, "")
      table.insert(lines, data[section][subsection])
      table.insert(lines, "")
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

---@param data table
_H.callback_receive_slice = function(data)
  local section_subsection_line = _H.buf2dict "0"
  local new = vim.tbl_deep_extend("force", section_subsection_line, data)
  _H.callback_dict2buf(new)
end

M.cmd.fetch_progress = function()
  vim.fn["BiteSendData"] { action = "fetch_progress", callback = "callback_receive_progress" }
end

_H.callback_receive_progress = function(data)
  local n = _H.get_curr_section_nr()
  if n == nil then return end
  ---@type number
  local _edge = vim.fn.confirm("Apply " .. data.x .. " to which edge?", "&Start\n&End\n&Cancel")
  local edge
  if _edge == 1 then edge = "start" elseif _edge == 2 then edge = "end" else return end
  M.cmd.push_slice(n, edge, data.x)
  M.cmd.fetch_slice()
end

M.cmd.fetch_content = function()
  vim.fn["BiteSendData"] { action = "fetch_content", callback = "callback_dict2buf" }
end

M.cmd.speed = function(offset)
  vim.fn["BiteSendData"] { action = "speed", offset = offset }
end

M.cmd.diff_content = function()
  vim.fn["BiteSendData"] { action = "fetch_content", callback = "callback_diff_content" }
end

_H.callback_diff_content = function(remote)
  vim.cmd [[exe 'normal! <c-w>o' | topleft vsplit]]
  local buf_remote = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf_remote, "浏览器")
  vim.bo[buf_remote].bufhidden = "wipe"
  vim.bo[buf_remote].buftype = "nowrite"
  vim.api.nvim_set_current_buf(buf_remote)
  _H.callback_dict2buf(remote, buf_remote)
  vim.cmd [[windo diffthis]]
end

_H.callback = function(data)
  local func = _H[data.callback]
  if func == nil then
    vim.notify("找不到回调函数: " .. data.callback, vim.log.levels.ERROR)
    return
  end
  data.callback = nil
  func(data)
end

local opt = { buffer = true, nowait = true, noremap = true }
M.config = {
  keymaps = {
    { "n", "<bar>", M.append_plain_sep, opt },
    { "n", "<c-bar>", M.append_switch_sep, opt },
    { "n", "<c-n>", M.new_section, opt },
    { "n", "{", M.prev_subsection, opt },
    { "n", "}", M.next_subsection, opt },
    { "n", "[[", M.prev_section, opt },
    { "n", "]]", M.next_section, opt },
    { "n", "<c-t>", M.diff_orig_smth, opt },
    { "n", "gp", M.cmd.play, opt },
    { "n", "<space>", M.cmd.toggle, opt },
    { "n", "<left>", M.cmd.back, opt },
    { "n", "gI", M.cmd.init_transcripts, opt },
    { "n", "<c-s-h>", vim.fn["BiteToggleServer"], opt },
    { "n", "g<enter>", _H.push_currline_slice, opt },
    { "n", "<leader><enter>", M.cmd.fetch_slice, opt },
    { "n", "<up>", function() M.cmd.speed(1) end, opt },
    { "n", "<down>", function() M.cmd.speed(-1) end, opt },
    { "n", "[b", function() vim.fn.search([[【\?｜】\?]], "b") end, opt },
    { "n", "]b", function() vim.fn.search [[【\?｜】\?]] end, opt },
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
