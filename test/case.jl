
# we need to import these so that we can extend them
import ParserCombinator: execute, response

# a simple example of a matcher that calls a sub-matcher, gets the result, and
# capitalizes the first letter found.  so it expects to receive a string.

# much of the work is already done for us by the Delegate related code in
# matchers.jl.  to use that, we need to follow the conventions of having a
# matcher with a matcher field and a state with a state field (they can have
# more fields - those are the minimal requirements).

immutable Case<:Delegate
    matcher::Matcher
end

immutable CaseState<:DelegateState
    state::State
end

# the Delegate code handles the initial call (with CLEAN), and failure.  all
# we need to do is add handlig for success

function response(k::Config, m::Case, s, t, i, r::Success)
    # we don't care about the old state for this matcher (s), but we need to
    # save the child state (t), so that it can be used in backtracking.
    new_s = CaseState(t)
    # get the string contents from the child matcher
    # (nicer code would check this was a list containing a single string)
    contents::AbstractString = r.value[1]
    new_contents = uppercase(contents[1:1]) * contents[2:end]
    # and build the response from this matcher (see types.jl)
    Response(new_s, i, Success([new_contents]))
end


# now let's test that
@test parse_one("foo", Case(p".*")) == ["Foo"]

# to see what's happening in more detail, add debug logging:
@test parse_one("foo", Debug(Case(p".*"))) == ["Foo"]
# which gives
#0001     Debug/DebugState => Case/Clean          
#0001           Case/Clean => Pattern/Clean       
#0004           Case/Clean <= Success             
#0004     Debug/DebugState <= Success             
