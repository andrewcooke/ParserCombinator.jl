

# fundamental types (expanded below)

abstract Matcher   # nodes in the AST that describe the grammar
abstract Result    # result of a particular matcher's matching
abstract Message   # data sente between trampoline and methods
abstract State     # state associated with Matchers during evaluation



# Result sub-types

# match failed - backtrack
immutable Failure<:Result end
FAILURE = Failure()

# match succeeded (we use an array to handle empty values in a natural way)

typealias Value Array{Any,1}

function flatten(x::Array{Value,1})
    y::Value = vcat(x...)
    return y
end

immutable Success<:Result
    value::Value  # immutable!
    Success(x::Any...) = new(vcat(x...))
end

EMPTY = Success()
==(x::Success, y::Success) = x.value == y.value
hash(x::Success) = hash(x.value)



# Message sub-types

# parent and state_paprent are popped from the stack.  a call is made to
# response(parent, state_parent, child, state_child, iter, source, result)
immutable Response{C<:Matcher,SC<:State,R<:Result}<:Message
    child::C
    state_child::SC
    iter
    result::R
end

# parent and state_parent are pushed to the stack.  a call is made to
# execute(child, state_child, iter, source)
immutable Execute{P<:Matcher,SP<:State,C<:Matcher,SC<:State}<:Message
    parent::P
    state_parent::SP
    child::C
    state_child::SC
    iter
end



# State sub-types

# the state used on first call
immutable Clean<:State end
CLEAN = Clean()

# the state used when no further calls should be made
immutable Dirty<:State end
DIRTY = Dirty()



# other stuff

# user-generated errors (ie bad input, etc).
# internal errors in the library (bugs) may raise Error
immutable ParserException<:Exception
    msg
end
