
@testset "10k-49963" begin

println("10k-49963")
s = open(s -> read(s, String), "gml/10k-49963.gml")
parse_raw(s; debug=false)
@time parse_raw(s; debug=false)

#println("10k-49963 raw")
#io = open("gml/10k-49963.gml")
#parse_dict(io; debug=false)
#io = open("gml/10k-49963.gml")
#@time parse_dict(io; debug=false)

# initial (without :!)
#  223.622 seconds      (284 M allocations: 66954 MB, 18.56% gc time)
# with :!
#  235.137 seconds      (274 M allocations: 66469 MB, 6.03% gc time)
# with push!
#   87.233 seconds      (273 M allocations: 11556 MB, 5.63% gc time)
#   99.867 seconds      (273 M allocations: 11556 MB, 5.25% gc time)
# with :! on space
#   83.584 seconds      (235 M allocations: 9603 MB, 5.39% gc time)
#   85.376 seconds      (235 M allocations: 9603 MB, 5.44% gc time)
# slurping spaces with [, ]
#   96.082 seconds      (274 M allocations: 11600 MB, 5.46% gc time)
# string input
#   74.171 seconds      (235 M allocations: 9617 MB, 5.67% gc time)
# parse_one instead of parse_try (with string)
#   OOM
# with fixed string
#   74.171 seconds      (238 M allocations: 9788 MB, 5.71% gc time)

end
