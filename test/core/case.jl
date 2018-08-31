
# we need to import these so that we can extend them
import ParserCombinator: execute, success, failure
# defines hash() and == for us
using AutoHashEquals

# a simple example of a matcher that calls a sub-matcher, gets the result, and
# capitalizes the first letter found.  so it expects to receive a string.

# much of the work is already done for us by the Delegate related code in
# matchers.jl.  to use that, we need to follow the conventions of having a
# matcher with a matcher field and a state with a state field (they can have
# more fields - those are the minimal requirements).

# every matcher has a name field, which by default is the name of the matcher
# (using @with_names changes this to the variable name - see calc.jl)
@auto_hash_equals mutable struct Case<:Delegate
    name::Symbol
    matcher::Matcher
    Case(matcher) = new(:Case, matcher)
end

struct CaseState<:DelegateState
    state::State
end


# the Delegate code handles the initial call (with CLEAN), and failure.  all
# we need to do is add handling for success

function success(k::Config, m::Case, s, t, i, r::Value)
    # we don't care about the old state for this matcher (s), but we need to
    # save the child state (t), so that it can be used in backtracking.
    new_s = CaseState(t)
    # get the string contents from the child matcher
    # (nicer code would check this was a list containing a single string)
    contents::AbstractString = r[1]
    new_contents = uppercase(contents[1:1]) * contents[2:end]
    # and build the response from this matcher (see types.jl)
    Success(new_s, i, Any[new_contents])
end

@testset "case" begin

# now let's test that
@test parse_one("foo", Case(p".*")) == ["Foo"]

# to see what's happening in more detail, add debug logging:
@test parse_dbg("foo", Trace(Case(p".*"))) == ["Foo"]
# which gives
#  1:foo        00 Trace->Case
#  1:foo        01  Case->Pattern
#  4:           01  Case<-["foo"]
#  4:           00 Trace<-["Foo"]
# and we can see that Case calls Pattern, as expected; that the Pattern
# returns foo; and that Case transforms that to Foo.

println("case ok")

end
