#!/usr/bin/env lua


local M = {}
---区间末尾是句子边界时要加分隔符
---@param s string
M.check_slice_ending = function(s)
  return s:match "[。！？”’｜】]$"
end

---@param s string
local check_number = function(s)
  -- 中文与数字、字母之间要有空格
  if vim.fn.match(s, "\\v[^ [:alnum:][:punct:]，。？！：“”‘’—…][[:alnum:]]") >= 0 then
    return false, "中文右边是数字、字母时要加空格"
  end
  if vim.fn.match(s, "\\v[[:alnum:]][^ [:alnum:][:punct:]，。！？：“”‘’—…]") >= 0 then
    return false, "中文左边是数字、字母时要加空格"
  end
  if vim.fn.match(s, "  ") >= 0 then
    return false, "连续多个空格"
  end

  -- sep 符号
  if vim.fn.match(s, [[\v【?丨】?]]) >= 0 then
    return false, "sep 符号错误"
  end
  if vim.fn.match(s, "\\v[[:blank:]]%(【?｜】?)@=") >= 0 then
    return false, "sep 符号左边有空白字符"
  end
  if vim.fn.match(s, "\\v%([[:punct:][:alnum:]]【?｜】?)@<=[[:alnum:]]") >= 0 then
    return false, "英文 sep 符号右边需有空格"
  end
  if vim.fn.match(s, "\\v%([，。？！：”’—…]【?｜】?)@<=[[:blank:]]") >= 0 then
    return false, "中文 sep 符号右边不能有空格"
  end

  -- 完整年份、月、日用阿拉伯数字，如 2015 年、1 月 1 日
  if vim.fn.match(s, [[\v[零一二三四五六七八九十]{4}年]]) >= 0 then
    return false, "完整年份须用阿拉伯数字"
  end

  -- 缩写年份、xx世纪、xx年代用汉字，如二十世纪八十年代、一七年。
  if vim.fn.match(s, [[\v%(^|[^0-9])[0-9]{,2}%(年代?|世纪)]]) >= 0 then
    return false, "缩写年份须用汉字"
  end

  -- 星期几、周几用汉字，如星期三、周二
  if vim.fn.match(s, [[\v%(星期|周)\s*\d]]) >= 0 then
    return false, "星期几、周几须用汉字"
  end

  -- 农历用汉字，如丙寅年十月十五日、腊月二十三日、正月初五、八月十五中秋节
  if vim.fn.match(s, [[\v%([甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]年)?\s*\d+\s*月]]) >= 0 then
    return false, "天干地支年份须用汉字，如丙寅年十月十五日"
  end
  if vim.fn.match(s, [[\v腊月\s*\d+\s*%(日|号)]]) >= 0 then
    return false, "农历须用汉字，如腊月二十三日"
  end
  if vim.fn.match(s, [[\v正月初?\s*\d+\s*%(日|号)?]]) >= 0 then
    return false, "农历须用汉字，如腊月二十三日"
  end

  -- 时间点、时间段用汉字，如三点四十、二十六分四十二秒
  if vim.fn.match(s, [[\v\d+\s*[时点][零一二三四五六七八九十0-9 ]+分?|\d+\s*分[零一二三四五六七八九十0-9 ]+秒?|分\s*\d+\s*秒]]) >= 0 then
    return false, "时间点、时间段须用汉字，如三点四十，二十六分四十二秒"
  end
  return true, nil
end

local ok, msg

for _, s_ret in ipairs {
  { "二零二五年", false },
  { "18年", false },
  { "20 世纪", false },
  { "80  年代", false },
  { "星期3", false },
  { "周 4", false },
  { "星期三", true },
  { "周四", true },
  { "子丑年 12月1 日", false },
  { "腊月 23日", false },
  { "正月12 号", false },
  { "正月初 5", false },
  { "3点 40", false },
  { "3时 40分", false },
  { "3时四十分", false },
  { "四十分19 秒", false },
  { "word  word", false },
  { "中文word", false },
  { "word中文", false },
  { "中文11", false },
  { "11中文", false },
  { "，11", true },
  { "11。", true },
  { "丨", false }, -- 4e28
  { "【丨】", false }, -- 4e28
  { " 丨", false }, -- 4e28
  { " 【丨】", false }, -- 4e28
  { "｜word", false }, -- ff5c
  { "【｜】word", false }, -- ff5c
  { "，｜ ", false }, -- ff5c
  { "，【｜】 ", false }, -- ff5c
} do
  ok, msg = check_number(s_ret[1])
  if ok ~= s_ret[2] then
    vim.print "--------------------------------------------------------------------------------"
    vim.print(s_ret[1], ok, s_ret[2], msg)
  end
end

return M
