
using ParserCombinator.Parsers.Regex; R = ParserCombinator.Parsers.Regex

@test parse_one("abc", R.pattern) == [R.Sequence([R.Literal('a'), R.Literal('b'), R.Literal('c')])]

