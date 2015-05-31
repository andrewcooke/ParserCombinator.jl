
# various simple matchers

@test parse_one("", Epsilon()) == []
@test parse_one("", Insert("foo")) == ["foo"]
@test parse_one("", Drop(Insert("foo"))) == []
@test_throws ParserException parse_one("x", Equal("a")) 
@test parse_one("a", Equal("a")) == ["a"]
@test_throws ParserException parse_one("a", Repeat(Equal("a"), 2, 2))
@test parse_one("aa", Repeat(Equal("a"), 2, 2)) == ["a", "a"]
@test parse_one("aa", Repeat(Equal("a"), 2, 1)) == ["a", "a"]
@test parse_one("", Repeat(Equal("a"), 0, 0)) == []
@test parse_one("ab", And(Pattern(r"a"), Dot())) == ["a", 'b']
@test parse_one("ab", p"." + s"b") == ["a", "b"]
@test parse_one("abc", p"." + s"b" + s"c") == ["a", "b", "c"]
@test parse_one("abc", p"." + S"b" + s"c") == ["a", "c"]
@test parse_one("b", Alt(s"a", s"b", s"c")) == ["b"]
@test collect(parse_all("b", Alt(Epsilon(), Repeat(s"b", 1, 0)))) == Array[[], ["b"], []]
@test parse_one("abc", p"." + (s"b" | s"c")) == ["a", "b"]
@test length(collect(parse_all("abc", p"."[0:3]))) == 4
@test length(collect(parse_all("abc", p"."[1:2]))) == 2
@test parse_one("abc", p"."[3] > tuple) == [("a", "b", "c")]
@test parse_one("1.2", PFloat64()) == [1.2]
m1 = Delayed()
m1.matcher = Nullable{ParComb.Matcher}(And(Dot(), Opt(m1)))
@test parse_one_nc("abc", m1) == ['a', 'b', 'c']


# check that greedy repeat is exactly the same as regexp

for i in 1:10
    lo = rand(0:3)
    hi = lo + rand(0:2)
    r = Regex("a{$lo,$hi}")
    n = rand(0:4)
    s = repeat("a", n)
    m = match(r, s)
    println("$lo $hi $s $r")
    if m == nothing
        @test_throws ParserException parse_one(s, Repeat(Equal("a"), hi, lo))
    else
        @test length(m.match) == length(parse_one(s, Repeat(Equal("a"), hi, lo)))
    end
end


# backtracking in sequences of repeats

@test parse_one("ab", And(Equal("a"), Equal("b"))) == ["a", "b"]
@test parse_one("abc", Dot() + Dot() + Dot()) == ['a', 'b', 'c']
@test map(x -> [length(x[1]), length(x[2])],
          collect(parse_all("aaa", 
                            And((Repeat(Equal("a"), 3, 0) > tuple),
                                (Repeat(Equal("a"), 3, 0) > tuple))))) == 
                                Array[[3,0],
                                      [2,1],[2,0],
                                      [1,2],[1,1],[1,0],
                                      [0,3],[0,2],[0,1],[0,0]]


# is caching useful?  only in extreme cases, apparently
# (but we may need to define equality on states!)

@test parse_one_nc("aa", Equal("a")) == ["a"]
function slow(n)
#    matcher = Repeat(Repeat(Equal("a"), n, 0), n, 0)
#    matcher = And(Repeat(Equal("a"), n, 0), Repeat(Equal("a"), n, 0))
    matcher = Repeat(Equal("a"), n, 0)
    for i in 1:n
        matcher = And(Repeat(Equal("a"), n, 0), matcher)
    end
    source = repeat("a", n)
    println("no cache $n")
    @time collect(parse_all_nc(source, matcher))
    @time n1 = collect(parse_all_nc(source, matcher))
    println("cache $n")
    @time collect(parse_all(source, matcher))
    @time n2 = collect(parse_all(source, matcher))
    @test n1 == n2
end
slow(3)
# slow(6)  # not for travis!
