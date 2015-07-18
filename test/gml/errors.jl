
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


io = open("gml/error.gml")
try
    parse_raw(io)
    @test false
catch x
    println(x)
    println(typeof(x))
    Base.show_backtrace(STDOUT, catch_backtrace())
    @test isa(x, ParserError)
    println(x.msg)
    @test x.msg == "Expected ] at (2,15)\n  node [ id 1 \"sausage\" ]\n              ^\n"
end


parse_dict("graph [a 0] graph [a 1 a 2]"; lists=[:a,:graph])
for unsafe in (true, false)
    try
        parse_dict("graph [a 0] graph [a 1 a 2]"; unsafe=unsafe)
        @test unsafe == true  # can parse when unsafe
    catch x
        println(x)
        @test unsafe == false # error when safe
        @test isa(x, GMLError)
        @test contains("a is a list", x.msg)
    end
end
