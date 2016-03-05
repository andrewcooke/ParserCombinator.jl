
module Regex

using ...ParserCombinator
using AutoHashEquals

abstract Pattern

@auto_hash_equals type Choice <: Pattern
    patterns::Vector{Pattern}
end

@auto_hash_equals type Sequence <: Pattern
    patterns::Vector{Pattern}
end

@auto_hash_equals type Repeat <: Pattern
    pattern::Pattern
    lo::Int
    hi::Int
end

make_rpt(lo) = p -> Repeat(p, lo, typemax(Int))
make_rpt(lo, hi) = p -> Repeat(p, lo, hi)

@auto_hash_equals type Range <: Pattern
    lo::Char
    hi::Char
end

Literal(s::AbstractString) = (@assert length(s) == 1; Range(s[1], s[1]))
Literal(c::Char) = Range(c, c)
Wild() = Range(typemin(Char), typemax(Char))

@auto_hash_equals type Group <: Pattern
    index::Int
    pattern::Pattern
end

function make_pattern()

    @with_names begin

        # group numbering is tricky - we need to number fomr the left and
        # avoid repetitions on backtracking.  so push entries (keyed by
        # iter) to a stack on entering the group, pop on leaving.
        group_count = Dict{Any, Int}()
        group_stack = []
        group_popped = Dict{Any, Int}()
        function pre_group(i, p)
            if !haskey(group_count, i)
                group_count[i] = length(group_count) + 1
                push!(group_stack, group_count[i])
            end
            p
        end
        function post_group(i, p)
            if !haskey(group_popped, i)
                group_popped[i] = pop!(group_stack)
            end
            Group(group_popped[i], p)
        end
        
        make_sequence(p) = length(p) == 1 ? p[1] : Sequence(p)
        make_choice(p) = length(p) == 1 ? p[1] : Choice(p)
        
        
        literal = p"[^[\].*+\\|(){}?]"                          > Literal
        escaped = ~Equal("\\") + Dot()                          > Literal
        wild = E"."                                             > Wild
        outseq = Delayed()
        
        atom = literal | escaped | wild | outseq
        plus = atom + E"+"                                      > make_rpt(1)
        star = atom + E"*"                                      > make_rpt(0)
        opt = atom + E"?"                                       > make_rpt(0, 1)
        once = atom + !(E"*"|E"+"|E"?")
        
        inseq = Plus(plus | star | opt | once)                 |> make_sequence
        choice = PlusList(inseq, E"|")                         |> make_choice
        
        open = ITransform(E"("+ !(e"?") ,                         pre_group)
        gchoice = IApp(open + choice + E")",                      post_group)
        nchoice = E"(?:" + choice + E")"
        
        outseq.matcher = Plus(gchoice | nchoice)               |> make_sequence
        
        return choice + Eos()
    end
end

end
