
importall SimpleParser
using Base.Test

@test_throws ParseException parse("x", Equal("a")) 
@test parse("a", Equal("a")) == "a"
@test_throws ParseException parse("a", Repeat(Equal("a"), 2))
@test parse("aa", Repeat(Equal("a"), 2)) == ["a", "a"]

