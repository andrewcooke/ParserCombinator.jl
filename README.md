# SimpleParser

This is a simple-to-use parser for Julia that tries to be reasonably
efficient, without burdening the end-user with too many type annotations.  It
is similar to parser combinator libraries in other languages (eg Haskell's
Parsec).

**EXAMPLE HERE**

For large parsing tasks (eg parsing source code for a compiler) it would
probably be better to use a wrapper around an external parser generator, like
Anltr.

## Design

### Overview

Julia does not support tail call recursion, and is not lazy, so a naive
combinator library would be limited by recursion depth and poor efficiency.
Instead, the "combinators" in SimpleParser construct a tree that describes the
grammar, and which is "interpreted" during parsing, by dispatching functions
on the tree nodes.  The traversal over the tree (effectvely a depth first
search) is implemented via trampolining, with an optional (adjustable) cache
to avoid repeated evaluation and detect left-recursive grammars.

The advantages of this approch are:

  * Recursion is avoided

  * Caching can be isolated to within the trampoline

  * Method dispatch on node types leads to idiomatic Julia code

### Matcher Protocol

Consider the matcher `Example`:

```
immutable Example<:Matcher
  # values needed for evaluation (child matchers, repeat counts, etc)
end

function match(m::Example, source, isource)
  # called on initial match.  isource is the iterator for source.
  # evaluate the match and return a subtype of Return:
  #   Failure() on failure
  #   Success(isource, result) on success
  #   Bounce(isource, child, state) to trampoline down to a child matcher
end

# resume() methods are called only if match() returns Bounce

function resume(m::Example, source, isource, state)
  # called when the child match has failed
  # return Success (unlikely here), Failure or a new Bounce
end

function resume(m::Example, source, isource, state, result)
  # called when a child match has succeeded
  # return Success, Failure (unlikely here) or a new Bounce
end
```

### Source Protocol

The source is read using the [standard Julia iterator
protocol](http://julia.readthedocs.org/en/latest/stdlib/collections/?highlight=iterator).

[![Build
Status](https://travis-ci.org/andrewcooke/SimpleParser.jl.png)](https://travis-ci.org/andrewcooke/SimpleParser.jl)
Julia 0.3 and 0.4 (trunk).
