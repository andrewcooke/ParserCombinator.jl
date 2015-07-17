

# add pre/post-fix matchers to anything that in a grammar that is
# named using a symbol.

# for example,
#  with_pre Drop(Star(Space())) begin
#     word = p"\w+"
#     sentence = Plus(word) + Drop(s".") > array(Any)
# would drop spaces before 'word' and 'sentence'


set_fix(pre::Bool, p::Matcher, x::Any) = x
set_fix(pre::Bool, p::Matcher, x::Delayed) = x
set_fix(pre::Bool, p::Matcher, m::Matcher) = pre ? Seq(p, m) : Seq(m, p)

is_equal(node) = node.head == :(=) && length(node.args) == 2
is_symbol_1(node) = isa(node.args[1], Symbol)
is_delayed_1(node) = isa(node.args[1], Expr) && node.args[1].head == :. &&
length(node.args[1].args) == 2 && isa(node.args[1].args[1], Symbol) && node.args[1].args[2] == :matcher

set_fixes(pre, p, x) = x
function set_fixes(pre::Bool, p::Any, node::Expr)
    if is_equal(node) && (is_symbol_1(node) || is_delayed_1(node))
        node.args[2] = Expr(:call, :set_fix, pre, p, node.args[2])
    end
    node.args = map(a -> set_fixes(pre, p, a), node.args)
    node
end


macro with_pre(pre, block)
    esc(set_fixes(true, pre, block))
end

macro with_post(post, block)
    esc(set_fixes(false, post, block))
end
