
module Regex

using ...ParserCombinator


abstract Pattern

type Choice <: Pattern
    patterns::Vector{Pattern}
end

type Sequence <: Pattern
    patterns::Vector{Pattern}
end

type Literal <: Pattern
    char::Char
end

pattern = Delayed()

choice = PlusList(pattern, e"|") |> Choice
sequence = Plus(pattern) |> Sequence
literal = p"[^[\].*+\\]" > Literal

pattern.matcher = (choice | sequence | literal) + Eos()

end
