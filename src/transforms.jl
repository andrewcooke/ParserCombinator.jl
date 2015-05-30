

# transform a result (including failure)
# note that the function will receive a Result instance (Failure, Empty or
# Value) and that the value returned must also be a Result

immutable TransformResult<:DelegateMatcher
    matcher::Matcher
    f::Function
end

immutable TransformState<:DelegateState
    state::State
end

# needed to remove ambiguity from default short-circuit action
function response(m::TransformResult, s, c, t, i, src, r::Failure)
    Response(m, TransformState(t), i, m.f(r))
end

function response(m::TransformResult, s, c, t, i, src, r::Result)
    Response(m, TransformState(t), i, m.f(r))
end



# transform successes (Empty and Value)
# again, function must return a Result instance

immutable TransformSuccess<:DelegateMatcher
    matcher::Matcher
    f::Function
end

function response(m::TransformSuccess, s, c, t, i, src, r::Success)
    Response(m, TransformState(t), i, m.f(r))
end




# transform Value instances
# again, function must return a Result instance

immutable TransformValue<:DelegateMatcher
    matcher::Matcher
    f::Function
end

function response(m::TransformValue, s, c, t, i, src, r::Value)
    Response(m, TransformState(t), i, m.f(r))
end

