
using ParserCombinator.Parsers.GML

for text in ["a 1", "a 1.0", "a \"b\"",
             " a 1", " a 1.0", " a \"b\"",
             "a 1 ", "a 1.0 ", "a \"b\" ",
             "a [b 1]", " a [b 1]", "a [ b 1]", "a [b 1 ]", "a [b 1] ", 
             "a [b [c 1]]", "a [b [c 1 d 2.0 e \"3\"]]",
             "a\n# comment\n1", " a \n# comment \n 1",
             "#comment\na 1"]
    println("'$(text)'")
    println(parse_raw(text))
    println()
end

