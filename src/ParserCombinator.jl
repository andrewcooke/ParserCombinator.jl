
module ParserCombinator

using Compat
using AutoHashEquals
import Base: start, next, done, endof, getindex, colon, isless

export Matcher, 
Config, Cache, NoCache, make, make_all, make_one, once,
parse_one, parse_one_cache, parse_one_nocache, 
parse_all, parse_all_cache, parse_all_nocache,
Debug, Trace, 
parse_dbg, parse_one_dbg, parse_one_cache_dbg, parse_one_nocache_dbg,
parse_all_dbg, parse_all_cache_dbg, parse_all_nocache_dbg,
Success, EMPTY, Failure, FAILURE, Execute,
State, Clean, CLEAN, Dirty, DIRTY,
ParserException, Value, Empty, EMPTY, Delegate, DelegateState,
Epsilon, Insert, Dot, Fail, Drop, Equal, 
Repeat, Depth, Breadth, Depth!, Breadth!, ALL, 
Series, Seq, And, Seq!, And!, Alt, Alt!, Lookahead, Not, Pattern, Delayed, Eos,
Transform, App, Appl,
@p_str, @P_str, @s_str, @S_str, Opt,
Parse, PUInt, PUInt8, PUInt16, PUInt32, PUInt64, 
PInt, PInt8, PInt16, PInt32, PInt64, PFloat32, PFloat64,
Word, Space, Star, Plus,
@with_names, set_name,
@with_pre, @with_post, set_fix,
TrySource, TryIter, ExpiredContent, TryCache, TryNoCache, Try, 
ParserError, Error, 
parse_try, parse_try_dbg, parse_try_nocache, parse_try_nocache_dbg,
Parsers

include("core/types.jl")
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
