
@testset "examples" begin

D = ParserCombinator.Parsers.DOT

# from http://graphs.grevian.org/example

d = parse_dot(open(p -> read(p, String), "dot/simple.dot"))[1]
@test nodes(d) == Set(["a", "b", "c", "d", "e"])
@test edges(d) == Set([("a","e"),("c","d"),("c","e"),("b","c"),("a","c"),("a","b")])

d = parse_dot(open(p -> read(p, String), "dot/k6.dot"))[1]
@test nodes(d) == Set(["a", "b", "c", "d", "e", "f"])
@test length(edges(d)) == 6*5/2

d = parse_dot(open(p -> read(p, String), "dot/simple-digraph.dot"))[1]
@test nodes(d) == Set(["a", "b", "c", "d"])
@test edges(d) == Set([("a","b"),("b","c"),("c","d"),("d","a")])

d = parse_dot(open(p -> read(p, String), "dot/full-digraph.dot"))[1]
@test nodes(d) == Set(["a", "b", "c", "e"])
@test edges(d) == Set([("a","b"),("a","c"),("c","b"),("e","b"),("e","e"),("c","e")])
@test length(d.stmts) == 6
@test length(d.stmts[1].nodes) == 2
# id.id are attribues of NodeID and StringID
@test d.stmts[1].nodes[1].id.id == "a"
@test isnull(d.stmts[1].nodes[1].port)
@test d.stmts[1].nodes[2].id.id == "b"
@test isnull(d.stmts[1].nodes[2].port)
@test length(d.stmts[1].attrs) == 2
@test d.stmts[1].attrs[1].name.id == "label"
@test d.stmts[1].attrs[1].value.id == "0.2"
@test d.stmts[1].attrs[2].name.id == "weight"
@test d.stmts[1].attrs[2].value.id == "0.2"

for f in ("path1.dot", "path2.dot")
    d = parse_dot(open(p -> read(p, String), "dot/$f"))[1]
    @test nodes(d) == Set(["a", "b", "c", "d", "e", "f"])
    @test edges(d) == Set([("a","b"),("a","d"),("b","c"),("b","d"),("c","d"),("c","f"),("e","f"),("d","e")])
end

# this example also has comments (ignored in parse)
d = parse_dot(open(p -> read(p, String), "dot/simple-subgraph.dot"))[1]
@test nodes(d) == Set(["a", "b", "c", "d", "f"])
@test edges(d) == Set([("a","b"),("a","f"),("b","c"),("c","d"),("f","c")])
@test length(d.stmts) == 2
@test isa(d.stmts[1], SubGraph)
@test !isnull(d.stmts[1].id)
@test get(d.stmts[1].id).id == "cluster_0"
@test d.stmts[1].stmts[1].name.id == "label"
@test d.stmts[1].stmts[1].value.id == "Subgraph A"

d = parse_dot(open(p -> read(p, String), "dot/bipartite-subgraph.dot"))[1]
@test nodes(d) == Set(["a", "b", "c", "d", "e"])
@test length(edges(d)) == 6

d1 = parse_dot(open(p -> read(p, String), "dot/large1.dot"))[1]
@test length(nodes(d1)) == 21
@test length(edges(d1)) == 42

d2 = parse_dot(open(p -> read(p, String), "dot/large2.dot"))[1]
@test length(nodes(d2)) == 21
@test length(edges(d2)) == 42

@test nodes(d1) == nodes(d2)
@test edges(d1) == edges(d2)

s = open(p -> read(p, String), "dot/tictactoe.dot")
@time d = parse_dot(s)[1]
@time n = nodes(d)
@time e = edges(d)
# these numbers are not really checks, just what the code returns
@test length(n) == 744
@test length(e) == 4361

d = parse_dot(open(p -> read(p, String), "dot/double.dot"))
d1, d2 = d
@test nodes(d1) == Set(["a", "b", "c", "d", "e"])
@test edges(d1) == Set([("a","e"),("c","d"),("c","e"),("b","c"),("a","c"),("a","b")])
@test nodes(d2) == Set(["a", "b", "c", "d", "e"])
@test edges(d2) == Set([("a","e"),("c","d"),("c","e"),("b","c"),("a","c"),("a","b")])

println("examples ok")

end
