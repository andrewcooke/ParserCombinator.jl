
always_print(::Matcher) = false

print_field{N}(m::Matcher, n::Type{Val{N}}) = "$(N)"

print_matcher(m::Matcher) = print_matcher(m, Dict{Matcher, Int}())

# this is optimized to be compact.  it could be prettier with more
# spaces, but then it's not as useful for large grammars.

# we don't use Set for known because it seems to be immutable, despite
# having push! defined on it.
function print_matcher(m::Matcher, known::Dict{Matcher, Int})
    function producer()
        if haskey(known, m)
            produce("$(m.name)...")
        else
            produce("$(m.name)")
            if !always_print(m)
                known[m] = 1
            end
            names = filter(n -> n != :name, fieldnames(m))
            for name in names
                if isa(m.(name), Matcher)
                    for (i, line) = enumerate(print_matcher(m.(name), known))
                        if name == names[end]
                            produce(i == 1 ? "`-$(line)" : "  $(line)")
                        else
                            produce(i == 1 ? "+-$(line)" : "| $(line)")
                        end
                    end
                elseif isa(m.(name), Array{Matcher,1})
                    for (j, x) in enumerate(m.(name))
                        tag = name == :matchers ? "[$j]" : "$(name)[$j]"
                        for (i, line) = enumerate(print_matcher(m.(name)[j], known))
                            if name == names[end] && j == length(m.(name))
                                produce(i == 1 ? "`-$(tag):$(line)" : "  $(line)")
                            else
                                produce(i == 1 ? "+-$(tag):$(line)" : "| $(line)")
                            end
                        end
                    end
                else
                    if name == names[end]
                        produce("`-$(print_field(m, Val{name}))")
                    else
                        produce("+-$(print_field(m, Val{name}))")
                    end
                end
            end
        end
    end
    Task(producer)
end

function Base.print(io::Base.IO, m::Matcher)
    print(io, join(print_matcher(m), "\n"))
end
