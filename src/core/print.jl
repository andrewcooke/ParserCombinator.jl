
always_print(::Matcher) = false

print_field(m::Matcher, n::Type{Val{N}}) where {N} = "$(N)"

print_matcher(m::Matcher) = print_matcher(m, Set{Matcher}())

# this is optimized to be compact.  it could be prettier with more
# spaces, but then it's not as useful for large grammars.

function print_matcher(m::Matcher, known::Set{Matcher})
    function producer(c::Channel)
        if m in known
            put!(c, "$(m.name)...")
        else
            put!(c, "$(m.name)")
            if !always_print(m)
                push!(known, m)
            end
            names = [n for n in fieldnames(typeof(m)) if n != :name]
            for name in names
                if isa(getfield(m, name), Matcher)
                    for (i, line) = enumerate(print_matcher(getfield(m, name), known))
                        if name == names[end]
                            put!(c, i == 1 ? "`-$(line)" : "  $(line)")
                        else
                            put!(c, i == 1 ? "+-$(line)" : "| $(line)")
                        end
                    end
                elseif isa(getfield(m, name), Array{Matcher,1})
                    for (j, x) in enumerate(getfield(m, name))
                        tag = name == :matchers ? "[$j]" : "$(name)[$j]"
                        for (i, line) = enumerate(print_matcher(getfield(m, name)[j], known))
                            if name == names[end] && j == length(getfield(m, name))
                                put!(c, i == 1 ? "`-$(tag):$(line)" : "  $(line)")
                            else
                                put!(c, i == 1 ? "+-$(tag):$(line)" : "| $(line)")
                            end
                        end
                    end
                else
                    if name == names[end]
                        put!(c, "`-$(print_field(m, Val{name}))")
                    else
                        put!(c, "+-$(print_field(m, Val{name}))")
                    end
                end
            end
        end
    end
    Channel(c -> producer(c))
end

function Base.print(io::Base.IO, m::Matcher)
    print(io, join(print_matcher(m), "\n"))
end
