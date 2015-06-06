

# associate names with matchers so that debugging is easier


# all NamedMatcher instances must havea name::N field, constructors that 
# set it to anon(), and expose the type so that it can be dispatched on.
typealias Name Union(Void,Symbol)
ANON = nothing
abstract NamedMatcher{N<:Name}<:Matcher

name(x::Any, s::Symbol) = x
name(m::NamedMatcher, s::Symbol) = (m.name = s; m)    

set_names(x) = x
function set_names(node::Expr)
    if node.head == :(=) && length(node.args) == 2 && isa(node.args[1], Symbol)
        node.args[2] = Expr(:call, :name, node.args[2], QuoteNode(node.args[1]))
    end
    node.args = map(set_names, node.args)
    node
end

macro with_names(block)
    esc(set_names(block))
end
