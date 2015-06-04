
# some basic definitions for generic matches

execute(k::Config, m, s, i) = error("$m did not expect to be called with state $s")

response(k::Config, m, s, t, i, r) = error("$m did not expect to receive state $s, response $r")

execute(k::Config, m::Matcher, s::Dirty, i) = Response(s, i, FAILURE)



# many matchers delegate to a child, making only slight modifications.
# we can describe the default behaviour just once, here.
# child matchers then need to implement (1) state creation (typically on 
# response) and (2) anything unusual (ie what the matcher actually does)

# assume this has a matcher field
abstract Delegate<:Matcher

# assume this has a state field
abstract DelegateState<:State

execute(k::Config, m::Delegate, s::Clean, i) = Execute(m, s, m.matcher, CLEAN, i)

execute(k::Config, m::Delegate, s::DelegateState, i) = Execute(m, s, m.matcher, s.state, i)

# this avoids re-calling child on backtracking on failure
response(k::Config, m::Delegate, s, t, i, r::Failure) = Response(DIRTY, i, FAILURE)



# various weird things for completeness

immutable Epsilon<:Matcher end

execute(k::Config, m::Epsilon, s::Clean, i) = Response(DIRTY, i, EMPTY)

immutable Insert<:Matcher
    text
end

execute(k::Config, m::Insert, s::Clean, i) = Response(DIRTY, i, Success(m.text))

immutable Dot<:Matcher end

function execute(k::Config, m::Dot, s::Clean, i)
    if done(k.source, i)
        Response(DIRTY, i, FAILURE)
    else
        c, i = next(k.source, i)
        Response(DIRTY, i, Success(c))
    end
end

immutable Fail<:Matcher end

execute(k::Config, m::Fail, s::Clean, i) = Response(DIRTY, i, FAILURE)



# evaluate the sub-matcher, but replace the result with EMPTY

immutable Drop<:Delegate
    matcher::Matcher
end

immutable DropState<:DelegateState
    state::State
end

response(k::Config, m::Drop, s, t, i, rs::Success) = Response(DropState(t), i, EMPTY)



# exact match

immutable Equal<:Matcher
    string
end

function execute(k::Config, m::Equal, s::Clean, i)
    for x in m.string
        if done(k.source, i)
            return Response(DIRTY, i, FAILURE)
        end
        y, i = next(k.source, i)
        if x != y
            return Response(DIRTY, i, FAILURE)
        end
    end
    Response(DIRTY, i, Success(m.string))
end



# repetition

# in both cases (Depth and Breadth) we perform a tree search of all
# possible states (limited by the maximum number of matches), yielding
# when we have a result within the lo/hi range.

abstract Repeat_<:Matcher   # _ to avoid conflict with abstract type in 0.3

ALL = typemax(Int)

abstract RepeatState<:State

function Repeat(m::Matcher, lo, hi; flatten=true, greedy=true)
    if greedy
        Depth(m, lo, hi; flatten=flatten)
    else
        Breadth(m, lo, hi; flatten=flatten)
    end
end
Repeat(m::Matcher, lo; flatten=true, greedy=true) = Repeat(m, lo, lo; flatten=flatten, greedy=greedy)
Repeat(m::Matcher; flatten=true, greedy=true) = Repeat(m, 0, ALL; flatten=flatten, greedy=greedy)


# depth-first (greedy) state and logic

immutable Depth<:Repeat_
    matcher::Matcher
    lo::Integer
    hi::Integer
    flatten::Bool
    Depth(m, lo, hi; flatten=true) = new(m, lo, hi, flatten)
end

# greedy matching is effectively depth first traversal of a tree where:
# * performing an additional match is moving down to a new level 
# * performaing an alternate match (backtrack+match) moves across
# the traversal requires a stack.  the DepthState instances below all
# store that stack - actually three of them.  the results stack is 
# unusual / neat in that it is also what we need to return.

# unfortunately, things are a little more complex, because it's not just
# DFS, but also post-order.  which means there's some extra messing around
# so that the node ordering is correct.

abstract DepthState<:RepeatState

immutable Slurp<:DepthState
    # there's a mismatch in lengths here because the empty results is
    # associated with an iter and state
    results::Array{Value,1} # accumulated.  starts []
    iters::Array{Any,1}     # at the end of the result.  starts [i]
    states::Array{State,1}  # at the end of the result.  starts {CLEAN]
end

immutable DepthYield<:DepthState
    results::Array{Value,1}
    iters::Array{Any,1}
    states::Array{State,1}
end

immutable Backtrack<:DepthState
    results::Array{Value,1}
    iters::Array{Any,1}
    states::Array{State,1}
end

# when first called, create base state and make internal transition

execute(k::Config, m::Depth, s::Clean, i) = execute(k, m, Slurp(Array(Value, 0), [i], State[DIRTY]), i)

# repeat matching until at bottom of this branch (or maximum depth)

max_depth(m::Depth, results) = m.hi == length(results)

function execute(k::Config, m::Depth, s::Slurp, i)
    if max_depth(m, s.results)
        execute(k, m, DepthYield(s.results, s.iters, s.states), i)
    else
        Execute(m, s, m.matcher, CLEAN, i)
    end
end

function response(k::Config, m::Depth, s::Slurp, t, i, r::Success)
    results = Value[s.results..., r.value]
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if max_depth(m, results)
        execute(k, m, DepthYield(results, iters, states), i)
    else
        Execute(m, Slurp(results, iters, states), m.matcher, CLEAN, i)
    end
end

function response(k::Config, m::Depth, s::Slurp, t, i, ::Failure)
    execute(k, m, DepthYield(s.results, s.iters, s.states), i)
end

# yield a result and set state to backtrack

function execute(k::Config, m::Depth, s::DepthYield, i)
    n = length(s.results)
    if n >= m.lo
        if m.flatten
            Response(Backtrack(s.results, s.iters, s.states), s.iters[end], Success(flatten(s.results)))
        else
            Response(Backtrack(s.results, s.iters, s.states), s.iters[end], Success([s.results;]))
        end
    else
        # we need to continue searhcing in case there's some other weird
        # case that gets us back into valid matches
        execute(k, m, Backtrack(s.results, s.iters, s.states), i)
    end
end

# backtrack once and then move down again if possible.  we cannot repeat a
# path because we always advance child state.

function execute(k::Config, m::Depth, s::Backtrack, i)
    if length(s.iters) == 1  # we've exhausted the search space
        Response(DIRTY, i, FAILURE)
    else
        # we need the iter from *before* the result
        Execute(m, Backtrack(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matcher, s.states[end], s.iters[end-1])
    end
end

function response(k::Config, m::Depth, s::Backtrack, t, i, r::Success)
    # backtrack succeeded so move down
    println(s.results)
    println(r.value)
    println(vcat(s.results, r.value))
    x = vcat(s.results, r.value)
    y = vcat(s.iters, i)
    z = vcat(s.states, t)
    println(typeof(x))
    println(typeof(y))
    println(typeof(z))
    println("*********")
    println(Slurp(x, y, z))
    execute(k, m, Slurp(vcat(s.results, r.value), vcat(s.iters, i), vcat(s.states, t)), i)
end

function response(k::Config, m::Depth, s::Backtrack, t, i, ::Failure)
    # we couldn't move down, so yield this point
    execute(k, m, DepthYield(s.results, s.iters, s.states), i)
end


# breadth-first specific state and logic

immutable Breadth<:Repeat_
    matcher::Matcher
    lo::Integer
    hi::Integer
    flatten::Bool
    Breadth(m, lo, hi; flatten=true) = new(m, lo, hi, flatten)
end

# minimal matching is effectively breadth first traversal of a tree where:
# * performing an additional match is moving down to a new level 
# * performaing an alternate match (backtrack+match) moves across
# the traversal requires a queue.  unfortunately, unlike with greedy,
# that means we need to store the entire result for each node.

# on the other hand, because the results are pre-order, the logic is simpler
# than for th egreedy match (wikipedia calls this "level order" so my 
# terminology may be wrong).

immutable Entry
    iter
    state::State
    results::Array{Value,1}
end

abstract BreadthState<:RepeatState

immutable Grow<:BreadthState
    start  # initial iter
    queue::Array{Entry,1}  # this has to be immutable for caching
end

immutable BreadthYield<:BreadthState
    start  # initial iter
    queue::Array{Entry,1}  # this has to be immutable for caching
end

# when first called, create base state and make internal transition

execute(k::Config, m::Breadth, s::Clean, i) = execute(k, m, BreadthYield(i, Entry[Entry(i, CLEAN, [])]), i)

# yield the top state

function execute(k::Config, m::Breadth, s::BreadthYield, i)
    q = s.queue[1]
    n = length(q.results)
    if n >= m.lo
        if m.flatten
            Response(Grow(s.start, s.queue), q.iter, Success(flatten(q.results)))
        else
            Response(Grow(s.start, s.queue), q.iter, Success([q.results;]))
        end
    else
        execute(k, m, Grow(s.start, s.queue), i)
    end
end

# add the next row

function execute(k::Config, m::Breadth, s::Grow, i)
    if length(s.queue[1].results) > m.hi
        Response(DIRTY, s.start, FAILURE)
    else
        Execute(m, s, m.matcher, CLEAN, s.queue[1].iter)
    end
end

response(k::Config, m::Breadth, s::Grow, t, i, r::Success) = Execute(m, Grow(s.start, vcat(s.queue, Entry(i, t, Value[s.queue[1].results..., r.value]))), m.matcher, t, i)

# discard what we have yielded and grown

function response(k::Config, m::Breadth, s::Grow, t, i, r::Failure)
    if (length(s.queue) > 1)
        execute(k, m, BreadthYield(s.start, s.queue[2:end]), i)
    else
        Response(DIRTY, s.start, FAILURE)
    end
end



# match all in a sequence with backtracking

# there are two nearly identical matchers here - the only difference is 
# whether results are merged (Seq/+) or not (And/&).

# we need two different types so that we can define + and & appropriately.  
# to make the user API more conssistent we add flatten to the constructors 
# and choose accordingly.

abstract Series_<:Matcher

function Series(m::Matcher...; flatten=true)
    if flatten
        Seq(m...)
    else
        And(m...)
    end
end

immutable Seq<:Series_
    matchers::Array{Matcher,1}
    Seq(m::Matcher...) = new([m...])
    Seq(m::Array{Matcher,1}) = new(m)
end

serial_success(m::Seq, results) = Success(flatten(results))

immutable And<:Series_
    matchers::Array{Matcher,1}
    And(m::Matcher...) = new([m...])
    And(m::Array{Matcher,1}) = new(m)
end

# copy so that state remains immutable
serial_success(m::And, results) = Success([results;])

immutable SeriesState<:State
    results::Array{Value,1}
    iters::Array{Any,1}
    states::Array{State,1}
end

# when first called, call first matcher

function execute(l::Config, m::Series_, s::Clean, i) 
    if length(m.matchers) == 0
        Response(DIRTY, i, EMPTY)
    else
        Execute(m, SeriesState(Value[], [i], State[]), m.matchers[1], CLEAN, i)
    end
end

# if the final matcher matched then return what we have.  otherwise, evaluate
# the next.

function response(k::Config, m::Series_, s::SeriesState, t, i, r::Success)
    n = length(s.iters)
    results = Value[s.results..., r.value]
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if n == length(m.matchers)
        Response(SeriesState(results, iters, states), i, serial_success(m, results))
    else
        Execute(m, SeriesState(results, iters, states), m.matchers[n+1], CLEAN, i)
    end
end

# if the first matcher failed, fail.  otherwise backtrack

function response(k::Config, m::Series_, s::SeriesState, t, i, r::Failure)
    n = length(s.iters)
    if n == 1
        Response(DIRTY, s.iters[1], FAILURE)
    else
        Execute(m, SeriesState(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matchers[n-1], s.states[end], s.iters[end-1])
    end
end

# try to advance the current match

function execute(k::Config, m::Series_, s::SeriesState, i)
    @assert length(s.states) == length(m.matchers)
    Execute(m, SeriesState(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matchers[end], s.states[end], s.iters[end-1])
end




# backtracked alternates

immutable Alt<:Matcher
    matchers::Array{Matcher,1}
    Alt(matchers::Matcher...) = new([matchers...])
    Alt(matchers::Array{Matcher,1}) = new(matchers)    
end

immutable AltState<:State
    state::State
    iter
    i
end

function execute(k::Config, m::Alt, s::Clean, i)
    if length(m.matchers) == 0
        Response(DIRTY, i, FAILURE)
    else
        execute(k, m, AltState(CLEAN, i, 1), i)
    end
end

function execute(k::Config, m::Alt, s::AltState, i)
    Execute(m, s, m.matchers[s.i], s.state, s.iter)
end

function response(k::Config, m::Alt, s::AltState, t, i, r::Success)
    Response(AltState(t, s.iter, s.i), i, r)
end

function response(k::Config, m::Alt, s::AltState, t, i, r::Failure)
    if s.i == length(m.matchers)
        Response(DIRTY, i, FAILURE)
    else
        execute(k, m, AltState(CLEAN, s.iter, s.i + 1), i)
    end
end



# evaluate the child, but discard values and do not advance the iter

immutable Lookahead<:Delegate
    matcher::Matcher
end

immutable LookaheadState<:DelegateState
    state::State
    iter
end

execute(k::Config, m::Lookahead, s::Clean, i) = Execute(m, LookaheadState(s, i), m.matcher, CLEAN, i)

response(k::Config, m::Lookahead, s, t, i, r::Success) = Response(LookaheadState(t, s.iter), s.iter, EMPTY)



# if the child matches, fail; if the child fails return EMPTY
# no backtracking of the child is supported (i don't understand how it would
# work, but feel free to correct me....)

immutable Not<:Matcher
    matcher::Matcher
end

immutable NotState<:State
    iter
end

execute(k::Config, m::Not, s::Clean, i) = Execute(m, NotState(i), m.matcher, CLEAN, i)

response(k::Config, m::Not, s, t, i, r::Success) = Response(s, s.iter, FAILURE)

response(k::Config, m::Not, s, t, i, r::Failure) = Response(s, s.iter, EMPTY)


# match a regular expression.

# because Regex match against strings, this matcher works only against 
# string sources.

# for efficiency, we need to know the offset where the match finishes.
# we do this by adding r"(.??)" to the end of the expression and using
# the offset from that.

# we also prepend ^ to anchor the match

immutable Pattern<:Matcher
    regex::Regex
    Pattern(r::Regex) = new(Regex("^" * r.pattern * "(.??)"))
    Pattern(s::AbstractString) = new(Regex("^" * s * "(.??)"))
end

function execute(k::Config, m::Pattern, s::Clean, i)
    @assert isa(k.source, AbstractString)
    x = match(m.regex, k.source[i:end])
    if x == nothing
        Response(DIRTY, i, FAILURE)
    else
        Response(DIRTY, i + x.offsets[end] - 1, Success(x.match))
    end
end



# support loops

type Delayed<:Matcher
    matcher::Nullable{Matcher}
    Delayed() = new(Nullable{Matcher}())
end

function execute(k::Config, m::Delayed, s::Dirty, i)
    Response(DIRTY, i, FAILURE)
end

function execute(k::Config, m::Delayed, s::State, i)
    if isnull(m.matcher)
        error("assign to the Delayed() matcher attribute")
    else
        execute(k, get(m.matcher), s, i)
    end
end



# enable debug when in scope of child

immutable Debug<:Delegate
    matcher::Matcher
end

immutable DebugState<:DelegateState
    state::State
    depth::Int
end

execute(k::Config, m::Debug, s::Clean, i) = execute(k, m, DebugState(CLEAN, 0), i)

function execute(k::Config, m::Debug, s::DebugState, i)
    k.debug = true
    Execute(m, DebugState(s.state, s.depth+1), m.matcher, s.state, i)
end

function response(k::Config, m::Debug, s::DebugState, t, i, r::Success)
    if s.depth == 1
        k.debug = false
    end
    Response(DebugState(t, s.depth-1), i, r)
end
    
function response(k::Config, m::Debug, s::DebugState, t, i, r::Failure)
    if s.depth == 2
        k.debug = false
    end
    Response(DIRTY, i, FAILURE)
end
    


# end of stream / string

immutable Eos<:Matcher end

function execute(k::Config, m::Eos, s::Clean, i)
    if done(k.source, i)
        Response(DIRTY, i, EMPTY)
    else
        Response(DIRTY, i, FAILURE)
    end
end


