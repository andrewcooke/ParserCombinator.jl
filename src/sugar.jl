

# support literal matches and regpexps

# p"..." creates a matcher for the given regular expression
macro p_str(s)
    Pattern(Regex(s))
end

macro P_str(s)
    Drop(Pattern(Regex(s)))
end

# s"..." creates a matcher for the given string
macro s_str(s)
    Equal(s)
end

macro S_str(s)
    Drop(Equal(s))
end


Opt(m::Matcher) = Alt(m, Epsilon())



# sweet, sweet sugar

# match and discard
~(m::Matcher) = Drop(m)


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
endof{M<:Matcher}(m::M) = typemax(Int)
getindex(m::Matcher, r::Int, s::Symbol...) = getindex(m, r:r; s...)
function getindex(m::Matcher, r::UnitRange, s::Symbol...)
    greedy = true
    flatten = true
    for x in s
        if x == :?
            greedy = false
        elseif x == :&
            flatten = false
        else
            error("bad flag to []: $x")
        end
    end
    Repeat(m, r.start, r.stop; greedy=greedy, flatten=flatten)
end


# the raw Result instance
>=(m::Matcher, f::Union(Function, DataType)) = TransResult(m, f)
# interpolate multiple values (list or tuple)
>(m::Matcher, f::Union(Function, DataType)) = App(m, f)
# a single value
|>(m::Matcher, f::Union(Function, DataType)) = Appl(m, f)
