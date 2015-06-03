

# fundamental types (expanded below)

abstract Matcher   # nodes in the AST that describe the grammar
abstract Result    # result of a particular matcher's matching
abstract Message   # data sente between trampoline and methods
abstract State     # state associated with Matchers during evaluation

# all subtypes must have attributes:
#  source
#  debug::bool
#  stack
# and approriate dispatch functions
abstract Config



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

# parent and state_parent are popped from the stack.  a call is made to
# response(config, parent, state_parent, state_child, iter, result)
immutable Response{SC<:State,R<:Result}<:Message
    state_child::SC   # parent to store, passed in next call for backtracking
    iter              # original value on failure, or advanced on success
    result::R         # Failure, or Sucess in an Array (possibly empty)
end

# parent and state_parent are pushed to the stack.  a call is made to
# execute(config, child, state_child, iter)
immutable Execute{P<:Matcher,SP<:State,C<:Matcher,SC<:State}<:Message
    parent::P         # stored by trampoline, added to response
    state_parent::SP  # stored by trampoline, added to response
    child::C          # the matcher to evaluate
    state_child::SC   # needed by for evaluation (was stpred by parent)
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
