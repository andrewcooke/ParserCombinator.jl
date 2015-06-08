

type Debug<:Config
    source::Any
    stack::Array
    delegate::Config
    depth::Array{Int,1}
    abs_depth::Int
    max_depth::Int
    max_iter::Any
    n_calls::Int
    function Debug(source; delegate=NoCache, kargs...)
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

function dispatch(k::Debug, r::Response)
    if isa(r.state_child, TraceState)
        @assert 0 == pop!(k.depth)
    end
    if length(k.depth) > 0
        k.depth[end] -= 1
        debug(k, r)
    end
    k.abs_depth -= 1
    try
        k.max_iter = max(k.max_iter, r.iter)
    catch
        # max() may not be defined for this type
    end
    dispatch(k.delegate, r)
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

res(::Failure; max=MAX_RES) = truncate("!!!", max)

function res(s::Success; max=MAX_RES)
    txt = string(s.value)
    if ismatch(r"^Any", txt)
        txt = txt[4:end]
    end
    truncate(txt, max)
end

function debug(k::Debug, e::Execute)
    @printf("%3d:%s %02d %s%s->%s\n",
            e.iter, src(k.source, e.iter), k.depth[end], indent(k), e.parent.name, e.child.name)
end

function debug(k::Debug, r::Response)
    @printf("%3d:%s %02d %s%s<-%s\n",
            r.iter, src(k.source, r.iter), k.depth[end], indent(k), parent(k).name, res(r.result))
end



# this does nothing except delegate and, by simply "being seen" during
# disparch above, toggle debug state.

@auto type Trace<:Delegate
    name::Symbol
    matcher::Matcher
    Trace(matcher) = new(:Trace, matcher)
end

@auto type TraceState<:DelegateState
    state::State
end

# must handle both success and failure so that detection can occur above

response(k::Config, m::Trace, s, t, i, r::Success) = Response(TraceState(t), i, r)

response(k::Config, m::Trace, s, t, i, r::Failure) = Response(TraceState(t), i, r)
