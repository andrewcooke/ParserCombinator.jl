
@testset "example1" begin

example1 = "
graph [
  comment \"This is a sample graph\"
  directed 1
  id 42
  label \"Hello, I am a graph\"
  node [
    id 1
    label \"node 1\"
    thisIsASampleAttribute 42
  ]
  node [
    id 2
    label \"node 2\"
    thisIsASampleAttribute 43
  ]
  node [
    id 3
    label \"node 3\"
    thisIsASampleAttribute 44
  ]
  edge [
    source 1
    target 2
    label \"Edge from node 1 to node 2\"
  ]
  edge [
    source 2
    target 3
    label \"Edge from node 2 to node 3\"
  ]
  edge [
    source 3
    target 1
    label \"Edge from node 3 to node 1\"
  ]
]
"

root = parse_dict(example1)

for graph in root[:graph]
    println("graph $(graph[:label])")
    for node in graph[:node]
        println(" node $(node[:id])")
    end
    for edge in graph[:edge]
        println(" edge $(edge[:label]): $(edge[:source]) - $(edge[:target])")
    end
end

end
