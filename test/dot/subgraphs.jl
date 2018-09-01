
@testset "subgraphs" begin

d = parse_dot("""
graph {
  subgraph {
    a -- b
    a -- c
  }
  d -- e
}
""")[1]
@test nodes(d) == Set(["a", "b", "c", "d", "e"])
@test edges(d) == Set([("d","e"),("a","c"),("a","b")])

d = parse_dot("""
graph {
  subgraph {
    a -- b
    a -- c
  }
  d; e;
}
""")[1]
@test nodes(d) == Set(["a", "b", "c", "d", "e"])
@test edges(d) == Set([("a","c"),("a","b")])

d = parse_dot("""
graph {
  a -- subgraph {
    b -- c
    c -- d
  } -- e
}
""")[1]
@test nodes(d) == Set(["a", "b", "c", "d", "e"])
@test edges(d) == Set([("a","b"),("a","c"),("a","d"),("b","c"),("b","e"),("c","d"),("c","e"),("d","e")])

d = parse_dot("""
graph {
  subgraph { a -- b } -- subgraph { c -- d }
}
""")[1]
@test nodes(d) == Set(["a", "b", "c", "d"])
@test edges(d) == Set([("a","b"),("a","c"),("a","d"),("b","c"),("b","d"),("c","d")])

println("subgraphs ok")

end
