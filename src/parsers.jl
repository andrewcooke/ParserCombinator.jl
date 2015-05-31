
# all subtypes must have attributes:
#  source
#  debug::bool
#  stack
# and approriate dispatch functions

abstract Config


# evaluation without a cache (memoization)

type NoCache<:Config
    source::Any
    debug::Bool
    stack  # DataStructures.Stack has a dumb type
    NoCache(source; debug=false) = new(source, debug,
                                       Stack(Tuple{Matcher,State}))
end

function dispatch(c::NoCache, e::Execute)
    push!(c.stack, (e.parent, e.state_parent))
    execute(e.child, e.state_child, e.iter, c.source)
end

function dispatch(c::NoCache, r::Response,)
    (parent, state_parent) = pop!(c.stack)
    response(parent, state_parent, r.child, r.state_child, r.iter, c.source, r.result)
end


# evaluation with a complete cache (all intermediate results memoized)

typealias Key Tuple{Matcher,State,Any}  # final type is iter

type Cache<:Config
    source::Any
    debug::Bool
    stack  # DataStructures.Stack has a dumb type
    cache::Dict{Key,Message}
    Cache(source; debug=false) = new(source, debug, 
                                     Stack(Tuple{Matcher,State,Key}),
                                     Dict{Key,Message}())
end

function dispatch(c::Cache, e::Execute)
    key = (e.child, e.state_child, e.iter)
    push!(c.stack, (e.parent, e.state_parent, key))
    if haskey(c.cache, key)
        c.cache[key]
    else
        execute(e.child, e.state_child, e.iter, c.source)
    end
end

function dispatch(c::Cache, r::Response)
    parent, state_parent, key = pop!(c.stack)
    c.cache[key] = r
    response(parent, state_parent, r.child, r.state_child, r.iter, c.source, r.result)
end


# TODO - some kind of MRU cache?


# a dummy matcher used by the parser

immutable Root<:Delegate end

immutable RootState<:DelegateState
    state::State
end

response(m::Root, s::State, c::Matcher, t::State, i, src, r::Success) = Response(m, RootState(t), i, r)
response(m::Root, s::State, c::Matcher, t::State, i, src, r::Failure) = Response(m, DIRTY, i, r)

function producer(c::Config, m::Matcher)

    root = Root()
    msg::Message = Execute(root, CLEAN, m, CLEAN, start(c.source))

    while true
        msg = dispatch(c, msg)
        if isempty(c.stack)
            @assert isa(msg, Response)
            if isa(msg.result, Success)
                produce(msg.result.value)
                # my head hurts
                msg = Execute(root, CLEAN, m, msg.state_child.state, start(c.source))
            else
                return
            end
        end
    end

end


# these assume that any config construct takes a single source argument 
# plus optional keyword args

function make_all(config)
    function f(source, matcher::Matcher; kargs...)
        Task(() -> producer(config(source; kargs...), matcher))
    end
end

function make_one(config)
    function f(source, matcher::Matcher; kargs...)
        task = make_all(config)(source, matcher; kargs...)
        result = consume(task)
        if task.state == :done
            throw(ParserException("cannot parse"))
        else
            return result
        end
    end
end


# by default, we use the cache only when matching multiple results
# but obviously motivated users are free to constuct their own...

parse_all = make_all(Cache)
parse_one = make_one(NoCache)
