

# place the result of a series of matcher inside an array
# (in practice, use this instead of And)

immutable Seq<:DelegateMatcher
    matchers::Tuple
    Seq(matchers::Matcher...) = new(matchers)
end

immutable SeqState<:DelegateState
    matcher::Matcher
    state::State
end

function unpackSeq(n)
    function (v)
        a = Array(Any,0)
        function unpackValue(::Empty) end
        function unpackValue(x::Value) push!(a, x.value) end
        function unwind(i, v)
            if i == 1
                unpackValue(v)
            else
                left, right = v.value
                unwind(i-1, left)
                unpackValue(right)
            end
            return Value(a)
        end
        unwind(n, v)
    end
end

function execute(m::Seq, s::Clean, i, src)
    # unfortunately, we need to do this on first call since the Seq
    # node must exist in the grammar AST so that we can use '+', etc
    n = length(m.matchers)
    if n == 0
        matcher = Insert([])
    else
        matcher = m.matchers[1]
        for right in m.matchers[2:end]
            matcher = And(matcher, right)
        end
        matcher = TransformSuccess(matcher, unpackSeq(n))
    end
    Execute(m, SeqState(matcher, CLEAN), matcher, CLEAN, i)
end

function execute(m::Seq, s::SeqState, i, src)
    Execute(m, s, s.matcher, s.state, i)
end

function response(m::Seq, s::SeqState, c, t, i, src, r::Success)
    Response(m, SeqState(s.matcher, t), i, r)
end



# support literal matches and regpexps

# p"..." creates a matcher for the given regular expression
macro p_str(s)
    Pattern(Regex(s))
end

# s"..." creates a matcher for the given string
macro s_str(s)
    Equal(s)
end



~(m::Matcher) = Drop(m)
+(a::Seq, b::Seq) = Seq(vcat(a.matchers, b.matchers))
+(a::Seq, b::Matcher) = Seq(vcat(a.matchers, b))
+(a::Matcher, b::Seq) = Seq(vcat(a, b.matchers))
+(a::Matcher, b::Matcher) = Seq(a, b)
