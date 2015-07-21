
@test parse_one("aa", s"a"[0:end,:!]) == ["a", "a"]
@test parse_one_cache("aa", s"a"[0:end,:!]) == ["a", "a"]

open("test1.txt", "r") do io
    for c in TrySource(io)
        print(c)
    end
end

open("test1.txt", "r") do io
    f = TrySource(io)
    i = start(f)
    (c, i) = next(f, i)
    @test c == 'a'
    @test f[i:end] == "bcdefghijklmnopqrstuvwxyz\n"
end

for parse in (parse_try, parse_try_nocache, parse_try_dbg, parse_try_nocache_dbg)

    open("test1.txt", "r") do io
        @test_throws ParserException parse(TrySource(io), Trace(p"[a-z]"[0:end] + s"m" > string))
    end

    open("test1.txt", "r") do io
        result = parse(TrySource(io), Try(p"[a-z]"[0:end] + s"m" > string))
        println(result)
        @test result == Any["abcdefghijklm"]
    end

    open("test1.txt", "r") do io
        # multiple lines
        result = parse(TrySource(io), Try(p"(.|\n)"[0:end] + s"5" > string))
        println(result)
        @test result == Any["abcdefghijklmnopqrstuvwxyz\n012345"]
    end

    @test_throws ParserError parse(TrySource("?"), Alt!(p"[a-z]", p"\d", Error("not letter or number")))

end

println("try ok")
