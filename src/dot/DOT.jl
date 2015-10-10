
module DOT

using ...ParserCombinator
using Compat
using AutoHashEquals
import Base: ==

export Statement, Statements, ID, StringID, NumericID, HtmlID, Attribute,
       Attributes, Graph, Port, Node, Edge, Edges, SimpleEdge, ComplexEdge,
       GraphAttributes, NodeAttributes, EdgeAttributes, SubGraph

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

typealias Statements Vector{Statement}

abstract ID

@auto_hash_equals immutable StringID <: ID
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

typealias Attributes Vector{Attribute}

immutable Graph
    strict::Bool
    directed::Bool
    id::Nullable{ID}
    stmts::Statements
end

immutable SubGraph <: Statement
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


# IDs

spc = "([ \t]|\n#.*|\n|//.*|/\\*[.\n]*?\\*/)"
spc_init = ~Pattern(string("(#.*)?", spc, "*"))
spc_star = ~Pattern(string(spc, "*"))
spc_plus = ~Pattern(string(spc, "+"))

wrd = p"[a-zA-Z\200-\377_][a-zA-Z\200-\377_0-9]*"

str = Pattern("((?:[^\"]|\\\")*?)(?:\\\n)?", 1)
str_once = Seq!(P"\"", str, P"\"")
str_join = Seq!(str_once, 
                Star!(Seq!(spc_star, P"\\+", spc_star, str_once))) > string

str_id = Alt!(wrd, str_join) > StringID

num_id = P"-?(\.[0-9]+|[0-9]+(\.[0-9]*)?)" > NumericID

xml_sngl = p"<(\n|[^>])*?/>"
xml_open = p"<(\n|[^>])*?(\n|[^/])>"
xml_clos = p"</(\n|[^>])*?>"
xml_spc  = p"(\n|[^<])*"
xml      = Delayed()
# we are not checking that the closing element name matches the opening
# name, and this could involve a pile of backtracking
# TODO - make this more efficient
xml_nest = Seq(xml_open, xml_spc, Opt(xml), xml_spc, xml_clos) > string
xml.matcher = Alt(xml_sngl, xml_nest)

xml_id = xml > HtmlID

id = Alt!(str_id, num_id, xml_id)





#Seq!(spc_init, graph)

end
