
module ParserCombinator

using Compat
using AutoHashEquals
import Base: start, next, done, endof, getindex, colon

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
StrongStreamIter, WeakStreamIter, ExpiredContent, FailExpired, Try,
parse_weak, parse_weak_dbg

include("types.jl")
include("names.jl")
include("matchers.jl")
include("parsers.jl")
include("debug.jl")
include("transforms.jl")
include("sugar.jl")
include("extras.jl")
include("print.jl")
include("fix.jl")
include("files.jl")

end
