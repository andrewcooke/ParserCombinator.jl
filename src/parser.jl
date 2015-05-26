
function parse(source, m::Matcher)
    stack = Stack(Any)
    isource = start(source)
    ret = match(m, source, isource)
    while true
        if typeof(ret) == Success
            if isempty(stack)
                return ret.result
            else
                (m, state, isource) = pop!(stack)
                ret = resume(m, source, ret.isource, state, ret.result)
            end
        elseif typeof(ret) == Failure
            if isempty(stack)
                throw(ParseException("failed to parse"))
            else
                (m, state, isource) = pop!(stack)
                ret = resume(m, source, isource, state)
            end
        elseif typeof(ret) == Bounce
            push!(stack, (m, ret.state, ret.isource))
            ret = match(ret.m, source, ret.isource)
        else
            error("unexpected return $ret from $ast")
        end
    end
end

