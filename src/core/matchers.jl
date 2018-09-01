

# some basic definitions for generic matches

execute(k::Config, m, s, i) = error("$m did not expect to be called with state $s")
success(k::Config, m, s, t, i, r) = error("$m did not expect to receive state $s, result $r")
failure(k::Config, m, s) = error("$m did not expect to receive state $s, failure")

execute(k::Config, m::Matcher, s::Dirty, i) = FAILURE



# many matchers delegate to a child, making only slight modifications.
# we can describe the default behaviour just once, here.
# child matchers then need to implement (1) state creation (typically on 
# response) and (2) anything unusual (ie what the matcher actually does)

# assume this has a matcher field
abstract type Delegate<:Matcher end

# assume this has a state field
abstract type DelegateState<:State end

execute(k::Config, m::Delegate, s::Clean, i) = Execute(m, s, m.matcher, CLEAN, i)

execute(k::Config, m::Delegate, s::DelegateState, i) = Execute(m, s, m.matcher, s.state, i)

failure(k::Config, m::Delegate, s) = FAILURE



# various weird things for completeness

@auto_hash_equals mutable struct Epsilon<:Matcher
    name::Symbol
    Epsilon() = new(:Epsilon)
end

execute(k::Config, m::Epsilon, s::Clean, i) = Success(DIRTY, i, EMPTY)


@auto_hash_equals mutable struct Insert<:Matcher
    name::Symbol
    text
    Insert(text) = new(:Insert, text)
end

execute(k::Config, m::Insert, s::Clean, i) = Success(DIRTY, i, Any[m.text])


@auto_hash_equals mutable struct Dot<:Matcher
    name::Symbol
    Dot() = new(:Dot)
end

function execute(k::Config, m::Dot, s::Clean, i)
    if iterate(k.source, i) == nothing
        FAILURE
    else
        c, i = iterate(k.source, i)
        Success(DIRTY, i, Any[c])
    end
end


@auto_hash_equals mutable struct Fail<:Matcher
    name::Symbol
    Fail() = new(:Fail)
end

execute(k::Config, m::Fail, s::Clean, i) = FAILURE



# evaluate the sub-matcher, but replace the result with EMPTY

@auto_hash_equals mutable struct Drop<:Delegate
    name::Symbol
    matcher::Matcher
    Drop(matcher) = new(:Drop, matcher)
end

@auto_hash_equals struct DropState<:DelegateState
    state::State
end

success(k::Config, m::Drop, s, t, i, r::Value) = Success(DropState(t), i, EMPTY)



# exact match

@auto_hash_equals mutable struct Equal<:Matcher
    name::Symbol
    string
    Equal(string) = new(:Equal, string)
end

always_print(::Equal) = true
function print_field(m::Equal, ::Type{Val{:string}})
    if isa(m.string, AbstractString)
        "\"$(m.string)\""
    else
        :string
    end
end

function execute(k::Config, m::Equal, s::Clean, i)
    for x in m.string
        if iterate(k.source, i) == nothing
            return FAILURE
        end
        y, i = iterate(k.source, i)
        if x != y
            return FAILURE
        end
    end
    Success(DIRTY, i, Any[m.string])
end



# repetition

# in the first two cases (Depth and Breadth) we perform a tree search
# of all possible states (limited by the maximum number of matches),
# yielding when we have a result within the lo/hi range.

abstract type Repeat_<:Matcher end   # _ to avoid conflict with function in 0.3

ALL = typemax(Int)

abstract type RepeatState<:State end

function Repeat(m::Matcher, lo, hi; flatten=true, greedy=true, backtrack=true)
    if greedy
        backtrack ? Depth(m, lo, hi; flatten=flatten) : Depth!(m, lo, hi; flatten=flatten)
    else
        backtrack ? Breadth(m, lo, hi; flatten=flatten) : Breadth!(m, lo, hi; flatten=flatten)
    end
end
Repeat(m::Matcher, lo; flatten=true, greedy=true, backtrack=true) = Repeat(m, lo, lo; flatten=flatten, greedy=greedy, backtrack=backtrack)
Repeat(m::Matcher; flatten=true, greedy=true, backtrack=true) = Repeat(m, 0, ALL; flatten=flatten, greedy=greedy, backtrack=backtrack)

print_field(m::Repeat_, ::Type{Val{:lo}}) = "lo=$(m.lo)"
print_field(m::Repeat_, ::Type{Val{:hi}}) = "hi=$(m.hi)"
print_field(m::Repeat_, ::Type{Val{:flatten}}) = "flatten=$(m.flatten)"

function repeat_success(m::Repeat_, results::Vector{Value})
    if m.flatten
        flatten(results)
    else
        Any[results...]
    end
end

# depth-first (greedy) state and logic

@auto_hash_equals mutable struct Depth<:Repeat_
    name::Symbol
    matcher::Matcher
    lo::Integer
    hi::Integer
    flatten::Bool
    Depth(m, lo, hi; flatten=true) = new(:Depth, m, lo, hi, flatten)
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

abstract type DepthState<:RepeatState end

# an arbitrary iter to pass to a state where it's not needed (typically from
# failure)
arbitrary(s::DepthState) = s.iters[1]

@auto_hash_equals struct DepthSlurp{I}<:DepthState
    # there's a mismatch in lengths here because the empty results is
    # associated with an iter and state
    results::Vector{Value} # accumulated.  starts []
    iters::Vector{I}       # at the end of the result.  starts [i].
    states::Vector{State}  # at the end of the result.  starts [DIRTY],
                           # since [] at i is returned last.
end

@auto_hash_equals struct DepthYield{I}<:DepthState
    results::Vector{Value}
    iters::Vector{I}
    states::Vector{State}
end

@auto_hash_equals struct DepthBacktrack{I}<:DepthState
    results::Vector{Value}
    iters::Vector{I}
    states::Vector{State}
end

# when first called, create base state and make internal transition

execute(k::Config{S,I}, m::Depth, s::Clean, i::I) where {S,I} = execute(k, m, DepthSlurp{I}(Vector{Value}(), I[i], State[DIRTY]), i)

# repeat matching until at bottom of this branch (or maximum depth)

max_depth(m::Depth, results) = m.hi == length(results)

function execute(k::Config, m::Depth, s::DepthSlurp, i)
    if max_depth(m, s.results)
        execute(k, m, DepthYield(s.results, s.iters, s.states), i)
    else
        Execute(m, s, m.matcher, CLEAN, i)
    end
end

function success(k::Config, m::Depth, s::DepthSlurp, t, i, r::Value)
    results = Value[s.results..., r]
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if max_depth(m, results)
        execute(k, m, DepthYield(results, iters, states), i)
    else
        Execute(m, DepthSlurp(results, iters, states), m.matcher, CLEAN, i)
    end
end

function failure(k::Config, m::Depth, s::DepthSlurp)
    # the iter passed on is arbitrary and unused
    execute(k, m, DepthYield(s.results, s.iters, s.states), arbitrary(s))
end

# yield a result and set state to backtrack

function execute(k::Config, m::Depth, s::DepthYield, unused)
    n = length(s.results)
    if n >= m.lo
        Success(DepthBacktrack(s.results, s.iters, s.states), s.iters[end], repeat_success(m, s.results))
    else
        # we need to continue searching in case there's some other weird
        # case that gets us back into valid matches
        execute(k, m, DepthBacktrack(s.results, s.iters, s.states), arbitrary(s))
    end
end

# backtrack once and then move down again if possible.  we cannot repeat a
# path because we always advance child state.

function execute(k::Config, m::Depth, s::DepthBacktrack, unused)
    if length(s.iters) == 1  # we've exhausted the search space
        FAILURE
    else
        # we need the iter from *before* the result
        Execute(m, DepthBacktrack(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matcher, s.states[end], s.iters[end-1])
    end
end

# backtrack succeeded so move down
function success(k::Config, m::Depth, s::DepthBacktrack, t, i, r::Value)
    execute(k, m, DepthSlurp(Value[s.results..., r], vcat(s.iters, i), vcat(s.states, t)), i)
end

# we couldn't move down, so yield this point
function failure(k::Config, m::Depth, s::DepthBacktrack)
    execute(k, m, DepthYield(s.results, s.iters, s.states), arbitrary(s))
end


# breadth-first specific state and logic

@auto_hash_equals mutable struct Breadth<:Repeat_
    name::Symbol
    matcher::Matcher
    lo::Integer
    hi::Integer
    flatten::Bool
    Breadth(m, lo, hi; flatten=true) = new(:Breadth, m, lo, hi, flatten)
end

# minimal matching is effectively breadth first traversal of a tree where:
# * performing an additional match is moving down to a new level 
# * performaing an alternate match (backtrack+match) moves across
# the traversal requires a queue.  unfortunately, unlike with greedy,
# that means we need to store the entire result for each node.

# on the other hand, because the results are pre-order, the logic is simpler
# than for the greedy match (wikipedia calls this "level order" so my 
# terminology may be wrong).

@auto_hash_equals struct Entry{I}
    iter::I
    state::State
    results::Vector{Value}
end

abstract type BreadthState<:RepeatState end

arbitrary(s::BreadthState) = s.start

@auto_hash_equals struct BreadthGrow{I}<:BreadthState
    start::I  # initial iter
    queue::Vector{Entry{I}}  # this has to be immutable for caching
end

@auto_hash_equals struct BreadthYield{I}<:BreadthState
    start::I  # initial iter
    queue::Vector{Entry{I}}  # this has to be immutable for caching
end

# when first called, create base state and make internal transition

execute(k::Config{S,I}, m::Breadth, s::Clean, i::I) where {S,I} = execute(k, m, BreadthYield{I}(i, Entry{I}[Entry{I}(i, CLEAN, Any[])]), i)

# yield the top state

function execute(k::Config, m::Breadth, s::BreadthYield, unused)
    q = s.queue[1]
    n = length(q.results)
    if n >= m.lo
        Success(BreadthGrow(s.start, s.queue), q.iter, repeat_success(m, q.results))
    else
        execute(k, m, BreadthGrow(s.start, s.queue), unused)
    end
end

# add the next row

function execute(k::Config, m::Breadth, s::BreadthGrow, unused)
    if length(s.queue[1].results) > m.hi
        FAILURE
    else
        Execute(m, s, m.matcher, CLEAN, s.queue[1].iter)
    end
end

success(k::Config, m::Breadth, s::BreadthGrow, t, i, r::Value) = Execute(m, BreadthGrow(s.start, vcat(s.queue, Entry(i, t, Value[s.queue[1].results..., r]))), m.matcher, t, i)

# discard what we have yielded and grown

function failure(k::Config, m::Breadth, s::BreadthGrow)
    if (length(s.queue) > 1)
        execute(k, m, BreadthYield(s.start, s.queue[2:end]), arbitrary(s))
    else
        FAILURE
    end
end


# largest first (greedy) repetition without backtracking of child
# matchers

@auto_hash_equals mutable struct Depth!<:Repeat_
    name::Symbol
    matcher::Matcher
    lo::Integer
    hi::Integer
    flatten::Bool
    Depth!(m, lo, hi; flatten=true) = new(:Depth!, m, lo, hi, flatten)
end

mutable struct DepthSlurp!{I}<:RepeatState
    result::Vector{Value}
    iters::Vector{I}
end
hash(::DepthSlurp!, h::UInt) = throw(CacheException())

arbitrary(s::DepthSlurp!) = s.iters[1]

@auto_hash_equals struct DepthYield!{I}<:RepeatState
    result::Vector{Value}
    iters::Vector{I}
end

execute(k::Config{S,I}, m::Depth!, s::Clean, i::I) where {S,I} = execute(k, m, DepthSlurp!{I}(Value[], I[i]), i)

function execute(k::Config, m::Depth!, s::DepthSlurp!, i)
    if length(s.result) < m.hi
        Execute(m, s, m.matcher, CLEAN, i)
    else
        execute(k, m, DepthYield!(s.result, s.iters), i)
    end
end

function success(k::Config, m::Depth!, s::DepthSlurp!, t::State, i, r::Value)
    push!(s.result, r)
    push!(s.iters, i)
    execute(k, m, s, i)
end

failure(k::Config, m::Depth!, s::DepthSlurp!) = execute(k, m, DepthYield!(s.result, s.iters), arbitrary(s))

function execute(k::Config, m::Depth!, s::DepthYield!, unused)
    if length(s.result) == m.lo
        Success(DIRTY, s.iters[end], repeat_success(m, s.result))
    else
        Success(DepthYield!(s.result[1:end-1], s.iters[1:end-1]), s.iters[end], repeat_success(m, s.result))
    end
end


# smallest first (non-greedy) repetition without backtracking of child
# matchers

@auto_hash_equals mutable struct Breadth!<:Repeat_
    name::Symbol
    matcher::Matcher
    lo::Integer
    hi::Integer
    flatten::Bool
    Breadth!(m, lo, hi; flatten=true) = new(:Breadth!, m, lo, hi, flatten)
end

@auto_hash_equals struct BreadthState!{I}<:RepeatState
    result::Vector{Value}
    iter::I
end

function execute(k::Config, m::Breadth!, s::Clean, i)
    if m.lo == 0
        Success(BreadthState!(Value[], i), i, EMPTY)
    else
        execute(k, m, BreadthState!(Value[], i), i)
    end
end

function execute(k::Config, m::Breadth!, s::BreadthState!, unused)
    if length(s.result) == m.hi
        FAILURE
    else
        Execute(m, s, m.matcher, CLEAN, s.iter)
    end
end

function success(k::Config, m::Breadth!, s::BreadthState!, t::State, i, r::Value)
    result = Value[s.result..., r]
    if length(result) >= m.lo
        Success(BreadthState!(result, i), i, repeat_success(m, result))
    else
        execute(k, m, BreadthState!(result, i), i)
    end
end

failure(k::Config, m::Breadth!, s::BreadthState!) = FAILURE


# match all in a sequence with backtracking

# there are two nearly identical matchers here - the only difference is 
# whether results are merged (Seq/+) or not (And/&).

# we need two different types so that we can define + and & appropriately.  
# to make the user API more conssistent we also define Series (similar to
# Repeat) that takes a flatten argument.  finally, both are so similar
# that they can share the same state.

function Series(m::Matcher...; flatten=true, backtrack=true)
    if flatten
        backtrack ? Seq(m...) : Seq!(m...)
    else
        backtrack ? And(m...) : And!(m...)
    end
end

abstract type Series_<:Matcher end


# first, the backtracking version

@auto_hash_equals mutable struct Seq<:Series_
    name::Symbol
    matchers::Vector{Matcher}
    Seq(m::Matcher...) = new(:Seq, [m...])
    Seq(m::Vector{Matcher}) = new(:Seq, m)
end

serial_success(m::Seq, results::Vector{Value}) = flatten(results)

@auto_hash_equals mutable struct And<:Series_
    name::Symbol
    matchers::Vector{Matcher}
    And(m::Matcher...) = new(:And, Matcher[m...])
    And(m::Vector{Matcher}) = new(:And, m)
end

# copy to get type right (Array{Value,1} -> Array{Any,1})
serial_success(m::And, results::Vector{Value}) = Any[results...]

@auto_hash_equals struct SeriesState{I}<:State
    results::Vector{Value}
    iters::Vector{I}
    states::Vector{State}
end

# when first called, call first matcher

function execute(k::Config, m::Series_, s::Clean, i) 
    if length(m.matchers) == 0
        Success(DIRTY, i, EMPTY)
    else
        Execute(m, SeriesState(Value[], [i], State[]), m.matchers[1], CLEAN, i)
    end
end

# if the final matcher matched then return what we have.  otherwise, evaluate
# the next.

function success(k::Config, m::Series_, s::SeriesState, t, i, r::Value)
    n = length(s.iters)
    results = Value[s.results..., r]
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if n == length(m.matchers)
        Success(SeriesState(results, iters, states), i, serial_success(m, results))
    else
        Execute(m, SeriesState(results, iters, states), m.matchers[n+1], CLEAN, i)
    end
end

# if the first matcher failed, fail.  otherwise backtrack

function failure(k::Config, m::Series_, s::SeriesState)
    n = length(s.iters)
    if n == 1
        FAILURE
    else
        Execute(m, SeriesState(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matchers[n-1], s.states[end], s.iters[end-1])
    end
end

# try to advance the current match

function execute(k::Config, m::Series_, s::SeriesState, i)
    @assert length(s.states) == length(m.matchers)
    Execute(m, SeriesState(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matchers[end], s.states[end], s.iters[end-1])
end


# next, the non-backtracking version

abstract type Series!<:Matcher end

@auto_hash_equals mutable struct Seq!<:Series!
    name::Symbol
    matchers::Vector{Matcher}
    Seq!(m::Matcher...) = new(:Seq!, Matcher[m...])
    Seq!(m::Vector{Matcher}) = new(:Seq!, m)
end

serial_success(m::Seq!, results::Vector{Value}) = flatten(results)

@auto_hash_equals mutable struct And!<:Series!
    name::Symbol
    matchers::Vector{Matcher}
    And!(m::Matcher...) = new(:And!, Matcher[m...])
    ANd!(m::Vector{Matcher}) = new(:And!, m)
end

serial_success(m::And!, results::Vector{Value}) = Any[results...]

@auto_hash_equals struct SeriesState!<:State
    results::Vector{Value}
    i  # index into current alternative
end

execute(k::Config, m::Series!, s::Clean, i) = execute(k, m, SeriesState!(Value[], 0), i)

function execute(k::Config, m::Series!, s::SeriesState!, i)
    if s.i == length(m.matchers)
        return Success(DIRTY, i, serial_success(m, s.results))
    else
        return Execute(m, SeriesState!(s.results, s.i+1), m.matchers[s.i+1], CLEAN, i)
    end
end

success(k::Config, m::Series!, s::SeriesState!, t, i, r::Value) = execute(k, m, SeriesState!(Value[s.results..., r], s.i), i)

failure(k::Config, m::Series!, s::SeriesState!) = FAILURE


# alternatives (these need to be separate matchers so that | works ok)

function Alternatives(m::Matcher...; backtrack=true)
    backtrack ? Alt(m...) : Alt!(m...)
end

abstract type Alternatives_<:Matcher end


# first, the backtracking version

@auto_hash_equals mutable struct Alt<:Alternatives_
    name::Symbol
    matchers::Vector{Matcher}
    Alt(matchers::Matcher...) = new(:Alt, Matcher[matchers...])
    Alt(matchers::Vector{Matcher}) = new(:Alt, matchers)    
end

@auto_hash_equals struct AltState{I}<:State
    state::State
    iter::I
    i::Int  # index into current alternative
end

function execute(k::Config, m::Alt, s::Clean, i)
    if length(m.matchers) == 0
        FAILURE
    else
        execute(k, m, AltState(CLEAN, i, 1), i)
    end
end

function execute(k::Config, m::Alt, s::AltState, i)
    Execute(m, s, m.matchers[s.i], s.state, s.iter)
end

function success(k::Config, m::Alt, s::AltState, t, i, r::Value)
    Success(AltState(t, s.iter, s.i), i, r)
end

function failure(k::Config, m::Alt, s::AltState)
    if s.i == length(m.matchers)
        FAILURE
    else
        execute(k, m, AltState(CLEAN, s.iter, s.i+1), s.iter)
    end
end


# next, the non-backtracking version (for some sense of backtracking -
# it does not re-match children again, but does try other
# alternatives)

@auto_hash_equals mutable struct Alt!<:Alternatives_
    name::Symbol
    matchers::Vector{Matcher}
    Alt!(matchers::Matcher...) = new(:Alt!, Matcher[matchers...])
    Alt!(matchers::Vector{Matcher}) = new(:Alt!, matchers)    
end

@auto_hash_equals struct AltState!{I}<:State
    iter::I
    i::Int  # index into current alternative
end

execute(k::Config, m::Alt!, s::Clean, i) = execute(k, m, AltState!(i, 0), i)

function execute(k::Config, m::Alt!, s::AltState!, i)
    if s.i == length(m.matchers)
        FAILURE
    else
        Execute(m, AltState!(i, s.i+1), m.matchers[s.i+1], CLEAN, i)
    end
end

success(k::Config, m::Alt!, s::AltState!, t, i, r::Value) = Success(s, i, r)

failure(k::Config, m::Alt!, s::AltState!) = execute(k, m, AltState!(s.iter, s.i), s.iter)


# evaluate the child, but discard values and do not advance the iter

@auto_hash_equals mutable struct Lookahead<:Delegate
    name::Symbol
    matcher::Matcher
    Lookahead(matcher) = new(:Lookahead, matcher)
end

always_print(::Delegate) = true

@auto_hash_equals struct LookaheadState<:DelegateState
    state::State
    iter
end

execute(k::Config, m::Lookahead, s::Clean, i) = Execute(m, LookaheadState(s, i), m.matcher, CLEAN, i)

success(k::Config, m::Lookahead, s, t, i, r::Value) = Success(LookaheadState(t, s.iter), s.iter, EMPTY)



# if the child matches, fail; if the child fails return EMPTY
# repeated calls fail (the internal matcher is not backtracked).

@auto_hash_equals mutable struct Not<:Matcher
    name::Symbol
    matcher::Matcher
    Not(matcher) = new(:Not, matcher)
end

@auto_hash_equals struct NotState<:State
    iter
end

execute(k::Config, m::Not, s::Clean, i) = Execute(m, NotState(i), m.matcher, CLEAN, i)

execute(k::Config, m::Not, s::NotState, i) = FAILURE

success(k::Config, m::Not, s::NotState, t, i, r::Value) = FAILURE

failure(k::Config, m::Not, s::NotState) = Success(s, s.iter, EMPTY)



# match a regular expression.

# because Regex match against strings, this matcher works only against 
# string sources.

# for efficiency, we need to know the offset where the match finishes.
# we do this by adding r"(.??)" to the end of the expression and using
# the offset from that.

# we also prepend ^ to anchor the match

@auto_hash_equals mutable struct Pattern<:Matcher
    name::Symbol
    text::AbstractString
    regex::Regex
    groups::Tuple
    Pattern(r::Regex, group::Int...) = new(:Pattern, r.pattern, Regex("^(?:" * r.pattern * ")(.??)"), group)
    Pattern(s::AbstractString, group::Int...) = new(:Pattern, s, Regex("^(?:" * s * ")(.??)"), group)
    Pattern(s::AbstractString, flags::AbstractString, group::Int...) = new(:Pattern. s, Regex("^(?:" * s * ")(.??)", flags), group)
end

print_field(m::Pattern, ::Type{Val{:text}}) = "text=\"$(m.text)\""
print_field(m::Pattern, ::Type{Val{:regex}}) = "regex=r\"$(m.regex.pattern)\""

function execute(k::Config, m::Pattern, s::Clean, i)
    x = match(m.regex, forwards(k.source, i))
    if x == nothing
        FAILURE
    else
        i = discard(k.source, i, x.offsets[end]-1)
        if length(m.groups) > 0
            Success(DIRTY, i, Any[x.captures[i] for i in m.groups])
        else
            Success(DIRTY, i, Any[x.match])
        end
    end
end


# support loops

mutable struct Delayed<:Matcher
    name::Symbol
    matcher::Nullable{Matcher}
    Delayed() = new(:Delayed, Nullable{Matcher}())
end

function print_matcher(m::Delayed, known::Set{Matcher})
    function producer(c::Channel)
        tag = "$(m.name)"
        if (isnull(m.matcher))
            put!(c, "$(tag) OPEN")
        elseif m in known
            put!(c, "$(tag)...")
        else
            put!(c, "$(tag)")
            push!(known, m)
            for (i, line) in enumerate(print_matcher(get(m.matcher), known))
                put!(c, i == 1 ? "`-$(line)" : "  $(line)")
            end
        end
    end
    Channel(c -> producer(c))
end

function execute(k::Config, m::Delayed, s::Dirty, i)
    Response(DIRTY, i, FAILURE)
end

function execute(k::Config, m::Delayed, s::State, i)
    if isnull(m.matcher)
        error("set Delayed matcher")
    else
        execute(k, get(m.matcher), s, i)
    end
end



# end of stream / string

@auto_hash_equals mutable struct Eos<:Matcher
    name::Symbol
    Eos() = new(:Eos)
end

function execute(k::Config, m::Eos, s::Clean, i)
    if iterate(k.source, i) == nothing
        Success(DIRTY, i, EMPTY)
    else
        FAILURE
    end
end


# this is general, but usually not much use with backtracking

mutable struct ParserError{I}<:Exception
    msg::AbstractString
    iter::I
end

@auto_hash_equals mutable struct Error<:Matcher
    name::Symbol
    msg::AbstractString
    Error(msg::AbstractString) = new(:Error, msg)
end

function execute(k::Config, m::Error, s::Clean, i::I) where {I}
    msg = m.msg
    try
        msg = diagnostic(k.source, i, m.msg)
    catch x
        println("cannot generate diagnostic for $(typeof(k.source))")
        # continue with original message
    end
    throw(ParserError{I}(msg, i))
end
