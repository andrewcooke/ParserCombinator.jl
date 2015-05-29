
function no_caching_producer(source, matcher::Matcher)

    stack = Stack(Tuple{Matcher,State})
    n = 0
    msg::Message = Execute(ROOT, CLEAN, matcher, CLEAN, start(source))

    function dispatch(e::Execute)
        push!(stack, (e.parent, e.state_parent))
        execute(e.child, e.state_child, e.iter, source)
    end

    function dispatch(r::Response)
        (parent, state_parent) = pop!(stack)
        response(parent, state_parent, r.child, r.state_child, r.iter, source, r.result)
    end

    while true
        msg = dispatch(msg)
        n = n+1
        if length(stack) == 1
            if typeof(msg) <: Response && msg.result <: Success
                produce(msg.result)
                (parent, state_parent) = pop!(stack)
                msg = Execute(parent, state_parent, msg.child, msg.state_child, start(source))
            elseif typeof(msg) <: Response && msg.result <: Failure
                return
            end
        end
    end
end

function caching_producer(source, matcher::Matcher)

    stack = Stack(Tuple{Matcher,State,Tuple{Matcher,State,Any}})
    cache = Dict{Tuple{Matcher,State,Any},Message}()
    n, m = 0, 0
    msg::Message = Execute(ROOT, CLEAN, matcher, CLEAN, start(source))

    function dispatch(e::Execute)
        key = (e.child, e.state_child, e.iter)
        push!(stack, (e.parent, e.state_parent, key))
        if haskey(cache, key)
            m = m + 1
            cache[key]
        else
            execute(e.child, e.state_child, e.iter, source)
        end
    end

    function dispatch(r::Response)
        parent, state_parent, key = pop!(stack)
        cache[key] = r
        response(parent, state_parent, r.child, r.state_child, r.iter, source, r.result)
    end

    while true
        msg = dispatch(msg)
        n = n+1
        if length(stack) == 1
            if typeof(msg) <: Response && typeof(msg.result) <: Success
                produce(msg.result)
                (parent, state_parent) = pop!(stack)
                msg = Execute(parent, state_parent, msg.child, msg.state_child, start(source))
            elseif typeof(msg) <: Response && typeof(msg.result) <: Failure
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

parse_all_nc = make_all(no_caching_producer)
parse_one_nc = make_one(no_caching_producer)
parse_all = make_all(caching_producer)
parse_one = make_one(caching_producer)
