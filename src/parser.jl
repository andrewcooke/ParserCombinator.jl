
function producer(source, matcher::Matcher)

    to::Hdr = Hdr(matcher, CLEAN)
    from::Hdr = Hdr(ROOT, CLEAN)
    body::Body = Call(start(source))

    while true

        to, from, body = match(to, from, body, source)
#        print("$from -> $to:\n  $body\n")

        if to.matcher == ROOT
            if typeof(body) == Success
                produce(body.result)
            else
                return
            end
        end

    end
end

function parse_all(source, matcher::Matcher)
    Task(() -> producer(source, matcher))
end

function parse(source, matcher::Matcher)
    task = parse_all(source, matcher)
    result = consume(task)
    if task.state == :done
        throw(ParserException("cannot parse"))
    else
        return result
    end
end
