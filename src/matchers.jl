

# some basic definitions for generic matches

function execute(m, s, i, _)
    error("$m did not expect to be called with state $s")
end

function response(m, s, c, t, i, _, r)
    error("$m did not expect to receive state $s from $c")
end

function execute(m, s::Dirty, i, _)
    Response(m, s, i, FAILURE)
end

immutable ChildState<:State
    state::State
end



# various weird things for completeness

immutable Epsilon<:Matcher end

function execute(m::Epsilon, s::Clean, i, src)
    Response(m, DIRTY, i, EMPTY)
end

immutable Insert<:Matcher
    text
end

function execute(m::Insert, s::Clean, i, src)
    Response(m, DIRTY, i, Value(m.text))
end

immutable Dot<:Matcher end

function execute(m::Dot, s::Clean, i, src)
    if done(src, i)
        Response(m, DIRTY, i, FAILURE)
    else
        c, i = next(src, i)
        Response(m, DIRTY, i, Value(c))
    end
end



# evaluate the sub-matcher, but replace the result with EMPTY

immutable Drop<:Matcher
    matcher::Matcher
end

function execute(m::Drop, s::Clean, i, src)
    Execute(m, s, m.matcher, CLEAN, i)
end

function execute(m::Drop, s::ChildState, i, src)
    Execute(m, s, m.matcher, s.state, i)
end

function response(m::Drop, s, c, t, i, src, r::Success)
    Response(m, ChildState(t), i, EMPTY)
end

function response(m::Drop, s, c, t, i, src, r::Failure)
    Response(m, DIRTY, i, FAILURE)
end



# exact match

immutable Equal<:Matcher
    string
end

function execute(m::Equal, s::Clean, i, src)
    for x in m.string
        if done(src, i)
            return Response(m, DIRTY, i, FAILURE)
        end
        y, i = next(src, i)
        if x != y
            return Response(m, DIRTY, i, FAILURE)
        end
    end
    Response(m, DIRTY, i, Value(m.string))
end



# repetition (greedy and minimal)

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
    results::Array{Success,1}  # accumulated during slurp
    iters::Array{Any,1}    # at the end of the associated result
    states::Array{Any,1}   # at the end of the associated result
end

immutable Yield<:Greedy
    results::Array{Success,1}
    iters::Array{Any,1}
    states::Array{Any,1}
end

immutable Backtrack<:Greedy
    results::Array{Success,1}
    iters::Array{Any,1}
    states::Array{Any,1}
end

immutable Lazy<:RepeatState
end

# when first called, create base state and make internal transition

function execute(m::Repeat, s::Clean, i, src)
    if m.b > m.a
        execute(m, Lazy(), i, src)
    else
        execute(m, Slurp(Array(Success, 0), [i], Any[s]), i, src)
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

function response(m::Repeat, s::Slurp, c, t, i, src, r::Success)
    results = vcat(s.results, r)
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if work_to_do(m, results)
        Execute(m, Slurp(results, iters, states), c, CLEAN, i)
    else
        execute(m, Yield(results, iters, states), i, src)
    end
end

function response(m::Repeat, s::Slurp, c, t, i, src, ::Failure)
    execute(m, Yield(s.results, s.iters, s.states), i, src)
end

# yield a result

# a similar unpack

unpackArray(a) = map(x -> x.value, filter(x -> typeof(x) <: Value, a))

function execute(m::Repeat, s::Yield, i, src)
    n = length(s.results)
    if n >= m.b
        Response(m, Backtrack(s.results, s.iters, s.states), s.iters[end], Value(unpackArray(s.results)))
    else
        Response(m, DIRTY, i, FAILURE)
    end
end

# another result is required, so discard and then advance if possible

function execute(m::Repeat, s::Backtrack, i, src)
    if length(s.iters) < 2  # is this correct?
        Response(m, DIRTY, i, FAILURE)
    else
        # we need the iter from *before* the result
        Execute(m, Backtrack(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matcher, s.states[end], s.iters[end-1])
    end
end

function response(m::Repeat, s::Backtrack, c, t, i, src, r::Success)
    execute(m, Slurp(vcat(s.results, r), vcat(s.iters, i), vcat(s.states, t)), i, src)
end

function response(m::Repeat, s::Backtrack, c, t, i, src, ::Failure)
    execute(m, Yield(s.results, s.iters, s.states), i, src)
end



# the state machine for sequencing two matchers
# in practice, use Seq from sugar.jl, which sweetens this considerably

immutable And<:Matcher
    left::Matcher
    right::Matcher
end

abstract AndState<:State

immutable Left<:AndState
    left_iter
end

immutable Right<:AndState
    left_iter
    left_state::State
    right_iter
    result
end

immutable Both<:AndState
    left_iter
    left_state::State
    right_iter
    right_state::State
    result
end

# on initial entry, save iter then call left
function execute(m::And, s::Clean, i, src)
    Execute(m, Left(i), m.left, CLEAN, i)
end

# if left couldn't match, then we're done
function response(m::And, s::Left, c, t, i, src, ::Failure)
    Response(m, DIRTY, i, FAILURE)
end

# if left did match, then save everything and match the right
function response(m::And, s::Left, c, t, i, src, r::Success)
    Execute(m, Right(s.left_iter, t, i, r), m.right, CLEAN, i)
end

# if right couldn't match, then try again with left
function response(m::And, s::Right, c, t, i, src, ::Failure)
    Execute(m, Left(s.left_iter), m.left, s.left_state, s.left_iter)
end

# if right did match, then save everything and return
function response(m::And, s::Right, c, t, i, src, r::Success)
    Response(m, Both(s.left_iter, s.left_state, s.right_iter, t, s.result), i, Value((s.result, r)))
end

# if we're called with Both state, we need to backtrack on the right
function execute(m::And, s::Both, i, src)
    Execute(m, Right(s.left_iter, s.left_state, s.right_iter, s.result), m.right, s.right_state, s.right_iter)
end



# a dummy matcher used by the parser

immutable Root<:Matcher end
ROOT = Root()