

# place the result of a series of matcher inside anarray
# (in practice, use this instead of And)

function Seq(matcher::Matcher...)
    n = length(matcher)
    if n == 0
        return Insert([])
    else
        left = matcher[1]
        for right in matcher[2:end]
            left = And(left, right)
        end
        return TransformSuccess(left, unpackSeq(n))
    end
end

function unpackSeq(n)
    function (v)
        a = []
        function unpackValue(::Empty) end
        function unpackValue(x::Value) push!(a, x.value) end
        function unwind(i, v)
            if i == 1
                unpackValue(v)
            else
                left, right = v.value
                unwind(i-1, left)
                unpackValue(right)
            end
            return Value(a)
        end
        unwind(n, v)
    end
end
