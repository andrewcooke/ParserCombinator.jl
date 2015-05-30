

# extra matchers that don't do anything exciting, but save typing

Parse(r::Regex, t::Type) = Parse(Pattern(r), t)
Parse(r::Regex, t::Type, base) = Parse(Pattern(r), t, base)
Parse(m::Matcher, t::Type) = m |> s -> parse(t, s)
Parse(m::Matcher, t::Type, base) = m |> s -> parse(t, s, base)
PUInt() = Parse(p"\d+", UInt)
PInt() = Parse(p"-?\d+", Int)
PFloat() = Parse(p"-?(\d*\.?\d+|\d+\.\d*)([eE]\d+)?", Float64)

Word() = p"\w+"
Space() = p"\s+"
