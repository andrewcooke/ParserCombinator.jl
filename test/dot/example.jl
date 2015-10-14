
using ParserCombinator.Parsers.DOT

my_graph = "graph {
  1 -- 2
  2 -- 3
  3 -- 1
}
"

root = parse_dot(my_graph)

for node in nodes(root)
    println("node $(node)")
end
for (node1, node2) in edges(root)
    println("edge $(node1) - $(node2)")
end
