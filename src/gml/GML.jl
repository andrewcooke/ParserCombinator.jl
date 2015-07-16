
module GML

using ...ParserCombinator

export parse_raw

# TODO - single line comments


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

        parse_int(x) = parse(Int32, x)
        parse_flt(x) = parse(Float64, x)

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
        
        # first line comment must be explicit (no prefious linefeed)
        comment + spc + list + ((spc + Eos()) | expect("key"))

    end
end

parser = mk_parser()


function line(s::AbstractString, e::ParserError{TryIter})
    lines = split(s, "\n")
    if e.iter.line <= length(lines)
        lines[e.iter.line]
    else
        "[End of stream]"
    end
end

# this returns the "natural" representation as nested arrays and tuples
function parse_raw(s::AbstractString; debug=false)
    try
        (debug ? parse_try_dbg : parse_try)(TrySource(s), Trace(parser))
    catch x
        if isa(x, ParserError)
            l = line(s, x)
            arrow = string(repeat(" ", x.iter.col-1), "^")
            throw(ParserError("$(x.msg) at ($(x.iter.line),$(x.iter.col))\n$l\n$(arrow)\n", x.iter))
        else
            throw(x)
        end
    end
end


# structured model of GML graph files




end
