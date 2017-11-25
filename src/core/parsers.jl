

# the main loop for the trampoline is parameterised over the Config
# type.  this lets us implement different semantics by simply changing
# the provided Config subtype (and implementing the appropriate
# dispatch() functions, etc).


# this works for most configs
parent(k::Config) = k.stack[end][1]


# evaluation without a cache (memoization)

mutable struct NoCache{S,I}<:Config{S,I}
    source::S
    stack::Vector{Tuple{Matcher, State}}
end
NoCache(source; kargs...) = NoCache(source, Vector{Tuple{Matcher,State}}())

function dispatch(k::NoCache, e::Execute)
    push!(k.stack, (e.parent, e.parent_state))
    try
        execute(k, e.child, e.child_state, e.iter)
    catch x
        isa(x, FailureException) ? FAILURE : rethrow()
    end
end

function dispatch(k::NoCache, s::Success)
    (parent, parent_state) = pop!(k.stack)
    try
        success(k, parent, parent_state, s.child_state, s.iter, s.result)
    catch x
        isa(x, FailureException) ? FAILURE : rethrow()
    end
end

function dispatch(k::NoCache, f::Failure)
    (parent, parent_state) = pop!(k.stack)
    try
        failure(k, parent, parent_state)
    catch x
        isa(x, FailureException) ? FAILURE : rethrow()
    end
end


# evaluation with a complete cache (all intermediate results memoized)

const Key{I} = Tuple{Matcher,State,I}

mutable struct Cache{S,I}<:Config{S,I}
    source::S
    stack::Vector{Tuple{Matcher,State,Key{I}}}
    cache::Dict{Key{I},Message}
end
Cache(source; kargs...) = Cache(source, Vector{Tuple{Matcher,State,Key{I}}}(), Dict{Key{I},Message}())

function dispatch(k::Cache, e::Execute)
    key = (e.child, e.child_state, e.iter)
    push!(k.stack, (e.parent, e.parent_state, key))
    if haskey(k.cache, key)
        k.cache[key]
    else
        try
            execute(k, e.child, e.child_state, e.iter)
        catch x
            isa(x, FailureException) ? FAILURE : rethrow()
        end
    end
end

function dispatch(k::Cache, s::Success)
    parent, parent_state, key = pop!(k.stack)
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

function dispatch(k::Cache, f::Failure)
    parent, parent_state, key = pop!(k.stack)
    try
        k.cache[key] = f
    catch x
        isa(x, CacheException) ? nothing : rethrow()
    end
    try
        failure(k, parent, parent_state)
    catch x
        isa(x, FailureException) ? FAILURE : rethrow()
    end
end



# TODO - some kind of MRU cache?



# a dummy matcher used by the parser

mutable struct Root<:Delegate 
    name::Symbol
    Root() = new(:Root)
end

struct RootState<:DelegateState
    state::State
end

success(k::Config, m::Root, s::State, t::State, i, r::Value) = Success(RootState(t), i, r)
failure(k::Config, m::Root, s::State) = FAILURE


# the core loop that drives the parser, calling the appropriate dispatch
# functions (above) depending on which Config was used.
# to modify the behaviour you can create a new Config subtype and then
# add your own dispatch functions.

function producer(k::Config, m::Matcher; debug=false)

    root = Root()
    msg::Message = Execute(root, CLEAN, m, CLEAN, start(k.source))

    try

        while true
            msg = dispatch(k, msg)
            if isempty(k.stack)
                if isa(msg, Execute)
                    error("Unexpected execute message")
                elseif isa(msg, Success)
                    produce(msg.result)
                    # my head hurts
                    msg = Execute(root, CLEAN, m, msg.child_state.state, start(k.source))
                else
                    break
                end
            end
        end
        
    catch x
        if (debug)
            println("debug was set, so showing error from inside task")
            println(x)
            Base.show_backtrace(STDOUT, catch_backtrace())
        end
        throw(x)
    end

end



# helper functions to generate the parsers from the above

# these assume that any config construct takes a single source argument 
# plus optional keyword args

function make{S}(config, source::S, matcher; debug=false, kargs...)
    I = typeof(start(source))
    k = config{S,I}(source; debug=debug, kargs...)
    (k, Task(() -> producer(k, matcher; debug=debug)))
end

function make_all(config; kargs_make...)
    function multiple_results(source, matcher::Matcher; kargs_parse...)
        kargs = vcat(kargs_make, kargs_parse)
        make(config, source, matcher; kargs...)[2]
    end
end

function once(task)
    result = consume(task)
    if task.state == :done
        throw(ParserException("cannot parse"))
    else
        return result
    end
end

function make_one(config; kargs_make...)
    function single_result(source, matcher::Matcher; kargs_parse...)
        kargs = vcat(kargs_make, kargs_parse)
        once(make(config, source, matcher; kargs...)[2])
    end
end



# the default parsers

# we use the cache only when matching multiple results but obviously motivated
# users are free to construct their own...

parse_all_cache = make_all(Cache)
parse_all_nocache = make_all(NoCache)
parse_all = parse_all_cache

parse_one_cache = make_one(Cache)
parse_one_nocache = make_one(NoCache)
parse_one = parse_one_nocache

parse_lines(source, matcher; kargs...) = parse_one(LineSource(source), matcher; kargs...)
parse_lines_cache(source, matcher; kargs...) = parse_one_cache(LineSource(source), matcher; kargs...)
