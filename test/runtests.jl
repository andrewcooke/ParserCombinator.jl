
importall SimpleParser
using Base.Test

println(collect(parse_all("aaa", 
                          And(Repeat(Equal("a"), 3, 0),
                              Repeat(Equal("a"), 3, 0)))))
error("stop")

@test_throws ParserException parse_one("x", Equal("a")) 
@test parse_one("a", Equal("a")).value == "a"
@test_throws ParserException parse_one("a", Repeat(Equal("a"), 2, 2))
@test parse_one("aa", Repeat(Equal("a"), 2, 2)).value == ["a", "a"]
@test parse_one("aa", Repeat(Equal("a"), 2, 1)).value == ["a", "a"]
@test parse_one("", Repeat(Equal("a"), 0, 0)).value == []

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
        @test length(m.match) == length(parse_one(s, Repeat(Equal("a"), hi, lo)).value)
    end
end

@test parse_one("ab", And(Equal("a"), Equal("b"))).value == (Value("a"), Value("b"))
@test collect(parse_all("aaa", 
                        And(Repeat(Equal("a"), 3, 0),
                            Repeat(Equal("a"), 3, 0)))) == 
                            [(["a","a","a"],[]),
                             (["a","a"],["a"]),
                             (["a","a"],[]),
                             (["a"],["a","a"]),
                             (["a"],["a"]),
                             (["a"],[]),
                             ([],["a","a","a"]),
                             ([],["a","a"]),
                             ([],["a"]),
                             ([],[])]

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
slow(4)
slow(8)
