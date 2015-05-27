

function match(to::Hdr, from::Hdr, body::Body, source)
    error("$to did not expect to receive $body from $from")
end

function match{M<:Matcher}(to::Hdr{M,Dirty}, from::Hdr, call::Call, s)
    return from, to, Fail(call.iter)
end


immutable Equal<:Matcher
    string
end

function match(to::Hdr{Equal,Clean}, from::Hdr, call::Call, s)
    iter = call.iter
    for c in to.matcher.string
        if done(s, iter)
            return from, dirty(to), Fail(iter)
        end
        s, iter = next(s, iter)
        if s != c
            return from, dirty(to), Fail(iter)
        end
    end
    from, dirty(to), Success(iter, to.matcher.string)
end


immutable Repeat<:Matcher
    matcher::Matcher
    a::Integer
    b::Integer
end

abstract RepeatState<:State

immutable Greedy<:RepeatState
    results::Array{Any,1}
    prev_count::Int
    child_state::State
    from::Hdr
end
Greedy(from::Hdr) = Greedy(Array(Any, 0), typemax(Int), CLEAN, from)
Greedy(g::Greedy, count::Int) = Greedy(g.results, count, g.child_state, g.from)
Greedy(g::Greedy, results::Array) = Greedy(results, g.prev_count, g.child_state, g.from)

immutable Lazy<:RepeatState
    results::Array{Any,1}
    prev_count::Int
    child_state::State
    from::Hdr
end
Lazy(from::Hdr) = Lazy(Array(Any, 0), -1, CLEAN, from)

# when first called, create base state and re-call
function match(to::Hdr{Repeat,Clean}, from::Hdr, call::Call, _)
    if to.matcher.b > to.matcher.a
        replace(to, Lazy(from)), from, call
    else
        replace(to, Greedy(from)), from, call
    end
end

# for greedy, call child repeatedly until we have all the results we need,
# or the child fails.  then jump to fail handler which also handles 
# backtracking via prev_count

work_to_do(h::Hdr{Repeat,Greedy}) = h.matcher.a > length(h.state.results)

function match(to::Hdr{Repeat,Greedy}, from::Hdr, call::Call, _)
    if work_to_do(to)
        Hdr(to.matcher.matcher, to.state.child_state), to, call
    else
        to, from, Fail(call.iter)
    end
end

function match(to::Hdr{Repeat,Greedy}, from::Hdr, success::Success, _)
    to = replace(to, Greedy(to.state, vcat(to.state.results, success.result)))
    if work_to_do(to)
        # reset state to CLEAN because this is a new iter (presumably?)
        clean(from), to, Call(success.iter)
    else
        to, from, Fail(success.iter)
    end
end

function match(to::Hdr{Repeat,Greedy}, from::Hdr, fail::Fail, _)
    s, m = to.state, to.matcher
    c = length(s.results)
    if c != s.prev_count && c >= m.b && c <= m.a
        s.from, replace(to, Greedy(s, c)), Success(fail.iter, s.results)
    elseif c > m.b  # we can match less
        results = s.results[1:end-1]
        s.from, replace(to, Greedy(s, results)), Success(fail.iter, results)
    else
        s.from, dirty(to), fail
    end
end


immutable And<:Matcher
    left::Matcher
    right::Matcher
end

abstract AndState<:State

immutable Left<:AndState
    iter
    from::Hdr
end

immutable Right<:AndState
    iter
    from::Hdr
    left::State
    result
end

immutable Both<:AndState
    iter
    from::Hdr
    left::State
    result
    right::State
end

# TODO - constructors to simplify building from prev state

# on initial entry, save iter and from, then call left
function match(to::Hdr{And,Clean}, from::Hdr, call::Call, _)
    s, m = to.state, to.matcher
    Hdr(m.left, CLEAN), replace(to, Left(call.iter, from)), call
end

# if left couldn't match, then we're done
function match(to::Hdr{And,Left}, from::Hdr, fail::Fail, _)
    to.state.from, dirty(to), fail
end

# if left did match, then save everything and match the right
function match(to::Hdr{And,Left}, from::Hdr, success::Success, _)
    s, m = to.state, to.matcher
    Hdr(m.right, CLEAN), replace(to, Right(s.iter, s.from, from.state, success.result)), Call(success.iter)
end

# if right couldn't match, then try again with left
function match(to::Hdr{And,Right}, from::Hdr, fail::Fail, _)
    s, m = to.state, to.matcher
    Hdr(m.left, s.left), replace(to, Left(s.iter, s.from)), Call(s.iter)
end

# if right did match, then save everything and return
function match(to::Hdr{And,Right}, from::Hdr, success::Success, _)
    s, m = to.state, to.matcher
    s.from, replace(to, Both(s.iter, s.from, s.left, s.result, from.state)), Success(success.iter, (s.result, success.result))
end

# if we're called with Both state, we need to backtrack on the right
function match(to::Hdr{And,Both}, from::Hdr, call::Call, _)
    s, m = to.state, to.matcher
    Hdr(m.right, s.right), replace(to, Right(s.iter, s.from, s.left, s.result)), call
end
