
module ParserCombinator

using DataStructures.Stack
using Compat
import Base: start, endof, getindex

export @auto, @with_names, set_name,
Config, Cache, NoCache, make_all, make_one, parse_one, parse_all,
Matcher, State, Result, Success, Execute, Response, 
Failure, EMPTY, FAILURE, Clean, CLEAN, Dirty, DIRTY,
ParserException, Value, Empty, EMPTY, Delegate, DelegateState,
Epsilon, Insert, Dot, Fail, Drop, Equal, Repeat, Depth, Breadth, ALL, 
Series, Seq, And, Alt, Lookahead, Not, Pattern, Delayed, Debug, Eos,
TransResult, TransSuccess, TransValue, App, Appl,
@p_str, @P_str, @s_str, @S_str, Opt,
Parse, PUInt, PUInt8, PUInt16, PUInt32, PUInt64, 
PInt, PInt8, PInt16, PInt32, PInt64, PFloat32, PFloat64,
Word, Space, Star, Plus

include("auto.jl")
include("types.jl")
include("names.jl")
include("matchers.jl")
include("parsers.jl")
include("transforms.jl")
include("sugar.jl")
include("extras.jl")

end
