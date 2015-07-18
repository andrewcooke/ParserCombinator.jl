
module GML

using ...ParserCombinator
using Compat

export parse_raw, parse_dict, parse_id_raw, parse_id_dict, GMLError


function mk_parser()

    # this is such a simple grammar that we can use parse_try and Error() to
    # give useful error messages (we don't need to backtrack to any degree).

    # the only tricky things are getting the spaces right so that matching
    # spaces doesn't commit us to anything unexpeted, and placing errors only
    # when we're sure we're wrong (you can't have one in the definition of
    # key, for example, because that can fail...).

    # inside a function just to avoid junk in global namespace.

    @with_names begin

        expect(x) = Error("Expected $x")

        parse_int(x) = parse(Int, x)
        parse_flt(x) = parse(Float, x)

        comment = P"(#.*)?"
        wspace  = P"[\t ]+" | (P"[\r\n]+" + comment)
        space   = wspace[1:end]
        spc     = wspace[0:end]

        key     = p"[a-zA-Z][a-zA-Z0-9]*"                     > symbol
        int     = p"(\+|-)?\d+"                               > parse_int
        real    = p"(\+|-)?\d+.\d+((E|e)(\+|-)?\d+)?"         > parse_flt
        str     = S"\"" + p"[^\"]+"[0:end] + S"\""            > string

        list    = Delayed()
        sublist = S"[" + spc + list + ((S"]" + spc) | expect("]"))
        value   = (real | int | str | sublist | expect("value")) + spc
        element = key + space + value                         > tuple
        
        list.matcher = Nullable{Matcher}(element[0:end]       > vcat)
        
        # first line comment must be explicit (no previous linefeed)
        comment + spc + list + ((spc + Eos()) | expect("key"))

    end
end

parser = mk_parser()


function line(s::AbstractString, e::ParserError{TryIter})
    lines = split(s, "\n")
    e.iter.line <= length(lines) ? lines[e.iter.line] : "[End of stream]"
end

function line(io::IO, e::ParserError{TryIter})
    seekstart(io)
    lne = ""
    for i in 1:e.iter.line
        lne = readline(io)
    end
    lne == "" ? "[End of stream]" : lne[1:end-1]
end

# this returns the "natural" representation as nested arrays and tuples
function parse_raw(s; debug=false)
    try
        # we don't seem to need the cache and it's 2x faster without
        (debug ? parse_try_nocache_dbg : parse_try_nocache)(TrySource(s), Trace(parser); debug=debug)
    catch x
        if (debug) 
            Base.show_backtrace(STDOUT, catch_backtrace())
        end
        if isa(x, ParserError)
            l = line(s, x)
            arrow = string(repeat(" ", x.iter.col-1), "^")
            throw(ParserError("$(x.msg) at ($(x.iter.line),$(x.iter.col))\n$l\n$(arrow)\n", x.iter))
        else
            throw(x)
        end
    end
end


# (semi) structured model of GML graph files

# the GML specs that i have found are really rather frustrating, because they
# don't seme to acknowledge a fundamental problem with this format, which is
# that you cannot tell, from the file alone, whether a particuar field is a
# list or a single value.

# obviously, a name that occurs multiple times in a single scope is a list.
# but the opposite - that an isolated name is a single value - is not
# necessarily true, because it may be a singleton list.

# one solution is to make a model that very closely follows the "predefined
# keys" part of himsolt's 1996 document, available as part of the tarball from
# http://www.fim.uni-passau.de/fileadmin/files/lehrstuhl/brandenburg/projekte/gml/gml-documentation.tar.gz
# but that seems very specific, perhaps dated, and still doesn't help with
# additional fields.

# another solution is to treat everything as a list, and use dictionaries of
# lists.  but that means that the idea of "keys" is messed up with additional
# [1] indexes into singleton lists.

# after some reflection, i've decide to take a list of names of lists, and to
# validate against that.  this isn't perfect - it doesn't allow for the same
# name to have different meanings in different contexts, for example - but it
# seems to be a good middle ground for "doing the right thing" in general
# cases.

# users with different requirements are free to take the "raw" parse and build
# their own object models.

type GMLError<:Exception
    msg::AbstractString
end

LISTS = [:graph,:node,:edge]

typealias GMLDict Dict{Symbol, Any}

function build_dict(raw; lists=LISTS, unsafe=false)
    root = GMLDict()
    if length(raw) > 0
        build_dict(root, raw[1]; lists=lists, unsafe=unsafe)
    end
    root
end

function build_dict(dict::GMLDict, raw; lists=LISTS, unsafe=false)
    for (name, value) in raw
        if isa(value, Vector)
            entry = GMLDict()
            build_dict(entry, value; lists=lists, unsafe=unsafe)
        else
            entry = value
        end
        if name in lists
            if !haskey(dict, name)
                dict[name] = Any[]
            end
            push!(dict[name], entry)
        else
            if !haskey(dict, name)
                dict[name] = entry
            elseif !unsafe
                throw(GMLError("$name is a list"))
            end
        end
    end
end

# lists describes which symbols should be modelled as lists
# if unsafe is false, multiple values for non-list symbols throw an error;
# if true they are silently discarded
parse_dict(s; debug=false, lists=LISTS, unsafe=false) = build_dict(parse_raw(s; debug=debug); lists=lists, unsafe=unsafe)

end
