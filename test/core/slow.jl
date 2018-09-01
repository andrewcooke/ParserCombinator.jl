@testset "slow" begin

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
            all1 = make_all(config)
            @time collect(all1(source, matcher))
            @time n = length(collect(all1(source, matcher)))
            println("n results: $n")
            debug, all2 = make(Debug, source, matcher; delegate=config)
            collect(all2)
            println("max depth: $(debug.max_depth)")
            println("max iter: $(debug.max_iter)")
            println("n calls: $(debug.n_calls)")
        end
    end
end
slow(3)
#slow(7)  # not for travis!

println("slow ok")

end
