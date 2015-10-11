
# set this to force tetsing for malmaud branch
#FAST_REGEX=true

using ParserCombinator

using Base.Test
using Compat

include("dot/fragments.jl")
exit()

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

include("gml/ok.jl")
include("gml/errors.jl")
include("gml/example1.jl")
include("gml/example2.jl")
# need zip files unpacking
#include("gml/celegansneural.jl")
#include("gml/polblogs.jl")
#include("gml/10k-49963.jl")
