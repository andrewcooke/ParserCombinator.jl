
function parse(source, matcher::Matcher)

    to::Hdr = Hdr(matcher, CLEAN)
    from::Hdr = Hdr(ROOT, CLEAN)
    body::Body = Call(start(source))

    while true

        to, from, body = match(to, from, body, source)
#        print("$from -> $to:\n  $body\n")

        if to.matcher == ROOT
            if typeof(body) == Success
                return body.result
            else
                throw(ParseException("cannot parse"))
            end
        end

    end
end
