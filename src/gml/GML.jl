
module GML

using ...ParserCombinator

export parse_raw


function mk_parser()

    expect(x) = Error("Expected $x")

    @with_names begin

        parse_int(x) = parse(Int32, x)
        parse_flt(x) = parse(Float64, x)

        wspace  = P"[\n\r\t ]+"
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
        
        list.matcher = element[0:end]                         > vcat
        
        spc + list + ((spc + Eos()) | expect("key"))

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

end
