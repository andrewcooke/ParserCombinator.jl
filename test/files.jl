
open("test1.txt", "r") do io
    for c in TryIter(io)
        print(c)
    end
end

open("test1.txt", "r") do io
    f = TryIter(io)
    i = start(f)
    (c, i) = next(f, i)
    @test c == 'a'
    @test f[i:end] == "bcdefghijklmnopqrstuvwxyz\n"
end

open("test1.txt", "r") do io
    @test_throws ParserException parse_try(TryIter(io), p"[a-z]"[0:end] + s"m" > string)
end

open("test1.txt", "r") do io
    result = parse_try(TryIter(io), Try(p"[a-z]"[0:end] + s"m" > string))
    println(result)
    @test result == Any["abcdefghijklm"]
end

open("test1.txt", "r") do io
    # multiple lines
    result = parse_try(TryIter(io), Try(p"(.|\n)"[0:end] + s"5" > string))
    println(result)
    @test result == Any["abcdefghijklmnopqrstuvwxyz\n012345"]
end

parse_try(TryIter("?"), Alt!(p"[a-z]"), p"\d", Error("not letter or number"))

println("files ok")

