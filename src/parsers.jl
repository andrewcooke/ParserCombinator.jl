

# the main loop for the trampoline is parameterised over the Config
# type.  this lets us implement different semantics by simply changing
# the provided Config subtype (and implementing the appropriate
# dispatch() functions, etc).


# this works for most configs
parent(k::Config) = k.stack[end][1]


# evaluation without a cache (memoization)

type NoCache<:Config
    source::Any
    @compat stack::Array{Tuple{Matcher, State},1}
    @compat NoCache(source) = new(source, Array(Tuple{Matcher,State}, 0))
end

function dispatch(k::NoCache, e::Execute)
    push!(k.stack, (e.parent, e.parent_state))
    execute(k, e.child, e.child_state, e.iter)
end

function dispatch(k::NoCache, s::Success)
    (parent, parent_state) = pop!(k.stack)
    success(k, parent, parent_state, s.child_state, s.iter, s.result)
end

function dispatch(k::NoCache, f::Failure)
    (parent, parent_state) = pop!(k.stack)
    failure(k, parent, parent_state)
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
    key = (e.child, e.child_state, e.iter)
    push!(k.stack, (e.parent, e.parent_state, key))
    if haskey(k.cache, key)
        k.cache[key]
    else
        execute(k, e.child, e.child_state, e.iter)
    end
end

function dispatch(k::Cache, s::Success)
    parent, parent_state, key = pop!(k.stack)
    k.cache[key] = s
    success(k, parent, parent_state, s.child_state, s.iter, s.result)
end

function dispatch(k::Cache, f::Failure)
    parent, parent_state, key = pop!(k.stack)
    k.cache[key] = f
    failure(k, parent, parent_state)
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

success(k::Config, m::Root, s::State, t::State, i, r::Value) = Success(RootState(t), i, r)
failure(k::Config, m::Root, s::State) = FAILURE


# the core loop that drives the parser, calling the appropriate dispatch
# functions (above) depending on which Config was used.
# to modify the behaviour you can create a new Config subtype and then
# add your own dispatch functions.

function producer(k::Config, m::Matcher)

    root = Root()
    msg::Message = Execute(root, CLEAN, m, CLEAN, start(k.source))

    try

    while true
        msg = dispatch(k, msg)
        if isempty(k.stack)
            @assert !isa(msg, Execute)
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
        println(x)
        Base.show_backtrace(STDOUT, catch_backtrace())
        throw(x)
    end

end



# helper functions to generate the parsers from the above

# these assume that any config construct takes a single source argument 
# plus optional keyword args

function make(config, source, matcher; kargs...)
    k = config(source; kargs...)
    (k, Task(() -> producer(k, matcher)))
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
