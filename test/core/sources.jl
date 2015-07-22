
@test diagnostic("abc", 0, "bad") == "(0, 0): bad\n[Before start]\n^\n"
@test diagnostic("abc", 1, "bad") == "(1, 1): bad\nabc\n^\n"
@test diagnostic("abc", 2, "bad") == "(1, 2): bad\nabc\n ^\n"
@test diagnostic("abc", 3, "bad") == "(1, 3): bad\nabc\n  ^\n"
@test diagnostic("abc", 4, "bad") == "(2, 0): bad\n[After end]\n^\n"

@test diagnostic("l1\nl2", 2, "bad") == "(1, 2): bad\nl1\n ^\n"
@test diagnostic("l1\nl2", 3, "bad") == "(1, 3): bad\nl1\n  ^\n"
@test diagnostic("l1\nl2", 4, "bad") == "(2, 1): bad\nl2\n^\n"


@test diagnostic(LineSource("abc"), LineIter(0, 0), "bad") == "(0, 0): bad\n[Not available]\n^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 0), "bad") == "(1, 0): bad\n[Not available]\n^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 1), "bad") == "(1, 1): bad\nabc\n^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 2), "bad") == "(1, 2): bad\nabc\n ^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 3), "bad") == "(1, 3): bad\nabc\n  ^\n"
@test diagnostic(LineSource("abc"), LineIter(1, 4), "bad") == "(1, 4): bad\n[Not available]\n   ^\n"
@test diagnostic(LineSource("abc"), LineIter(2, 0), "bad") == "(2, 0): bad\n[Not available]\n^\n"
@test diagnostic(LineSource("abc"), LineIter(2, 1), "bad") == "(2, 1): bad\n[Not available]\n^\n"

@test diagnostic(LineSource("l1\nl2"), LineIter(1, 2), "bad") == "(1, 2): bad\nl1\n ^\n"
@test diagnostic(LineSource("l1\nl2"), LineIter(1, 3), "bad") == "(1, 3): bad\nl1\n  ^\n"
@test diagnostic(LineSource("l1\nl2"), LineIter(2, 1), "bad") == "(2, 1): bad\nl2\n^\n"



println("sources ok")
