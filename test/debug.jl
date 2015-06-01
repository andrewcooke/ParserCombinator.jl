
# not really a test, since it's not verified.  but if you run this you
# should see appropriate output to stdout.

parse_one("ab", Equal("a") + Debug(Dot()[0:end]) + Equal("b"))
