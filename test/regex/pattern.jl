
using ParserCombinator.Parsers.Regex; R = ParserCombinator.Parsers.Regex

for (s, r) in [
               ("abc", 
                [R.Sequence([R.Literal('a'), R.Literal('b'), R.Literal('c')])]),
               ("a|b", 
                [R.Choice([R.Literal('a'), R.Literal('b')])]),
               ("aa|b", 
                [R.Choice([R.Sequence([R.Literal('a'), R.Literal('a')]), R.Literal('b')])]),
               ("a|bb", 
                [R.Choice([R.Literal('a'), R.Sequence([R.Literal('b'), R.Literal('b')])])]),
               ("(a|b)", 
                [R.Group(1, R.Choice([R.Literal('a'), R.Literal('b')]))]),
               ("(a|(b))", 
                [R.Group(1, R.Choice([R.Literal('a'), R.Group(2, R.Literal('b'))]))]),
               ("(?:a|b)", 
                [R.Choice([R.Literal('a'), R.Literal('b')])]),
               ("a|b(?:c|d)", 
                [R.Choice([R.Literal('a'), R.Sequence([R.Literal('b'), R.Choice([R.Literal("c"), R.Literal("d")])])])]),
               ("a*",
                [R.Repeat(R.Literal('a'), 0, typemax(Int))]),
               ("a+",
                [R.Repeat(R.Literal('a'), 1, typemax(Int))]),
               ("ab+",
                [R.Sequence([R.Literal('a'), R.Repeat(R.Literal('b'), 1, typemax(Int))])]),
               ("a?a|b", 
                [R.Choice([R.Sequence([R.Repeat(R.Literal('a'), 0, 1), R.Literal('a')]), R.Literal('b')])]),
               ("aa?|b", 
                [R.Choice([R.Sequence([R.Literal('a'), R.Repeat(R.Literal('a'), 0, 1)]), R.Literal('b')])]),
               ("a|b?b", 
                [R.Choice([R.Literal('a'), R.Sequence([R.Repeat(R.Literal('b'), 0, 1), R.Literal('b')])])]),
               ("a|bb?", 
                [R.Choice([R.Literal('a'), R.Sequence([R.Literal('b'), R.Repeat(R.Literal('b'), 0, 1)])])]),
               ("a",
                [R.Literal('a')]),
               ("\\+",
                [R.Literal('+')])
               ]
    print("$s...")
    pattern = R.make_pattern()
    @test parse_dbg(s, pattern; debug=true) == r
    println(" ok")
end
