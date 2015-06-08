
import Base.hash   # needed because the macro overrides

@auto type A 
    a::Int
    b
end
@test typeof(A(1,2)) == A
@test hash(A(1,2)) == hash(2,hash(1,hash(:A)))
@test A(1,2) == A(1,2)
@test A(1,2) != A(1,3)
@test A(1,2) != A(3,2)

abstract B
@auto immutable C<:B x::Int end
@auto immutable D<:B x::Int end
@test isa(C(1), B)
@test isa(D(1), B)
@test C(1) != D(1)
@test hash(C(1)) != hash(D(1))
@test C(1) == C(1)
@test hash(C(1)) == hash(C(1))

abstract E{N<:Union(Void,Int)}
@auto type F{N}<:E{N} e::N end
@auto type G{N}<:E{N}
    e::N 
end
G() = G{Void}(nothing)
@test hash(F(1)) == hash(1, hash(:F))
@test hash(F(1)) != hash(F(2))
@test F(1) == F(1)
@test F(1) != F(2)
@test hash(G()) == hash(nothing, hash(:G))
@test G() == G()

macro dummy(x)
    x
end
@test @dummy(1) == 1

@auto type H
    @dummy h
    i
    @dummy j::Int
end
@test H(1,2,3) != H(2,1,3)
@test H(1,2,3) == H(1,2,3)
@test hash(H(1,2,3)) == hash(H(1,2,3))
@test hash(H(1,2,3)) != hash(H(2,1,3))

println("auto ok")
