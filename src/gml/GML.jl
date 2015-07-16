
module GML

using ...ParserCombinator

export parse_raw


function mk_parser()

    @with_names begin

        parse_int(x) = parse(Int32, x)
        parse_flt(x) = parse(Float64, x)

        space   = P"[\n\r\t ]+"
        key     = p"[a-zA-Z][a-zA-Z0-9]*"                     > symbol
        int     = p"(\+|-)?\d+"                               > parse_int
        real    = p"(\+|-)?\d+.\d+((E|e)(\+|-)?\d+)?"         > parse_flt
        str     = S"\"" + p"[^\"]+" + S"\""                   > string
        
        list    = Delayed()
        value   = int | real | str | (S"[" + list + (S"]" | Error("expected ]"))) | Error("expected value")
        element = space[0:end] + key + space[1:end] + value > tuple
        
        list.matcher = element[0:end] + space[0:end]         > vcat
        
        list + Eos()

    end
end

parser = mk_parser()
parse_raw(x) = parse_try_dbg(TryIter(x), Trace(parser))

end
