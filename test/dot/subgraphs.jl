
using ParserCombinator.Parsers.DOT

d = parse_dot("""
graph {
  subgraph {
    a -- b
    a -- c
  }
  c -- b
}
""")
@test nodes(d) == Set(["a", "b", "c"])

d = parse_dot("""
graph {
  subgraph {
    a -- b
    a -- c
  }
  c; d;
}
""")
@test nodes(d) == Set(["a", "b", "c", "d"])

d = parse_dot("""
graph {
  a -- subgraph {
    b -- c
    c -- d
  } -- e
}
""")
@test nodes(d) == Set(["a", "b", "c", "d", "e"])

println("subgraphs ok")
