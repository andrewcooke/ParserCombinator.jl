
using ParserCombinator.Parsers.Regex; R = ParserCombinator.Parsers.Regex

for (s, r) in [("abc", 
                [R.Sequence([R.Literal('a'), R.Literal('b'), R.Literal('c')])]),
               ("a|b", 
                [R.Choice([R.Literal('a'), R.Literal('b')])]),
               ("a|b(?:c|d)", 
                [R.Choice([R.Literal('a'), R.Sequence([R.Literal('b'), R.Choice([R.Literal("c"), R.Literal("d")])])])])
               ]
    @test parse_dbg(s, R.pattern) == r
    println("$s ok")
end
