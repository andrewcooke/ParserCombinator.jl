
abstract Matcher
abstract Return

immutable Failure<:Return
end

immutable Success<:Return
    isource
    result
end

immutable Bounce<:Return
    isource
    m::Matcher
    state
end

immutable ParseException<:Exception
    msg
end
