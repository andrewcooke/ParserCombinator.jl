
using ParserCombinator.Parsers.Regex; R = ParserCombinator.Parsers.Regex

for (s, r) in [("abc", 
                [R.Sequence([R.Literal('a'), R.Literal('b'), R.Literal('c')])]),
               ("a|b", 
                [R.Choice([R.Literal('a'), R.Literal('b')])]),
               ("aa|b", 
                [R.Choice([R.Sequence([R.Literal('a'), R.Literal('a')]), R.Literal('b')])]),
               ("(a|b)", 
                [R.Group(1, R.Choice([R.Literal('a'), R.Literal('b')]))]),
               ("(a|(b))", 
                [R.Group(1, R.Choice([R.Literal('a'), R.Group(2, R.Literal('b'))]))]),
               ("(?:a|b)", 
                [R.Choice([R.Literal('a'), R.Literal('b')])]),
               ("a|b(?:c|d)", 
                [R.Choice([R.Literal('a'), R.Sequence([R.Literal('b'), R.Choice([R.Literal("c"), R.Literal("d")])])])]),
               ("a*",
                [R.Repeat(0, typemax(Int), R.Literal('a'))]),
               ("a+",
                [R.Repeat(1, typemax(Int), R.Literal('a'))]),
               ("ab+",
                [R.Sequence([R.Literal('a'), R.Repeat(1, typemax(Int), R.Literal('b'))])])
               ]
    print("$s...")
    pattern = R.make_pattern()
    @test parse_dbg(s, pattern; debug=true) == r
    println(" ok")
end
