
ParserCombinator.@auto type A 
    a::Int
    b
end

@test typeof(A(1,2)) == A
@test hash(A(1,2)) == hash(1,hash(2))
@test A(1,2) == A(1,2)
@test A(1,2) != A(1,3)
@test A(1,2) != A(3,2)

