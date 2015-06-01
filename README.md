# ParserCombinator

This is a parser for Julia that tries to strike a balance between being both
(moderately) efficient and simple (for the end-user and the maintainer).  It
is similar to parser combinator libraries in other languages (eg Haskell's
Parsec) - it can include caching (memoization) but does not handle
left-recursive grammars.

ParserCombinator can parse any iterable type (not just strings).

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


# the grammar

num = PFloat64()
sum = Delayed()

par = S"(" + sum + S")"
val = par | num

inv = (S"/" + val) > Inv
dir = (S"*" + val)
prd = val + (inv | dir)[0:end] |> Prd

neg = (S"-" + prd) > Neg
pos = (S"+" + prd)
sum.matcher = (prd | neg | pos) + (neg | pos)[0:end] |> Sum

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
  `+`, or `TransformValue(...)` instead of `>`.

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

## Manual

### Basic Concepts



## Design

### Overview

Julia does not support tail call recursion, and is not lazy, so a naive
combinator library would be limited by recursion depth and strict evaluation
(no caching).  Instead, the "combinators" in ParserCombinator construct a tree
that describes the grammar, and which is "interpreted" during parsing, by
dispatching functions on the tree nodes.  The traversal over the tree is
implemented via trampolining, with an optional cache to avoid repeated
evaluation (and, possibly, in the future, detect left-recursive grammars).

The advantages of this approach are:

  * Recursion is reduced (repetition and sequential matching are iterative,
    but the grammar itself can still contain loops).

  * Caching can be isolated to within the trampoline (and has access to exact,
    explicit state for the matcher, which makes keying the lookup trivial).

  * Method dispatch on node types leads to idiomatic Julia code (well,
    as idiomatic as possble, for what is a glorified state machine).

It would also have been possible to use Julia tasks (coroutines).  I avoided
this approach because my understanding is (although I have no proof) that
tasks are significantly "heavier".

Note - this is not a magic bullet.  There is still a "stack" in the
trampoline, although in user-space and significantly more compact.

### Matcher Protocol

Below I try to give a "high level picture" of how evaluation proceeds.  For
the full details, please see the source.

Consider the matchers `Parent` and `Child` which might be used in some way to
parse "hello world":

```
immutable Child<:Matcher
  text
end

immutable Parent<:Matcher
  child1::Child
  child2::Child  
end

# this is a very vague example, don't think too hard about what it means
hello = Child("hello")
world = Child("world")
hello_world_grammar = Parent(hello, world)
```

Each matcher has some associated types that store state (the matchers
themselves describe only the *static* grammar; the state describes the
associated state during matching and backtracking).  Two states, `CLEAN` and
`DIRTY`, are used globally to indicate that a matcher is uncalled, or has
exhausted all matches, respectively.

Methods are then associated with combinations of matchers and state.
Transitions between these methods implement a state machine.

These transitions are triggered via `Message` types.  A method associated with
a matcher (and state) can return one of the messages and the trampoline will
call the corresponding code for the target.

So, for example:

```
function execute(p::Parent, s::ParentState, iter, source)
  # the parent wants to match the source text at offset iter against child1
  Execute(p, s, p.child1, ChildStateStart(), iter)
end

function execute(c::Child, s::ChildStateStart, iter, source)
  # the above returns an Execute instance, which tells the trampoline to
  # make a call here, where we check if the text matches
  if compare(c.text, source[iter:])
    Response(ChildStateSucceeded(), iter, Success(c.text))
  else
    Response(ChildStateFailed(), iter, FAILURE)
  end
end

function response(p::Parent, s::ParentState, t::ChildState, iter, source, result::Value)
  # the Response message containing Success above triggers a call here, where
  # we do something with the result (like save it in the ParentState)
  ...
  # and then perhaps evaluate child2...
  Execute(p, s, p.child2, ChildStateStart(), iter)
end
```

Hopefully you can see how each returned `Execute` and `Response` results in
the calling of an `execute()` or `response()` function.  In this way we can
write code that works as though it is recursive, without exhausting Julia's
stack.

Finally, to simplify caching in the trampoline, it is important that the
different matchers appear as simple calls and responses.  So internal
transitions between states in the same matcher are *not* made by messages, but
by direct calls.  This explains why, for example, you see both `Execute(...)`
and `execute(...)` in the source - the latter is an internal transition to the
given method.

### Source (Input Text) Protocol

The source text is read using the [standard Julia iterator
protocol](http://julia.readthedocs.org/en/latest/stdlib/collections/?highlight=iterator).

This has the unfortunate result that `Dot()` returns characters, not strings.
But in practice that matcher is rarely used (particularly since, with strings,
you can use regular expressions - `p"pattern"` for example).

[![Build
Status](https://travis-ci.org/andrewcooke/ParserCombinator.jl.png)](https://travis-ci.org/andrewcooke/ParserCombinator.jl)
Julia 0.3 and 0.4 (trunk).
