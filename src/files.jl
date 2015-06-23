

# the state for these (which i've unfortunately called "iter"
# throughout the rest of the code) is (a, s), where a is an index into
# the lines, and s is an index into that line.

abstract StreamIter  # must contain io field

start(f::StreamIter) = (1, 1)

EOL = (-1, -1)
endof(f::StreamIter) = EOL

# very restricted - just enough to support iter[i:end] as current line
# for regexps
function getindex(f::StreamIter, r::UnitRange)
    a, s = r.start
    line = line_at(f, a)
    if r.stop == EOL
        t = endof(line)
    else
        b, t = r.stop
        @assert a == b
    end
    return line[s:t]
end

function next(f::StreamIter, i)
    a, s = i
    line = line_at(f, a)
    if done(line, s)
        next(f, (a+1, 1))
    else
        c, s = next(line, s)
        c, (a, s)
    end
end

function done(f::StreamIter, i)
    try
        a, s = i
        line = line_at(f, a)
        done(line, s) && eof(f.io)
    catch
        true
    end
end


type StrongStreamIter<:StreamIter
    io::IOStream
    lines::Array{AbstractString,1}
    StrongStreamIter(io::IOStream) = new(io, AbstractString[])
end

function line_at(f::StrongStreamIter, a)
    while length(f.lines) < a
        push!(f.lines, readline(f.io))
    end
    f.lines[a]
end


type ExpiredContent<:Exception end

type WeakStreamIter<:StreamIter
    io::IOStream
    frozen::Bool
    zero::Int
    lines::Array{AbstractString,1}
    WeakStreamIter(io::IOStream) = new(io, false, 0, AbstractString[])
end

function line_at(f::WeakStreamIter, a)
    if a < f.zero
        throw(ExpiredContent())
    end
    while length(f.lines) < a - f.zero
        if f.frozen
            push!(f.lines, readline(f.io))
        else
            f.zero += length(f.lines)  # discarded
            f.lines = AbstractString[readline(f.io)]
        end
    end
    f.lines[a - f.zero]
end
