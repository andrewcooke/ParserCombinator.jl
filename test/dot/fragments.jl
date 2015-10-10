
using ParserCombinator.Parsers.DOT; D = ParserCombinator.Parsers.DOT

@test parse_one("abc", D.str_id)[1] == StringID("abc")
@test parse_one("\"a c\"", D.str_id)[1] == StringID("a c")
