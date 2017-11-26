
using AutoHashEquals

@compat abstract type Graph end

@auto_hash_equals type Node<:Graph
    label::String
    children::Vector{Graph}
    Node(label, children...) = new(label, Graph[children...])
end

type Cycle<:Graph
    node::Nullable{Graph}
    Cycle() = new(Nullable{Graph}())
end

function gprint_producer(c::Channel)
    if n in known
        put!(c, string(n.label, "..."))
    else
        push!(known, n)
        put!(c, n.label)
        for child in n.children
            prefix = child == n.children[end] ? "`-" : "+-"
            for line in gprint(known, child)
                put!(c, string(prefix, line))
                prefix = child == n.children[end] ? "  " : "| y"
            end
        end
        delete!(known, n)
    end
end

gprint(known::Set{Graph}, n::Node) = Channel(gprint_producer)

function gprint(known::Set{Graph}, c::Cycle)
    if isnull(c.node)
        Channel(c -> put!(c, "?"))
    elseif c in known
        Channel(c -> put!(c, "..."))
    else
        push!(known, c)
        t = gprint(known, get(c.node))
        delete!(known, c)
        t
    end
end

function Base.print(io::Base.IO, g::Graph)
    for line in gprint(Set{Graph}(), g)
        println(io, line)
    end
end

x = Cycle()
g = Node("a",
         Node("b"),
         Node("c",
              x,
              Node("d")))
print(g)

x.node = g
print(g)
