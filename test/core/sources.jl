@testset "sources" begin

@test diagnostic("abc", 0, "bad") == "bad at (0,0)\n[Before start]\n^\n"
@test diagnostic("abc", 1, "bad") == "bad at (1,1)\nabc\n^\n"
@test diagnostic("abc", 2, "bad") == "bad at (1,2)\nabc\n ^\n"
@test diagnostic("abc", 3, "bad") == "bad at (1,3)\nabc\n  ^\n"
@test diagnostic("abc", 4, "bad") == "bad at (2,0)\n[After end]\n^\n"

@test diagnostic("l1\nl2", 2, "bad") == "bad at (1,2)\nl1\n ^\n"
@test diagnostic("l1\nl2", 3, "bad") == "bad at (1,3)\nl1\n  ^\n"
@test diagnostic("l1\nl2", 4, "bad") == "bad at (2,1)\nl2\n^\n"


@test diagnostic(LineSource("abc"), LineIter(0, 0), "bad") == "bad at (0,0)\n[Not available]\n^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 0), "bad") == "bad at (1,0)\n[Not available]\n^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 1), "bad") == "bad at (1,1)\nabc\n^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 2), "bad") == "bad at (1,2)\nabc\n ^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 3), "bad") == "bad at (1,3)\nabc\n  ^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 4), "bad") == "bad at (1,4)\n[Not available]\n   ^\n"
@test diagnostic(LineSource("abc"), LineIter(2, 0), "bad") == "bad at (2,0)\n[Not available]\n^\n"
@test diagnostic(LineSource("abc"), LineIter(2, 1), "bad") == "bad at (2,1)\n[Not available]\n^\n"

@test diagnostic(LineSource("l1\nl2"), LineIter(1, 2), "bad") == "bad at (1,2)\nl1\n ^\n"
@test diagnostic(LineSource("l1\nl2"), LineIter(1, 3), "bad") == "bad at (1,3)\nl1\n  ^\n"
@test diagnostic(LineSource("l1\nl2"), LineIter(2, 1), "bad") == "bad at (2,1)\nl2\n^\n"

line = Trace(p"(.|\n)+"[0:end] + Eos())
@test parse_one("abc\n", line) == ["abc\n"]
@test parse_one(LineSource("abc\n"), line) == ["abc\n"]

println("sources ok")

end
