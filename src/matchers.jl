

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
    if to.matcher.b > to.matcher.a
        replace(to, Lazy(from)), from, call
    else
        replace(to, Greedy(from)), from, call
    end
end

# for greedy, call child repeatedly until we have all the matches we need,
# or the child fails.  then jump to fail handler which also handles 
# backtracking via prev_count

work_to_do(h::Hdr{Repeat,Greedy}) = h.matcher.a > length(h.state.matches)

function match(to::Hdr{Repeat,Greedy}, from::Hdr, call::Call, _)
    if work_to_do(to)
        Hdr(to.matcher.matcher, to.state.child_state), to, call
    else
        to, from, Fail(call.iter)
    end
end

function match(to::Hdr{Repeat,Greedy}, from::Hdr, success::Success, _)
    to = replace(to, Greedy(to.state, vcat(to.state.matches, success.result)))
    if work_to_do(to)
        # reset state to CLEAN because this is a new iter (presumably?)
        clean(from), to, Call(success.iter)
    else
        to, from, Fail(success.iter)
    end
end

function match(to::Hdr{Repeat,Greedy}, from::Hdr, fail::Fail, _)
    s, m = to.state, to.matcher
    c = length(s.matches)
    if c != s.prev_count && c >= m.b && c <= m.a
        s.from, replace(to, Greedy(s, c)), Success(fail.iter, s.matches)
    elseif c > m.b  # we can match less
        matches = s.matches[1:end-1]
        s.from, replace(to, Greedy(s, matches)), Success(fail.iter, matches)
    else
        s.from, dirty(to), fail
    end
end

