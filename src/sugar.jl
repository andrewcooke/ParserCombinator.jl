

# support literal matches and regpexps

# p"..." creates a matcher for the given regular expression
macro p_str(s)
    Pattern(Regex(s))
end

# s"..." creates a matcher for the given string
macro s_str(s)
    Equal(s)
end



Opt(m::Matcher) = Alt(m, Epsilon())



# sweet, sweet sugar

# match and discard
~(m::Matcher) = Drop(m)

# match in sequence, result in array
+(a::Matcher, b::Matcher) = And(a, b)

# alternates
|(a::Alt, b::Alt) = Alt(vcat(a.matchers, b.matchers))
|(a::Alt, b::Matcher) = Alt(vcat(a.matchers, b))
|(a::Matcher, b::Alt) = Alt(vcat(a, b.matchers))
|(a::Matcher, b::Matcher) = Alt(a, b)

# repeat via [lo:hi] or [n]
# TODO - special value used by Range
#endof(::Matcher) = -1
getindex(m::Matcher,r::Int) = Repeat(m, r, r)
getindex(m::Matcher,r::UnitRange) = Repeat(m, r.stop, r.start)

# interpolate multiple values (list or tuple)
>(m::Matcher, f::Function) = TransformSuccess(m, x -> Success(f(x.value...)))
# a single value
|>(m::Matcher, f::Function) = TransformSuccess(m, x -> Success(f(x.value)))
# the raw Result instance
>=(m::Matcher, f::Function) = TransformResult(m, f)
