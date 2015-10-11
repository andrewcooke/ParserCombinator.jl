
using ParserCombinator.Parsers.DOT; D = ParserCombinator.Parsers.DOT

str_one = D.str_one > D.unesc_join
@test parse_one("\"abc\"", str_one)[1] == "abc"
@test parse_one("\"abc\\\ndef\"", str_one)[1] == "abcdef"
@test parse_one("\"abc\\\ndef\\\nghi\"", str_one)[1] == "abcdefghi"
@test parse_one("\"abc\\\n\"", str_one)[1] == "abc"
@test parse_one("\"a\\\"c\\\n\"", str_one)[1] == "a\"c"
@test parse_one("\"\\\ndef\"", str_one)[1] == "def"
@test parse_one("\"\\\n\"", str_one)[1] == ""

@test parse_one("\"a\" +\"b\\\nc\"", D.str_many)[1] == "abc"

@test parse_one("\"a\" +\"b\\\nc\"", D.str_id)[1] == StringID("abc")
@test parse_one("abc", D.str_id)[1] == StringID("abc")

@test parse_one("-3.14", D.num_id)[1] == NumericID("-3.14")

@test parse_one("<abc/>", D.xml_id)[1] == HtmlID("<abc/>")
@test parse_one("<abc></abc>", D.xml_id)[1] == HtmlID("<abc></abc>")
@test parse_one("<abc> \n</abc>", D.xml_id)[1] == HtmlID("<abc> \n</abc>")
@test parse_one("<abc><def/></abc>", D.xml_id)[1] == HtmlID("<abc><def/></abc>")
@test parse_one("<abc><abc></abc></abc>", D.xml_id)[1] == HtmlID("<abc><abc></abc></abc>")

@test parse_one("abc", D.id)[1] == StringID("abc")
@test parse_one("123", D.id)[1] == NumericID("123")
@test parse_one("<abc/>", D.id)[1] == HtmlID("<abc/>")

@test parse_one(":A:n", D.port)[1] == Port(StringID("A"), "n")
@test parse_one(":n", D.port)[1] == Port(nothing, "n")
@test parse_one(":A", D.port)[1] == Port(StringID("A"), nothing)


println("fragments ok")
