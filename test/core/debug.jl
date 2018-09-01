@testset "debug" begin

# not really a test, since it's not verified.  but if you run this you
# should see appropriate output to stdout.

@test ParserCombinator.truncate("1234567890", 10) == "1234567890"
@test ParserCombinator.truncate("1234567890",  9) == "1234...90"
@test ParserCombinator.truncate("1234567890",  8) == "123...90"
@test ParserCombinator.truncate("1234567890",  7) == "123...0"
@test ParserCombinator.truncate("1234567890",  6) == "12...0"
@test ParserCombinator.truncate("1234567890",  5) == "1...0"


println("one level")
parse_dbg("ab", Trace(Dot()))

println("multiple")
parse_dbg("ab", Equal("a") + Trace(Dot()[0:end]) + Equal("b"))

grammar = p"\d+" + Eos()
debug, task = make(Debug, "123abc", grammar; delegate=NoCache)
@test_throws ParserException once(task)
@test debug.max_iter == 4

println("debug ok")

end
