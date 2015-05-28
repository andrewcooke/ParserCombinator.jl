
importall SimpleParser
using Base.Test

@test_throws ParserException parse_one("x", Equal("a")) 
@test parse_one("a", Equal("a")) == "a"
@test_throws ParserException parse_one("a", Repeat(Equal("a"), 2, 2))
@test parse_one("aa", Repeat(Equal("a"), 2, 2)) == ["a", "a"]
@test parse_one("aa", Repeat(Equal("a"), 2, 1)) == ["a", "a"]
@test parse_one("", Repeat(Equal("a"), 0, 0)) == []

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

@test parse_one("ab", And(Equal("a"),Equal("b"))) == ("a", "b")
@test collect(parse_all("aaa", 
                        And(Repeat(Equal("a"), 3, 0),
                            Repeat(Equal("a"), 3, 0)))) == 
                            [(Any["a","a","a"],Any[]),
                             (Any["a","a"],Any["a"]),
                             (Any["a","a"],Any[]),
                             (Any["a"],Any["a","a"]),
                             (Any["a"],Any["a"]),
                             (Any["a"],Any[]),
                             (Any[],Any["a","a","a"]),
                             (Any[],Any["a","a"]),
                             (Any[],Any["a"]),
                             (Any[],Any[])]

