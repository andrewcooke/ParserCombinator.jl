

# debug functions for printing trace

short_typeof(m::Matcher) = m.name

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
        @printf("%04d %20s <> %-20s\n", 
                i, short_typeof(p) * "/" * short_typeof(s), 
                short_typeof(c) * "/" * short_typeof(t))
    else
        @printf("%04d %20s => %-20s\n", 
                i, short_typeof(p) * "/" * short_typeof(s), 
                short_typeof(c) * "/" * short_typeof(t))
    end
end

function debug(k, p, s, t, i, r)
    @printf("%04d %20s <= %-20s\n", 
            i, short_typeof(p) * "/" * short_typeof(s), short_typeof(r))
end



# evaluation without a cache (memoization)

type NoCache<:Config
    source::Any
    debug::Bool
    stack::Stack  # DataStructures.Stack has a dumb type
    NoCache(source; debug=false) = new(source, debug,
                                       Stack(Tuple{Matcher,State}))
end

function dispatch(k::NoCache, e::Execute)
    push!(k.stack, (e.parent, e.state_parent))
    if k.debug 
        debug(k, e.parent, e.state_parent, e.child, e.state_child, e.iter, false)
    end
    execute(k, e.child, e.state_child, e.iter)
end

function dispatch(k::NoCache, r::Response,)
    (parent, state_parent) = pop!(k.stack)
    if k.debug 
        debug(k, parent, state_parent, r.state_child, r.iter, r.result)
    end
    response(k, parent, state_parent, r.state_child, r.iter, r.result)
end



# evaluation with a complete cache (all intermediate results memoized)

typealias Key @compat Tuple{Matcher,State,Any}  # final type is iter

type Cache<:Config
    source::Any
    debug::Bool
    stack  # DataStructures.Stack has a dumb type
    cache::Dict{Key,Message}
    Cache(source; debug=false) = new(source, debug, 
                                     Stack(Tuple{Matcher,State,Key}),
                                     Dict{Key,Message}())
end

function dispatch(k::Cache, e::Execute)
    key = (e.child, e.state_child, e.iter)
    push!(k.stack, (e.parent, e.state_parent, key))
    cached = haskey(k.cache, key)
    if k.debug 
        debug(k, e.parent, e.state_parent, e.child, e.state_child, e.iter, cached)
    end
    if haskey(k.cache, key)
        k.cache[key]
    else
        execute(k, e.child, e.state_child, e.iter)
    end
end

function dispatch(k::Cache, r::Response)
    parent, state_parent, key = pop!(k.stack)
    k.cache[key] = r
    if k.debug 
        debug(k, parent, state_parent, r.state_child, r.iter, r.result)
    end
    response(k, parent, state_parent, r.state_child, r.iter, r.result)
end



# TODO - some kind of MRU cache?



# a dummy matcher used by the parser

immutable Root<:Delegate end

immutable RootState<:DelegateState
    state::State
end

response(k::Config, m::Root, s::State, t::State, i, r::Success) = Response(RootState(t), i, r)
response(k::Config, m::Root, s::State, t::State, i, r::Failure) = Response(DIRTY, i, r)



# the core loop that drives the parser, calling the appropriate dispatch
# functions (above) depending on which Config was used.
# to modify th ebehaviour you can create a new Config sub-type and then
# add your own dispatch functions.

function producer(k::Config, m::Matcher)

    root = Root()
    msg::Message = Execute(root, CLEAN, m, CLEAN, start(k.source))

    while true
        msg = dispatch(k, msg)
        if isempty(k.stack)
            @assert isa(msg, Response)
            if isa(msg.result, Success)
                produce(msg.result.value)
                # my head hurts
                msg = Execute(root, CLEAN, m, msg.state_child.state, start(k.source))
            else
                return
            end
        end
    end

end



# helper functions to generate the parsers from the above

# these assume that any config construct takes a single source argument 
# plus optional keyword args

function make_all(config)
    function f(source, matcher::Matcher; kargs...)
        Task(() -> producer(config(source; kargs...), matcher))
    end
end

function make_one(config)
    function single_result(source, matcher::Matcher; kargs...)
        task = make_all(config)(source, matcher; kargs...)
        result = consume(task)
        if task.state == :done
            throw(ParserException("cannot parse"))
        else
            return result
        end
    end
end



# the default parsers

# we use the cache only when matching multiple results but obviously motivated
# users are free to constuct their own...

parse_all = make_all(Cache)
parse_one = make_one(NoCache)
