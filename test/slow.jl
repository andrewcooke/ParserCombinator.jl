
# is caching useful?  only in extreme cases, apparently
# (but we may need to define equality on states!)

function slow(n)
#    matcher = Repeat(Repeat(Equal("a"), 0, n), n, 0)
#    matcher = Seq(Repeat(Equal("a"), 0, ), Repeat(Equal("a"), 0, n))
#    for greedy in (true, false)
    for greedy in (true,)  # false just eats memory
        println("greedy $greedy")
        matcher = Repeat(Equal("a"), 0, n; greedy=greedy)
        for i in 1:n
            matcher = Seq(Repeat(Equal("a"), 0, n; greedy=greedy), matcher)
        end
        source = repeat("a", n)
        for config in (NoCache, Cache)
            println("$(config)")
            all = make_all(config)
            @time collect(all(source, matcher))
            @time n = length(collect(all(source, matcher)))
            println(n)
        end
    end
end
slow(3)
# slow(6)  # not for travis!

println("slow ok")
