

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

abstract Greedy<:RepeatState

immutable Slurp<:RepeatState
    results::Array{Any,1}
    iters::Array{Any,1}
    from::Hdr
end

immutable Retreat<:RepeatState
    results::Array{Any,1}
    iters::Array{Any,1}
end

immutable Lazy<:RepeatState
end
Lazy(from::Hdr) = Lazy()

# when first called, create base state and re-call
function match(to::Hdr{Repeat,Clean}, from::Hdr, call::Call, _)
    if to.matcher.b > to.matcher.a
        replace(to, Lazy(from)), from, call
    else
        replace(to, Slurp(Array{Any,1}(), [call.iter], from)), from, call
    end
end

work_to_do(matcher::Repeat, results) = matcher.a > length(results)

function match(to::Hdr{Repeat,Slurp}, from::Hdr, call::Call, _)
    if work_to_do(to.matcher, to.state.results)
        println("repeat: match")
        Hdr(to.matcher.matcher, CLEAN), to, call
    else
        println("no need to match")
        s = to.state
        replace(to, Retreat(s.results, s.iters)), s.from, call
    end
end

function match(to::Hdr{Repeat,Slurp}, from::Hdr, success::Success, _)
    results = vcat(to.state.results, success.result)
    iters = vcat(to.state.iters, success.iter)
    if work_to_do(to.matcher, results)
        println("match another")
        # reset state to CLEAN because this is a new iter (presumably?)
        clean(from), replace(to, Slurp(results, iters, to.state.from)), Call(success.iter)
    else
        println("all matched $results")
        replace(to, Retreat(results, iters)), to.state.from, Call(success.iter)
    end
end

function match(to::Hdr{Repeat,Slurp}, from::Hdr, fail::Fail, _)
    s = to.state
    replace(to, Retreat(s.results, s.iters)), s.from, Call(fail.iter)
end

function match(to::Hdr{Repeat,Retreat}, from::Hdr, call::Call, _)
    s, m = to.state, to.matcher
    c = length(s.results)
    if c >= m.b
        if c > 0
            println("trimming $(s.results) $(s.iters)")
            results, iters = s.results[1:end-1], s.iters[1:end-1]
            from, replace(to, Retreat(results, iters)), Success(s.iters[end], s.results)
        else
            from, dirty(to), Success(s.iters[end], s.results)
        end
    else
        from, dirty(to), Fail(call.iter)
    end
end


immutable And<:Matcher
    left::Matcher
    right::Matcher
end

abstract AndState<:State

immutable Left<:AndState
    from::Hdr
    left_iter
end

immutable Right<:AndState
    from::Hdr
    left_iter
    left_state::State
    right_iter
    result
end

immutable Both<:AndState
    from::Hdr
    left_iter
    left_state::State
    right_iter
    right_state::State
    result
end

# TODO - constructors to simplify building from prev state

# on initial entry, save iter and from, then call left
function match(to::Hdr{And,Clean}, from::Hdr, call::Call, _)
    s, m = to.state, to.matcher
    println("and: match on left")
    Hdr(m.left, CLEAN), replace(to, Left(from, call.iter)), call
end

# if left couldn't match, then we're done
function match(to::Hdr{And,Left}, from::Hdr, fail::Fail, _)
    println("and: give up")
    to.state.from, dirty(to), fail
end

# if left did match, then save everything and match the right
function match(to::Hdr{And,Left}, from::Hdr, success::Success, _)
    s, m = to.state, to.matcher
    println("and: match on right from $(success.iter)")
    Hdr(m.right, CLEAN), replace(to, Right(s.from, success.iter, from.state, success.iter, success.result)), Call(success.iter)
end

# if right couldn't match, then try again with left
function match(to::Hdr{And,Right}, from::Hdr, fail::Fail, _)
    s, m = to.state, to.matcher
    println("and: backtrack on left")
    Hdr(m.left, s.left_state), replace(to, Left(s.from, s.left_iter)), Call(s.left_iter)
end

# if right did match, then save everything and return
function match(to::Hdr{And,Right}, from::Hdr, success::Success, _)
    s, m = to.state, to.matcher
    println("and: result $(s.result) $(success.result)")
    s.from, replace(to, Both(s.from, s.left_iter, s.left_state, success.iter, from.state, s.result)), Success(success.iter, (s.result, success.result))
end

# if we're called with Both state, we need to backtrack on the right
function match(to::Hdr{And,Both}, from::Hdr, call::Call, _)
    s, m = to.state, to.matcher
    println("and: backtrack on right")
    Hdr(m.right, s.right_state), replace(to, Right(s.from, s.left_iter, s.left_state, s.right_iter, s.result)), Call(s.right_iter)
end


immutable Root<:Matcher end
ROOT = Root()
