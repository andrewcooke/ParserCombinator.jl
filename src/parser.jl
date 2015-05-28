
function no_caching_producer(source, matcher::Matcher)

    stack = Stack(Tuple{Matcher,State})

    msg::Message = Execute(ROOT, CLEAN, matcher, CLEAN, start(source))

    function dispatch(e::Execute)
        push!(stack, (e.parent, e.state_parent))
        execute(e.child, e.state_child, e.iter, source)
    end

    function dispatch(s::Success)
        (parent, state_parent) = pop!(stack)
        success(parent, state_parent, s.child, s.state_child, s.iter, source, s.result)
    end

    function dispatch(f::Failure)
        (parent, state_parent) = pop!(stack)
        failure(parent, state_parent, f.child, f.state_child, f.iter, source)
    end

    while true
        msg = dispatch(msg)
        if length(stack) == 1
            if typeof(msg) <: Success
                produce(msg.result)
                (parent, state_parent) = pop!(stack)
                msg = Execute(parent, state_parent, msg.child, msg.state_child, start(source))
            elseif typeof(msg) <: Failure
                return
            end
        end
    end
end

function make_all(producer)
    function (source, matcher::Matcher)
        Task(() -> producer(source, matcher))
    end
end

function make_one(producer)
    function (source, matcher::Matcher)
        task = make_all(producer)(source, matcher)
        result = consume(task)
        if task.state == :done
            throw(ParserException("cannot parse"))
        else
            return result
        end
    end
end

parse_all = make_all(no_caching_producer)
parse_one = make_one(no_caching_producer)
