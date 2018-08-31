
@testset "celegansneural" begin

println("celegansneural")
s = open(s -> read(s, String), "gml/celegansneural.gml")
parse_dict(s; debug=false)
@time x = parse_dict(s; debug=false)
@test length(x) == 2
@test x[:Creator] == "Mark Newman on Thu Aug 31 12:59:09 2006"
@test length(x[:graph][1]) == 3
@test length(x[:graph][1][:node]) == 297
@test length(x[:graph][1][:edge]) == 2359

end

