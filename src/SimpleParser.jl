
module SimpleParser

using DataStructures.Stack
using Compat
import Base: start

export parse, ParseException, Equal, Repeat

abstract Matcher

abstract Return
immutable Failure<:Return
end
immutable Success<:Return
    isource
    result
end
immutable Bounce<:Return
    isource
    m
    state
end

immutable Equal<:Matcher
    string
end

immutable ParseException<:Exception
    msg
end

function match(m::Equal, source, isource)
    for c in m.string
        if done(source, isource)
            return Failure()
        end
        s, isource = next(source, isource)
        if s != c
            return Failure()
        end
    end
    return Success(isource, m.string)
end

immutable Repeat<:Matcher
    m::Matcher
    n
end

function match(m::Repeat, source, isource)
    return Bounce(isource, m.m, (1, Array(Any, 0)))
end

function resume(m::Repeat, source, isource, state) 
   return Failure()
end

function resume(m::Repeat, source, isource, state, result)
    count, array = state
    push!(array, result)
    if count == m.n
        return Success(isource, array)
    else
        return Bounce(isource, m.m, (count+1, array))
    end
end

function parse(source, m::Matcher)
    stack = Stack(Any)
    isource = start(source)
    ret = match(m, source, isource)
    while true
        if typeof(ret) == Success
            if isempty(stack)
                return ret.result
            else
                (m, state, isource) = pop!(stack)
                ret = resume(m, source, ret.isource, state, ret.result)
            end
        elseif typeof(ret) == Failure
            if isempty(stack)
                throw(ParseException("failed to parse"))
            else
                (m, state, isource) = pop!(stack)
                ret = resume(m, source, isource, state)
            end
        elseif typeof(ret) == Bounce
            push!(stack, (m, ret.state, ret.isource))
            ret = match(ret.m, source, ret.isource)
        else
            error("unexpected return $ret from $ast")
        end
    end
end

end
