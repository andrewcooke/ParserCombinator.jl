# a Config instance that delegates to another, printing information about
# messages as they are sent.  WARNING: makes a pile of assumptions about the
# source being a string.

# the default parse_dbg uses a simple no-caching delegate, but you can
# construct your own with any type by using the delegate=... keyword.  see
# test/calc.j for an example.

mutable struct Debug{S,I}<:Config{S,I}
    source::S
    stack::Vector
    delegate::Config{S,I}
    depth::Vector{Int}
    abs_depth::Int
    max_depth::Int
    max_iter
    n_calls::Int
    function Debug{S, I}(source::S; delegate=NoCache, kargs...) where {S,I}
        k = delegate{S,I}(source; kargs...)
        new{S, I}(k.source, k.stack, k, Vector{Int}(), 0, 0, firstindex(k.source), 0)
    end
end
# i don't get why this is necessary, but it seems to work
Debug(source; kargs...) = Debug{typeof(source),typeof(firstindex(source))}(source; kargs...)

parent(k::Debug) = parent(k.delegate)

function dispatch(k::Debug, e::Execute)
    if isa(e.parent, Trace)
        push!(k.depth, 0)
    end
    if length(k.depth) > 0
        debug(k, e)
        k.depth[end] += 1
    end
    k.abs_depth += 1
    k.max_depth = max(k.max_depth, k.abs_depth)
    k.n_calls += 1
    dispatch(k.delegate, e)
end

function dispatch(k::Debug, s::Success)
    if length(k.depth) > 0
        k.depth[end] -= 1
        debug(k, s)
    end
    k.abs_depth -= 1
    k.max_iter = max(k.max_iter, s.iter)
    if isa(parent(k), Trace)
        @assert 0 == pop!(k.depth)
    end
    dispatch(k.delegate, s)
end

function dispatch(k::Debug, f::Failure)
    if length(k.depth) > 0
        k.depth[end] -= 1
        debug(k, f)
    end
    k.abs_depth -= 1
    if isa(parent(k), Trace)
        @assert 0 == pop!(k.depth)
    end
    dispatch(k.delegate, f)
end


# debug functions for printing trace

MAX_RES = 50
MAX_SRC = 10
MAX_IND = 10

if VERSION < v"0.4-"
    shorten(s) = s
else
#   shorten(s) = replace(s, r"(?:[a-zA-Z]+\.)+([a-zA-Z]+)", s"\1")
    shorten(s) = replace(s, r"(?:[a-zA-Z]+\.)+([a-zA-Z]+)" =>
                         Base.SubstitutionString("\1"))
end

function truncate(s::AbstractString, n=10)
    if length(s) <= n
        return s
    end
    s = shorten(s)
    l = length(s)
    if l <= n
        return s
    else
        j = div(2*n+1,3) - 2
        # j + 3 + (l - k + 1) = n
        k = j + 3 + l + 1 - n
        s[1:j] * "..." * s[k:end]
    end
end

pad(s::AbstractString, n::Int) = s * repeat(" ", n - length(s))
indent(k::Debug; max=MAX_IND) = repeat(" ", k.depth[end] % max)

src(::Any, ::Any; max=MAX_SRC) = pad(truncate("...", max), max)
src(s::AbstractString, i::Int; max=MAX_SRC) = pad(truncate(escape_string(s[i:end]), max), max)

function debug(k::Debug{S}, e::Execute) where {S<:AbstractString}
    @printf("%3d:%s %02d %s%s->%s\n",
            e.iter, src(k.source, e.iter), k.depth[end], indent(k), e.parent.name, e.child.name)
end

function short(s::Value)
    result = string(s)
    if occursin(r"^Any", result)
        result = result[4:end]
    end
    truncate(result, MAX_RES)
end

function debug(k::Debug{S}, s::Success) where {S<:AbstractString}
    @printf("%3d:%s %02d %s%s<-%s\n",
            s.iter, src(k.source, s.iter), k.depth[end], indent(k), parent(k).name, short(s.result))
end

function debug(k::Debug{S}, f::Failure) where {S<:AbstractString}
    @printf("   :%s %02d %s%s<-!!!\n",
            pad(" ", MAX_SRC), k.depth[end], indent(k), parent(k).name)
end

function src(s::LineAt, i::LineIter; max=MAX_SRC)
    try
        pad(truncate(escape_string(forwards(s, i)), max), max)
    catch x
        if isa(x, LineException)
            pad(truncate("[unavailable]", max), max)
        else
            rethrow()
        end
    end
end
   
function debug(k::Debug{S}, e::Execute) where {S<:LineAt}
    @printf("%3d,%-3d:%s %02d %s%s->%s\n",
            e.iter.line, e.iter.column, src(k.source, e.iter), k.depth[end], indent(k), e.parent.name, e.child.name)
end

function debug(k::Debug{S}, s::Success) where {S<:LineAt}
    @printf("%3d,%-3d:%s %02d %s%s<-%s\n",
            s.iter.line, s.iter.column, src(k.source, s.iter), k.depth[end], indent(k), parent(k).name, short(s.result))
end

function debug(k::Debug{S}, f::Failure) where {S<:LineAt}
    @printf("       :%s %02d %s%s<-!!!\n",
            pad(" ", MAX_SRC), k.depth[end], indent(k), parent(k).name)
end


# this does nothing except delegate and, by simply "being seen" during
# disparch above, toggle debug state.

@auto_hash_equals mutable struct Trace<:Delegate
    name::Symbol
    matcher::Matcher
    Trace(matcher) = new(:Trace, matcher)
end

@auto_hash_equals struct TraceState<:DelegateState
    state::State
end


# must handle both success and failure so that detection can occur above

success(k::Config, m::Trace, s, t, i, v::Value) = Success(TraceState(t), i, v)
failure(k::Config, m::Trace, s) = FAILURE


parse_one_cache_dbg = make_one(Debug; delegate=Cache)
parse_one_nocache_dbg = make_one(Debug; delegate=NoCache)
parse_one_dbg = parse_one_nocache_dbg
parse_dbg = parse_one_nocache_dbg

parse_all_cache_dbg = make_all(Debug; delegate=Cache)
parse_all_nocache_dbg = make_all(Debug; delegate=NoCache)
parse_all_dbg = parse_all_cache_dbg

parse_lines_dbg(source, matcher; kargs...) = parse_one_dbg(LineSource(source), matcher; kargs...)
parse_lines_cache_dbg(source, matcher; kargs...) = parse_one_cache_dbg(LineSource(source), matcher; kargs...)
