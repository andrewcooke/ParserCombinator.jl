
import Base.hash

@auto type A 
    a::Int
    b
end

@test typeof(A(1,2)) == A
@test hash(A(1,2)) == hash(1,hash(2))
@test A(1,2) == A(1,2)
@test A(1,2) != A(1,3)
@test A(1,2) != A(3,2)

abstract B

@auto immutable C<:B x::Int end

@test isa(C(1), B)

@test CLEAN == CLEAN
@test CLEAN != DIRTY

abstract D{N<:Union(Void,Int)}
type G{N}<:D{N} e::N end
hash(g::G) = hash(g.e)
@auto type E{N}<:D{N} e::N end
@auto type F{N}<:D{N} e::N 
    F() = new(nothing)
end

println("auto ok")
