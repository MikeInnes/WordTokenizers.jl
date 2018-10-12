# TODO: the input + idx combination should probably be replaced by a stream

mutable struct TokenBuffer
  input::Vector{Char}
  buffer::Vector{Char}
  tokens::Vector{String}
  idx::Int
end

TokenBuffer(input) = TokenBuffer(input, [], [], 1)

TokenBuffer(input::AbstractString) = TokenBuffer(collect(input))

Base.getindex(ts::TokenBuffer, i = ts.idx) = ts.input[i]
isdone(ts::TokenBuffer) = ts.idx > length(ts.input)

function flush!(ts::TokenBuffer, s...)
  if !isempty(ts.buffer)
    push!(ts.tokens, String(ts.buffer))
    empty!(ts.buffer)
  end
  push!(ts.tokens, s...)
  return
end

function lookahead(ts::TokenBuffer, s; boundary = false)
  ts.idx + length(s) - 1 > length(ts.input) && return false
  for j = 1:length(s)
    ts.input[ts.idx-1+j] == s[j] || return false
  end
  if boundary
    next = ts.idx + length(s)
    next > length(ts.input) && return true
    (isletter(ts[next]) || ts[next] == '-') && return false
  end
  return true
end

function character(ts)
  push!(ts.buffer, ts[])
  ts.idx += 1
  return true
end

function spaces(ts::TokenBuffer)
  isspace(ts[]) || return false
  flush!(ts)
  ts.idx += 1
  return true
end

function atoms(ts, as)
  for a in as
    lookahead(ts, a) || continue
    flush!(ts, String(a))
    ts.idx += length(a)
    return true
  end
  (ispunct(ts[]) && ts[] != '.' && ts[] != '-') || return false
  flush!(ts, string(ts[]))
  ts.idx += 1
  return true
end

function suffixes(ts, ss)
  isempty(ts.buffer) && return false
  for s in ss
    lookahead(ts, s, boundary=true) || continue
    flush!(ts, String(s))
    ts.idx += length(s)
    return true
  end
  return false
end

function splits(ts, ss)
  for (s, l) in ss
    lookahead(ts, s, boundary=true) || continue
    flush!(ts, s[1:l], s[l+1:end])
    ts.idx += length(s)
    return true
  end
  return false
end

function openquote(ts)
  ts[] == '"' || return false
  flush!(ts, "``")
  ts.idx += 1
  return true
end

function closingquote(ts)
  ts[] == '"' || return false
  flush!(ts, "''")
  ts.idx += 1
  return true
end

function number(ts, sep = (':', ',', '\'', '.'))
  isdigit(ts[]) || return false
  i = ts.idx
  while i <= length(ts.input) && (isdigit(ts[i]) ||
        (ts[i] in sep && i < length(ts.input) && isdigit(ts[i+1])))
    i += 1
  end
  flush!(ts, String(ts[ts.idx:i-1]))
  ts.idx = i
  return true
end
