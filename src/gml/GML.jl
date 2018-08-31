
module GML

using ...ParserCombinator
using Nullables

export parse_raw, parse_dict, GMLError


function mk_parser(string_input)

    # this is such a simple grammar that we don't need backtracking, so we can
    # use Seq! et al, and Error for useful diagnostics.

    # the only tricky things are getting the spaces right so that matching
    # spaces doesn't commit us to anything unexpected, and placing errors only
    # when we're sure we're wrong (you can't have one in the definition of
    # key, for example, because that can fail...).

    @with_names begin

        expect(x) = Error("Expected $x")

        pint(x) = parse(Int64, x)
        pflt(x) = parse(Float64, x)

        comment = P"(#.*)?"

        # we need string input as we match multiple lines
        if string_input

            wspace   = "([\t ]+|[\r\n]+(#.*)?)"
            wstar(x) = string(x, wspace, "*")
            wplus(x) = string(x, wspace, "+")
            space    = ~Pattern(wplus(""))
            spc      = ~Pattern(wstar(""))

            open     = ~Pattern(wstar("\\["))
            close    = ~Pattern(wstar("]"))

            key      = Pattern(wplus("([a-zA-Z][a-zA-Z0-9]*)"), 1)    > Symbol
            int      = Pattern(wstar("((\\+|-)?\\d+)"), 1)            > pint
            real     = Pattern(wstar("((\\+|-)?\\d+.\\d+((E|e)(\\+|-)?\\d+)?)"), 1) > pflt
            str      = Pattern(wstar("\"([^\"]*)\""), 1)

        else

            wspace   = Alt!(P"[\t ]+", Seq!(P"[\r\n]+", comment))
            space    = wspace[1:end,:!]
            spc      = wspace[0:end,:!]

            open     = Seq!(E"[", spc)
            close    = Seq!(E"]", spc)

            key      = Seq!(p"[a-zA-Z][a-zA-Z0-9]*", space)           > Symbol
            int      = Seq!(p"(\+|-)?\d+", spc)                       > pint
            real     = Seq!(p"(\+|-)?\d+.\d+((E|e)(\+|-)?\d+)?", spc) > pflt
            str      = Seq!(Pattern("\"([^\"]*)\"", 1), spc)

        end

        list    = Delayed()
        sublist = Seq!(open, list, Alt!(close, expect("]")))
        value   = Alt!(real, int, str, sublist, expect("value"))
        element = Seq!(key, value)                            > tuple
        
        list.matcher = Nullable{Matcher}(element[0:end,:!]    > vcat)
        
        # first line comment must be explicit (no previous linefeed)
        Seq!(comment, spc, list, Alt!(Seq!(spc, Eos()), expect("key")))

    end
end


# this returns the "natural" representation as nested arrays and tuples
function parse_raw(s; debug=false)
    parser = mk_parser(isa(s, AbstractString))
    try
        (debug ? parse_one_dbg : parse_one)(s, Trace(parser); debug=debug)
    catch x
        if (debug) 
            Base.show_backtrace(stdout, catch_backtrace())
        end
        rethrow()
    end
end


# (semi) structured model of GML graph files

# the GML specs that i have found are really rather frustrating, because they
# don't seem to acknowledge a fundamental problem with this format, which is
# that you cannot tell, from the file alone, whether a particular field is a
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

# after some reflection, I've decide to take a list of names of lists, and to
# validate against that.  this isn't perfect - it doesn't allow for the same
# name to have different meanings in different contexts, for example - but it
# seems to be a good middle ground for "doing the right thing" in general
# cases.

# users with different requirements are free to take the "raw" parse and build
# their own object models.

mutable struct GMLError<:Exception
    msg::AbstractString
end

LISTS = [:graph,:node,:edge]

const GMLDict = Dict{Symbol, Any}

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
