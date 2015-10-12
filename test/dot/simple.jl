
using ParserCombinator.Parsers.DOT; D = ParserCombinator.Parsers.DOT

s = open(readall, "dot/simple.dot")
d = parse_dot(s)

@test nodes(d) == Set(["a", "b", "c", "d", "e"])
println(edges(d))

println("simple ok")
