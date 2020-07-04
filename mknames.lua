local function split(s)
  local list = {}
  local first = 1
  local last
  repeat
    last = s:find(',', first, true)
    if last then
      list[#list + 1] = s:sub(first, last - 1)
      first = last + 1
    else
      list[#list + 1] = s:sub(first)
    end
  until last == nil

  return list
end

local function load_markov_chain(category, lang, order)

  local fname = ("data/%s/%s-%d.mkvc"):format(category, lang, order)
  local fh = io.open(fname, 'r')
  if not fh then
    return nil
  end
  io.input(fh)
  local mkv_chain = {}
  for line in io.lines() do
    local parts = split(line)
    local nextchars = {}
    mkv_chain[parts[1]] = nextchars
    local count = 0
    for i = 2, #parts, 2 do
      local n = tonumber(parts[i + 1])
      nextchars[#nextchars + 1] = { parts[i], n }
      count = count + n
    end
    nextchars.__count = count
  end
  return mkv_chain
end

local function get_next_char(candidates)
  local count = candidates.__count
  local roll = math.random(count)
  for _, follower in ipairs(candidates) do
    roll = roll - follower[2]
    if roll <= 0 then
      return follower[1]
    end
  end
end

local function make_word(mkv_chain, order)
  local word = ""
  for _ = 1, order do
    word = '_' .. word
  end

  local i = 1
  while true do
    local ngram = word:sub(i, i + order)
    local next_char_candidates = mkv_chain[ngram]
    local next_char = get_next_char(next_char_candidates)
    if next_char == '_' then
      return word:sub(order + 1, -1)
    end
    word = word .. next_char
    i = i + 1
  end
end

local function compile_pattern(s)
  local V = "[aiueoy]"
  local C = "[^aiueoy]"

  local p = ""
  for c in s:gmatch('.') do
    if c == 'V' then
      p = p .. V
    elseif c == 'C' then
      p =p .. C
    else
      p = p .. c
    end
  end
  return p
end

local lang
local order = 3
local count = 10
local seed = os.time()
local min_len, max_len = 1, math.maxinteger
local pattern
local category
local options = {
  { "--category",function(s, i) category = s; return i + 1 end },
  {"--pattern", function(s, i) pattern = compile_pattern(s); return i + 1 end },
  { "--min_len", function(s, i) min_len = tonumber(s); return i + 1 end },
  { "--max_len", function(s, i) max_len = tonumber(s) return i + 1 end },
  { "--lang", function(s, i) lang = s; return i + 1 end },
  {"--order", function(s, i) order = tonumber(s); return i + 1 end },
  { "--count", function(s, i) count = tonumber(s); return i + 1 end },
  { "--seed", function(s, i) seed = tonumber(s); return i + 1 end }
}

local function parse_options()
  local i = 1
  while i <= #arg do
    local s = arg[i]
    for _, option in ipairs(options) do
      if option[1] == s then
        i = option[2](arg[i + 1], i)
      end
    end
    i = i + 1
  end
end

parse_options()
if not lang then
  print("missing required '--lang' option")
  os.exit(1)
end
if not category then
  print("missing required '--category' option")
  os.exit(1)
end

math.randomseed(seed)

local function log(name, value)
  if value then
    print(('%-15s %s'):format(name, value))
  end
end

print('======================================')
log('count', count)
log('order', order)
log('seed', seed)
log('lang', lang)
log('category', category)
log('pattern', pattern)
log('min_len', min_len)
log('max_len', max_len)
print('======================================')

local mkv_chain = load_markov_chain(category, lang, order)

local i, generated = 0, {}
while count > 0 do
  local function make_one()
    local word = make_word(mkv_chain, order)
    if min_len and #word < min_len then
      return nil
    end
    if max_len and #word > max_len then
      return nil
    end
    if generated[word] then return nil end
    if pattern and not word:match(pattern) then return nil end
    return word
  end
  local word = make_one()
  if word then
    generated[word] = true
    print(('%4d %s'):format(i, word))
    count = count - 1
    i = i + 1
  end
end

