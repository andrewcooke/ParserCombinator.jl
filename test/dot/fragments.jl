
@testset "fragments" begin

D = ParserCombinator.Parsers.DOT

for s in ("", " ", "  ", " // ", " /*  */ ", "\n\t")
    parse_one(s, Trace(D.spc_star + Eos()))
end

# test wrd too for high bit

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

@test parse_one("<<abc/>>", D.html_id)[1] == HtmlID("<abc/>")
@test parse_one("<<abc></abc>>", D.html_id)[1] == HtmlID("<abc></abc>")
@test parse_one("<<abc> \n</abc>>", D.html_id)[1] == HtmlID("<abc> \n</abc>")
@test parse_one("<<abc><def/></abc>>", D.html_id)[1] == HtmlID("<abc><def/></abc>")
@test parse_one("<<abc><abc></abc></abc>>", D.html_id)[1] == HtmlID("<abc><abc></abc></abc>")

@test parse_one("abc", D.id)[1] == StringID("abc")
@test parse_one("\"abc\"", D.id)[1] == StringID("abc")
@test parse_one("123", D.id)[1] == NumericID("123")
@test parse_one("<<abc/>>", D.id)[1] == HtmlID("<abc/>")

@test parse_one(":A:n", D.port)[1] == Port(StringID("A"), "n")
@test parse_one(":n", D.port)[1] == Port("n")
@test parse_one(":A", D.port)[1] == Port(StringID("A"))

@test parse_one("[a=b]", D.attr_list)[1] == 
Attribute[Attribute(StringID("a"), StringID("b"))]
@test parse_one("[a=b c = d]", D.attr_list)[1] == 
Attribute[Attribute(StringID("a"), StringID("b")), 
          Attribute(StringID("c"), StringID("d"))]
@test parse_one("[a=b; c = d]", D.attr_list)[1] == 
Attribute[Attribute(StringID("a"), StringID("b")), 
          Attribute(StringID("c"), StringID("d"))]
@test parse_one("[a=b,c=d][e=f]", D.attr_list)[1] == 
Attribute[Attribute(StringID("a"), StringID("b")), 
          Attribute(StringID("c"), StringID("d")),
          Attribute(StringID("e"), StringID("f"))]

@test parse_one("a:b:c[d=e]", D.node_stmt)[1] == 
Node(NodeID(StringID("a"), Port(StringID("b"), "c")), 
     Attribute[Attribute(StringID("d"), StringID("e"))])

@test parse_one("a--b[c=d]", D.edge_stmt)[1] ==
Edge(EdgeNode[NodeID(StringID("a")), NodeID(StringID("b"))], 
     Attribute[Attribute(StringID("c"), StringID("d"))])

@test parse_one("graph [a=b]", D.attr_stmt)[1] ==
GraphAttributes(Attribute[Attribute(StringID("a"), StringID("b"))])

println("fragments ok")

end
