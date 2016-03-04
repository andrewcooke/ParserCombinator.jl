
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
    patterns::Vector{Pattern}
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
Dot() = Range(typemin(Char), typemax(Char))

@auto_hash_equals type Group <: Pattern
    index::Int
    pattern::Pattern
end

function make_pattern()

    group_count = 0
    function make_group(pattern)
        group_count += 1
        Group(group_count, pattern)
    end

    make_sequence(p) = length(p) == 1 ? p[1] : Sequence(p)
    make_choice(p) = length(p) == 1 ? p[1] : Choice(p)

    
    literal = p"[^[\].*+\\|(){}?]"                              > Literal
    any = E"."                                                  > Dot

    outseq = Delayed()
    atom = literal | any | outseq
    plus = atom + E"+"                                          > make_rpt(1)
    star = atom + E"*"                                          > make_rpt(0)
    opt = atom + E"?"                                           > make_rpt(0, 1)
    once = atom + !(E"*"|E"+"|E"?")
    inseq = Plus(plus | star | opt | once)                     |> make_sequence
    choice = PlusList(inseq, E"|")                             |> make_choice
    gchoice = E"(" + !(e"?") + choice + E")"                    > make_group
    nchoice = E"(?:" + choice + E")"
    outseq.matcher = Plus(gchoice | nchoice | literal)         |> make_sequence

    return  choice + Eos()
end

pattern = make_pattern()

end
