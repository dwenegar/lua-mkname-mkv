local function load_words(filename)
  local words = {}
  for w in io.lines(filename) do
    w = w:match("^%s*(%S+)")
    if w and #w > 0 then
      words[#words + 1] = w:lower()
    end
  end
  return words
end

local function reshape(mkv_chain)
  for ngram, transitions in pairs(mkv_chain) do
    local new_transitions = {}
    local transition_count = 0
    for transition, frequency in pairs(transitions) do
      new_transitions[#new_transitions + 1] = { transition, frequency }
      transition_count = transition_count + frequency
    end
    table.sort(new_transitions, function(a, b) return a[2] > b[2] end)
    new_transitions.__count = transition_count
    mkv_chain[ngram] = new_transitions
  end
end

local function build_markv_chain(words, order)

  local mkv_chain = setmetatable({}, {
    __index = function(t, k)
      t[k] = {}
      return t[k]
    end
  })

  local prefix = ('_'):rep(order)
  local function process_word(word)

    if order > 0 then
      word = prefix .. word
    end
    word = word .. '_'

    local n = word:len()
    for i = 1, n - order do
      local ngram = word:sub(i, i + order - 1)
      local transition = word:sub(i + order, i + order)
      local transitions = mkv_chain[ngram]
      transitions[transition] = (transitions[transition] or 0) + 1
    end
  end

  for _, w in ipairs(words) do
    if #w >=order then
      process_word(w)
    end
  end

  setmetatable(mkv_chain, nil)
  reshape(mkv_chain)
  return mkv_chain
end

local function write_markov_chain(filename, mkv_chain)
  local lines = {}
  for ngram, transitions in pairs(mkv_chain) do
    local line = { ngram }
    for _, transition in ipairs(transitions) do
      line[#line + 1] = transition[1]
      line[#line + 1] = transition[2]
    end
    lines[#lines + 1] = line
  end
  table.sort(lines, function(a, b) return a[1] < b[1] end)
  local file = io.open(filename, 'w')
  for _, line in pairs(lines) do
    file:write(table.concat(line, ','))
    file:write('\n')
  end
  io.close()
end

local input_filename = arg[1]
local basename = input_filename:match('^(%S+)%.txt$')
local words = load_words(input_filename)
for order = 1, 4 do
  local output_filename = string.format("%s-%d.mkvc", basename, order)
  local chain = build_markv_chain(words, order)
  write_markov_chain(output_filename, chain)
end
