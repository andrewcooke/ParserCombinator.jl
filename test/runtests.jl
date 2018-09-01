
# modules prevent namespace pollution

module CoreTest

using ParserCombinator
using Test
using Compat
using Nullables

@testset "core" begin

include("core/sources.jl")
include("core/fix.jl")
include("core/print.jl")
include("core/names.jl")
include("core/tests.jl")
include("core/slow.jl")
include("core/case.jl")
include("core/calc.jl")
include("core/debug.jl")
include("core/try.jl")

end
end

module GmlTest

using ParserCombinator
using ParserCombinator.Parsers.GML
using Test
using Compat
using Nullables

@testset "GML" begin
include("gml/ok.jl")
include("gml/errors.jl")
include("gml/example1.jl")
include("gml/example2.jl")
# need zip files unpacking
#include("gml/celegansneural.jl")
#include("gml/polblogs.jl")
#include("gml/10k-49963.jl")

end
end

module DotTest

using ParserCombinator
using ParserCombinator.Parsers.DOT
using Test
using Compat
using Nullables

@testset "DOT" begin
include("dot/example.jl")
include("dot/fragments.jl")
include("dot/subgraphs.jl")
include("dot/examples.jl")
end
end
