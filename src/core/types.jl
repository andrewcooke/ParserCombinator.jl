

# fundamental types (expanded below)

# nodes in the AST that describe the grammar.  all Matcher instances must be
# mutable and have an attribute
#  name::Symbol
# which is set automatically to the matcher type by the constructor.
# (re-set to a more useful type inside with_names() - see names.jl)
abstract type Matcher end

abstract type Message end   # data sent between trampoline and methods
abstract type State end    # state associated with Matchers during evaluation

# used to configure the parser.  all Config subtypes must have associated
# dispatch functions (see parser.jl), a parent() function, and have a
# constructor that takes the source as first argument and additional arguments
# as keywords.  the type of the source is exposed and if it's a subclass of
# string then the iterator is assumed to be a simple integer index.
abstract type Config{S,I} end


# important notes on mutability / hash / equality

# 1 - immutable types in julia are not "just" immutable.  they are
# effectively values - they are passed by value.  so do not use
# "immutable" just because the data should not change.  think about
# details.

# 2 - immutable types have an automatic equality and hash based on
# content (which is copied).  mutable types have an automatic equality
# and hash based on address.  so default hash and equality for
# immutable types that contain mutable types, and for mutable types,
# may not be what is required.

# 3 - caching within the parser REQUIRES that both Matcher and State
# instances have 'useful' equality and hash values.

# 4 - for matchers, which are created when the grammar is defined, and
# then unchanged, the default hash and equality are likely just fine,
# even for mutable objects (in fact, mutable may be slightly faster
# since equality is just a comparison of an Int64 address,
# presumably).

# 5 - for states, which often includes mutable result objects, more
# care is needed:

# 5a - whether or not State instances are mutable or immutable, they,
# and their contents, must not change during matching.  so all arrays,
# for example, must be copied when new instances are created with
# different values.

# 5b - structurally identical states must be equal, and hash equally.
# this is critical for efficient caching.  so it it likely that
# custom hash and equality methods will be needed (see above and
# auto.jl).


# defaults for mismatching types and types with no content
==(a::Matcher, b::Matcher) = false
==(a::T, b::T) where {T<:Matcher} = true
==(a::State, b::State) = false
==(a::T, b::T) where {T<:State} = true


# use an array to handle empty values in a natural way

const Value = Vector{Any}

const EMPTY = Any[]

function flatten(x::Array{Value,1}) where {Value}
    y::Value = vcat(x...)
    return y
end




# Message sub-types

# use mutable types here since they are packed and unpacked often

# parent and parent_state are popped from the stack.  a call is made to
# success(config, parent, parent_state, child_state, iter, result)
struct Success{CS<:State,I}<:Message
    child_state::CS   # parent to store, passed in next call for backtracking
    iter::I           # advanced as appropriate
    result::Value     # possibly empty
end

# parent and parent_state are popped from the stack.  a call is made to
# failure(config, parent, parent_state)
struct Failure<:Message end
const FAILURE = Failure()

# parent and parent_state are pushed to the stack.  a call is made to
# execute(config, child, child_state, iter)
struct Execute{I}<:Message
    parent::Matcher         # stored by trampoline, added to response
    parent_state::State  # stored by trampoline, added to response
    child::Matcher          # the matcher to evaluate
    child_state::State   # needed by for evaluation (was stored by parent)
    iter::I
end



# State sub-types

# use immutable types because these are simple, magic values

# the state used on first call
struct Clean<:State end
const CLEAN = Clean()

# the state used when no further calls should be made
struct Dirty<:State end
const DIRTY = Dirty()



# other stuff

# user-generated errors (ie bad input, etc).
# internal errors in the library (bugs) may raise Error
struct ParserException<:Exception
    msg
end

# this cannot be cached (thrown by hash())
struct CacheException<:Exception end

# this is equivalent to a matcher returning Failure.  used when source
# information is not available.
abstract type FailureException<:Exception end

const Applicable = Union{Function, DataType}
