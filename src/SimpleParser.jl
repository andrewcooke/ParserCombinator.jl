
module SimpleParser

using DataStructures.Stack
import Base: start

export parse, ParseException, Equal, Repeat

abstract AST

abstract Return
immutable Failure<:Return
end
immutable Success<:Return
    isource
    result
end
immutable Bounce<:Return
    isource
    ast
    state
end

type Equal<:AST
    string
end

immutable ParseException<:Exception
    msg
end

function match(ast::Equal, source, isource)
    for c in ast.string
        if done(source, isource)
            return Failure()
        end
        s, isource = next(source, isource)
        if s != c
            return Failure()
        end
    end
    return Success(isource, ast.string)
end

type Repeat<:AST
    ast::AST
    n
end

function match(ast::Repeat, source, isource)
    return Bounce(isource, ast.ast, (1, Array{Any,1}()))
end

function resume(ast::Repeat, source, isource, state) 
   return Failure()
end

function resume(ast::Repeat, source, isource, state, result)
    count, array = state
    push!(array, result)
    if count == ast.n
        return Success(isource, array)
    else
        return Bounce(isource, ast.ast, (count+1, array))
    end
end


function parse(source, ast::AST)
    stack = Stack(Any)
    isource = start(source)
    ret = match(ast, source, isource)
    while true
        if typeof(ret) == Success
            if isempty(stack)
                return ret.result
            else
                (ast, state, isource) = pop!(stack)
                ret = resume(ast, source, ret.isource, state, ret.result)
            end
        elseif typeof(ret) == Failure
            if isempty(stack)
                throw(ParseException("failed to parse"))
            else
                (ast, state, isource) = pop!(stack)
                ret = resume(ast, source, isource, state)
            end
        elseif typeof(ret) == Bounce
            push!(stack, (ast, ret.state, ret.isource))
            ret = match(ret.ast, source, ret.isource)
        else
            error("unexpected return $ret from $ast")
        end
    end
end

end
