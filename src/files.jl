

# this reproduces parsec's behaviour, by disallowing matched input to be
# used again.  to do this we need to:
# 1 - provide a source that allows input to be discarded
# 2 - discard input on success
# 3 - disable discarding input when inside Try()
# 4 - throw an exception when discarded input is accessed
# 5 - treat that exception as failure

# not sure what to name this.  originally used "weak" (weak references
# to source), then "file".  am now going with "try" since that is the
# main user-visible feature.

# the source wraps an IO instance.  this is how julia manages files
# (which is presumably where this is needed most, since strings are
# already available in memory).  but strings can also be wrapped.


type ExpiredContent<:Exception end

type TryIter
    io::IOStream
    frozen::Int    # non-zero is frozen; count allows nested Try()
    zero::Int      # offset to lines (lines[x] contains line x+zero)
    right::Int     # rightmost expired column
    lines::Array{AbstractString,1}
    TryIter(io::IOStream) = new(io, 0, 0, 0, AbstractString[])
end
TryIter(s::AbstractString) = TryIter(IOBuffer(s))

@auto_hash_equals immutable TryIterState
    line::Int
    col::Int
end

immutable TryRange
    start::TryIterState
    stop::TryIterState
end

END_COL = typemax(Int)
FLOAT_LINE = -1
FLOAT_END = TryIterState(FLOAT_LINE, END_COL)


function expire(f::TryIter, s::TryIterState)
    if f.frozen == 0
        n = s.line - f.zero
        f.lines = f.lines[n:end]
        f.zero += (n-1)
        f.right = s.col
    end
end

function line_at(f::TryIter, s::TryIterState)
    if s.line <= f.zero || (s.line == f.zero+1 && s.col <= f.right)
        throw(ExpiredContent())
    end
    n = s.line - f.zero
    while length(f.lines) < n
        push!(f.lines, readline(f.io))
    end
    f.lines[n]
end


unify_line(a::TryIterState, b::TryIterState) = b.line == FLOAT_LINE ? TryIterState(a.line, b.col) : b
unify_col(line::AbstractString, b::TryIterState) = b.col == END_COL ? TryIterState(b.line, endof(line)) : b

start(f::TryIter) = TryIterState(1, 1)
endof(f::TryIter) = FLOAT_END

colon(a::TryIterState, b::TryIterState) = TryRange(a, b)

# very restricted - just enough to support iter[i:end] as current line
# for regexps.  step is ignored,
function getindex(f::TryIter, r::TryRange)
    start = r.start
    line = line_at(f, start)
    stop = unify_col(line, unify_line(start, r.stop))
    if start.line != stop.line
        error("Can only index a range within a line ($(start.line), $(stop.line))")
    else
        return line[start.col:stop.col]
    end
end

function next(f::TryIter, s::TryIterState)
    # there's a subtlelty here.  the line is always correct for
    # reading more data (the check on done() comes *after* next).
    # this is so that getindex can access the line correctly if needed
    # (if we didn't have the line correct, getindex would take a slice
    # from the end of the previous line).
    line = line_at(f, s)
    c, col = next(line, s.col)
    if done(line, col)
        c, TryIterState(s.line+1, 1)
    else
        c, TryIterState(s.line, col)
    end
end

function done(f::TryIter, s::TryIterState)
    try
        line = line_at(f, s)
        done(line, s.col) && eof(f.io)
    catch
        true
    end
end


# as NoCache, but treat ExpiredContent exceptions as failures

type TryConfig<:Config
    source::TryIter
    @compat stack::Array{Tuple{Matcher, State},1}
    @compat TryConfig(source::TryIter) = new(source, Array(Tuple{Matcher,State}, 0))
end

function dispatch(k::TryConfig, e::Execute)
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

function dispatch(k::TryConfig, s::Success)
    (parent, parent_state) = pop!(k.stack)
    expire(k.source, s.iter)
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

function dispatch(k::TryConfig, f::Failure)
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


@auto_hash_equals type Try<:Delegate
    name::Symbol
    matcher::Matcher
    Try(matcher) = new(:Try, matcher)
end

@auto_hash_equals immutable TryState<:DelegateState
    state::State
end

execute(k::TryConfig, m::Try, s::Clean, i) = execute(k, m, TryState(CLEAN), i)

function execute(k::TryConfig, m::Try, s::TryState, i)
    k.source.frozen += 1
    Execute(m, s, m.matcher, s.state, i)
end

function success(k::TryConfig, m::Try, s::TryState, t, i, r::Value)
    k.source.frozen -= 1
    Success(TryState(t), i, r)
end

function failure(k::TryConfig, m::Try, s::TryState)
    k.source.frozen -= 1
    FAILURE
end


parse_try = make_one(TryConfig)
parse_try_dbg = make_one(Debug; delegate=TryConfig)


function src(s::TryIter, i::TryState; max=MAX_SRC)
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
   
function debug{S<:TryIter}(k::Debug{S}, e::Execute)
    @printf("%3d:%3d:%s %02d %s%s->%s\n",
            e.iter.line, e.iter.col, src(k.source, e.iter), k.depth[end], indent(k), e.parent.name, e.child.name)
end

function debug{S<:TryIter}(k::Debug{S}, s::Success)
    @printf("%3d:%3d:%s %02d %s%s<-%s\n",
            s.iter.line, s.iter.col, src(k.source, s.iter), k.depth[end], indent(k), parent(k).name, short(s.result))
end

function debug{S<:TryIter}(k::Debug{S}, f::Failure)
    @printf("       :%s %02d %s%s<-!!!\n",
            pad(" ", MAX_SRC), k.depth[end], indent(k), parent(k).name)
end


# this is general, but usually not much use with backtracking

type ParserError<:Exception
    msg::AbstractString
    iter
end

@auto_hash_equals immutable Error<:Matcher
    name::Symbol
    msg::AbstractString
    Error(msg::AbstractString) = new(:Error, msg)
end

execute(k::Config, m::Error, s::Clean, i) = throw(ParserError(msg, i))
