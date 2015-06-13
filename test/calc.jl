
# https://github.com/JuliaLang/julia/issues/11618
signed_prod(lst) = length(lst) == 1 ? lst[1] : Base.prod(lst)
signed_sum(lst) = length(lst) == 1 ? lst[1] : Base.sum(lst)

abstract Node
==(n1::Node, n2::Node) = isequal(n1.val, n2.val)
calc(n::Float64) = n
type Inv<:Node val end
calc(i::Inv) = 1.0/calc(i.val)
type Prd<:Node val end
calc(p::Prd) = signed_prod(map(calc, p.val))
type Neg<:Node val end
calc(n::Neg) = -calc(n.val)
type Sum<:Node val end
calc(s::Sum) = signed_sum(map(calc, s.val))

@with_names begin

    sum = Delayed()
    val = S"(" + sum + S")" | PFloat64()

    neg = Delayed()             # allow multiple negations (eg ---3)
    neg.matcher = Nullable{Matcher}(val | (S"-" + neg > Neg))
    
    mul = S"*" + neg
    div = S"/" + neg > Inv
    prd = neg + (mul | div)[0:end] |> Prd
    
    add = S"+" + prd
    sub = S"-" + prd > Neg
    sum.matcher = Nullable{Matcher}(prd + (add | sub)[0:end] |> Sum)
    
    all = sum + Eos()

end

println(all)

@test val.name == :val
@test typeof(val) == Alt
@test length(val.matchers) == 2
@test neg.name == :neg
@test typeof(neg) == Delayed
@test typeof(get(neg.matcher)) == Alt
@test length(get(neg.matcher).matchers) == 3  # flattening
@test prd.name == :prd
@test typeof(prd) == TransSuccess
@test typeof(prd.matcher) == Seq
@test length(prd.matcher.matchers) == 2
@test typeof(prd.matcher.matchers[2]) == Depth
@test sum.name == :sum
@test typeof(sum) == Delayed
@test typeof(get(sum.matcher).matcher) == Seq
@test length(get(sum.matcher).matcher.matchers) == 2
@test typeof(get(sum.matcher).matcher.matchers[2]) == Depth

parse_dbg("1+2*3/4", Trace(all))

for (src, val) in [
                   ("1", 1),
                   ("-1", -1),
                   ("1+1", 2),
                   ("1-1", 0),
                   ("-1-1", -2)
                   ]
#    @test_approx_eq calc(parse_dbg(src, Trace(all))[1]) val
    @test_approx_eq calc(parse_one(src, Trace(all))[1]) val
    println("$src = $val")
end

for (src, ast, val) in 
    [
     ("1.0", Sum([Prd([1.0])]), 1.0)
     ("-1.0", Sum([Prd([-1.0])]), -1.0)
     ("--1.0", Sum([Prd([Neg(-1.0)])]), 1.0)
     ("1+2", Sum([Prd([1.0]),Prd([2.0])]), 3.0)
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
@test_approx_eq calc(parse_one("((-6.0/6.0+7.0))*((-1.0-3.0/5.0))+-(9.0)", all)[1]) -18.6

x = Neg(Prd(Any[7.0,
                Inv(0.0),
                Inv(2.0),
                Inv(Neg(0.0))]))
y = calc(x)
z = -7.0/0.0/2.0/-0.0
println("$x $y $z")
@test isequal(y, z)

for x in [Inv(Neg(0.0)),
          Inv(Prd(Any[Neg(Sum(Any[Prd(Any[0.0])]))])),
          Inv(Sum(Any[Prd(Any[Neg(Sum(Any[Prd(Any[0.0])]))])]))
          ]
    y = calc(x)
    println("$x $y")
    @test isequal(y, -Inf)
end

x = Neg(Prd(Any[7.0,
                Inv(0.0),
                Inv(2.0),
                Inv(Sum(Any[Prd(Any[Neg(Sum(Any[Prd(Any[0.0])]))])])),
                3.0]))
y = calc(x)
z = -7.0/0.0/2.0/(-(0.0))*3.0
println("$x $y $z")
@test isequal(y, z)

p = Sum(Any[Prd(Any[-9.0]),
            Neg(Prd(Any[7.0,Inv(0.0),Inv(2.0),Inv(Sum(Any[Prd(Any[Neg(Sum(Any[Prd(Any[0.0])]))])])),3.0])),
            Neg(Prd(Any[7.0,Inv(Neg(Sum(Any[Prd(Any[9.0]),Prd(Any[5.0])])))])),
            Prd(Any[5.0]),
            Neg(Prd(Any[7.0]))]) 

a = eval(parse("-9.0-7.0/0.0/2.0/(-(0.0))*3.0-7.0/-(9.0+5.0)+5.0-7.0"))
b = parse_one("-9.0-7.0/0.0/2.0/(-(0.0))*3.0-7.0/-(9.0+5.0)+5.0-7.0", all)[1]
c = calc(b)
println("$a $b $c")
@test isequal(a, c)

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
    # julia desn't like repeated -
    expr = replace(expr, r"-+", "-")
    println("expr $(expr)")
    try
        a = eval(parse(expr)) 
        b = calc(parse_one(expr, all)[1])
        if ! isequal(a, b)   # allow for Inf etc
            @test_approx_eq a b
        end
    catch
        @test_throws Exception parse(expr)
        @test_throws Exception calc(parse_one(expr, all)[1])
    end
end

println("calc ok")
