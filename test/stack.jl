
# compare stack depth to trampoline depth

function stack(n, m)
    if n > m
        n
    else
        if n % 1000 == 0
#            println("stack $n")
        end
        n + stack(n+1, m)
    end
end

stack(0, 10)
@time println(stack(0, 100_000))
# stack limit is somewhere around 100,000 (certainly less than 200,000)

abstract Msg

type Call<:Msg
    before::Function
    after::Function
    value::Int
end

type Return<:Msg
    value::Int
end
   
function inc(n, m)
    if n > m
        Return(n)
    else
        if n % 1000 == 0
#            println("trampoline $n")
        end
        Call(inc, (x, m) -> Return(n+x), n+1)
    end
end

function sum(n, m)
    Return(n)
end
function trampoline(n, m)
    stack = Function[inc]
    while length(stack) > 0
        f = pop!(stack)
        msg = f(n, m)
        if isa(msg, Call)
            push!(stack, msg.after)
            push!(stack, msg.before)
        end
        n = msg.value
    end
    n
end
    

trampoline(0, 10)
@time println(trampoline(0, 100_000))
@time println(trampoline(0, 1_000_000))
@time println(trampoline(0, 10_000_000))
