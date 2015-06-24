
for iter in (StrongStreamIter, WeakStreamIter)
    println(iter)

    open("test1.txt", "r") do io
        for c in iter(io)
            print(c)
        end
    end

    open("test1.txt", "r") do io
        f = iter(io)
        i = start(f)
        (c, i) = next(f, i)
        @test c == 'a'
        @test f[i:end] == "bcdefghijklmnopqrstuvwxyz\n"
    end

    open("test1.txt", "r") do io
        # this backtracks within a single line
        result = parse_weak(iter(io), p"[a-z]"[0:end] + s"m" > string)
        println(result)
        @test result == Any["abcdefghijklm"]
    end

    open("test1.txt", "r") do io
        # this backtracks across multiple lines
#        result = parse_weak(iter(io), p"."[0:end] + s"5" > string)
        result = parse_weak_dbg(iter(io), p"."[0:end] + s"5" > string)
        println(result)
    end

end

println("files ok")

