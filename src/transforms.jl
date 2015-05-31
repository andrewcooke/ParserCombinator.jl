

# transform a result (including failure)
# note that the function will receive a Result instance (Failure, Empty or
# Value) and that the value returned must also be a Result

immutable TransformResult<:Delegate
    matcher::Matcher
    f::Function
end

immutable TransformState<:DelegateState
    state::State
end

# execute comes from DelegateMatcher

# needed to remove ambiguity from default short-circuit action
response(m::TransformResult, s, c, t, i, src, r::Failure) = Response(m, TransformState(t), i, m.f(r))

response(m::TransformResult, s, c, t, i, src, r::Success) = Response(m, TransformState(t), i, m.f(r))



# transform successes (Empty and Value)
# again, function must return a Result instance

immutable TransformSuccess<:Delegate
    matcher::Matcher
    f::Function
end

# execute comes from Delegate

response(m::TransformSuccess, s, c, t, i, src, r::Success) = Response(m, TransformState(t), i, m.f(r))
