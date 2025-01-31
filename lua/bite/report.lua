#!/usr/bin/env lua

local _H = {}
local M = { _H = _H }

---@param s string
---@param rules table
_H.report_helper = function(s, rules)
  local ret = {}
  for _, pat_msg in ipairs(rules) do
    pat, msg = unpack(pat_msg)
    m = vim.fn.matchstr(s, pat)
    if m ~= "" then table.insert(ret, string.format("%s：“%s”", msg, m)) end
  end
  return ret
end

---@param s string
---@return string[]
_H.common = function(s)
  return _H.report_helper(s,
    {
      { [[\v^\s+%(\S+)]], "行首空格" },
    }
  )
end

---@param s string
---@return string[]
_H.zh_ungrouped = function(s)
  return _H.report_helper(s,
    {
      { [[\v\S{,5}｜\S{,5}]], "非断句但出现 sep 符号" },
    }
  )
end

---@param s string
---@return string[]
_H.en_ungrouped = function(s)
  return _H.report_helper(s,
    {
      { [[\v\S*｜\S*]], "非断句但出现 sep 符号" },
    }
  )
end

---@param s string
---@return string[]
_H.cmn_grouped = function(s)
  local ret = {}
  if vim.fn.match(s, "｜") == -1 then table.insert(ret, "无 sep 符号，未划分意群") end
  return ret
end

---@param s string
---@return string[]
_H.zh_grouped = function(s)
  return _H.report_helper(s, {
    { "\\v\\S{1,5}%([，。？！：”’—…]【?｜】?)@<=[[:blank:]]\\S{1,5}", "中文里 sep 符号两侧应无空格" },
    { [[\v\S{1,5}[…。!！?？]+[”"’'）)】]*\s*$]], "行尾是意群结尾时也应加 sep" },
    { [[\v\S{1,5}【?丨】?\S{1,5}]], "sep 符号错误，竖杠应为｜，unicode 编码 ff5c" },
    { "\\v\\S{1,5}[[:blank:]]%(【?｜】?)", "中文里 sep 符号两侧应无空格" },
    { "\\v^\\s*【?｜】?\\s*\\S{1,5}", "行首 sep 符号应放在上一区间行尾" },
  })
end

---@param s string
---@return string[]
_H.en_grouped = function(s)
  return _H.report_helper(s, {
    { "\\v%([[:punct:][:alnum:]]【?｜】?)[[:alnum:]]+", "英文里 sep 符号左边需无空格，右边需有一个空格" },
    { [[\v\S+\s+%(%(%(<al)@<!%(\u\l{,2})@<!(\.\a)@<!\.|[!?])+['’"”]?)\s*$]], "行尾是意群结尾时也应加 sep" },
    { [[\v\S+【?丨】?\s*\S+]], "sep 符号错误，竖杠应为｜，unicode 编码 ff5c" },
    { "\\v\\S+[[:blank:]]%(【?｜】?)", "英文里 sep 符号左边需无空格，右边需有一个空格" },
    { "\\v^\\s*【?｜】?\\s*\\S+", "行首 sep 符号应放在上一区间行尾" },
  })
end

---@param s string
---@return string[]
_H.en_smoothed = function(s)
  return _H.report_helper(s, {
    {
      "\\v\\S+\\s+<%(ah|aha|ahem|ahh|ahhh|alas|argh|aw|aya|eeek|eek|eh|er|ew|eww|ey|gee|geez|god|gosh|ha|ha|ha|ha|ha|ha|hah|hey|hm|hmm|hmmm|hmmmm|hoo|hoorah|hooray|huh|hurrah|hurray|jah|jeez|muah|mwa|mwah|nah|no|oh|ooh|oooops|ooops|oops|ouch|ow|phew|sh|sheesh|shh|shir|shoo|ugh|uh|uh-huh|uhm|um|umm|%(as )@<!well|whoa|whoo|wow|ya|yahoo|ye|yeah|yo|yoo|yoo-hoo|yuck|%(do )@<!you know%( it)@!|ok|okay|I mean)>\\s*\\S+\\C",
      "顺滑出现语气词" },
    -- {
    --   "\\v<%(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred%(s)@!|thousand%(s)@!)\\C",
    --   "英文数字考虑顺滑为阿拉伯数字"
    -- },
    { "\\v<%(gonna|cuz|cause)>\\C", "缩约形式未展开" },
    { "\\(\\<\\w\\+\\>\\)\\_s*\\<\\1\\>", "连续重复词需去重" },
  })
end

---@param s string
---@return string[]
_H.en_orig = function(s)
  return _H.report_helper(s, {
    { "\\v\\S+\\s+[0-9]+\\s*\\S+", "忠实版数字应采用英文形式" },
  })
end

_H.cmn_en = function(s)
  return _H.report_helper(s,
    {
      { [[\v\S+  %(\S+)?]], "连续空格" },
      { "\\v\\([^)]+\\)", "疑似笑声" },
    }
  )
end

_H.cmn_zh = function(s)
  return _H.report_helper(s,
    {
      { [[\v\S{1,5}  \S{,5}]], "连续空格" },
      { "\\v[^ [:alnum:][:punct:]｜【】《》，。？！、：“”‘’—…]{1,5}[[:alnum:]]+",
        "汉字右边是数字字母时要加空格" },
      { "\\v[[:alnum:]]+[^ [:alnum:][:punct:]｜【】《》，。？！、：“”‘’—…]{1,5}",
        "汉字左边是数字字母时要加空格" },
      { "[^ [:alnum:][:punct:]｜【】《》，。？！、：“”‘’—…] [^ [:alnum:][:punct:]｜【】《》，。？！、：“”‘’—…]",
        "汉字之间无需空格" },
      { [[\v[零一二三四五六七八九十]{4}年]],
        "完整年份须用阿拉伯数字" },
      { [[\v%(^|[^0-9])[0-9]{1,2}%(年代?|世纪)]],
        "缩写年份须用汉字" },
      { [[\v%(星期|周)\s*\d]],
        "星期几、周几须用汉字" },
      { [[\v%([甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]年)?\s*\d+\s*月]],
        "天干地支年份须用汉字，如丙寅年十月十五日" },
      { [[\v腊月\s*\d+\s*%(日|号)]],
        "农历须用汉字，如腊月二十三日" },
      { [[\v正月初?\s*\d+\s*%(日|号)?]],
        "农历须用汉字，如腊月二十三日" },
      { [[\v\d+\s*[时点][零一二三四五六七八九十0-9 ]+分?|\d+\s*分[零一二三四五六七八九十0-9 ]+秒?|分\s*\d+\s*秒]],
        "时间点、时间段须用汉字，如三点四十，二十六分四十二秒" },
      {
        "\\v[（(][^)]+[）)]",
        "增补无需括号" }
    }
  )
end

---@param s string
---@param funcs function[]
---@return string[]
_H.report = function(s, funcs)
  local ret = {}
  for _, func in ipairs(funcs) do
    vim.list_extend(ret, func(s))
  end
  return ret
end

_H["人工英文断句结果"] = function(s)
  return _H.report(s, { _H.common, _H.cmn_en, _H.en_grouped, _H.en_orig })
end
_H["人工英文顺滑断句结果"] = function(s)
  return _H.report(s, { _H.common, _H.cmn_en, _H.en_grouped, _H.en_smoothed, })
end
_H["人工同传中文断句结果"] = function(s)
  return _H.report(s, { _H.common, _H.cmn_zh, _H.zh_grouped, })
end
---@param s string
_H["人工英文转写结果"] = function(s)
  return _H.report(s, { _H.common, _H.cmn_en, _H.en_ungrouped, _H.en_orig })
end
_H["人工同传中文结果"] = function(s)
  return _H.report(s, { _H.common, _H.cmn_zh, _H.zh_ungrouped, })
end
_H["人工英文顺滑结果"] = function(s)
  return _H.report(s, { _H.common, _H.cmn_en, _H.en_ungrouped, _H.en_smoothed })
end

M.cmpr_zh_grp_ungrpd = function(grpd, ungrpd)
  local ret = {}
  grpd = vim.fn.substitute(grpd, "\\v【?｜】?", "", "g")
  ungrpd = vim.fn.substitute(ungrpd, "\\v【?｜】?", "", "g")
  local words1 = vim.fn.split(grpd, "\\zs")
  local words2 = vim.fn.split(ungrpd, "\\zs")
  local max_len = math.max(#words1, #words2)

  for i = 1, max_len do
    if words1[i] ~= words2[i] then
      local s = math.max(i - 2, 1)
      table.insert(ret, string.format("断句前后不一致，中文为“%s”，中文断句为“%s”",
        vim.fn.join(vim.list_slice(words1, s, math.min(i + 2, #words1)), ""),
        vim.fn.join(vim.list_slice(words2, s, math.min(i + 2, #words2)), "")))
      break
    end
  end
  return ret
end

M.cmpr_en_grp_ungrpd = function(grpd, ungrpd)
  local ret = {}
  grpd = vim.fn.substitute(grpd, "\\v\\s*【?｜】?\\s*", " ", "g")
  ungrpd = vim.fn.substitute(ungrpd, "\\v\\s*【?｜】?\\s*", " ", "g")
  local words1 = vim.fn.split(grpd, " ")
  local words2 = vim.fn.split(ungrpd, " ")
  local max_len = math.max(#words1, #words2)

  for i = 1, max_len do
    if words1[i] ~= words2[i] then
      local s = math.max(i - 2, 1)
      table.insert(ret, string.format("断句前后不一致，英文转写为“%s”，英文断句为“%s”",
        vim.fn.join(vim.list_slice(words1, s, math.min(i + 2, #words1))),
        vim.fn.join(vim.list_slice(words2, s, math.min(i + 2, #words2)))))
      break
    end
  end
  return ret
end

M.report = function(d)
  local ret = {}
  local ret_section, ret_subsection, heading_section, sep_orig, sep_orig_switch, sep_smooth, sep_smooth_switch, sep_zh, sep_zh_switch
  for _, section in ipairs(vim.fn.sort(vim.tbl_keys(d), "N")) do
    ret_section = {}
    subsection_line = d[section]
    for subsection, line in pairs(subsection_line) do
      ret_subsection = {}
      repeat
        if line:match "^%s*$" then break end
        if _H[subsection] == nil then break end
        vim.list_extend(ret_subsection, _H[subsection](line))
      until true

      if next(ret_subsection) ~= nil then
        table.insert(ret_section, string.format("## %s", subsection))
        vim.list_extend(ret_section, ret_subsection)
      end
    end
    -- 检查断句前后是否一致
    vim.list_extend(ret_section, M.cmpr_en_grp_ungrpd(subsection_line["人工英文断句结果"],
      subsection_line["人工英文转写结果"]))
    vim.list_extend(ret_section, M.cmpr_zh_grp_ungrpd(subsection_line["人工同传中文断句结果"],
      subsection_line["人工同传中文结果"]))

    -- 比较断句轮换 sep 数量是否一致
    sep_orig_switch = vim.fn.count(subsection_line["人工英文断句结果"], "【｜】")
    sep_smooth_switch = vim.fn.count(subsection_line["人工英文顺滑断句结果"], "【｜】")
    sep_zh_switch = vim.fn.count(subsection_line["人工同传中文断句结果"], "【｜】")
    if sep_orig_switch ~= sep_smooth_switch or sep_smooth_switch ~= sep_zh_switch then
      table.insert(ret_section, string.format("【｜】数量不一致：英文断句%d，顺滑断句%d，中文断句%d",
        sep_orig_switch, sep_smooth_switch, sep_zh_switch))
    end
    -- 比较断句普通 sep 数量是否一致
    sep_orig = vim.fn.count(subsection_line["人工英文断句结果"], "｜") - sep_orig_switch
    sep_smooth = vim.fn.count(subsection_line["人工英文顺滑断句结果"], "｜") - sep_smooth_switch
    sep_zh = vim.fn.count(subsection_line["人工同传中文断句结果"], "｜") - sep_zh_switch
    if sep_orig ~= sep_smooth or sep_smooth ~= sep_zh then
      table.insert(ret_section, string.format("｜数量不一致：英文断句%d，顺滑断句%d，中文断句%d",
        sep_orig, sep_smooth, sep_zh))
    end

    if next(ret_section) ~= nil then
      heading_section = string.format("# 第 %d 小条", section)
      if #vim.tbl_filter(function(s) return not s:match "^## " end, ret_section) >= 3 then
        heading_section = string.format("%s (规则失误大于3个，不合格)", heading_section)
      end
      table.insert(ret, heading_section)

      vim.list_extend(ret, ret_section)
    end
  end
  return ret
end

return M
