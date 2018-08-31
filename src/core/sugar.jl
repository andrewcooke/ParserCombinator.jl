

# support literal matches and regpexps

# p"..." creates a matcher for the given regular expression
macro p_str(s)
    Pattern(Regex(s))
end

macro P_str(s)
    Drop(Pattern(Regex(s)))
end

# e"..." creates a matcher for the given string
macro e_str(s)
    Equal(s)
end

macro E_str(s)
    Drop(Equal(s))
end


Opt(m::Matcher) = Alt(m, Epsilon())
Opt!(m::Matcher) = Alt!(m, Epsilon())


# sweet, sweet sugar

# match and discard
~(m::Matcher) = Drop(m)

# refuse
!(m::Matcher) = Not(Lookahead(m))

# match in sequence, result in array

# merge results
+(a::Seq, b::Seq) = Seq(vcat(a.matchers, b.matchers))
+(a::Seq, b::Matcher) = Seq(vcat(a.matchers, b))
+(a::Matcher, b::Seq) = Seq(vcat(a, b.matchers))
+(a::Matcher, b::Matcher) = Seq(a, b)

# separate results
# https://github.com/JuliaLang/julia/issues/11521
(&)(a::And, b::And) = And(vcat(a.matchers, b.matchers))
(&)(a::And, b::Matcher) = And(vcat(a.matchers, b))
(&)(a::Matcher, b::And) = And(vcat(a, b.matchers))
(&)(a::Matcher, b::Matcher) = And(a, b)


# alternates
|(a::Alt, b::Alt) = Alt(vcat(a.matchers, b.matchers))
|(a::Alt, b::Matcher) = Alt(vcat(a.matchers, b))
|(a::Matcher, b::Alt) = Alt(vcat(a, b.matchers))
|(a::Matcher, b::Matcher) = Alt(a, b)


# repeat via [lo:hi] or [n]
lastindex(m::Matcher) = typemax(Int)
size(m::Matcher, n) = endof(m)
axes(m::Matcher, n) = (n == 1) ? Base.OneTo(lastindex(m)) : 1
lastindex(m::Matcher, n) = last(axes(m, n))
getindex(m::Matcher, r::Int, s::Symbol...) = getindex(m, r:r; s...)
function getindex(m::Matcher, r::UnitRange, s::Symbol...)
    greedy = true
    flatten = true
    backtrack = true
    for x in s
        if x == :?
            greedy = false
        elseif x == :&
            flatten = false
        elseif x == :!
            backtrack = false
        else
            error("bad flag to []: $x")
        end
    end
    Repeat(m, r.start, r.stop; greedy=greedy, flatten=flatten, backtrack=backtrack)
end


# the raw Result instance
>=(m::Matcher, f::Applicable) = TransResult(m, f)
# interpolate multiple values (list or tuple)
>(m::Matcher, f::Applicable) = App(m, f)
# a single value
|>(m::Matcher, f::Applicable) = Appl(m, f)
