

# associate names with matchers so that debugging is easier


set_name(x::Any, s::Symbol) = x
set_name(m::Matcher, s::Symbol) = (m.name = s; m)    

set_names(x) = x
function set_names(node::Expr)
    if node.head == :(=) && length(node.args) == 2 && isa(node.args[1], Symbol)
        node.args[2] = Expr(:call, :set_name, node.args[2], QuoteNode(node.args[1]))
    end
    node.args = map(set_names, node.args)
    node
end


# this should be applied to a begin/end block, and sets the names of all
# matchers within that block to match the variables they are asigned to.

# so, for example
#   foo = Dot() 
# will set the name field of Dot() to :foo.

# since this clutters the code with extra calls (to set_name()) it should only
# be used around code that is evaluated once, to construct the grammar.

macro with_names(block)
    esc(set_names(block))
end
