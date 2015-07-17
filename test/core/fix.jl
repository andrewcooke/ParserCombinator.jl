
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

    spc = Drop(Star(Space()))

    @with_pre spc begin
        
        sum = Delayed()
        val = S"(" + spc + sum + spc + S")" | PFloat64()
        
        neg = Delayed()             # allow multiple negations (eg ---3)
        neg.matcher = Nullable{Matcher}(val | (S"-" + neg > Neg))
        
        mul = S"*" + neg
        div = S"/" + neg > Inv
        prd = neg + (mul | div)[0:end] |> Prd
        
        add = S"+" + prd
        sub = S"-" + prd > Neg
        sum.matcher = Nullable{Matcher}(prd + (add | sub)[0:end] |> Sum)
        
        all = sum + spc + Eos()

    end
end

parse_one(" 1 + 2 * 3 / 4 ", Trace(all))

for (src, val) in [
                   (" 1 ", 1),
                   (" - 1 ", -1),
                   (" 1 + 1 ", 2),
                   (" 1 - 1 ", 0),
                   (" - 1 - 1 ", -2)
                   ]
#    @test_approx_eq calc(parse_dbg(src, Trace(all))[1]) val
    @test_approx_eq calc(parse_one(src, Trace(all))[1]) val
    println("$src = $val")
end


println("fix ok")
