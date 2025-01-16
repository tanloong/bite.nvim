#!/usr/bin/env lua

-- TODO: 检查非断句不能有sep，断句不能没有sep

local _H = {}
local M = {
  _H = _H,
}

---@param s string
---@param rules table
_H.lint_helper = function(s, rules)
  local ret = {}
  for _, pat_msg in ipairs(rules) do
    pat, msg = unpack(pat_msg)
    m = vim.fn.matchstr(s, pat)
    if m ~= "" then table.insert(ret, string.format("%s\t%s", msg, m)) end
  end
  return ret
end

---@param s string
---@return string[]
_H.common = function(s)
  return _H.lint_helper(s,
    {
      { [[  ]], "连续多个空格" },
      { [[\v^\s]], "行首空格" },
    }
  )
end

---@param s string
---@return string[]
_H.cmn_ungrouped = function(s)
  return _H.lint_helper(s,
    {
      { [[｜]], "非断句出现'｜'" },
    }
  )
end

---@param s string
---@return string[]
_H.cmn_grouped = function(s)
  local ret = _H.lint_helper(s, {
    { [[\v【?丨】?]], "sep 符号错误" },
    { "\\v[[:blank:]]%(【?｜】?)@=", "sep 符号左边有空白字符" },
    { "\\v^\\s*【?｜】?", "行首 sep 符号应放在上一区间行尾" },
  })
  if vim.fn.match(s, "｜") == -1 then table.insert(ret, "断句无'｜'") end
  return ret
end

---@param s string
---@return string[]
_H.zh_grouped = function(s)
  return _H.lint_helper(s, {
    { "\\v%([，。？！：”’—…]【?｜】?)@<=[[:blank:]]", "中文 sep 符号右边不能有空格" },
  })
end

---@param s string
---@return string[]
_H.en_grouped = function(s)
  return _H.lint_helper(s, {
    { "\\v%([[:punct:][:alnum:]]【?｜】?)@<=[[:alnum:]]", "英文 sep 符号右边缺空格" },
  })
end

---@param s string
---@return string[]
_H.en_smoothed = function(s)
  return _H.lint_helper(s, {
    {
      "\\v<%(ah|aha|ahem|ahh|ahhh|alas|argh|aw|aya|eeek|eek|eh|er|ew|eww|ey|gee|geez|god|gosh|ha|ha|ha|ha|ha|ha|hah|hey|hm|hmm|hmmm|hmmmm|hoo|hoorah|hooray|huh|hurrah|hurray|jah|jeez|muah|mwa|mwah|nah|no|oh|ooh|oooops|ooops|oops|ouch|ow|phew|sh|sheesh|shh|shir|shoo|ugh|uh|uh-huh|uhm|um|umm|well|whoa|whoo|wow|ya|yahoo|ye|yeah|yo|yoo|yoo-hoo|yuck|you know|ok|okay)>\\C",
      "顺滑出现语气词" },
    {
      "\\v<%(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|billion|trillion)\\C",
      "英文数字考虑顺滑为阿拉伯数字"
    }
  })
end

---@param s string
---@return string[]
_H.en_orig = function(s)
  return _H.lint_helper(s, {
    {
      "\\v[0-9]+",
      "转写的数字应采用英文形式" }
  })
end

---@param s string
---@return string[]
_H.cmn_en = function(s)
  return _H.lint_helper(s, {
    {
      "\\v\\([^)]+\\)",
      "疑似笑声" }
  })
end

---@param s string
---@return string[]
_H.cmn_zh = function(s) -- {{{
  return _H.lint_helper(s, {
    -- 中文与数字、字母之间要有空格
    { "\\v[^ [:alnum:][:punct:]｜【】《》，。？！：“”‘’—…][[:alnum:]]",
      "中文右边是数字、字母时要加空格" },
    { "\\v[[:alnum:]][^ [:alnum:][:punct:]｜【】《》，。！？：“”‘’—…]",
      "中文左边是数字、字母时要加空格" },
    -- 完整年份、月、日用阿拉伯数字，如 2015 年、1 月 1 日
    { [[\v[零一二三四五六七八九十]{4}年]],
      "完整年份须用阿拉伯数字" },
    -- 缩写年份、xx世纪、xx年代用汉字，如二十世纪八十年代、一七年。
    { [[\v%(^|[^0-9])[0-9]{1,2}%(年代?|世纪)]],
      "缩写年份须用汉字" },
    -- 星期几、周几用汉字，如星期三、周二
    { [[\v%(星期|周)\s*\d]],
      "星期几、周几须用汉字" },
    -- 农历用汉字，如丙寅年十月十五日、腊月二十三日、正月初五、八月十五中秋节
    { [[\v%([甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]年)?\s*\d+\s*月]],
      "天干地支年份须用汉字，如丙寅年十月十五日" },
    { [[\v腊月\s*\d+\s*%(日|号)]],
      "农历须用汉字，如腊月二十三日" },
    { [[\v正月初?\s*\d+\s*%(日|号)?]],
      "农历须用汉字，如腊月二十三日" },
    -- 时间点、时间段用汉字，如三点四十、二十六分四十二秒
    { [[\v\d+\s*[时点][零一二三四五六七八九十0-9 ]+分?|\d+\s*分[零一二三四五六七八九十0-9 ]+秒?|分\s*\d+\s*秒]],
      "时间点、时间段须用汉字，如三点四十，二十六分四十二秒" },
    {
      "\\v[（(][^)]+[）)]",
      "增补无需括号" }
  })
end -- }}}

--- TODO: 区间末尾是句子边界时要有分隔符，｜或【｜】
--- TODO: 英文区间末不是句子边界时要有空格，中文区间末非句子边界时不能有空格
---@param s string
M.check_slice_ending = function(s)
  return s:match "[。！？”’｜】]$"
end

-- local ok, msg
--
-- for _, s_ret in ipairs {
--   { "二零二五年", false },
--   { "18年", false },
--   { "20 世纪", false },
--   { "80  年代", false },
--   { "星期3", false },
--   { "周 4", false },
--   { "星期三", true },
--   { "周四", true },
--   { "子丑年 12月1 日", false },
--   { "几年前", true },
--   { "腊月 23日", false },
--   { "正月12 号", false },
--   { "正月初 5", false },
--   { "3点 40", false },
--   { "3时 40分", false },
--   { "3时四十分", false },
--   { "四十分19 秒", false },
--   { "word  word", false },
--   { "中文word", false },
--   { "word中文", false },
--   { "中文11", false },
--   { "11中文", false },
--   { "，11", true },
--   { "11。", true },
--   { "丨", false }, -- 4e28
--   { "【丨】", false }, -- 4e28
--   { " 丨", false }, -- 4e28
--   { " 【丨】", false }, -- 4e28
--   { "｜word", false }, -- ff5c
--   { "【｜】word", false }, -- ff5c
--   { "，｜ ", false }, -- ff5c
--   { "，【｜】 ", false }, -- ff5c
-- } do
--   ok, msg = check_number(s_ret[1])
--   if ok ~= s_ret[2] then
--     vim.print "--------------------------------------------------------------------------------"
--     vim.print(s_ret[1], ok, s_ret[2], msg)
--   end
-- end

---@param s string
---@param funcs function[]
---@return string[]
_H.lint = function(s, funcs)
  local ret = {}
  for _, func in ipairs(funcs) do
    vim.list_extend(ret, func(s))
  end
  return ret
end

---@param s string
_H["人工英文转写结果"] = function(s)
  return _H.lint(s, { _H.common, _H.cmn_ungrouped, _H.cmn_en, _H.en_orig })
end

_H["人工英文断句结果"] = function(s)
  return _H.lint(s, { _H.common, _H.cmn_grouped, _H.cmn_en, _H.en_grouped, _H.en_orig })
end

_H["人工同传中文结果"] = function(s)
  return _H.lint(s, { _H.common, _H.cmn_ungrouped, _H.cmn_zh })
end

_H["人工同传中文断句结果"] = function(s)
  return _H.lint(s, { _H.common, _H.cmn_grouped, _H.cmn_zh, _H.zh_grouped })
end

_H["人工英文顺滑结果"] = function(s)
  return _H.lint(s, { _H.common, _H.cmn_ungrouped, _H.cmn_en, _H.en_smoothed })
end
_H["人工英文顺滑断句结果"] = function(s)
  return _H.lint(s, { _H.common, _H.cmn_grouped, _H.cmn_en, _H.en_grouped, _H.en_smoothed })
end

---@return boolean, string|nil
_H.cmpr_ungrpd_grpd = function(ungrpd, grpd)
  grpd = vim.fn.substitute(grpd, "\\v【?｜】?", "", "g")

  if grpd ~= ungrpd then
    return false, "断句前后文本不一致"
  else
    return true, nil
  end
end

---@param dict table
---@return string[]
M.lint = function(dict)
  local grpd_ungrpd = {
    ["人工英文断句结果"] = "人工英文转写结果",
    ["人工同传中文断句结果"] = "人工同传中文结果",
    ["人工英文顺滑断句结果"] = "人工英文顺滑结果"
  }
  local ret = {}
  local ok, msg

  for section, subsection_line in pairs(dict) do
    for subsection, line in pairs(subsection_line) do
      repeat
        if line:match "^%s*$" then break end
        if _H[subsection] == nil then break end
        for _, _msg in ipairs(_H[subsection](line)) do
          table.insert(ret, string.format("%s:%s:\t%s", section, subsection, _msg))
        end
        -- 断句前后文本需一致
        if subsection:match "断句" then
          ok, msg = _H.cmpr_ungrpd_grpd(subsection_line[grpd_ungrpd[subsection]], line)
          if not ok then
            table.insert(ret, string.format("%s:%s:\t%s", section, subsection, msg))
          end
        end
      until true
    end
  end

  return ret
end

return M
