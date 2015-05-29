
abstract Matcher
abstract Message
abstract State
abstract Result


immutable Failure<:Result end
FAILURE = Failure()

abstract Success<:Result

immutable Empty<:Success end
EMPTY = Empty()

immutable Value{T}<:Success
    value::T
end

function unSuccess(a::Array{Success,1})
    map(x -> x.value, filter(x -> typeof(x) <: Value, a))
end

=={T}(x::Value{T}, y::Value{T}) = x.value == y.value
hash(x::Value) = hash(x.value)

# parent and state_paprent are popped from the stack.  call is made to
# success(parent, state_parent, child, state_child, iter, source, result)
immutable Response{C<:Matcher,SC<:State,R<:Result}<:Message
    child::C
    state_child::SC
    iter
    result::R
end

# parent and state_parent are pushed to the stack.  call is made to
# execute(child, state_child, iter, source)
immutable Execute{P<:Matcher,SP<:State,C<:Matcher,SC<:State}<:Message
    parent::P
    state_parent::SP
    child::C
    state_child::SC
    iter
end


# the state used on first call
immutable Clean<:State end
CLEAN = Clean()

# the state used when no further calls should be made
immutable Dirty<:State end
DIRTY = Dirty()


# user-generated errors (ie bad input, etc).
# internal errors in the library (bugs) may raise Error
immutable ParserException<:Exception
    msg
end
