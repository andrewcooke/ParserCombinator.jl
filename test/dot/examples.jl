
using ParserCombinator.Parsers.DOT; D = ParserCombinator.Parsers.DOT


d = parse_dot(open(readall, "dot/simple.dot"))
@test nodes(d) == Set(["a", "b", "c", "d", "e"])
@test edges(d) == Set([("a","e"),("c","d"),("c","e"),("b","c"),("a","c"),("a","b")])

d = parse_dot(open(readall, "dot/k6.dot"))
@test nodes(d) == Set(["a", "b", "c", "d", "e", "f"])
@test length(edges(d)) == 6*5/2


println("examples ok")
