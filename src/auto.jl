
# add == and hash() to composite types (ie type and immutable blocks).

# @auto type Foo
#     a::Int
#     b
# end

# becomes

# type Foo
#     a::Int
#     b
# end
# hash(a::Foo) = hash(a.a, hash(a.b))
# ==(a::Foo, b::Foo) = a.a == b.a && a.b == b.b


function auto_hash(name, names)

    function expand(i)
        if i == length(names)
            :(hash(a.$(names[i])))
        else
            :(hash(a.$(names[i]), $(expand(i+1))))
        end
    end

    quote
        function hash(a::$(name)) 
            $(expand(1))
        end
    end

end

function auto_equals(name, names)

    function expand(i)
        if i == length(names)
            :(a.$(names[i]) == b.$(names[i]))
        else
            :(a.$(names[i]) == b.$(names[i]) && $(expand(i+1)))
        end
    end

    quote
        function ==(a::$(name), b::$(name)) 
            $(expand(1))
        end
    end

end

macro auto(typ)

    @assert typ.head == :type

    if typeof(typ.args[2]) == Symbol
        name = typ.args[2]
    elseif typeof(typ.args[2]) == Expr && typ.args[2].head == :(<:)
        name = typ.args[2].args[1]
    else
        error("Cannot find name for $typ")
    end

    fields = typ.args[3].args
    names = Array(Symbol,0)
    for i in 1:length(fields)
        if typeof(fields[i]) == Symbol
            push!(names, fields[i])
        elseif typeof(fields[i]) == Expr && fields[i].head == :(::)
            push!(names, fields[i].args[1])
        end
    end
    @assert length(names) > 0

    quote
        $(esc(typ))
        $(esc(auto_hash(name, names)))
        $(esc(auto_equals(name, names)))
    end
end
