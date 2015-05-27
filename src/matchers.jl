

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
    lo::Integer
    hi::Integer
end

abstract RepeatState<:State

immutable Greedy<:RepeatState
    matches::Array{Any,1}
    prev_count::Int
    child_state::State
    from::Hdr
end
Greedy(from::Hdr) = Greedy(Array(Any, 0), typemax(Int), CLEAN, from)
Greedy(g::Greedy, count::Int) = Greedy(g.matches, count, g.child_state, g.from)
Greedy(g::Greedy, matches::Array) = Greedy(matches, g.prev_count, g.child_state, g.from)

immutable Lazy<:RepeatState
    matches::Array{Any,1}
    prev_count::Int
    child_state::State
    from::Hdr
end
Lazy(from::Hdr) = Lazy(Array(Any, 0), -1, CLEAN, from)

# when first called, create base state and re-call
function match(to::Hdr{Repeat,Clean}, from::Hdr, call::Call, _)
    if to.matcher.hi > to.matcher.lo
        match(replace(to, Lazy(from)), from, call, s)
    else
        match(replace(to, Greedy(from)), from, call, s)
    end
end

# called with valid state, so call child
function match{S<:RepeatState}(to::Hdr{Repeat,S}, from::Hdr, call::Call, _)
    Hdr(to.matcher.matcher, to.state.child_state), to, call
end

# child matcher failed, so return what we have, if it is new
function match(to::Hdr{Repeat,Greedy}, from::Hdr, fail::Fail, _)
    s, m = to.state, to.matcher
    count = length(s.matches)
    if count != s.prev_count && count >= m.lo && count <= m.hi
        s.from, Hdr(m, Greedy(s, count)), Success(fail.iter, s.matches)
    elseif count > m.lo
        matches = s.matches[1:end-1]
        s.from, Hdr(m, Greedy(s, matches)), Success(fail.iter, matches)
    else
        s.from, dirty(to), fail
    end
end

# child matcher succeeded, to extend matches and recall
function match(to::Hdr{Repeat,Greedy}, from::Hdr, success::Success, _)
    s, m = to.state, to.matcher
    # reset state to CLEAN because this is a new iter (presumably?)
    clean(from), Hdr(m, Greedy(s, vcat(s.matches, success.result))), Call(success.iter)
end
