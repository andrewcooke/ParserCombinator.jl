

# we provide support for two kinds of source.  the differnece is important
# mainly because of how the source interacts with the regexp matcher, whiich
# can be critical when trying to get best performance with large files.

# however, the parser code will interact with "any" source provided it
# provides the API here.


# utilities

function fmt_error(line, col, text, msg)
    arrow = string(repeat(" ", max(col-1, 0)), "^")
    "$(msg) at ($(line),$(col))\n$(text)\n$(arrow)\n"
end


# strings indexed by offset.  in this csae, the type of the source is simply
# the string itself, so we do not need to implement the iter protocol, since
# that already exists.  but we do need some extra functions.

# given a source and iterator, return a message identifying line and
# column

nl(x) = x == '\n'

function round_up(s, i)
    i = max(i, 1)
    nl(s[i]) ? i+1 : i
end

function round_down(s, i)
    i = i == 0 ? endof(s) : i
    nl(s[i]) ? i-1 : i
end

function diagnostic(s::AbstractString, i, msg)
    if i < 1
        l, c, t = 0, 0, "[Before start]"
    elseif i > length(s)
        l, c, t = count(nl, s)+2, 0, "[After end]"
    else
        l = count(nl, SubString(s, 1, max(1, i-1))) + 1
        p = round_up(s, findprev(nl, s, max(1, i-1)))  # excluding new line
        q = round_down(s, findnext(nl, s, i))  # end of line, excluding newline
        t = SubString(s, p, q)
        c = i - p + 1
    end
    fmt_error(l, c, t, msg)
end

# given a source and iterator, return following text for regexp
#forwards(s::AbstractString, i) = SubString(s, i)
forwards(s::AbstractString, i) = s[i:end]

discard(::ASCIIString, i, n) = i + n

# UTF strings are not directly indexable
function discard(s::AbstractString, i, n)
    for j in 1:n
        c, i = next(s, i)
    end
    i
end

# io instance, from which lines are read.  the lines are stored so that we
# have backtracking.  this is pretty pointless, because you might as well just
# read the whole thing into memory at the start, but it serves as the basis
# for a similar approach in try.jl where not all lines are saved.

# since it's so pointless as it is, we thrown in an extra feature - a maximum
# depth (in lines) after which data are discarded.  it might be useful
# somewhere.

# all the below is based on line_at()
abstract LineAt

type LineSource{S}<:LineAt
    io::IO
    zero::Int      # offset to lines (lines[x] contains line x+zero)
    limit::Int     # maximum number of lines
    lines::Vector{S}
    LineSource(io::IO, line::S; limit=-1) = new(io, 0, limit, S[line])
end

function LineSource(io::IO; limit=-1)
    line = readline(io)
    LineSource{typeof(line)}(io, line; limit=limit)
end

LineSource{S<:AbstractString}(s::S; limit=-1) = LineSource(IOBuffer(s); limit=limit)

immutable LineException<:FailureException end

@auto_hash_equals immutable LineIter
    line::Int
    column::Int
end

# used in debug

isless(a::LineIter, b::LineIter) = a.line < b.line || (a.line == b.line && a.column < b.column)

# iter protocol

start(f::LineAt) = LineIter(1, 1)

function line_at(s::LineSource, i::LineIter; check=true)
    if check && i.line <= s.zero || i.column < 1
        throw(LineException())
    else
        n = i.line - s.zero
        while length(s.lines) < n
            push!(s.lines, readline(s.io))
        end
        while s.limit > 0 && length(s.lines) > s.limit
            s.zero += 1
            pop!(s.lines)
        end
        line = s.lines[i.line - s.zero]
        if check && i.column > length(line)
            throw(LineException())
        end
    end
    line
end

function next(s::LineSource, i::LineIter)
    # i.line is always correct for further reading (eg via forwards())
    line = line_at(s, i)
    c, column = next(line, i.column)
    if done(line, column)
        c, LineIter(i.line+1, 1)
    else
        c, LineIter(i.line, column)
    end
end

function done(s::LineSource, i::LineIter)
    line = line_at(s, i; check=false)
    done(line, i.column) && eof(s.io)
end

# other api

function diagnostic(s::LineAt, i::LineIter, msg)
    line = "[Not available]"
    try
        line = line_at(s, i)
        if nl(line[end])
            line = line[1:end-1]
        end
    catch x
        if !isa(x, FailureException)
            throw(x)
        end
    end
    fmt_error(i.line, i.column, line, msg)
end

# regexp only works within the current line
#forwards(s::LineAt, i::LineIter) = done(s, i) ? "" : SubString(line_at(s, i), i.column)
# currently (pre-patch) this is faster
forwards(s::LineAt, i::LineIter) = done(s, i) ? "" : line_at(s, i)[i.column:end]

function discard(s::LineAt, i::LineIter, n)
    while n > 0 && !done(s, i)
        l = line_at(s, i)
        available = length(l) - i.column + 1
        if n < available
            i = LineIter(i.line, i.column+n)
            n = 0
        else
            i = LineIter(i.line+1, 1)
            n -= available
        end
    end
    i
end


