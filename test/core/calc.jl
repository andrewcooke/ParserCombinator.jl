
@testset "calc" begin

# using prev defs from fix.jl

@with_names begin

    sum = Delayed()
    val = E"(" + sum + E")" | PFloat64()

    neg = Delayed()             # allow multiple negations (eg ---3)
    neg.matcher = Nullable{Matcher}(val | (E"-" + neg > Neg))
    
    mul = E"*" + neg
    div = E"/" + neg > Inv
    prd = neg + (mul | div)[0:end] |> Prd
    
    add = E"+" + prd
    sub = E"-" + prd > Neg
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
@test typeof(prd) == Transform
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
    @test calc(parse_one(src, Trace(all))[1]) ≈ val
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
    @test calc(parse_one(src, all)[1]) ≈ val
    println("$src = $val")
end


# some regression tests
@test calc(parse_one("-5.0/7.0+5.0-5.0", all)[1]) ≈ -0.7142857142857144
@test eval(Meta.parse("-5.0/7.0+5.0-5.0")) ≈ -0.7142857142857144
@test calc(parse_one("(0.0-9.0)", all)[1]) ≈ -9.0
@test calc(parse_one("((0.0-9.0))", all)[1]) ≈ -9.0
@test calc(parse_one("-((0.0-9.0))", all)[1]) ≈ 9.0
@test calc(parse_one("(-6.0/5.0)", all)[1]) ≈ -1.2
@test calc(parse_one("3.0*-((0.0-9.0))", all)[1]) ≈ 27
@test calc(parse_one("-9.0*3.0*-((0.0-9.0))*9.0", all)[1]) ≈ -2187.0
@test calc(parse_one("5.0/3.0*(-6.0/5.0)", all)[1]) ≈ -2.0
@test calc(parse_one("3*6-9*1", all)[1]) ≈ 9
@test calc(parse_one("4.0-5.0-0.0/8.0/5.0/3.0*(-6.0/5.0)-9.0*3.0*-((0.0-9.0))*9.0", all)[1]) ≈ -2188.0
@test calc(parse_one("((-6.0/6.0+7.0))*((-1.0-3.0/5.0))+-(9.0)", all)[1]) ≈ -18.6
# this has a large numerical error (~1e-15) and i don't understand why
@test abs(calc(parse_one("7.0/3.0*9.0-5.0-0.0+-(-9.0/7.0)*9.0*-0.0-7.0+-4.0-5.0", all)[1]) - 0.0) < 1e-10

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

a = eval(Meta.parse("-9.0-7.0/0.0/2.0/(-(0.0))*3.0-7.0/-(9.0+5.0)+5.0-7.0"))
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
    expr = replace(expr, r"-+" => "-")
    println("expr $(expr)")
    try
        a = eval(Meta.parse(expr))
        b = calc(parse_one(expr, all)[1])
        println("$a $b")
        if ! isequal(a, b)   # allow for Inf etc
            @test a ≈ b
        end
    catch
        @test_throws Exception parse(expr)
        @test_throws Exception calc(parse_one(expr, all)[1])
    end
end

println("calc ok")

end
