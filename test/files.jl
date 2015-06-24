
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

end

println("files ok")

