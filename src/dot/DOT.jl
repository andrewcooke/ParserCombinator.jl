
module DOT

using ...ParserCombinator
using Compat

# i've gone with a very literal parsing, which returns a structure that is
# pretty much what is described in the grammar at
# http://www.graphviz.org/content/dot-language.  this is because it is not
# clear to me exactly how the syntax is connected to the semantics of graph
# layout.  for example, a simple graph like the one at
# http://www.graphviz.org/Gallery/gradient/colors.gv.txt has the node
# attributes specified before the node ID.  if you look at the syntax
# carefully that means that the attributes are not associated with that
# particular node (such attributes come after the node ID) and instead seem to
# be "global" node attributes in some sense.  so the format is more like a
# "program" (where order is important, with the "global" node attributes
# changing as the file is "processed") than a specification.

abstract Statement

typealias Vector{Statement} Statements

abstract ID

immutable StringID <: ID
    id::AbstractString
end

immutable NumericID <: ID
    id::AbstractString
end

immutable HtmlID <: ID
    id::AbstractString
end 

immutable Attribute <: Statement
    name::ID
    value::ID
end

typealias Vector{Attribute} Attributes

immutable Graph
    strict::Bool
    directed::Bool
    id::Nullable{ID}
    stmts::Statements
end

immutable Port
    id::Nullable{ID}
    point::Nullable{AbstractString}
end

immutable Node <: Statement
    id::ID
    ports::Vector{Port}
    attrs::Attributes
end

abstract Edge

immutable Edges <: Statement
    edges::Vector{Edge}
end

immutable SimpleEdge
    id::ID
    attrs::Attributes
end

immutable ComplexEdge
    subgraph::SubGraph
    attrs::Attributes
end

immutable GraphAttributes <: Statement
    attrs::Attributes
end

immutable NodeAttributes <: Statement
    attrs::Attributes
end

immutable EdgeAttributes <: Statement
    attrs::Attributes
end

immutable SubGraph <: Statement
    id::Nullable{ID}
    stmts::Statements
end

end
