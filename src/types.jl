

# fundamental types (expanded below)

# nodes in the AST that describe the grammar.  all Matcher instacnes must be
# mutable and have an attribute
#  name::Symbol
# which is set automatically to the matcher type by the constructor.
# (re-set to a more useful type inside with_names() - see names.jl)
abstract Matcher

abstract Message   # data sent between trampoline and methods
abstract State     # state associated with Matchers during evaluation

# used to configure the parser.  all Config subtypes must have associated
# dispatch functions (see parser.jl), a parent() function, and have a
# constructor that takes the sorce as first argument and additional arguments
# as keyword.
abstract Config


# important notes on mutability / hash / equality

# 1 - immutable types in julia are not "just" immutable.  they are effectively
# values - they are passed by value.  so do not use "immutable" just because the data should not change.  think about details.

# 2 - immutable types have an automatic equality and hash based on content
# (which is copied).  mutable types have an automatic equality and hash based
# on address.  so default hash and equality for immutable types that contain
# mutable types, and for mutable types, may not be what is required.

# 3 - caching within the parser REQUIRES that bpth Matcher and State instances
# have 'useful' equality and hash values.

# 4 - for matchers, which are created when the grammar is defined, and then
# unchanged, the default hash and equality are likely just fine, even for
# mutable objects (in fact, mutable may be slightly faster since equality is
# just a comparison of an Int64 address, presumably).

# 5 - for states, which often includes mutable result objects, more care is
# needed:

# 5a - whether or not State instances are mutable or immutable, they, and
# their contents, must not change during matching.  so all arrays, for
# example, must be copied when new instances are created with different
# values.

# 5b - structurally identical states must be equal, and hash equally.  this is
# critical for efficienct caching.  so it it likely that custom hash and
# equality methods will be needed (see above and auto.jl).


# defaults for mismatching types and types with no content
==(a::Matcher, b::Matcher) = false
=={T<:Matcher}(a::T, b::T) = true
==(a::State, b::State) = false
=={T<:State}(a::T, b::T) = true


# use an array to handle empty values in a natural way

typealias Value Array{Any,1}

EMPTY = Any[]

function flatten(x::Array{Value,1})
    y::Value = vcat(x...)
    return y
end




# Message sub-types

# use mutable types here since they are packed and unpacked often

# parent and parent_state are popped from the stack.  a call is made to
# success(config, parent, parent_state, child_state, iter, result)
type Success{CS<:State}<:Message
    child_state::CS   # parent to store, passed in next call for backtracking
    iter              # advanced as appropriate
    result::Value     # possibly empty
end

# parent and parent_state are popped from the stack.  a call is made to
# failure(config, parent, parent_state)
type Failure<:Message end
FAILURE = Failure()

# parent and parent_state are pushed to the stack.  a call is made to
# execute(config, child, child_state, iter)
type Execute{P<:Matcher,PS<:State,C<:Matcher,CS<:State}<:Message
    parent::P         # stored by trampoline, added to response
    parent_state::PS  # stored by trampoline, added to response
    child::C          # the matcher to evaluate
    child_state::CS   # needed by for evaluation (was stored by parent)
    iter
end



# State sub-types

# use immutable types because these are simple, magic values

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
