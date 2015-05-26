
immutable Equal<:Matcher
    string
end

function match(m::Equal, source, isource)
    for c in m.string
        if done(source, isource)
            return Failure()
        end
        s, isource = next(source, isource)
        if s != c
            return Failure()
        end
    end
    return Success(isource, m.string)
end


immutable Repeat<:Matcher
    m::Matcher
    n
end

function match(m::Repeat, source, isource)
    return Bounce(isource, m.m, (1, Array(Any, 0)))
end

function resume(m::Repeat, source, isource, state) 
   return Failure()
end

function resume(m::Repeat, source, isource, state, result)
    count, array = state
    push!(array, result)
    if count == m.n
        return Success(isource, array)
    else
        return Bounce(isource, m.m, (count+1, array))
    end
end
