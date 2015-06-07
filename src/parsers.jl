
# TODO - return config too, so that debug can return calls made etc


# this works for all configs defined so far

parent(k::Config) = k.stack[end][1]


# evaluation without a cache (memoization)

type NoCache<:Config
    source::Any
    @compat stack::Array{Tuple{Matcher, State},1}
    @compat NoCache(source) = new(source, Array(Tuple{Matcher,State}, 0))
end

function dispatch(k::NoCache, e::Execute)
    push!(k.stack, (e.parent, e.state_parent))
    execute(k, e.child, e.state_child, e.iter)
end

function dispatch(k::NoCache, r::Response)
    (parent, state_parent) = pop!(k.stack)
    response(k, parent, state_parent, r.state_child, r.iter, r.result)
end


# evaluation with a complete cache (all intermediate results memoized)

@compat typealias Key Tuple{Matcher,State,Any}  # final type is iter

type Cache<:Config
    source::Any
    @compat stack::Array{Tuple{Matcher,State,Key}}
    cache::Dict{Key,Message}
    @compat Cache(source) = new(source, Array(Tuple{Matcher,State,Key}, 0), Dict{Key,Message}())
end

function dispatch(k::Cache, e::Execute)
    key = (e.child, e.state_child, e.iter)
    push!(k.stack, (e.parent, e.state_parent, key))
    cached = haskey(k.cache, key)
    if haskey(k.cache, key)
        k.cache[key]
    else
        execute(k, e.child, e.state_child, e.iter)
    end
end

function dispatch(k::Cache, r::Response)
    parent, state_parent, key = pop!(k.stack)
    k.cache[key] = r
    response(k, parent, state_parent, r.state_child, r.iter, r.result)
end



# TODO - some kind of MRU cache?



# a dummy matcher used by the parser

type Root<:Delegate 
    name::Symbol
    Root() = new(:Root)
end

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

function make_all(config; kargs_make...)
    function multiple_results(source, matcher::Matcher; kargs_parse...)
        function startup()
            kargs = vcat(kargs_make, kargs_parse)
            k = config(source; kargs...)
            producer(k, matcher)
        end
        Task(startup)
    end
end

function make_one(config; kargs_make...)
    function single_result(source, matcher::Matcher; kargs_parse...)
        task = make_all(config, kargs_make...)(source, matcher; kargs_parse...)
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
