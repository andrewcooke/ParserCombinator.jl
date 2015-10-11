
module DOT

using ...ParserCombinator
using Compat
using AutoHashEquals
import Base: ==, print

export Statement, Statements, ID, StringID, NumericID, HtmlID, Attribute,
       Attributes, Graph, Port, NodeID, Node, EdgeNode, Edge, GraphAttributes, 
       NodeAttributes, EdgeAttributes, SubGraph, parse_dot, nodes, edges

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
    Graph(s::Bool, d::Bool, id::ID, st::Statements) = new(s, d, id, st)
    Graph(s::Bool, d::Bool, st::Statements) = new(s, d, Nullable{ID}(), st)
end

@auto_hash_equals immutable SubGraph <: Statement
    id::Nullable{ID}
    stmts::Statements
    SubGraph(id::ID, s::Statements) = new(id, s)
    SubGraph(s::Statements) = new(Nullable{ID}(), s)
end

@auto_hash_equals immutable Port
    id::Nullable{ID}
    point::Nullable{AbstractString}
    Port(id::ID, p::AbstractString) = new(id, p)
    Port(id::ID) = new(id, Nullable{AbstractString}())
    Port(p::AbstractString) = new(Nullable{ID}(), p)
end

@auto_hash_equals immutable NodeID
    id::ID
    port::Nullable{Port}
    NodeID(id::ID, p::Port) = new(id, p)
    NodeID(id::ID) = new(id, Nullable{Port}())
end    

@auto_hash_equals immutable Node <: Statement
    id::NodeID
    attrs::Attributes
    Node(id::NodeID, a::Attributes) = new(id, a)
    Node(id::NodeID) = new(id, Attributes())
end

typealias EdgeNode Union{NodeID, SubGraph}

@auto_hash_equals immutable Edge <: Statement
    nodes::Vector{EdgeNode}
    attrs::Attributes
    Edge(n::Vector{EdgeNode}, a::Attributes) = new(n, a)
    Edge(n::Vector{EdgeNode}) = new(n, Attributes())
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


@with_names begin

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
    xml_nest = Seq(xml_open, xml_spc, Opt!(xml), xml_spc, xml_clos) > string
    xml.matcher = Alt(xml_sngl, xml_nest)

    xml_id = xml > HtmlID

    id = Alt!(str_id, num_id, xml_id)

    cmp = p"(n|ne|e|se|s|sw|w|nw|c|_)"
    col = E":"

    # port grammar seeems to be ambiguous, since :ID could be :point
    # this is a best guess at what was meant
    port = Alt!(Seq!(col, spc_star, id, spc_star, col, spc_star, cmp),
                Seq!(col, spc_star, cmp),
                Seq!(col, spc_star, id)) > Port

    # this is a raw ID=ID, not the attr_stmt in the grammar
    attr = Seq!(id, spc_star, E"=", spc_star, id) > Attribute

    attr_sep = Seq!(spc_star, P"[;,]?", spc_star)
    attr_list = PlusList!(Seq!(E"[", StarList!(attr, attr_sep), E"]"), spc_star) |> Vector{Attribute}

    node_id = Seq!(id, spc_star, Opt!(port)) > NodeID
    node_stmt = Seq!(node_id, spc_star, Opt!(attr_list)) > Node

    NoCase(s) = Pattern(join(["[$(lowercase(c))$(uppercase(c))]" for c in s]))

    stmt = Delayed()

    # not a list because canhave a trailing ;
    # this eats trailing spaces, but i don't think it matters
    stmt_list = Star!(Seq!(stmt, spc_star, Opt!(Seq!(E";", spc_star)))) |> Statements

    sub_graph = Seq!(~NoCase("subgraph"), spc_star, Opt!(id), spc_star, E"{", spc_star, stmt_list, spc_star, E"}") > SubGraph

    # order important here, since we don't backtrack and "subgraph" could
    # be a node
    edge_node = Alt!(sub_graph, node_id)
    edge_sep = Seq!(spc_star, P"(--|->)", spc_star)
    edge_list = Seq!(edge_node, edge_sep, PlusList!(edge_node, edge_sep)) |> Vector{EdgeNode}
    edge_stmt = Seq!(edge_list, spc_star, Opt!(attr_list)) > Edge

    attr_stmt = Alt!(Seq!(~NoCase("graph"), spc_star, attr_list) > GraphAttributes,
                     Seq!(~NoCase("node"), spc_star, attr_list) > NodeAttributes,
                     Seq!(~NoCase("edge"), spc_star, attr_list) > EdgeAttributes)

    # order important here as node_stmt can match almost anything
    stmt.matcher = Alt!(edge_stmt, attr_stmt, attr, sub_graph, node_stmt)

    strict = Alt!(Seq!(~NoCase("strict"), Insert(true)), Insert(false))
    direct = Alt!(Seq!(~NoCase("digraph"), Insert(true)),
                  Seq!(~NoCase("graph"), Insert(false)))
    graph = Seq!(strict, spc_star, direct, spc_star, Opt!(id), spc_star, E"{", spc_star, stmt_list, spc_star, E"}") > Graph

    dot = Seq!(spc_star, graph, spc_star, Eos())

end


function parse_dot(s; debug=false)
    try
        if debug
            parse_one_dbg(s, Trace(dot); debug=true)[1]
        else
            parse_one(s, dot)[1]
        end
    catch x
        if debug
            Base.show_backtrace(STDOUT, catch_backtrace())
        end
        rethrow()
    end
end


# expend both nodes and edges, then use sets to de-duplication
nodes(g::Graph) = union(map(nodes, g.stmts)...)
nodes(s::Statement) = Set()
nodes(s::SubGraph) = union(map(nodes, s.stmts)...)
nodes(n::Node) = nodes(n.id)
nodes(n::NodeID) = Set([n.id.id])
nodes(e::Edge) = union(map(nodes, e.nodes)...)

edges(g::Graph) = vcat(map(edges, g.stmts)...)
edges(s::Statement) = []
edges(s::SubGraph) = vcat(map(edges, s.stmts)...)
edges(e::Edge) = []


end
