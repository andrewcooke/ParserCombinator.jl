[![Build
Status](https://travis-ci.org/andrewcooke/ParserCombinator.jl.png)](https://travis-ci.org/andrewcooke/ParserCombinator.jl)
[![Coverage Status](https://coveralls.io/repos/andrewcooke/ParserCombinator.jl/badge.svg)](https://coveralls.io/r/andrewcooke/ParserCombinator.jl)
[![ParserCombinator](http://pkg.julialang.org/badges/ParserCombinator_release.svg)](http://pkg.julialang.org/?pkg=ParserCombinator&ver=release)



# ParserCombinator

* [Example](#example)
* [Install](#install)
* [Manual](#manual)
* [Design](#design)
* [Releases](#releases)

A parser combinator library for Julia, similar to those in other
languages, like Haskell's Parsec or Python's pyparsing.

ParserCombinator's main advantage may be its flexible design, which
separates the matchers from the evaluation strategy.  That may sound
odd, but makes it [easy](#evaluation) to "plug in" memoization, or
debug traces, or to restrict backtracking in a similar way to Parsec -
all while using the same grammar.

It can also parse any iterable type (not just strings) (except for
regexp matchers, of course).

## Example

```julia
using ParserCombinator


# the AST nodes we will construct, with evaluation via calc()

abstract Node
==(n1::Node, n2::Node) = n1.val == n2.val
calc(n::Float64) = n
type Inv<:Node val end
calc(i::Inv) = 1.0/calc(i.val)
type Prd<:Node val end
calc(p::Prd) = Base.prod(map(calc, p.val))
type Neg<:Node val end
calc(n::Neg) = -calc(n.val)
type Sum<:Node val end
calc(s::Sum) = Base.sum(map(calc, s.val))


# the grammar (the combinators!)

sum = Delayed()
val = S"(" + sum + S")" | PFloat64()

neg = Delayed()       # allow multiple (or no) negations (eg ---3)
neg.matcher = val | (S"-" + neg > Neg)

mul = S"*" + neg
div = S"/" + neg > Inv
prd = neg + (mul | div)[0:end] |> Prd

add = S"+" + prd
sub = S"-" + prd > Neg
sum.matcher = prd + (add | sub)[0:end] |> Sum

all = sum + Eos()


# and test 

# this prints 2.5
calc(parse_one("1+2*3/4")[0])

# this prints [Sum([Prd([1.0]),Prd([2.0])])]
parse_one("1+2")
```

Some explanation of the above:

* I used rather a lot of "syntactic sugar".  You can use a more verbose,
  "parser combinator" style if you prefer.  For example, `Seq(...)` instead of
  `+`, or `App(...)` instead of `>`.

* The matcher `S"xyz"` matches and then discards the string `"xyz"`.

* Every matcher returns a list of matched values.  This can be an empty list
  if the match succeeded but matched nothing.

* The operator `+` matches the expressions to either side and appends the
  resulting lists.  Similarly, `|` matches one of two alternatives.

* The operator `|>` calls the function to the right, passing in the results
  from the matchers on the left.

* `>` is similar to `|>` but interpolates the arguments (ie uses `...`).  So
  instead of passing a list of values, it calls the function with multiple
  arguments.

* `Delayed()` lets you define a loop in the grammar.

* The syntax `[0:end]` is a greedy repeat of the matcher to the left.  An
  alternative would be `Star(...)`, while `[3:4]` would match only 3 or 4
  values.

And it supports packrat parsing too (more exactly, it can memoize results to
avoid repeating matches).

Still, for large parsing tasks (eg parsing source code for a compiler) it
would probably be better to use a wrapper around an external parser generator,
like Anltr.

**Note:** There's an [issue](https://github.com/JuliaLang/Compat.jl/issues/94)
  with the Compat library which means the code above (the assignment to
  `Delayed.matcher`) doesn't work with 0.3.  See [calc.jl](test/calc.jl) for
  the uglier, hopefully temporary, 0.3 version.

## Install

```julia
julia> Pkg.add("ParserCombinator")
```

## Manual

* [Evaluation](#evaluation)
* [Basic Matchers](#basic-matchers)
  * [Equality](#equality)
  * [Sequences](#sequences)
  * [Empty Values](#empty-values)
  * [Alternates](#alternates)
  * [Regular Expressions](#regular-expressions)
  * [Repetition](#repetition)
  * [Full Match](#full-match)
  * [Transforms](#transforms)
  * [Lookahead And Negation](#lookahead-and-negation)
* [Other](#other)
  * [Backtracking](#backtracking)
  * [Controlling Memory Use](#controlling-memory-use)
  * [Spaces - Pre And Post-Fixes](#spaces---pre-and-post-fixes)
  * [Locating Errors](#locating-errors)
  * [Coding Style](#coding-style)
  * [Adding Matchers](#adding-matchers)
  * [Debugging](#debugging)
  * [More Information](#more-information)

### Evaluation

Once you have a grammar (see [below](#basic-matchers)) you can
evaluate it against some input in various ways:

* `parse_one()` - a simple, recursive decent parser with backtracking,
  but no memoization.  Returns a single result or throws a
  `ParserException`.

* `parse_all()` - a packrat parser, with memoization, that returns an
  iterator (evaluated lazily) over all possible parses of the input.

* `parse_try()` - similar to Haskell's Parsec, with backtracking only
  inside the `Try()` matcher (but no memoization).  More info
  [here](#controlling-memory-use).

* `parse_dbg()` - as `parse_one()`, but also prints a trace of
  evaluation for all of the matchers that are children of a `Trace()`
  matchers.  Can also be used with other matchers via the keword
  `delegate`; for example `parse_dbg(...; delegate=Cache)` will
  provide tracing of the packrat parser (`parse_all()` above).  More
  info [here](#debugging).

These are all implemented by providing different `Config` subtypes.
For more information see [Design](#design), [types.jl](src/types.jl)
and [parsers.jl](src/parsers.jl).

### Basic Matchers

In what follows, remember that the power of parser combinators comes from how
you combine these.  They can all be nested, refer to each other, etc etc.

#### Equality

```julia
julia> parse_one("abc", Equal("ab"))
1-element Array{Any,1}:
 "ab"

julia> parse_one("abc", Equal("abx"))
ERROR: ParserCombinator.ParserException("cannot parse")
```

This is so common that there's a corresponding [string
literal](http://julia.readthedocs.org/en/latest/manual/strings/#non-standard-string-literals)
(it's "s" for "string").

```julia
julia> parse_one("abc", s"ab")
1-element Array{Any,1}:
 "ab"
```

#### Sequences

Matchers return lists of values.  Multiple matchers can return lists of lists,
or the results can be "flattened" a level (usually more useful):

```julia
julia> parse_one("abc", Series(Equal("a"), Equal("b")))
2-element Array{Any,1}:
 "a"
 "b"

julia> parse_one("abc", Series(Equal("a"), Equal("b"); flatten=false))
2-element Array{Any,1}:
 Any["a"]
 Any["b"]

julia> parse_one("abc", Seq(Equal("a"), Equal("b")))
2-element Array{Any,1}:
 "a"
 "b"

julia> parse_one("abc", And(Equal("a"), Equal("b")))
2-element Array{Any,1}:
 Any["a"]
 Any["b"]

julia> parse_one("abc", s"a" + s"b")
2-element Array{Any,1}:
 "a"
 "b"

julia> parse_one("abc", s"a" & s"b")
2-element Array{Any,1}:
 Any["a"]
 Any["b"]
```

Where `Series()` is implemented as `Seq()` or `And()`, depending on the value
of `flatten` (default `true`).

#### Empty Values

Often, you want to match something but then discard it.  An empty (or
discarded) value is an empty list.  This may help explain why I said
flattening lists was useful above.

```julia
julia> parse_one("abc", And(Drop(Equal("a")), Equal("b")))
2-element Array{Any,1}:
 Any[]   
 Any["b"]

julia> parse_one("abc", Seq(Drop(Equal("a")), Equal("b")))
1-element Array{Any,1}:
 "b"

julia> parse_one("abc", ~s"a" + s"b")
1-element Array{Any,1}:
 "b"

julia> parse_one("abc", S"a" + s"b")
1-element Array{Any,1}:
 "b"
```

Note the `~` (tilde / home directory) and capital `S` in the last two
examples, respectively.

#### Alternates

```julia
julia> parse_one("abc", Alt(s"x", s"a"))
1-element Array{Any,1}:
 "a"

julia> parse_one("abc", s"x" | s"a")
1-element Array{Any,1}:
 "a"
```

#### Regular Expressions

```julia
julia> parse_one("abc", Pattern(r".b."))
1-element Array{Any,1}:
 "abc"

julia> parse_one("abc", p".b.")
1-element Array{Any,1}:
 "abc"

julia> parse_one("abc", P"." + p"b.")
1-element Array{Any,1}:
 "bc"
```

As with equality, a capital prefix to the string literal ("p" for "pattern" by
the way) implies that the value is dropped.

Note that regular expresions do not backtrack.  A typical, greedy,
regular expression will match as much of the input as possible, every
time that it is used.  Backtracking only exists within the library
matchers (which can duplicate regular expression functionality, when
needed).

#### Repetition

```julia
julia> parse_one("abc", Repeat(p"."))
3-element Array{Any,1}:
 "a"
 "b"
 "c"

julia> parse_one("abc", Repeat(p".", 2))
2-element Array{Any,1}:
 "a"
 "b"

julia> collect(parse_all("abc", Repeat(p".", 2, 3)))
2-element Array{Any,1}:
 Any["a","b","c"]
 Any["a","b"]    

julia> parse_one("abc", Repeat(p".", 2; flatten=false))
2-element Array{Any,1}:
 Any["a"]
 Any["b"]

julia> collect(parse_all("abc", Repeat(p".", 0, 3)))
4-element Array{Any,1}:
 Any["a","b","c"]
 Any["a","b"]    
 Any["a"]        
 Any[]           

julia> collect(parse_all("abc", Repeat(p".", 0, 3; greedy=false)))
4-element Array{Any,1}:
 Any[]           
 Any["a"]        
 Any["a","b"]    
 Any["a","b","c"]
```

You can also use `Depth()` and `Breadth()` for greedy and non-greedy repeats
directly (but `Repeat()` is more readable, I think).

The sugared version looks like this:

```julia
julia> parse_one("abc", p"."[1:2])
2-element Array{Any,1}:
 "a"
 "b"

julia> parse_one("abc", p"."[1:2,:?])
1-element Array{Any,1}:
 "a"

julia> parse_one("abc", p"."[1:2,:&])
2-element Array{Any,1}:
 Any["a"]
 Any["b"]

julia> parse_one("abc", p"."[1:2,:&,:?])
1-element Array{Any,1}:
 Any["a"]
```

Where the `:?` symbol is equivalent to `greedy=false` and `:&` to
`flatten=false` (compare with `+` and `&` above).

There are also some well-known special cases:

```julia
julia> collect(parse_all("abc", Plus(p".")))
3-element Array{Any,1}:
 Any["a","b","c"]
 Any["a","b"]    
 Any["a"]        

julia> collect(parse_all("abc", Star(p".")))
4-element Array{Any,1}:
 Any["a","b","c"]
 Any["a","b"]    
 Any["a"]        
 Any[]           
```

#### Full Match

To ensure that all the input is matched, add `Eos()` to the end of the
grammar.

```julia
julia> parse_one("abc", Equal("abc") + Eos())
1-element Array{Any,1}:
 "abc"

julia> parse_one("abc", Equal("ab") + Eos())
ERROR: ParserCombinator.ParserException("cannot parse")
```

#### Transforms

Use `App()` or `>` to pass the current results to a function (or datatype
constructor) as individual values.

```julia
julia> parse_one("abc", App(Star(p"."), tuple))
1-element Array{Any,1}:
 ("a","b","c")

julia> parse_one("abc", Star(p".") > string)
1-element Array{Any,1}:
 "abc"
```

The action of `Appl()` and `|>` is similar, but everything is passed as a
single argument (a list).

```julia
julia> type Node children end

julia> parse_one("abc", Appl(Star(p"."), Node))
1-element Array{Any,1}:
 Node(Any["a","b","c"])

julia> parse_one("abc", Star(p".") |> x -> map(uppercase, x))
3-element Array{Any,1}:
 "A"
 "B"
 "C"
```

#### Lookahead And Negation

Sometimes you can't write a clean grammar that just consumes data: you need to
check ahead to avoid something.  Or you need to check ahead to make sure
something works a certain way.

```julia
julia> parse_one("12c", Lookahead(p"\d") + PInt() + Dot())
2-element Array{Any,1}:
 12   
   'c'

julia> parse_one("12c", Not(Lookahead(p"[a-z]")) + PInt() + Dot())
2-element Array{Any,1}:
 12   
   'c'
```

More generally, `Not()` replaces any match with failure, and failure with an
empty match (ie the empty list).


### Other

#### Backtracking

By default, matchers will backtrack as necessary.

In some (unusual) cases, it is useful to disable backtracking.  For
example, see PCRE's "possessive" matching.  This can be done here on a
case-by-case basis by adding `backtrack=false` to `Repeat()`,
`Alternatives()` and `Series()`, or by appending `!` to the matchers
that those functions generate: `Depth!`, `Breadth!`, `Alt!`, `Seq!`
and `And!`.

For example,

```julia
collect(parse_all("123abc", Seq!(p"\d"[0:end], p"[a-z]"[0:end])))
```

will give just a single match, because `Seq!` (with trailing `!`) does
not backtrack the `Repeat()` child matchers.

However, since regular expressions do not backtrack, it would have been
simpler, and faster, to write the above as

```julia
collect(parse_all("123abc", p"\d+[a-z]+"))
```

Using `backtrack=false` only disables backtracking of the direct
children of those matchers.  To disable *all* backtracking, then the
change must be made to *all* matchers in the grammar.  For example, in
theory, the following two grammars have different backtracking
behaviour:

```julia
Series(Repeat(s"a", 0, 3), s"b"; backtrack=false)
Series(Repeat(s"a", 0, 3; backtrack=false), s"b"; backtrack=false)
```

(although, in practice, they are identical, in this contrived example,
because `s"a"` doesn't backtrack anyway).

This makes a grammar more efficient, but also more specific.  It can
reduce the memory consumed by the parser, but does not guarantee that
resources will be released - see the next section for a better
approach to reducing memory use.

#### Controlling Memory Use

Haskell's Parsec, if I understand correctly, does not backtrack by
default.  More exactly, it does not allow input that has been consumed
(matched) to be read again.  This reduces memory consumption (at least
when parsing files, since read data can be discarded), but only
accepts LL(1) grammars.

To allow parsing of a wider range of grammars, Parsec then introduces
the `Try` combinator, which enables backtracking in some (generally
small) portion of the grammar.

The same approach can be used with this library, using `TryIter` as a
source with `parse_try`.

```
file1.txt:
abcdefghijklmnopqrstuvwxyz
0123456789
```

```julia
open("test1.txt", "r") do io
    # this throws an execption because it requires backtracking
    parse_try(TryIter(io), p"[a-z]"[0:end] + s"m" > string)
end

open("test1.txt", "r") do io
    # this (with Try(...)) works fine
    parse_try(TryIter(io), Try(p"[a-z]"[0:end] + s"m" > string))
end
```

Without backtracking, error messages using the `Error()` matcher are
much more useful (this is why Parsec can provide good error messages):

```julia
parse_try(TryIter("?"), Alt!(p"[a-z]", p"\d", Error("not letter or number")))
# ParserError("not letter or number",ParserCombinator.TryIterState(1,1))
```

where the `(1,1)` (the `iter` field of the error) is line number and
column - so this failed on the first character of the first line.

#### Spaces - Pre And Post-Fixes

The lack of a lexer can complicate the handling of whitespace when
using parser combinators.  This library includes the ability to add
arbitrary matchers before or after named matchers in the grammar -
something that can be useful for matching and discarding whitespace.

For example,

```julia
spc = Drop(Star(Space()))

@with_pre spc begin

    sum = Delayed()
    val = S"(" + spc + sum + spc + S")" | PFloat64()

    neg = Delayed()             # allow multiple negations (eg ---3)
    neg.matcher = Nullable{Matcher}(val | (S"-" + neg > Neg))

    mul = S"*" + neg
    div = S"/" + neg > Inv
    prd = neg + (mul | div)[0:end] |> Prd

    add = S"+" + prd
    sub = S"-" + prd > Neg
    sum.matcher = Nullable{Matcher}(prd + (add | sub)[0:end] |> Sum)

    all = sum + spc + Eos()

end
```

extends the parser given earlier to discard whitespace between numbers
and symbols.  The automatc addition of `spc` as a prefix to named
matchers (those assigned to a variable: `sum`, `val`, `neg`, etc)
means that it only needs to be added explicitly in a few places.

#### Locating Errors

Sometimes it is useful to report to the user where the input text is
"wrong".  For a recursive descent parser one useful indicator is the
maximum depth reached in the source.

This can be retrieved using the `Debug` config.  Here is a simple
example that delegates to `NoCache` (the default confg for
`parse_one()`):

```julia
grammar = p"\d+" + Eos()
source = "123abc"
             # make the parser task
debug, task = make(Debug, source, grammar; delegate=NoCache)
once(task)   # this does the parsing and throws an exception
             # the debug config now contains max_iter
println(source[debug.max_iter:end])   # show the error location "abc"
```

This is a little complex because I don't pre-define a function for
this case (cf `parse_one()`).  Please email me if you think I should
(currently it's unclear what features to support directly, and what to
leave for "advanced" users).

For more information see [parsers.jl](src/parsers.jl) and
[debug.jl](src/debug.jl).

An alternative approach to error messages is to use `parse_try()` with
the `Error()` matcher - see [here](#controlling-memory-use).

#### Coding Style

Don't go reinventing regexps.  The built-in regexp engine is way, way more
efficient than this library could ever be.  So call out to regexps liberally.
The `p"..."` syntax makes it easy.

But don't use regular expressions if you need to backtrack what is
being matched.

Drop stuff you don't need.

Transform things into containers so that your result has nice types.  Look at
how the [example](#example) works.

#### Adding Matchers

First, are you sure you need to add a matcher?  You can do a *lot* with
[transforms](#transforms).

If you do, here are some places to get started:

* `Equal()` in [matchers.jl](src/matchers.jl) is a great example for
  something that does a simple, single thing, and returns success or failure.

* Most matchers that call to a sub-matcher can be implemented as transforms.
  But if you insist, there's an example in [case.jl](test/case.jl).

* If you want to write complex, stateful matchers then I'm afraid you're going
  to have to learn from the code for `Repeat()` and `Series()`.  Enjoy!

#### Debugging

Debugging a grammar can be a frustrating experience - there are times when it
really helps to have a simple view "inside" what is happening.  This is
supported by `parse_dbg` which will print a record of all messages (execute
and response - see [design](#design)) for matchers inside a `Trace()` matcher.

In addition, if the grammar is defined inside a `@with_names` macro, the
symbols used to identify various parts of the grammar (the variable names)
are displayed when appropriate.

Here's a full example (you can view less by applying `Trace()` to only the
matchers you care about):

```julia
@with_names begin

    sum = Delayed()
    val = S"(" + sum + S")" | PFloat64()

    neg = Delayed()             # allow multiple negations (eg ---3)
    neg.matcher = val | (S"-" + neg > Neg)
    
    mul = S"*" + neg
    div = S"/" + neg > Inv
    prd = neg + (mul | div)[0:end] |> Prd
    
    add = S"+" + prd
    sub = S"-" + prd > Neg
    sum.matcher = prd + (add | sub)[0:end] |> Sum
    
    all = sum + Eos()
end

parse_dbg("1+2*3/4", Trace(all))
```

which gives:

```
  1:1+2*3/4    00 Trace->all
  1:1+2*3/4    01  all->sum
  1:1+2*3/4    02   Transform->Seq
  1:1+2*3/4    03    Seq->prd
  1:1+2*3/4    04     prd->Seq
  1:1+2*3/4    05      Seq->neg
  1:1+2*3/4    06       Alt->Seq
  1:1+2*3/4    07        Seq->Drop
  1:1+2*3/4    08         Drop->Equal
   :           08         Drop<-!!!
   :           07        Seq<-!!!
   :           06       Alt<-!!!
  1:1+2*3/4    06       Alt->Transform
  1:1+2*3/4    07        Transform->Pattern
  2:+2*3/4     07        Transform<-{"1"}
  2:+2*3/4     06       Alt<-{1.0}
  2:+2*3/4     05      Seq<-{1.0}
  2:+2*3/4     05      Seq->Depth
  2:+2*3/4     06       Depth->Alt
  2:+2*3/4     07        Alt->mul
  2:+2*3/4     08         mul->Drop
  2:+2*3/4     09          Drop->Equal
   :           09          Drop<-!!!
   :           08         mul<-!!!
   :           07        Alt<-!!!
  2:+2*3/4     07        Alt->div
  2:+2*3/4     08         div->Seq
  2:+2*3/4     09          Seq->Drop
  2:+2*3/4     10 Drop->Equal
   :           10 Drop<-!!!
   :           09          Seq<-!!!
   :           08         div<-!!!
   :           07        Alt<-!!!
   :           06       Depth<-!!!
  2:+2*3/4     05      Seq<-{}
  2:+2*3/4     04     prd<-{1.0}
  2:+2*3/4     03    Seq<-{Prd({1.0})}
  2:+2*3/4     03    Seq->Depth
  2:+2*3/4     04     Depth->Alt
  2:+2*3/4     05      Alt->add
  2:+2*3/4     06       add->Drop
  2:+2*3/4     07        Drop->Equal
  3:2*3/4      07        Drop<-{"+"}
  3:2*3/4      06       add<-{}
  3:2*3/4      06       add->prd
  3:2*3/4      07        prd->Seq
  3:2*3/4      08         Seq->neg
  3:2*3/4      09          Alt->Seq
  3:2*3/4      10 Seq->Drop
  3:2*3/4      11  Drop->Equal
   :           11  Drop<-!!!
   :           10 Seq<-!!!
   :           09          Alt<-!!!
  3:2*3/4      09          Alt->Transform
  3:2*3/4      10 Transform->Pattern
  4:*3/4       10 Transform<-{"2"}
  4:*3/4       09          Alt<-{2.0}
  4:*3/4       08         Seq<-{2.0}
  4:*3/4       08         Seq->Depth
  4:*3/4       09          Depth->Alt
  4:*3/4       10 Alt->mul
  4:*3/4       11  mul->Drop
  4:*3/4       12   Drop->Equal
  5:3/4        12   Drop<-{"*"}
  5:3/4        11  mul<-{}
  5:3/4        11  mul->neg
  5:3/4        12   Alt->Seq
  5:3/4        13    Seq->Drop
  5:3/4        14     Drop->Equal
   :           14     Drop<-!!!
   :           13    Seq<-!!!
   :           12   Alt<-!!!
  5:3/4        12   Alt->Transform
  5:3/4        13    Transform->Pattern
  6:/4         13    Transform<-{"3"}
  6:/4         12   Alt<-{3.0}
  6:/4         11  mul<-{3.0}
  6:/4         10 Alt<-{3.0}
  6:/4         09          Depth<-{3.0}
  6:/4         09          Depth->Alt
  6:/4         10 Alt->mul
  6:/4         11  mul->Drop
  6:/4         12   Drop->Equal
   :           12   Drop<-!!!
   :           11  mul<-!!!
   :           10 Alt<-!!!
  6:/4         10 Alt->div
  6:/4         11  div->Seq
  6:/4         12   Seq->Drop
  6:/4         13    Drop->Equal
  7:4          13    Drop<-{"/"}
  7:4          12   Seq<-{}
  7:4          12   Seq->neg
  7:4          13    Alt->Seq
  7:4          14     Seq->Drop
  7:4          15      Drop->Equal
   :           15      Drop<-!!!
   :           14     Seq<-!!!
   :           13    Alt<-!!!
  7:4          13    Alt->Transform
  7:4          14     Transform->Pattern
  8:           14     Transform<-{"4"}
  8:           13    Alt<-{4.0}
  8:           12   Seq<-{4.0}
  8:           11  div<-{4.0}
  8:           10 Alt<-{Inv(4.0)}
  8:           09          Depth<-{Inv(4.0)}
  8:           09          Depth->Alt
  8:           10 Alt->mul
  8:           11  mul->Drop
  8:           12   Drop->Equal
   :           12   Drop<-!!!
   :           11  mul<-!!!
   :           10 Alt<-!!!
  8:           10 Alt->div
  8:           11  div->Seq
  8:           12   Seq->Drop
  8:           13    Drop->Equal
   :           13    Drop<-!!!
   :           12   Seq<-!!!
   :           11  div<-!!!
   :           10 Alt<-!!!
   :           09          Depth<-!!!
  8:           08         Seq<-{3.0,Inv(4.0)}
  8:           07        prd<-{2.0,3.0,Inv(4.0)}
  8:           06       add<-{Prd({2.0,3.0,Inv(4.0)})}
  8:           05      Alt<-{Prd({2.0,3.0,Inv(4.0)})}
  8:           04     Depth<-{Prd({2.0,3.0,Inv(4.0)})}
  8:           04     Depth->Alt
  8:           05      Alt->add
  8:           06       add->Drop
  8:           07        Drop->Equal
   :           07        Drop<-!!!
   :           06       add<-!!!
   :           05      Alt<-!!!
  8:           05      Alt->sub
  8:           06       sub->Seq
  8:           07        Seq->Drop
  8:           08         Drop->Equal
   :           08         Drop<-!!!
   :           07        Seq<-!!!
   :           06       sub<-!!!
   :           05      Alt<-!!!
   :           04     Depth<-!!!
  8:           03    Seq<-{Prd({2.0,3.0,Inv(4.0)})}
  8:           02   Transform<-{Prd({1.0}),Prd({2.0,3.0,Inv(4.0)})}
  8:           01  all<-{Sum({Prd({1.0}),Prd({2.0,3.0,Inv(4.0)})})}
  8:           01  all->Eos
  8:           01  all<-{}
  8:           00 Trace<-{Sum({Prd({1.0}),Prd({2.0,3.0,Inv(4.0)})})}
```

Some things to note here:

* The number on the left is the current iterator, followed by the source
  at the current offset.

* The second column of numbers is the depth (relative to `Trace()`).  The
  indentation of the messages to the right reflects this, but "wraps" every
  10 levels.

* The message flow shows execute as `->` and response as `<-`.  Matcher names
  are replaced by variable names (eg `sum`) where appropriate.

* This functionality is implemented as a separate parser `Config` instance, so
  has no performance penalty when not used.  See [debug.jl](src/debug.jl) for
  more details.

Finally, printing a matcher gives a useful tree view of the grammar.
Loops are elided with `...`:

```julia
println(all)
```

gives

```
all
+-[1]:sum
| `-TransSuccess
|   +-Seq
|   | +-[1]:prd
|   | | +-Seq
|   | | | +-[1]:neg
|   | | | | `-Alt
|   | | | |   +-[1]:Seq
|   | | | |   | +-[1]:Drop
|   | | | |   | | `-Equal
|   | | | |   | |   `-"("
|   | | | |   | +-[2]:sum...
|   | | | |   | `-[3]:Drop
|   | | | |   |   `-Equal
|   | | | |   |     `-")"
|   | | | |   +-[2]:TransSuccess
|   | | | |   | +-Pattern
|   | | | |   | | `-r"-?(\d*\.?\d+|\d+\.\d*)([eE]\d+)?"
|   | | | |   | `-f
|   | | | |   `-[3]:TransSuccess
|   | | | |     +-Seq
|   | | | |     | +-[1]:Drop
|   | | | |     | | `-Equal
|   | | | |     | |   `-"-"
|   | | | |     | `-[2]:neg...
|   | | | |     `-f
|   | | | `-[2]:Depth
|   | | |   +-Alt
|   | | |   | +-[1]:mul
|   | | |   | | +-[1]:Drop
|   | | |   | | | `-Equal
|   | | |   | | |   `-"*"
|   | | |   | | `-[2]:neg...
|   | | |   | `-[2]:div
|   | | |   |   +-Seq
|   | | |   |   | +-[1]:Drop
|   | | |   |   | | `-Equal
|   | | |   |   | |   `-"/"
|   | | |   |   | `-[2]:neg...
|   | | |   |   `-f
|   | | |   +-lo=0
|   | | |   +-hi=9223372036854775807
|   | | |   `-flatten=true
|   | | `-f
|   | `-[2]:Depth
|   |   +-Alt
|   |   | +-[1]:add
|   |   | | +-[1]:Drop
|   |   | | | `-Equal
|   |   | | |   `-"+"
|   |   | | `-[2]:prd...
|   |   | `-[2]:sub
|   |   |   +-Seq
|   |   |   | +-[1]:Drop
|   |   |   | | `-Equal
|   |   |   | |   `-"-"
|   |   |   | `-[2]:prd...
|   |   |   `-f
|   |   +-lo=0
|   |   +-hi=9223372036854775807
|   |   `-flatten=true
|   `-f
`-[2]:Eos
```

#### More Information

For more details, I'm afraid your best bet is the source code:

* [types.jl](src/types/jl) introduces the types use throughout the code

* [matchers.jl](src/matchers.jl) defines things like `Seq` and `Repeat`

* [sugar.jl](src/sugar.jl) adds `+`, `[...]` etc

* [extras.jl](src/extras.jl) has parsers for Int, Float, etc

* [parsers.jl](src/parsers.jl) has more info on creating the `parse_one` and
  `parse_all` functions

* [transforms.jl](src/trasnforms.jl) defines how results can be manipulated

* [tests.jl](test/tests.jl) has a pile of one-liner tests that might be useful

* [debug.jl](test/debug.jl) shows how to enable debug mode

* [case.jl](test/case.jl) has an example of a user-defined combinator

## Design

### Overview

Parser combinators were first written (afaik) in functional languages
where tail calls do not consume stack.  Also, packrat parsers are
easiest to implement in lazy languages, since shared, cached results
are "free".

Julia has neither tail recursion optimisation nor lazy evaluation.

On the other hand, tail call optimisation is not much use when you
want to support backtracking or combine results from child parsers.
And it is possible to implement combinators for repeated matches using
iteration rather than recursion.

In short, life is complicated.  Different parser features have
different costs and any particular implementation choice needs to be
defended with detailed analysis.  Ideally we want an approach that
supports features with low overhead by default, but which can be
extended to accomodate more expensive features when necessary.

This library defines the grammar in a static graph, which is then
"interpreted" using an explicit trampoline (described in more detail
below).  The main advantages are:

* Describing the grammar in a static graph of types, rather than
  mutually recursive functions, gives better integration with Julia's
  method dispatch.  So, for example, we can overload operators like
  `+` to sequence matchers, or use macros to modify the grammar at
  compile time.  And the "execution" of the grammar is simple, using
  dispatch on the graph nodes.

* The semantics of the parser can be modified by changing the
  trampoline implementation (which can also be done by method dispatch
  on a "configuration" type).  This allows, for example, the choice of
  whether to use memoization to be separated from the grammar itself.

* State is explicitly identified and encapsulated, simplifying both
  backtracking (resumption from the current state) and memoization.

The main disadvantages are:

* Defining new combinators is more complex.  The behaviour of a
  matcher is defined as a group of methods that correspond to
  transitions in a state machine.  On the other hand, with dispatch on
  the grammar and state nodes, the implementation remains idiomatic
  and compact.

* Although the "feel" and "end result" of the library are similar to
  other parser combinator libraries (the grammar types handled are as
  expected, for example), one could argue that the matchers are not
  "real" combinators (what is written be the user is a graph of types,
  not a set of recursive functions, even if the final execution logic
  is equivalent).

### Trampoline Protocol

A matcher is invoked by a call to

```julia
execute(k::Config, m::Matcher, s::State, i) :: Message
```

where `k` must include, at a minimum, the field `k.source` that
follows the [iterator
protocol](http://julia.readthedocs.org/en/latest/stdlib/collections/?highlight=iterator)
when used with `i`.  So, for example, `next(k.source, i)` returns the
next value from the source, plus a new iter.

The initial call (ie the first time a given value of `i` is used,
before any backtracking) will have `s` equal to `CLEAN`.

A matcher returns a `Message` which indicates to the trampine how
processing should continue:

* `Failure` indicates that the match has failed and probably (depending
  on parent matcher and configuration triggers backtracking).  There
  is a single instance of the type, `FAILURE`.

* `Success` indicates that the match succeeded, and so contains a
  result (of type `Value`, which is a type alias for `Any[]`) together
  with the updated iter `i` and any state that the matcher will need
  to look for further matchers (this can be be `DIRTY` which is
  globally used to indicate that all further matches will fail).

* `Execute` which results in a "nested" call to a child matcher's
  `execute` method (as above).

The `FAILURE` and `Success` messages are processed by the trampoline
and (typically, although a trampoline implementation may also use to
cached values) result in calls to

```julia
failure(k::Config, m::Matcher, s::State) :: Message

success(k::Config, m::Matcher, s::State, t::State, i, r::Value) :: Message
```

where the parent matcher can do any clean-up work, resulting in a new
`Message`.

Note that the child's state, `t`, is returned to the parent.  It is
the responsibility of the parent to save this (in its own state) if it
wants to re-call the child.

### Source (Input Text) Protocol

The source text is read using the [standard Julia iterator
protocol](http://julia.readthedocs.org/en/latest/stdlib/collections/?highlight=iterator).

This has the unfortunate result that `Dot()` returns characters, not
strings.  But in practice that matcher is rarely used (particularly
since, with strings, you can use regular expressions - `p"pattern"`
for example), and you can construct a string from multiple characters
using `> string` (similarly `> vcat` can be used to flatten an
additional layer of lists).

## Releases

1.1.0 - 2015-06-07 - Fixed calc example; debug mode; much rewriting.

1.0.0 - ~2015-06-03 - More or less feature complete.

