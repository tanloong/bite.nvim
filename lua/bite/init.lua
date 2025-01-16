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

_H.append_plain_sep = function()
  vim.api.nvim_put({ "｜" }, "c", true, true)
end

---如果光标在｜上，则在其两侧添加【】，如果不在｜上，在光标右侧插入【｜】
_H.append_switch_sep = function()
  ---Accepts pos args given by nvim_win_get_cursor(), used by _H.append_switch_sep()
  ---@param row integer 1-based
  ---@param col integer 0-based
  local get_char_right_of_pos = function(row, col)
    -- 获取当前行的内容
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    -- 将字节索引转换为 UTF-8 字符索引
    local char_idx = vim.str_utfindex(line, col)
    -- 获取光标右侧的第一个字符
    local next_char = vim.fn.strcharpart(line, char_idx, 1)
    -- 如果光标已经在行尾时 next_char 会是 ""
    return next_char
  end

  -- row is 1-based
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.print(get_char_right_of_pos(row, col))
  if get_char_right_of_pos(row, col) ~= "｜" then
    vim.api.nvim_put({ "【｜】" }, "c", true, true)
  else
    vim.api.nvim_put({ "【" }, "c", false, true)
    vim.api.nvim_put({ "】" }, "c", true, true)
  end
end

_H.prev_subsection = function()
  vim.fn.search("^## ", "bW")
  vim.fn.search("^[^#[]", "bW")
end
_H.next_subsection = function()
  vim.fn.search("^## ", "W")
  vim.fn.search("^[^#[]", "W")
end
_H.prev_section = function()
  vim.fn.search("^# ", "bW")
end

_H.next_section = function()
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
---@param lines1 string[]
---@param lines2 string[]
---@param bufname1 string
---@param bufname2 string
_H.diff_lines = function(lines1, lines2, bufname1, bufname2)
  vim.cmd [[belowright split]]
  local buf1 = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf1, bufname1)
  vim.bo[buf1].bufhidden = "wipe"
  vim.bo[buf1].buftype = "nowrite"
  vim.api.nvim_buf_set_lines(buf1, 0, -1, true, lines1)
  vim.api.nvim_set_current_buf(buf1)
  vim.cmd [[diffthis]]

  vim.cmd [[belowright vsplit]]
  local buf2 = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf2, bufname2)
  vim.bo[buf2].bufhidden = "wipe"
  vim.bo[buf2].buftype = "nowrite"
  vim.api.nvim_buf_set_lines(buf2, 0, -1, true, lines2)
  vim.api.nvim_set_current_buf(buf2)
  vim.cmd [[diffthis]]
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

---@return string|nil
_H.get_curr_subsection_name = function()
  local subsection_lineno = vim.fn.search("^## ", "cbWn")
  local section_lineno = vim.fn.search("^# ", "cbWn")
  if subsection_lineno == 0 or section_lineno > subsection_lineno then
    vim.notify("Not in a subsection!", vim.log.levels.ERROR)
    return
  end
  return vim.fn.getline(subsection_lineno):match "^## (%S+)"
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
    "人工英文顺滑断句结果",
    "人工同传中文断句结果",
    "人工英文顺滑结果",
    "人工同传中文结果",
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

M.cmd.diff_browser = function()
  vim.fn["BiteSendData"] { action = "fetch_content", callback = "callback_diff_browser" }
  vim.fn["BiteSendData"] { action = "fetch_content", callback = "callback_diff_browser" }
end

_H.callback_diff_browser = function(remote)
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
  if func == nil then func = M.cmd[data.callback] end
  if func == nil then
    vim.notify("找不到回调函数: " .. data.callback, vim.log.levels.ERROR)
    return
  end
  data.callback = nil
  func(data)
end

---@param section string
---@param subsection string|nil
_H.jump_to = function(section, subsection)
  vim.fn.search(string.format("^# %s$", section), "cw")
  if subsection ~= nil then
    vim.fn.search(string.format("^## %s$", subsection), "cW")
  end
end

---新建一个不可编辑的 split window，显示在界面下放，高度与 cmdwin 一致
---@param lines string[]
---@param sort boolean
---@param splitcmd string
---@return integer, integer
_H.create_scratch = function(lines, sort, splitcmd)
  if splitcmd == nil then splitcmd = "botright split" end
  vim.cmd(string.format([[%s | setlocal winfixheight | resize %d]], splitcmd, vim.o.cmdwinheight))
  local bufnr = vim.api.nvim_create_buf(true, true)
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_name(bufnr, "bite://" .. tostring(bufnr))
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "nowrite"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  if sort then
    vim.fn.win_execute(winnr, "sort n", true)
  end
  vim.bo[bufnr].modifiable = false

  return bufnr, winnr
end

local lt
M.cmd.lint = function()
  lt = lt or require "bite.lint"

  local dict = _H.buf2dict "0"
  if dict == nil then return end

  local errors = lt.lint(dict)
  if next(errors) == nil then
    vim.notify("Pass!", vim.log.levels.INFO); return
  end

  local origwinid = vim.api.nvim_get_current_win()
  _H.create_scratch(errors, true)

  local jump = function()
    local line = vim.api.nvim_get_current_line()
    local section = line:match [[^([^:]+)]]
    local subsection = line:match [[^[^:]+:([^:]+)]]
    vim.api.nvim_set_current_win(origwinid)
    _H.jump_to(section, subsection)
  end

  vim.keymap.set("n", "<enter>", jump, { silent = true, buffer = true, nowait = true, noremap = true })
end

M.cmd.outline = function()
  if M._outline_winid ~= nil then
    vim.api.nvim_set_current_win(M._outline_winid)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local sections = {}
  local n
  for _, line in ipairs(lines) do
    n = line:match "^# (%d+)"
    if n ~= nil then
      table.insert(sections, n)
    end
  end

  local origwinid = vim.api.nvim_get_current_win()
  local cursection = _H.get_curr_section_nr()
  local bufnr, winid = _H.create_scratch(sections)
  M._outline_winid = winid
  if cursection ~= nil then vim.fn.search(string.format("^%s$", cursection)) end

  local jump = function()
    local section = vim.api.nvim_get_current_line()
    vim.api.nvim_set_current_win(origwinid)
    _H.jump_to(section)
  end

  autocmd("BufUnload",
    {
      buffer = bufnr,
      group = augroup("bite", { clear = true }),
      callback = function() M._outline_winid = nil end,
    })

  vim.keymap.set("n", "<enter>", jump,
    { silent = true, buffer = true, nowait = true, noremap = true })
end

---1. 在“人工英文转写结果”添加语气词等和sep，将光标移动到“人工英文断句结果”，执行此函数会引用转写内容并删除转写中的sep
---2. 光标移动到“人工英文顺滑断句结果”，执行此函数会引用“人工英文断句结果”
---3. 编辑好“人工同传中文断句结果”
---4. 光标移动到“人工英文顺滑结果”，执行此函数会引用“人工英文顺滑断句结果”并删除其中的sep
---5. 光标移动到“人工同传中文结果”，执行此函数会引用“人工同传中文断句结果”并删除其中的sep
---6. 4、5两条可不手动操作，执行B lint时如果两个subsection为空则执行引用
M.cmd.reference = function()
  local n = _H.get_curr_section_nr()
  if n == nil then return end
  local name = _H.get_curr_subsection_name()
  if name == nil then return end
  local dict = _H.buf2dict "0"
  if dict == nil then return end

  if name == "人工英文断句结果" then
    dict[n][name] = dict[n]["人工英文转写结果"]
    dict[n]["人工英文转写结果"] = vim.fn.substitute(dict[n]["人工英文转写结果"], "\\v【?｜】?", "",
      "g")
  elseif name == "人工英文顺滑断句结果" then
    dict[n][name] = dict[n]["人工英文断句结果"]
  elseif name == "人工英文顺滑结果" then
    dict[n][name] = vim.fn.substitute(dict[n]["人工英文顺滑断句结果"], "\\v【?｜】?", "", "g")
  elseif name == "人工同传中文结果" then
    dict[n][name] = vim.fn.substitute(dict[n]["人工同传中文断句结果"], "\\v【?｜】?", "", "g")
  else
    vim.notify("Invalid subsection name: " .. name, vim.log.levels.ERROR)
    return
  end

  _H.callback_dict2buf(dict)
end

---@param dict table
---@param subsections string[]
---@return table
_H.filter_dict_subsection = function(dict, subsections)
  local ret = vim.deepcopy(dict)
  for _, subsection_line in pairs(ret) do
    for _subsection, _ in pairs(subsection_line) do
      if not vim.list_contains(subsections, _subsection) then
        subsection_line[_subsection] = nil
      end
    end
  end
  return ret
end

_H.diff_dicts = function(dict1, dict2, bufname1, bufname2)
  ---@type string[]
  local sections = vim.fn.sort(vim.tbl_keys(dict1), "N")
  local lines1 = {}
  local lines2 = {}
  for _, section in ipairs(sections) do
    table.insert(lines1, string.format("# %s", section))
    for _, subsection in ipairs(vim.fn.sort(vim.tbl_keys(dict1[section]))) do
      -- table.insert(lines1, string.format("## %s", subsection))
      table.insert(lines1, string.format(dict1[section][subsection]))
    end
    table.insert(lines2, string.format("# %s", section))
    for _, subsection in ipairs(vim.fn.sort(vim.tbl_keys(dict2[section]))) do
      -- table.insert(lines2, string.format("## %s", subsection))
      table.insert(lines2, string.format(dict2[section][subsection]))
    end
  end

  _H.diff_lines(lines1, lines2, bufname1, bufname2)
end

M.cmd.diff_smooth = function()
  local dict = _H.buf2dict "0"
  if dict == nil then return end
  local dict_unsmthed = _H.filter_dict_subsection(dict, { "人工英文转写结果" })
  local dict_smthed = _H.filter_dict_subsection(dict, { "人工英文顺滑结果" })

  _H.diff_dicts(dict_unsmthed, dict_smthed, "未顺滑", "顺滑")
end

M.cmd.diff_group = function()
  local dict = _H.buf2dict "0"
  if dict == nil then return end
  local dict_ungrped = _H.filter_dict_subsection(dict, { "人工英文转写结果", "人工英文顺滑结果",
    "人工同传中文结果" })
  local dict_grped = _H.filter_dict_subsection(dict, { "人工英文断句结果", "人工英文顺滑断句结果",
    "人工同传中文断句结果" })
  _H.diff_dicts(dict_ungrped, dict_grped, "未断句", "断句")
end

local opt = { buffer = true, nowait = true, noremap = true }
M.config = {
  keymaps = {
    { "n", "<bar>", _H.append_plain_sep, opt },
    { "n", "<c-bar>", _H.append_switch_sep, opt },
    { "n", "{", _H.prev_subsection, opt },
    { "n", "}", _H.next_subsection, opt },
    { "n", "[[", _H.prev_section, opt },
    { "n", "]]", _H.next_section, opt },
    { "n", "<c-t>", M.cmd.diff_smooth, opt },
    { "n", "<enter>", M.cmd.play, opt },
    { "n", "<space>", M.cmd.toggle, opt },
    { "n", "<left>", M.cmd.back, opt },
    { "n", "gI", M.cmd.init_transcripts, opt },
    { "n", "<c-s-h>", vim.fn["BiteToggleServer"], opt },
    { "n", "<s-enter>", _H.push_currline_slice, opt },
    { "n", "<leader><enter>", M.cmd.fetch_slice, opt },
    { "n", "<up>", function() M.cmd.speed(1) end, opt },
    { "n", "<down>", function() M.cmd.speed(-1) end, opt },
    { "n", "[b", function() vim.fn.search([[【\?｜】\?]], "b") end, opt },
    { "n", "]b", function() vim.fn.search [[【\?｜】\?]] end, opt },
    { "n", "gO", M.cmd.outline, opt },
    { "n", "gp", M.cmd.reference, opt },
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
    local cmds = vim.tbl_keys(M.cmd)
    if not prefix then
      return cmds
    else
      return vim.fn.matchfuzzy(cmds, prefix)
    end
  end,
  nargs = "*"
})

return M
