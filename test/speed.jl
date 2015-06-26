
# compare exceptions to returning a type

function run_exception(n)
    count = 0
    for i in 1:n
        try
            random_exception()
        catch
            count += 1
        end
    end
    println("exceptions: $count")
end

function random_exception()
    if rand(1:2) == 1
        error()
    end
end

function run_type(n)
    count = 0
    for i in 1:n
        if isa(random_type(), A)
            count += 1
        end
    end
    println("types: $count")
end

type A end
type B end

function random_type()
    if rand(1:2) == 1
        A()
    else
        B()
    end
end

run_exception(10)
run_type(10)
@time run_exception(1000)
@time run_type(1000)
@time run_exception(1000)
@time run_type(1000)


# exceptions are much slower

# exceptions: 521
#  33.651 milliseconds (703 allocations: 20269 bytes)
# types: 519
# 225.958 microseconds (31 allocations: 1248 bytes)
# exceptions: 518
#  33.506 milliseconds (549 allocations: 9552 bytes)
# types: 498
# 205.418 microseconds (30 allocations: 1232 bytes)
