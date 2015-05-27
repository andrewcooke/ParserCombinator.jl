
importall SimpleParser
using Base.Test

print(collect(parse_all("aaa", 
                        And(Repeat(Equal("a"), 3, 0),
                            Repeat(Equal("a"), 3, 0)))))

@test_throws ParserException parse("x", Equal("a")) 
@test parse("a", Equal("a")) == "a"
@test_throws ParserException parse("a", Repeat(Equal("a"), 2, 2))
@test parse("aa", Repeat(Equal("a"), 2, 2)) == ["a", "a"]
@test parse("aa", Repeat(Equal("a"), 2, 1)) == ["a", "a"]

for i in 1:10
    lo = rand(0:3)
    hi = lo + rand(0:2)
    r = Regex("a{$lo,$hi}")
    n = rand(0:4)
    s = repeat("a", n)
    m = match(r, s)
    println("$lo $hi $s $r")
    if m == nothing
        @test_throws ParserException parse(s, Repeat(Equal("a"), hi, lo))
    else
        @test length(m.match) == length(parse(s, Repeat(Equal("a"), hi, lo)))
    end
end

@test parse("ab", And(Equal("a"),Equal("b"))) == ("a", "b")
@test collect(parse_all("aaa", 
                        And(Repeat(Equal("a"), 3, 0),
                            Repeat(Equal("a"), 3, 0)))) == []

