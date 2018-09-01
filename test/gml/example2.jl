
@testset "example2" begin

my_graph = "graph [
  node [id 1]
  node [id 2]
  node [id 3]
  edge [source 1 target 2]
  edge [source 2 target 3]
  edge [source 3 target 1]
]"

root = parse_dict(my_graph)

for graph in root[:graph]  # there could be multiple graphs
    for node in graph[:node]
        println("node $(node[:id])")
    end
    for edge in graph[:edge]
        println("edge $(edge[:source]) - $(edge[:target])")
    end
end

end
