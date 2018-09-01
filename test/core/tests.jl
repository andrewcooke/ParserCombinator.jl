@testset "tests" begin

@test parse_one("", Epsilon()) == []
@test parse_one("", Insert("foo")) == ["foo"]
@test parse_one("", Drop(Insert("foo"))) == []
@test_throws ParserException parse_one("x", Equal("a")) 
@test parse_one("a", Equal("a")) == ["a"]
@test parse_one("aa", Equal("a")) == ["a"]
@test_throws ParserException parse_one("a", Repeat(Equal("a"), 2, 2))
@test parse_one("aa", Repeat(Equal("a"), 2, 2)) == ["a", "a"]
@test parse_one("aa", Repeat(Equal("a"), 1, 2)) == ["a", "a"]
@test parse_one("", Repeat(Equal("a"), 0, 0)) == []
@test_throws ParserException parse_one("a", Repeat(Equal("a"), 2, 2; greedy=false); debug=true)
@test parse_one("aa", Repeat(Equal("a"), 2, 2; greedy=false)) == ["a", "a"]
@test parse_one("aa", Repeat(Equal("a"), 1, 2; greedy=false)) == ["a"]
@test parse_one("", Repeat(Equal("a"), 0, 0; greedy=false)) == []

@test parse_one("ab", Series(Pattern(r"a"), Dot(); flatten=false)) == Any[["a"], ['b']]
@test parse_one("ab", Series(Pattern(r"a"), Dot())) == Any["a", 'b']
@test parse_one("ab", Seq(Pattern(r"a"), Dot())) == ["a", 'b']
@test parse_one("abc", Pattern("(.)(.)(.)", 1, 3)+Eos()) == ["a", "c"]
@test parse_one("true", p"([Tt][Rr][Uu][Ee])|([Ff][Aa][Ll][Ss][Ee])"+Eos()) == ["true"]
@test parse_one("abc", Seq(Equal("a"))) == ["a"]
@test parse_one("abc", Seq(Equal("a"), Equal("b"))) == ["a", "b"]
@test parse_one("abc", Seq(p"."[1:2], Equal("c"))) == ["a", "b", "c"]
@test parse_one("abc", Seq(p"."[1:2], Equal("b"))) == ["a", "b"]
@test parse_one("abc", Seq!(p"."[1:2], Equal("c"))) == ["a", "b", "c"]
@test_throws ParserException  parse_one("abc", Seq!(p"."[1:2], Equal("b"))) == ["a", "b"]
@test parse_one("abc", Seq(p"."[1:2], p"."[1:2])) == ["a", "b", "c"]
@test parse_one("abc", Seq(p"."[1:2,:&], p"."[1:2])) == Any[["a"], ["b"], "c"]
@test parse_one("abc", Seq(p"."[1:2,:&,:?], p"."[1:2])) == Any[["a"], "b", "c"]
@test_throws ErrorException parse_one("abc", Seq(p"."[1:2,:&,:?,:x], p"."[1:2]))
@test parse_one("abc", Seq(p"."[1:2], p"."[1:2], Equal("c"))) == ["a", "b", "c"]
@test parse_one("ab", p"." + e"b") == ["a", "b"]
@test parse_one("abc", p"." + e"b" + e"c") == ["a", "b", "c"]
@test parse_one("abc", p"." + E"b" + e"c") == ["a", "c"]
@test parse_one("b", Alt(e"a", e"b", e"c")) == ["b"]
@test parse_one("b", Alt!(e"a", e"b", e"c")) == ["b"]
@test collect(parse_all("b", Trace(Alt(Epsilon(), Repeat(e"b", 0, 1))))) == Array[[], ["b"], []]

@test collect(parse_all("b", Alt(Epsilon(), Repeat(e"b", 0, 1; greedy=false)))) == Array[[], [], ["b"]]
@test parse_one("abc", p"." + (e"b" | e"c")) == ["a", "b"]
@test length(collect(parse_all("abc", p"."[0:3]))) == 4
@test length(collect(parse_all("abc", p"."[1:2]))) == 2
@test parse_one("abc", p"."[3] > tuple) == [("a", "b", "c")]
@test parse_one("abc", p"."[3] > vcat) == Any[Any["a", "b", "c"]]
@test_throws ParserException parse_one("abc", And(Equal("a"), Lookahead(Equal("c")), Equal("b")))
@test parse_one("abc", And(Equal("a"), Not(Lookahead(Equal("c"))), Equal("b"))) == Any[["a"], [], ["b"]]
@test parse_one("1.2", PFloat64()) == [1.2]
m1 = Delayed()
m1.matcher = Nullable{ParserCombinator.Matcher}(Seq(Dot(), Opt(m1)))
@test parse_one("abc", m1) == ['a', 'b', 'c']
@test collect(parse_all("abc", Repeat(Fail(); flatten=false))) == Any[[]]
@test collect(parse_all("abc", Repeat(Fail(); flatten=false, greedy=false))) == Any[[]]
@test parse_one("12c", Lookahead(p"\d") + PInt()) == [12]
@test parse_one("12c", Lookahead(p"\d") + PInt() + Dot()) == [12, 'c']
@test_throws ParserException parse_one("12c", Not(Lookahead(p"\d")) + PInt() + Dot())
@test collect(parse_all("123abc", Seq!(p"\d"[0:end], p"[a-z]"[0:end]))) == Any[Any["1", "2", "3", "a", "b", "c"]]
@test parse_one("€", p"."; debug=true) == ["€"]

# check that repeat is exactly the same as regexp

for i in 1:10
    for greedy in (true, false)
        lo = rand(0:3)
        hi = lo + rand(0:2)
        r = Regex("a{$lo,$hi}" * (greedy ? "" : "?"))
        n = rand(0:4)
        s = repeat("a", n)
        m = match(r, s)
        println("$lo $hi $s $r")
        if m == nothing
            @test_throws ParserException parse_one(s, Repeat(Equal("a"), lo, hi; greedy=greedy))
        else
            @test length(m.match) == length(parse_one(s, Repeat(Equal("a"), lo, hi; greedy=greedy)))
        end
    end
end


# backtracking in sequences of repeats

@test parse_one("ab", Seq(Equal("a"), Equal("b"))) == ["a", "b"]
@test parse_one("abc", Dot() + Dot() + Dot()) == ['a', 'b', 'c']

for backtrack in (true, false)

    @test map(x -> [length(x[1]), length(x[2])],
              collect(parse_all("aaa", 
                                Seq((Repeat(Equal("a"), 0, 3; backtrack=backtrack) > tuple),
                                    (Repeat(Equal("a"), 0, 3; backtrack=backtrack) > tuple))))) == 
    Array[[3,0],
          [2,1],[2,0],
          [1,2],[1,1],[1,0],
          [0,3],[0,2],[0,1],[0,0]]

    @test map(x -> [length(x[1]), length(x[2])],
              collect(parse_all("aaa", 
                                Seq((Repeat(Equal("a"), 0, 3; backtrack=backtrack, greedy=false) > tuple),
                                    (Repeat(Equal("a"), 0, 3; backtrack=backtrack, greedy=false) > tuple))))) == 
    Array[[0,0],[0,1],[0,2],[0,3],
          [1,0],[1,1],[1,2],
          [2,0],[2,1],
          [3,0]]
end

println("tests ok")

end
