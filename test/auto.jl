
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
