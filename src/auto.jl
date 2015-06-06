
# TODO - isequal?  handle zero size.  add typeto hash.

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

type UnpackException <: Exception 
    msg
end

function unpack_name(node)
    if isa(node, Symbol)
        node
    else
        i = node.head == :type ? 2 : 1   # skip mutable flag
        if isa(node.args[i], Symbol)
            node.args[i]
        elseif isa(node.args[i], Expr) && node.args[i].head in (:(<:), :(::))
            unpack_name(node.args[i].args[1])
        else
            throw(UnpackException("cannot find name in $(node)"))
        end
    end
end


macro auto(typ)

    @assert typ.head == :type
    name = unpack_name(typ)

    names = Array(Symbol,0)
    for field in typ.args[3].args
        try
            push!(names, unpack_name(field))
        catch ParseException
            # not a field
        end
    end
    @assert length(names) > 0

    quote
        $(esc(typ))
        $(esc(auto_hash(name, names)))
        $(esc(auto_equals(name, names)))
    end
end
