

type Debug<:Config
    delegate::Config
    nested::Int
    Debug(delegate::Config) = new(delegate, 0)
end

function dispatch(k::Debug, e::Execute)
    dispatch(k.delegate, e)
end

function dispatch(k::Debug, r::Response)
    dispatch(k.dlegate, r)
end



# debug functions for printing trace

short_typeof(m::Matcher) = string(m.name)

function short_typeof(x)
    s = string(typeof(x))
    i = rsearchindex(s, ".")
    if i > 0
        s = s[i+1:end]
    end
    i = searchindex(s, "{")
    if i > 0
        s = s[1:i-1]
    end
    s
end

function debug(k, p, s, c, t, i, cached)
    if cached
        @printf("%03d %20s <> %-20s\n", 
                i, short_typeof(p) * "/" * short_typeof(s), 
                short_typeof(c) * "/" * short_typeof(t))
    else
        @printf("%03d %20s => %-20s\n", 
                i, short_typeof(p) * "/" * short_typeof(s), 
                short_typeof(c) * "/" * short_typeof(t))
    end
end

function debug(k, p, s, t, i, r)
    @printf("%03d %20s <= %-20s\n", 
            i, short_typeof(p) * "/" * short_typeof(s), short_typeof(r))
end



# enable debug when in scope of child

@auto type Trace<:Delegate
    name::Symbol
    matcher::Matcher
    Trace(matcher) = new(:Trace, matcher)
end

@auto type TraceState<:DelegateState
    state::State
end

execute(k::Debug, m::Trace, s::Clean, i) = execute(k, m, TraceState(CLEAN), i)

function execute(k::Debug, m::Trace, s::TraceState, i)
    k.nested += 1
    Execute(m, TraceState(s.state), m.matcher, s.state, i)
end

function response(k::Debug, m::Trace, s::TraceState, t, i, r::Success)
    k.nested -= 1
    Response(TraceState(t), i, r)
end
    
function response(k::Debug, m::Trace, s::TraceState, t, i, r::Failure)
    k.nested -= 1
    Response(DIRTY, i, FAILURE)
end
    
# for other configs, Delegtae does most of the work

execute(k::Config, m::Trace, s::TraceState, i) = Execute(m, s, m.matcher, s.state, i)

response(k::Config, m::Trace, s, t, i, r::Success) = Response(TraceState(t), i, r)


