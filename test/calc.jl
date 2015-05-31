
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
prd = val + (inv | dir)[0:99] |> Prd

neg = (S"-" + prd) > Neg
pos = (S"+" + prd)
sum.matcher = Nullable{SimpleParser.Matcher}((prd | neg | pos) + (neg | pos)[0:99] |> Sum)

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
