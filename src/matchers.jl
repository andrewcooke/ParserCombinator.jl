

# some basic definitions for generic matches

execute(m, s, i, _) = error("$m did not expect to be called with state $s")

response(m, s, t, i, _, r) = error("$m did not expect to receive state $s from $c")

execute(m::Matcher, s::Dirty, i, _) = Response(s, i, FAILURE)



# many matchers delegate to a child, making only slight modifications.
# we can describe the default behaviour just once, here.
# child matchers then need to implement (1) state creation (typically on 
# response) and (2) anything unusual (ie what the matcher actually does)

# assume this has a matcher field
abstract Delegate<:Matcher

# assume this has a state field
abstract DelegateState<:State

execute(m::Delegate, s::Clean, i, src) = Execute(m, s, m.matcher, CLEAN, i)

execute(m::Delegate, s::DelegateState, i, src) = Execute(m, s, m.matcher, s.state, i)

# this avoids re-calling child on backtracking on failure
response(m::Delegate, s, t, i, src, r::Failure) = Response(DIRTY, i, FAILURE)



# various weird things for completeness

immutable Epsilon<:Matcher end

execute(m::Epsilon, s::Clean, i, src) = Response(DIRTY, i, EMPTY)

immutable Insert<:Matcher
    text
end

execute(m::Insert, s::Clean, i, src) = Response(DIRTY, i, Success(m.text))

immutable Dot<:Matcher end

function execute(m::Dot, s::Clean, i, src)
    if done(src, i)
        Response(DIRTY, i, FAILURE)
    else
        c, i = next(src, i)
        Response(DIRTY, i, Success(c))
    end
end



# evaluate the sub-matcher, but replace the result with EMPTY

immutable Drop<:Delegate
    matcher::Matcher
end

immutable DropState<:DelegateState
    state::State
end

response(m::Drop, s, t, i, src, rs::Success) = Response(DropState(t), i, EMPTY)



# exact match

immutable Equal<:Matcher
    string
end

function execute(m::Equal, s::Clean, i, src)
    for x in m.string
        if done(src, i)
            return Response(DIRTY, i, FAILURE)
        end
        y, i = next(src, i)
        if x != y
            return Response(DIRTY, i, FAILURE)
        end
    end
    Response(DIRTY, i, Success(m.string))
end



# repetition (greedy and minimal)
# Repeat(m, hi, lo) is greedy; Repeat(m, lo, hi) is lazy

immutable Repeat<:Matcher
    matcher::Matcher
    a::Integer
    b::Integer
end

abstract RepeatState<:State

abstract Greedy<:RepeatState

immutable Slurp<:Greedy
    # there's a mismatch in lengths here because the empty results is
    # associated with an iter and state
    results::Array{Value,1}  # accumulated during slurp
    iters::Array{Any,1}      # at the end of the associated result
    states::Array{State,1}     # at the end of the associated result
end

immutable Yield<:Greedy
    results::Array{Value,1}
    iters::Array{Any,1}
    states::Array{State,1}
end

immutable Backtrack<:Greedy
    results::Array{Value,1}
    iters::Array{Any,1}
    states::Array{State,1}
end

immutable Lazy<:RepeatState
end

# when first called, create base state and make internal transition

function execute(m::Repeat, s::Clean, i, src)
    if m.b > m.a
        error("lazy repeat not yet supported")
        execute(m, Lazy(), i, src)
    else
        execute(m, Slurp(Array(Value, 0), [i], Any[s]), i, src)
    end
end

# match until complete

work_to_do(m::Repeat, results) = m.a > length(results)

function execute(m::Repeat, s::Slurp, i, src)
    if work_to_do(m, s.results)
        Execute(m, s, m.matcher, CLEAN, i)
    else
        execute(m, Yield(s.results, s.iters, s.states), i, src)
    end
end

function response(m::Repeat, s::Slurp, t, i, src, r::Success)
    results = Value[s.results..., r.value]
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if work_to_do(m, results)
        Execute(m, Slurp(results, iters, states), m.matcher, CLEAN, i)
    else
        execute(m, Yield(results, iters, states), i, src)
    end
end

function response(m::Repeat, s::Slurp, t, i, src, ::Failure)
    execute(m, Yield(s.results, s.iters, s.states), i, src)
end

# yield a result

function execute(m::Repeat, s::Yield, i, src)
    n = length(s.results)
    if n >= m.b
        Response(Backtrack(s.results, s.iters, s.states), s.iters[end], Success(flatten(s.results)))
    else
        Response(DIRTY, i, FAILURE)
    end
end

# another result is required, so discard and then advance if possible

function execute(m::Repeat, s::Backtrack, i, src)
    if length(s.iters) < 2  # is this correct?
        Response(DIRTY, i, FAILURE)
    else
        # we need the iter from *before* the result
        Execute(m, Backtrack(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matcher, s.states[end], s.iters[end-1])
    end
end

function response(m::Repeat, s::Backtrack, t, i, src, r::Success)
    execute(m, Slurp(Array{Value}[s.results... r.value], vcat(s.iters, i), vcat(s.states, t)), i, src)
end

function response(m::Repeat, s::Backtrack, t, i, src, ::Failure)
    execute(m, Yield(s.results, s.iters, s.states), i, src)
end

# see sugar.jl for [] syntax support

Star(m::Matcher) = m[0:end]
Plus(m::Matcher) = m[1:end]



# match all in a sequence with backtracking

immutable Seq<:Matcher
    matchers::Array{Matcher,1}
    Seq(matchers::Matcher...) = new([matchers...])
    Seq(matchers::Array{Matcher,1}) = new(matchers)    
end
    
immutable SeqState<:State
    results::Array{Value,1}
    iters::Array{Any,1}
    states::Array{State,1}
end

# when first called, call first matcher

function execute(m::Seq, s::Clean, i, src) 
    if length(m.matchers) == 0
        Response(DIRTY, i, EMPTY)
    else
        Execute(m, SeqState(Value[], [i], State[]), m.matchers[1], CLEAN, i)
    end
end

# if the final matcher matched then return what we have.  otherwise, evaluate
# the next.

function response(m::Seq, s::SeqState, t, i, src, r::Success)
    n = length(s.iters)
    results = Value[s.results..., r.value]
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if n == length(m.matchers)
        Response(SeqState(results, iters, states), i, Success(flatten(results)))
    else
        Execute(m, SeqState(results, iters, states), m.matchers[n+1], CLEAN, i)
    end
end

# if the first matcher failed, fail.  otherwise backtrack

function response(m::Seq, s::SeqState, t, i, src, r::Failure)
    n = length(s.iters)
    if n == 1
        Response(DIRTY, s.iters[1], FAILURE)
    else
        Execute(m, SeqState(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matchers[n-1], s.states[end], s.iters[end-1])
    end
end

# try to advance the current match

function execute(m::Seq, s::SeqState, i, src)
    @assert length(s.states) == length(m.matchers)
    Execute(m, SeqState(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matchers[end], s.states[end], s.iters[end-1])
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

function execute(m::Alt, s::Clean, i, src)
    if length(m.matchers) == 0
        Response(DIRTY, i, FAILURE)
    else
        execute(m, AltState(CLEAN, i, 1), i, src)
    end
end

function execute(m::Alt, s::AltState, i, src)
    Execute(m, s, m.matchers[s.i], s.state, s.iter)
end

function response(m::Alt, s::AltState, t, i, src, r::Success)
    Response(AltState(t, s.iter, s.i), i, r)
end

function response(m::Alt, s::AltState, t, i, src, r::Failure)
    if s.i == length(m.matchers)
        Response(DIRTY, i, FAILURE)
    else
        execute(m, AltState(CLEAN, s.iter, s.i + 1), i, src)
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

execute(m::Lookahead, s::Clean, i, src) = Execute(m, LookaheadState(s, i), m.matcher, CLEAN, i)

response(m::Lookahead, s, t, i, r::Success) = Response(LooakheadState(t, s.iter), s.iter, EMPTY)



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

function execute(m::Pattern, s::Clean, i, src)
    error("Pattern matcher works only with strings")
end

function execute(m::Pattern, s::Clean, i, src::AbstractString)
    x = match(m.regex, src[i:end])
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

function execute(m::Delayed, s::Dirty, i, src)
    Response(DIRTY, i, FAILURE)
end

function execute(m::Delayed, s::State, i, src)
    if isnull(m.matcher)
        error("assign to the Delayed() matcher attribute")
    else
        execute(get(m.matcher), s, i, src)
    end
end



# end of stream / string

immutable Eos<:Matcher end

function execute(m::Eos, s::Clean, i, src)
    if done(src, i)
        Response(DIRTY, i, EMPTY)
    else
        Response(DIRTY, i, FAILURE)
    end
end


