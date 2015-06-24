

# the state for these (which i've unfortunately called "iter"
# throughout the rest of the code) is (a, s), where a is an index into
# the lines, and s is an index into that line.

abstract StreamIter  # must contain io field

@auto_hash_equals immutable StreamState
    line::Int
    col::Int
end

END_COL = typemax(Int)
FLOAT_LINE = -1
FLOAT_END = StreamState(FLOAT_LINE, END_COL)

unify_line(a::StreamState, b::StreamState) = b.line == FLOAT_LINE ? StreamState(a.line, b.col) : b
unify_col(line::AbstractString, b::StreamState) = b.col == END_COL ? StreamState(b.line, endof(line)) : b

start(f::StreamIter) = StreamState(1, 1)
endof(f::StreamIter) = FLOAT_END

function colon(a::StreamState, b::StreamState)
    b = unify_line(a, b)
    StepRange(a, 1, b)
end
# step range is trying to be clever.  we're exploting that this is exposed
# in range.jl.  i guess we could implement all the necessary arithmetic...
# (we can't use unit range because of type restrictions - perhaps we should
# define StreamState to subclass the appropriate type?)
steprange_last(start::StreamState, step::Int, stop::StreamState) = stop

# very restricted - just enough to support iter[i:end] as current line
# for regexps.  step is ignored,
function getindex(f::StreamIter, r::StepRange)
    start = r.start
    line = line_at(f, start)
    stop = unify_col(line, unify_line(start, r.stop))
    if start.line != stop.line
        error("Can only index a range within a line")
    else
        println("$(start) $(stop)")
        return line[start.col:stop.col]
    end
end

function next(f::StreamIter, s::StreamState)
    line = line_at(f, s)
    if done(line, s.col)
        next(f, StreamState(s.line+1, 1))
    else
        c, col = next(line, s.col)
        c, StreamState(s.line, col)
    end
end

function done(f::StreamIter, s::StreamState)
    try
        line = line_at(f, s)
        done(line, s.col) && eof(f.io)
    catch
        true
    end
end


type StrongStreamIter<:StreamIter
    io::IOStream
    lines::Array{AbstractString,1}
    StrongStreamIter(io::IOStream) = new(io, AbstractString[])
end

function line_at(f::StrongStreamIter, s::StreamState)
    while length(f.lines) < s.line
        push!(f.lines, readline(f.io))
    end
    f.lines[s.line]
end


type ExpiredContent<:Exception end

type WeakStreamIter<:StreamIter
    io::IOStream
    frozen::Bool
    zero::Int
    lines::Array{AbstractString,1}
    WeakStreamIter(io::IOStream) = new(io, false, 0, AbstractString[])
end

function line_at(f::WeakStreamIter, s::StreamState)
    if s.line < f.zero
        throw(ExpiredContent())
    end
    while length(f.lines) < s.line - f.zero
        if f.frozen
            push!(f.lines, readline(f.io))
        else
            f.zero += length(f.lines)  # discarded
            f.lines = AbstractString[readline(f.io)]
        end
    end
    f.lines[s.line - f.zero]
end
