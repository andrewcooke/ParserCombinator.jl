
# not really a test, since it's not verified.  but if you run this you
# should see appropriate output to stdout.

parse_dbg = make_one(Debug)
parse_dbg("ab", Equal("a") + Trace(Dot()[0:end]) + Equal("b"))

println("debug ok")
