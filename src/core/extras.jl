

# extra matchers that don't do anything exciting, but save typing

Parse(r::Regex, t::Type) = Parse(Pattern(r), t)
Parse(r::Regex, t::Type, base) = Parse(Pattern(r), t, base)
Parse(m::Matcher, t::Type) = m > s -> parse(t, s)
Parse(m::Matcher, t::Type, base) = m > s -> parse(t, s, base)
PUInt() = Parse(p"\d+", UInt)
PUInt8() = Parse(p"\d+", UInt8)
PUInt16() = Parse(p"\d+", UInt16)
PUInt32() = Parse(p"\d+", UInt32)
PUInt64() = Parse(p"\d+", UInt64)
PInt() = Parse(p"-?\d+", Int)
PInt8() = Parse(p"-?\d+", Int8)
PInt16() = Parse(p"-?\d+", Int16)
PInt32() = Parse(p"-?\d+", Int32)
PInt64() = Parse(p"-?\d+", Int64)
PFloat32() = Parse(p"-?(\d*\.?\d+|\d+\.\d*)([eE]\d+)?", Float32)
PFloat64() = Parse(p"-?(\d*\.?\d+|\d+\.\d*)([eE]\d+)?", Float64)

Word() = p"\w+"
Space() = p"\s+"


# see sugar.jl for [] syntax support

Star(m::Matcher; flatten=true) = flatten ? m[0:end] : m[0:end,:&] 
Plus(m::Matcher; flatten=true) = flatten ? m[1:end] : m[1:end,:&] 
Star!(m::Matcher; flatten=true) = flatten ? m[0:end,:!] : m[0:end,:&,:!] 
Plus!(m::Matcher; flatten=true) = flatten ? m[1:end,:!] : m[1:end,:&,:!] 

# list with separator

StarList(m::Matcher, s::Matcher) = Alt(Seq(m, Star(Seq(s, m))), Epsilon())
StarList!(m::Matcher, s::Matcher) = Alt!(Seq!(m, Star!(Seq!(s, m))), Epsilon())
PlusList(m::Matcher, s::Matcher) = Seq(m, Star(Seq(s, m)))
PlusList!(m::Matcher, s::Matcher) = Seq!(m, Star!(Seq!(s, m)))
