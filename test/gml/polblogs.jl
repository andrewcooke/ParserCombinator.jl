
@testset "polblogs" begin

#io = ZipFile.Reader("gml/polblogs.zip").files[1]
#println("polblogs")
#io = open("gml/polblogs.gml")
#parse_dict(io; debug=false)
#io = open("gml/polblogs.gml")
#@time parse_dict(io; debug=false)

#println("polblogs id")
#io = open("gml/polblogs.gml")
#parse_id_dict(io; debug=false)
#io = open("gml/polblogs.gml")
#@time parse_id_dict(io; debug=false)

println("polblogs")
s = open(s -> read(s, String), "gml/polblogs.gml")
x = parse_dict(s; debug=false)
@test length(x[:graph][1][:edge]) == 19090
@time parse_raw(s; debug=false)

end



