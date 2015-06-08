

# add == and hash() to composite types (ie type and immutable blocks):
#   @auto type Foo
#       a::Int
#       b
#   end
# becomes
#   type Foo
#       a::Int
#       b
#   end
#   hash(a::Foo) = hash(a.b, hash(a.a, hash(:Foo)))
#   ==(a::Foo, b::Foo) = isequal(a.b, b.b) && isequal(a.a, b.a) && true
# where:
# * we use isequal because we want to match cached Inf values, etc.
# * we include the type in the hash so that different types with the same
#   contents don't collide
# * the type and "true" make it simple to generate code for empty types


function auto_hash(name, names)

    function expand(i)
        if i == 0
            :(hash($(QuoteNode(name))))
        else
            :(hash(a.$(names[i]), $(expand(i-1))))
        end
    end

    quote
        function hash(a::$(name)) 
            $(expand(length(names)))
        end
    end
end

function auto_equals(name, names)

    function expand(i)
        if i == 0
            :true
        else
            :(isequal(a.$(names[i]), b.$(names[i])) && $(expand(i-1)))
        end
    end

    quote
        function ==(a::$(name), b::$(name)) 
            $(expand(length(names)))
        end
    end
end

type UnpackException <: Exception 
    msg
end

unpack_name(node::Symbol) = node

function unpack_name(node::Expr)
    if node.head == :macrocall
        unpack_name(node.args[2])
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
