@testset "names" begin

@with_names begin
    a = Equal("a")
    b = Alt(a, Equal("c"))
end

@test a.name == :a
@test b.name == :b

println("names ok")

end
