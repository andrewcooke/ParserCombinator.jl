
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
z = Delayed()

a = S"(" + z + S")" | num        # things that can be negated
b = Delayed()
b.matcher = a | (S"-" + b > Neg) # things that can be added or multiplied

c = b + ((S"*" + b) | (S"/" + b > Inv))[0:end] |> Prd

d = c + ((S"*" + c) | (S"-" + c > Neg))[0:end] |> Sum
z.matcher = d

all = z + Eos()

@test typeof(a) == Alt{Void}
@test length(a.matchers) == 2
@test typeof(b) == Delayed{Void}
@test typeof(get(b.matcher)) == Alt{Void}
@test length(get(b.matcher).matchers) == 3  # flattening
@test typeof(c) == TransformSuccess{Void}
@test typeof(c.matcher) == Seq{Void}
@test length(c.matcher.matchers) == 2
@test typeof(c.matcher.matchers[2]) == Depth{Void}
@test typeof(d) == TransformSuccess{Void}
@test typeof(d.matcher) == Seq{Void}
@test length(d.matcher.matchers) == 2
@test typeof(d.matcher.matchers[2]) == Depth{Void}

println("******")

for (src, val) in [
                   ("1", 1),
                   ("-1", -1),
                   ("1+1", 2),
                   ("1-1", 0),
                   ("-1-1", -2)
                   ]
    @test_approx_eq calc(parse_one(src, Debug(all))[1]) val
    println("$src = $val")
end

error()

for (src, ast, val) in 
    [
#     ("1.0", Sum([Prd([1.0])]), 1.0)
#     ("-1.0", Sum([Prd([-1.0])]), -1.0)
#     ("--1.0", Sum([Neg(Prd([-1.0]))]), 1.0)
#     ("1+2", Sum([Prd([1.0]),Prd([2.0])]), 3.0)
     ("1+2*3/4", nothing, 2.5)
     ]
    if ast != nothing
        @test parse_one(src, all)[1] == ast
    end
    @test_approx_eq calc(parse_one(src, all)[1]) val
    println("$src = $val")
end


# some regression tests
@test_approx_eq calc(parse_one("-5.0/7.0+5.0-5.0", all)[1]) -0.7142857142857144
@test_approx_eq eval(parse("-5.0/7.0+5.0-5.0")) -0.7142857142857144
@test_approx_eq calc(parse_one("(0.0-9.0)", all)[1]) -9.0
@test_approx_eq calc(parse_one("((0.0-9.0))", all)[1]) -9.0
@test_approx_eq calc(parse_one("-((0.0-9.0))", all)[1]) 9.0
@test_approx_eq calc(parse_one("(-6.0/5.0)", all)[1]) -1.2
@test_approx_eq calc(parse_one("3.0*-((0.0-9.0))", all)[1]) 27
@test_approx_eq calc(parse_one("-9.0*3.0*-((0.0-9.0))*9.0", all)[1]) -2187.0
@test_approx_eq calc(parse_one("5.0/3.0*(-6.0/5.0)", all)[1]) -2.0
@test_approx_eq calc(parse_one("3*6-9*1", all)[1]) 9
@test_approx_eq calc(parse_one("4.0-5.0-0.0/8.0/5.0/3.0*(-6.0/5.0)-9.0*3.0*-((0.0-9.0))*9.0", all)[1]) -2188.0
@test_approx_eq calc(parse_one("((-6.0/6.0+7.0))*((-1.0-3.0/5.0))+-(9.0)", all)[1]) 0


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

for i in 1:20
    expr = subexpr()
    for _ in 1:rand(0:4)
        expr = expr * string("+-*/"[rand(1:4)]) * subexpr()
    end
    # julia desn't likerepeated -
    expr = replace(expr, "r\-+", "-")
    println(expr)
    try
        @test_approx_eq eval(parse(expr)) calc(parse_one(expr, all)[1])
    catch
        @test_throws Exception parse(expr)
        @test_throws Exception parse_one(expr, all)
    end
end

println("calc ok")
