
abstract Matcher
abstract Body
abstract State

immutable Hdr{M<:Matcher, S<:State}
    matcher::M
    state::S
end

immutable Fail<:Body
    iter
end

immutable Success<:Body
    iter
    result
end

immutable Call<:Body
    iter
end


immutable Clean<:State end
CLEAN = Clean()
clean{M<:Matcher,S<:State}(h::Hdr{M,S}) = Hdr(h.matcher, CLEAN)

immutable Dirty<:State end
DIRTY = Dirty()
dirty{M<:Matcher,S<:State}(h::Hdr{M,S}) = Hdr(h.matcher, DIRTY)

replace{M<:Matcher,S<:State}(h::Hdr{M,Clean}, state::S) = Hdr(h.matcher, state)

immutable Root<:Matcher end
ROOT = Root()


immutable ParseException<:Exception
    msg
end
