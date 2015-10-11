
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

@auto_hash_equals immutable NumericID <: ID
    id::AbstractString
end

@auto_hash_equals immutable HtmlID <: ID
    id::AbstractString
end 

@auto_hash_equals immutable Attribute <: Statement
    name::ID
    value::ID
end

typealias Attributes Vector{Attribute}

@auto_hash_equals immutable Graph
    strict::Bool
    directed::Bool
    id::Nullable{ID}
    stmts::Statements
end

@auto_hash_equals immutable SubGraph <: Statement
    id::Nullable{ID}
    stmts::Statements
end

@auto_hash_equals immutable Port
    id::Nullable{ID}
    point::Nullable{AbstractString}
end

@auto_hash_equals immutable Node <: Statement
    id::ID
    port::Nullable{Port}
    attrs::Attributes
end

abstract Edge

@auto_hash_equals immutable Edges <: Statement
    edges::Vector{Edge}
end

@auto_hash_equals immutable SimpleEdge
    id::ID
    attrs::Attributes
end

@auto_hash_equals immutable ComplexEdge
    subgraph::SubGraph
    attrs::Attributes
end

@auto_hash_equals immutable GraphAttributes <: Statement
    attrs::Attributes
end

@auto_hash_equals immutable NodeAttributes <: Statement
    attrs::Attributes
end

@auto_hash_equals immutable EdgeAttributes <: Statement
    attrs::Attributes
end


# IDs

spc = "([ \t]|\n#.*|\n|//.*|/\\*[.\n]*?\\*/)"
spc_init = ~Pattern(string("(#.*)?", spc, "*"))
spc_star = ~Pattern(string(spc, "*"))
spc_plus = ~Pattern(string(spc, "+"))

wrd = p"[a-zA-Z\200-\377_][a-zA-Z\200-\377_0-9]*"

# valid strings include:
# 1 - "..."
# 2 - "...\
#      ..."
# 3 = "..." + "..."
# and all can contain quoted quotes
unesc(s) = replace(s, "\\\"", "\"")
unesc_join(s...) = string(map(unesc, s)...)
str_cont = Pattern("((?:[^\"\n]|\\\\\")*)\\\\\\\n", 1)
str_end = p"([^\"\n]|\\\\\")*"
str_one = Seq!(E"\"", Star!(str_cont), str_end, E"\"")
str_many = Seq!(str_one, Star!(Seq!(spc_star, E"+", spc_star, str_one))) > unesc_join

str_id = Alt!(wrd, str_many) > StringID

num_id = p"-?(\.[0-9]+|[0-9]+(\.[0-9]*)?)" > NumericID

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

cmp = p"(n|ne|e|se|s|sw|w|nw|c|_)"
col = E":"

# port grammar seeems to be ambiguous, since :ID could be :point
# this is a best guess at what was meant
port = Alt!(Seq!(col, spc_star, id, spc_star, col, cmp) > Port,
            Seq!(col, spc_star, cmp) > (c -> Port(nothing, c)),
            Seq!(col, spc_star, id) > (i -> Port(i, nothing)))



#Seq!(spc_init, graph)

end
