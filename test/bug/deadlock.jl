
using AutoHashEquals

abstract type Graph end

@auto_hash_equals struct Node<:Graph
    label::AbstractString
    children::Vector{Graph}
    Node(label, children...) = new(label, Graph[children...])
end

mutable struct Cycle<:Graph
    node::Union{Graph, Nothing}
    Cycle() = new(nothing)
end

function gprint(known::Set{Graph}, n::Node)
    function producer()
        if n in known
            produce(string(n.label, "..."))
        else
            push!(known, n)
            produce(n.label)
            for child in n.children
                prefix = child == n.children[end] ? "`-" : "+-"
                for line in gprint(known, child)
                    produce(string(prefix, line))
                    prefix = child == n.children[end] ? "  " : "| y"
                end
            end
            delete!(known, n)
        end
    end
    Task(producer)
end

function gprint(known::Set{Graph}, c::Cycle)
    if c.node === nothing
        Task(() -> produce("?"))
    elseif c in known
        Task(() -> produce("..."))
    else
        push!(known, c)
        t = gprint(known, c.node)
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
