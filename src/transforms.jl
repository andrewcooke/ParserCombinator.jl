


# transform a result (including failure)
# note that the function will receive a Result instance (Failure, Empty or
# Value) and that the value returned must also be a Result

immutable TransformResult<:Matcher
    matcher::Matcher
    f::Function
end

function execute(m::TransformResult, s::Clean, i, src)
    Execute(m, s, m.matcher, CLEAN, i)
end

function execute(m::TransformResult, s::ChildState, i, src)
    Execute(m, s, m.matcher, s.state, i)
end

function response(m::TransformResult, s, c, t, i, src, r::Result)
    Response(m, ChildState(t), i, m.f(r))
end


immutable TransformSuccess<:Matcher
    matcher::Matcher
    f::Function
end

function execute(m::TransformSuccess, s::Clean, i, src)
    Execute(m, s, m.matcher, CLEAN, i)
end

function execute(m::TransformSuccess, s::ChildState, i, src)
    Execute(m, s, m.matcher, s.state, i)
end

function response(m::TransformSuccess, s, c, t, i, src, r::Success)
    Response(m, ChildState(t), i, m.f(r))
end

function response(m::TransformSuccess, s, c, t, i, src, ::Failure)
    Response(m, DIRTY, i, FAILURE)
end


immutable TransformValue<:Matcher
    matcher::Matcher
    f::Function
end

function execute(m::TransformValue, s::Clean, i, src)
    Execute(m, s, m.matcher, CLEAN, i)
end

function execute(m::TransformValue, s::ChildState, i, src)
    Execute(m, s, m.matcher, s.state, i)
end

function response(m::TransformValue, s, c, t, i, src, r::Value)
    Response(m, ChildState(t), i, m.f(r))
end

function response(m::TransformValue, s, c, t, i, src, ::Empty)
    Response(m, ChildState(t), i, EMPTY)
end

function response(m::TransformValue, s, c, t, i, src, ::Failure)
    Response(m, DIRTY, i, FAILURE)
end
