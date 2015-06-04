
abstract Node
==(n1::Node, n2::Node) = n1.val == n2.val
calc(n::Float64) = n
type Inv<:Node val end
calc(i::Inv) = 1.0/calc(i.val)
type Prd<:Node val end
calc(p::Prd) = Base.prod(map(calc, p.val))
type Neg<:Node val end
calc(n::Neg) = -calc(n.val)
type Sum<:Node val end
calc(s::Sum) = Base.sum(map(calc, s.val))

num = PFloat64()
sum = Delayed()

par = S"(" + sum + S")"
val = par | num

inv = (S"/" + val) > Inv
dir = (S"*" + val)
prd = val + (inv | dir)[0:end] |> Prd

neg = (S"-" + prd) > Neg
pos = (S"+" + prd)
sum.matcher = Nullable{ParserCombinator.Matcher}((prd | neg | pos) + (neg | pos)[0:end] |> Sum)

all = sum + Eos()

for (src, ast, val) in 
    [
     ("1.0", Sum([Prd([1.0])]), 1.0)
     ("-1.0", Sum([Prd([-1.0])]), -1.0)
     ("--1.0", Sum([Neg(Prd([-1.0]))]), 1.0)
     ("1+2", Sum([Prd([1.0]),Prd([2.0])]), 3.0)
     ("1+2*3/4", nothing, 2.5)
     ]
    if ast != nothing
        @test parse_one(src, all)[1] == ast
    end
    @test_approx_eq calc(parse_one(src, all)[1]) val
    println("$src = $val")
end


# some regressino tests
@test_approx_eq calc(parse_one("-5.0/7.0+5.0-5.0", all)[1]) -0.7142857142857144
@test_approx_eq eval(parse("-5.0/7.0+5.0-5.0")) -0.7142857142857144
#@test_approx_eq calc(parse_one("4.0-5.0-0.0/8.0/5.0/3.0*(-6.0/5.0)-9.0*3.0*-((0.0-9.0))*9.0", all)[1]) -0.7142857142857144


# generate random expressions, parse them, and compare the results to
# evaluating in julia

function subexpr()
    expr = string(rand(0:9)) * ".0"
    for k in 1:rand(1:5)
        case = rand(1:6)
        if case < 5
            expr = expr * "+-*/"[case:case] * string(rand(0:9)) * ".0"
        elseif case == 5
            expr = "(" * expr * ")"
        elseif case == 6
            expr = "-" * expr
        end
    end
    expr
end

#for i in 1:20
#    expr = subexpr()
#    for _ in 1:rand(0:4)
#        expr = expr * string("+-*/"[rand(1:4)]) * subexpr()
#    end
#    # julia desn't likerepeated -
#    expr = replace(expr, "r\-+"
#    println(expr)
#    try
#        @test_approx_eq eval(parse(expr)) calc(parse_one(expr, all)[1])
#    catch
#        @test_throws Exception parse(expr)
#        @test_throws Exception parse_one(expr, all)
#    end
#end

