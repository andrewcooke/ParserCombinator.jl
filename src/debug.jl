

# a Config instance that delegates to another, printing information about
# messages as they are sent.  WARNING: makes a pile of assumptions about the
# source being a string.

# the default parse_dbg uses a simple no-caching delegate, but you can
# construct your own with any type by using the delegate=... keyword.  see
# test/calc.j for an example.

type Debug<:Config
    source::AbstractString
    stack::Array
    delegate::Config
    depth::Array{Int,1}
    abs_depth::Int
    max_depth::Int
    max_iter::Int
    n_calls::Int
    function Debug(source::AbstractString; delegate=NoCache, kargs...)
        k = delegate(source; kargs...)
        new(k.source, k.stack, k, Array(Int, 0), 0, 0, start(k.source), 0)
    end
end

parse_dbg = make_one(Debug)


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
    if isa(f.child_state, TraceState)
        @assert 0 == pop!(k.depth)
    end
    if length(k.depth) > 0
        k.depth[end] -= 1
        debug(k, s)
    end
    k.abs_depth -= 1
    k.max_iter = max(k.max_iter, s.iter)
    dispatch(k.delegate, s)
end

function dispatch(k::Debug, f::Failure)
    if isa(f.child_state, TraceState)
        @assert 0 == pop!(k.depth)
    end
    if length(k.depth) > 0
        k.depth[end] -= 1
        debug(k, s)
    end
    k.abs_depth -= 1
    dispatch(k.delegate, f)
end


# debug functions for printing trace

MAX_RES = 50
MAX_SRC = 10
MAX_IND = 10

function truncate(s::AbstractString, n=10)
    l = length(s)
    if l <= n
        s
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
src(s::AbstractString, i::Int; max=MAX_SRC) = pad(truncate(s[i:end], max), max)

function res(v::Value; max=MAX_RES)
    txt = string(v)
    if ismatch(r"^Any", txt)
        txt = txt[4:end]
    end
    truncate(txt, max)
end

function debug(k::Debug, e::Execute)
    @printf("%3d:%s %02d %s%s->%s\n",
            e.iter, src(k.source, e.iter), k.depth[end], indent(k), e.parent.name, e.child.name)
end

function debug(k::Debug, s::Success)
    @printf("%3d:%s %02d %s%s<-%s\n",
            s.iter, src(s.source, s.iter), k.depth[end], indent(k), parent(k).name, res(s.result))
end

function debug(k::Debug, f::Failure)
    @printf("???:%s %02d %s%s<-!!!\n",
            src(k.source, None), k.depth[end], indent(k), parent(k).name)
end



# this does nothing except delegate and, by simply "being seen" during
# disparch above, toggle debug state.

@auto_hash_equals type Trace<:Delegate
    name::Symbol
    matcher::Matcher
    Trace(matcher) = new(:Trace, matcher)
end

@auto_hash_equals immutable TraceState<:DelegateState
    state::State
end

# must handle both success and failure so that detection can occur above

response(k::Config, m::Trace, s, t, i, r::Success) = Response(TraceState(t), i, r)
response(k::Config, m::Trace, s, t, i, r::Failure) = Response(TraceState(t), i, r)
