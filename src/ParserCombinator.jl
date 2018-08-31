
module ParserCombinator

using Nullables
using AutoHashEquals
import Base: iterate, getindex, isless, size, hash,
axes, lastindex, firstindex
import Base: ==, ~, +, &, |, >=, >, |>, !
using Printf: @printf

export Matcher, 
diagnostic, forwards, LineSource, LineIter,
Config, Cache, NoCache, make, make_all, make_one, once,
parse_one, parse_one_cache, parse_one_nocache, 
parse_all, parse_all_cache, parse_all_nocache,
parse_lines, parse_lines_cache,
Debug, Trace, 
parse_dbg, parse_one_dbg, parse_one_cache_dbg, parse_one_nocache_dbg,
parse_all_dbg, parse_all_cache_dbg, parse_all_nocache_dbg,
parse_lines_dbg, parse_lines_cache_dbg,
Success, EMPTY, Failure, FAILURE, Execute,
State, Clean, CLEAN, Dirty, DIRTY,
ParserException, Value, Empty, EMPTY, Delegate, DelegateState,
Epsilon, Insert, Dot, Fail, Drop, Equal, 
Repeat, Depth, Breadth, Depth!, Breadth!, ALL, 
Series, Seq, And, Seq!, And!, Alt, Alt!, Lookahead, Not, Pattern, Delayed, Eos,
ParserError, Error,
Transform, App, Appl, ITransform, IApp, IAppl,
@p_str, @P_str, @e_str, @E_str, Opt, Opt!,
Parse, PUInt, PUInt8, PUInt16, PUInt32, PUInt64, 
PInt, PInt8, PInt16, PInt32, PInt64, PFloat32, PFloat64,
Word, Space,
Star, Plus, Star!, Plus!, StarList, StarList!, PlusList, PlusList!,
@with_names, set_name,
@with_pre, @with_post, set_fix,
TrySource, Try, parse_try, parse_try_dbg, parse_try_cache, parse_try_cache_dbg,
Parsers, axes, lastindex

include("core/types.jl")
include("core/sources.jl")
include("core/names.jl")
include("core/matchers.jl")
include("core/parsers.jl")
include("core/debug.jl")
include("core/transforms.jl")
include("core/sugar.jl")
include("core/extras.jl")
include("core/print.jl")
include("core/fix.jl")
include("core/try.jl")

include("Parsers.jl")

end
