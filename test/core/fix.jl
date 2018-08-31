
import Base: ==


# https://github.com/JuliaLang/julia/issues/11618
signed_prod(lst) = length(lst) == 1 ? lst[1] : Base.prod(lst)
signed_sum(lst) = length(lst) == 1 ? lst[1] : Base.sum(lst)

abstract type Node end
==(n1::Node, n2::Node) = isequal(n1.val, n2.val)
calc(n::Float64) = n
mutable struct Inv<:Node val end
calc(i::Inv) = 1.0/calc(i.val)
mutable struct Prd<:Node val end
calc(p::Prd) = signed_prod(map(calc, p.val))
mutable struct Neg<:Node val end
calc(n::Neg) = -calc(n.val)
mutable struct Sum<:Node val end
calc(s::Sum) = signed_sum(map(calc, s.val))

@testset "fix" begin

@with_names begin

    spc = Drop(Star(Space()))

    @with_pre spc begin
        
        sum = Delayed()
        val = E"(" + spc + sum + spc + E")" | PFloat64()
        
        neg = Delayed()             # allow multiple negations (eg ---3)
        neg.matcher = Nullable{Matcher}(val | (E"-" + neg > Neg))
        
        mul = E"*" + neg
        div = E"/" + neg > Inv
        prd = neg + (mul | div)[0:end] |> Prd
        
        add = E"+" + prd
        sub = E"-" + prd > Neg
        sum.matcher = Nullable{Matcher}(prd + (add | sub)[0:end] |> Sum)
        
        all = sum + spc + Eos()

    end
end

parse_one(" 1 + 2 * 3 / 4 ", Trace(all); debug=true)

for (src, v) in [
                   (" 1 ", 1),
                   (" - 1 ", -1),
                   (" 1 + 1 ", 2),
                   (" 1 - 1 ", 0),
                   (" - 1 - 1 ", -2)
                   ]
#    @test calc(parse_dbg(src, Trace(all))[1]) ≈ v
    @test calc(parse_one(src, Trace(all))[1]) ≈ v
    println("$src = $v")
end


println("fix ok")

end
