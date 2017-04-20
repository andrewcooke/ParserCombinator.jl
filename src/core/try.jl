

# this reproduces parsec's behaviour, by disallowing matched input to be
# used again.  to do this we need to:
# 1 - provide a source that allows input to be discarded
# 2 - discard input on success
# 3 - disable discarding input when inside Try()
# 4 - throw an exception when discarded input is accessed
# 5 - treat that exception as failure

# the source wraps an IO instance.  this is how julia manages files
# (which is presumably where this is needed most, since strings are
# already available in memory).  but strings can also be wrapped.


type TrySource{S}<:LineAt
    io::IO
    frozen::Int    # non-zero is frozen; count allows nested Try()
    zero::Int      # offset to lines (lines[x] contains line x+zero)
    right::Int     # rightmost expired column
    lines::Vector{S}
    (::TrySource{S}){S}(io::IO, line::S) = new{S}(io, 0, 0, 0, S[line])
end

function TrySource(io::IO)
    line = Compat.readline(io, chomp=false)
    TrySource{typeof(line)}(io, line)
end

TrySource{S<:String}(s::S) = TrySource(IOBuffer(s))


function expire(s::TrySource, i::LineIter)
    if s.frozen == 0
        n = i.line - s.zero
        if n > 0
            s.lines = s.lines[n:end]
            s.zero += (n-1)
            if n > 1 || i.column > s.right
                s.right = i.column
            end
        end
    end
end

function line_at(f::TrySource, s::LineIter; check::Bool=true)
    if check
        if s.line <= f.zero || (s.line == f.zero+1 && s.column < f.right)
            throw(LineException())
        end
    end
    n = s.line - f.zero
    while length(f.lines) < n
        push!(f.lines, Compat.readline(f.io, chomp=false))
    end
    f.lines[n]
end

function next(f::TrySource, s::LineIter)
    # there's a subtlelty here.  the line is always correct for
    # reading more data (the check on done() comes *after* next).
    # this is so that getindex can access the line correctly if needed
    # (if we didn't have the line correct, getindex would take a slice
    # from the end of the previous line).
    line = line_at(f, s)
    c, col = next(line, s.column)
    if done(line, col)
        c, LineIter(s.line+1, 1)
    else
        c, LineIter(s.line, col)
    end
end

function done(s::TrySource, i::LineIter)
    line = line_at(s, i; check=false)
    done(line, i.column) && eof(s.io)
end


# the Try() matcher that enables backtracking

@auto_hash_equals type Try<:Delegate
    name::Symbol
    matcher::Matcher
    Try(matcher) = new(:Try, matcher)
end

@auto_hash_equals immutable TryState<:DelegateState
    state::State
end

execute(k::Config, m::Try, s::Clean, i) = error("use Try only with TrySource")

execute{S<:TrySource}(k::Config{S}, m::Try, s::Clean, i) = execute(k, m, TryState(CLEAN), i)

function execute{S<:TrySource}(k::Config{S}, m::Try, s::TryState, i)
    k.source.frozen += 1
    Execute(m, s, m.matcher, s.state, i)
end

function success{S<:TrySource}(k::Config{S}, m::Try, s::TryState, t, i, r::Value)
    k.source.frozen -= 1
    Success(TryState(t), i, r)
end

function failure{S<:TrySource}(k::Config{S}, m::Try, s::TryState)
    k.source.frozen -= 1
    FAILURE
end


function dispatch{S<:TrySource}(k::NoCache{S}, s::Success)
    (parent, parent_state) = pop!(k.stack)
    expire(k.source, s.iter)
    try
        success(k, parent, parent_state, s.child_state, s.iter, s.result)
    catch x
        isa(x, FailureException) ? FAILURE : rethrow()
    end
end

function dispatch{S<:TrySource}(k::Cache{S}, s::Success)
    parent, parent_state, key = pop!(k.stack)
    expire(k.source, s.iter)
    try
        k.cache[key] = s
    catch x
        isa(x, CacheException) ? nothing : rethrow()
    end
    try
        success(k, parent, parent_state, s.child_state, s.iter, s.result)
    catch x
        isa(x, FailureException) ? FAILURE : rethrow()
    end
end



# and a simple interface

parse_try(source, matcher; kargs...) = parse_one(TrySource(source), matcher; kargs...)
parse_try_dbg(source, matcher; kargs...) = parse_one_dbg(TrySource(source), matcher; kargs...)
parse_try_cache(source, matcher; kargs...) = parse_one_cache(TrySource(source), matcher; kargs...)
parse_try_cache_dbg(source, matcher; kargs...) = parse_one_cache_dbg(TrySource(source), matcher; kargs...)
