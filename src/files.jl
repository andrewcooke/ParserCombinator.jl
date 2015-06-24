

# the state for these (which i've unfortunately called "iter"
# throughout the rest of the code) is (a, s), where a is an index into
# the lines, and s is an index into that line.

abstract StreamIter  # must contain io field

@auto_hash_equals immutable StreamState
    line::Int
    col::Int
end

immutable StreamRange
    start::StreamState
    stop::StreamState
end

END_COL = typemax(Int)
FLOAT_LINE = -1
FLOAT_END = StreamState(FLOAT_LINE, END_COL)

unify_line(a::StreamState, b::StreamState) = b.line == FLOAT_LINE ? StreamState(a.line, b.col) : b
unify_col(line::AbstractString, b::StreamState) = b.col == END_COL ? StreamState(b.line, endof(line)) : b

start(f::StreamIter) = StreamState(1, 1)
endof(f::StreamIter) = FLOAT_END

colon(a::StreamState, b::StreamState) = StreamRange(a, b)

# very restricted - just enough to support iter[i:end] as current line
# for regexps.  step is ignored,
function getindex(f::StreamIter, r::StreamRange)
    start = r.start
    line = line_at(f, start)
    stop = unify_col(line, unify_line(start, r.stop))
    if start.line != stop.line
        error("Can only index a range within a line ($(start.line), $(stop.line))")
    else
        return line[start.col:stop.col]
    end
end

function next(f::StreamIter, s::StreamState)
    # there's a subtlelty here.  the line is always correct for
    # reading more data (the check on done() comes *after* next).
    # this is so that getindex can access the line correctly if needed
    # (if we didn't have the line correct, getindex would take a slice
    # from the end of the previous line).
    line = line_at(f, s)
    c, col = next(line, s.col)
    if done(line, col)
        c, StreamState(s.line+1, 1)
    else
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
    if s.line <= f.zero
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


# as NoCache, but treat ExpiredContent exceptions as failures

type FailExpired<:Config
    source::Any
    @compat stack::Array{Tuple{Matcher, State},1}
    @compat FailExpired(source) = new(source, Array(Tuple{Matcher,State}, 0))
end

function dispatch(k::FailExpired, e::Execute)
    push!(k.stack, (e.parent, e.parent_state))
    try
        execute(k, e.child, e.child_state, e.iter)
    catch err
        if isa(err, ExpiredContent)
            FAILURE
        else
            rethrow()
        end
    end
end

function dispatch(k::FailExpired, s::Success)
    (parent, parent_state) = pop!(k.stack)
    try
        success(k, parent, parent_state, s.child_state, s.iter, s.result)
    catch err
        if isa(err, ExpiredContent)
            FAILURE
        else
            rethrow()
        end
    end
end

function dispatch(k::FailExpired, f::Failure)
    (parent, parent_state) = pop!(k.stack)
    try
        failure(k, parent, parent_state)
    catch err
        if isa(err, ExpiredContent)
            FAILURE
        else
            rethrow()
        end
    end
end


parse_weak = make_one(FailExpired)
parse_weak_dbg = make_one(Debug; delegate=FailExpired)


function src(s::StreamIter, i::StreamState; max=MAX_SRC)
    try
        pad(truncate(escape_string(s[i:end]), max), max)
    catch x
        if isa(x, ExpiredContent)
            pad(truncate("[expired]", max), max)
        else
            rethrow()
        end
    end
end
   
function debug{S<:StreamIter}(k::Debug{S}, e::Execute)
    @printf("%3d:%3d:%s %02d %s%s->%s\n",
            e.iter.line, e.iter.col, src(k.source, e.iter), k.depth[end], indent(k), e.parent.name, e.child.name)
end

function debug{S<:StreamIter}(k::Debug{S}, s::Success)
    @printf("%3d:%3d:%s %02d %s%s<-%s\n",
            s.iter.line, s.iter.col, src(k.source, s.iter), k.depth[end], indent(k), parent(k).name, short(s.result))
end

function debug{S<:StreamIter}(k::Debug{S}, f::Failure)
    @printf("       :%s %02d %s%s<-!!!\n",
            pad(" ", MAX_SRC), k.depth[end], indent(k), parent(k).name)
end
