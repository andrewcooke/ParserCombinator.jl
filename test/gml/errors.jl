
using ParserCombinator.Parsers.GML

for (text, msg) in [("a 1 ]", "Expected key"),
                    ("a [1 2]", "Expected ]"),
                    ("a [a -w]", "Expected value")]
    try
        println(parse_raw(text))
    catch x
        if isa(x, ParserError)
            print(x.msg)
            @test contains(x.msg, msg)
        else
            println(x)
        end
    end

    @test_throws ParserError parse_raw(text)

end

