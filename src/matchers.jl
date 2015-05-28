
# some basic definitions for generic matches

function call(m, s, i, _)
    error("$m did not expect to be called with $s")
end

function success(m, s, c, t, i, _, r)
    error("$m did not expect to receive $s from success of $c")
end

function failure(m, s, c, t, i, _)
    error("$m did not expect to receive $s from failure of $c")
end

function execute(m, s::Dirty, i, _)
    Failure(m, s, i)
end



# the state machine for equality

immutable Equal<:Matcher
    string
end

function execute(m::Equal, s::Clean, i, src)
    for x in m.string
        if done(src, i)
            return Failure(m, DIRTY, i)
        end
        y, i = next(src, i)
        if x != y
            return Failure(m, DIRTY, i)
        end
    end
    Success(m, DIRTY, i, m.string)
end



# the state machine for repetition (greedy and minimal)

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
    results::Array{Any,1}  # accumulated during slurp
    iters::Array{Any,1}    # at the end of the associated result
    states::Array{Any,1}   # at the end of the associated result
end

immutable Yield<:Greedy
    results::Array{Any,1}
    iters::Array{Any,1}
    states::Array{Any,1}
end

immutable Backtrack<:Greedy
    results::Array{Any,1}
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
        execute(m, Slurp(Array(Any, 0), [i], Any[s]), i, src)
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

function success(m::Repeat, s::Slurp, c, t, i, src, r)
    results = vcat(s.results, r)
    iters = vcat(s.iters, i)
    states = vcat(s.states, t)
    if work_to_do(m, results)
        Execute(m, Slurp(results, iters, states), c, CLEAN, i)
    else
        execute(m, Yield(results, iters, states), i, src)
    end
end

function failure(m::Repeat, s::Slurp, c, t, i, src)
    execute(m, Yield(s.results, s.iters, s.states), i, src)
end

# yield a result

function execute(m::Repeat, s::Yield, i, src)
    n = length(s.results)
    if n >= m.b
        Success(m, Backtrack(s.results, s.iters, s.states), s.iters[end], s.results)
    else
        Failure(m, DIRTY, i)
    end
end

# another result is required, so discard and then advance if possible

function execute(m::Repeat, s::Backtrack, i, src)
    if length(s.results) == 0
        Failure(m, DIRTY, i)
    else
        # we need the iter from *before* the result
        Execute(m, Backtrack(s.results[1:end-1], s.iters[1:end-1], s.states[1:end-1]), m.matcher, s.states[end], s.iters[end-1])
    end
end

function success(m::Repeat, s::Backtrack, c, t, i, src, r)
    execute(m, Slurp(vcat(s.results, r), vcat(s.iters, i), vcat(s.states, t)), i, src)
end

function failure(m::Repeat, s::Backtrack, c, t, i, src)
    execute(m, Yield(s.results, s.iters, s.states), i, src)
end



# the state machine for sequencing two matchers

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
function failure(m::And, s::Left, c, t, i, src)
    Failure(m, DIRTY, i)
end

# if left did match, then save everything and match the right
function success(m::And, s::Left, c, t, i, src, r)
    Execute(m, Right(s.left_iter, t, i, r), m.right, CLEAN, i)
end

# if right couldn't match, then try again with left
function failure(m::And, s::Right, c, t, i, src)
    Execute(m, Left(s.left_iter), m.left, s.left_state, s.left_iter)
end

# if right did match, then save everything and return
function success(m::And, s::Right, c, t, i, src, r)
    Success(m, Both(s.left_iter, s.left_state, s.right_iter, t, s.result), i, (s.result, r))
end

# if we're called with Both state, we need to backtrack on the right
function execute(m::And, s::Both, i, src)
    Execute(m, Right(s.left_iter, s.left_state, s.right_iter, s.result), m.right, s.right_state, s.right_iter)
end


immutable Root<:Matcher end
ROOT = Root()
