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

It would also have been possible to use Julia tasks (coroutines).  I avoided
this approach because my understanding is (although I have no proof) that
tasks are significantly "heavier".

### Matcher Protocol

Consider the matchers `Parent` and `Child`:

```
immutable Example<:Matcher
  ...
end

immutable Child<:Matcher
  ...
end
```

These communicate via "messages".  Fields marked as `from trampoline` are set
automatically; the child sending the message doe snit provide them.

```
type Error<:Message
  # causes parser to fail immediately (no backtracking)
  msg
  iter
end

type Call{M::Matcher}<:Message
  # sent from parent to child
  child::M

type Fail{M::Matcher}<:Message
  # sent from child to parent, when fails to match
  parent::M  # from trampoline
  state      # from trampoline
  iter       # from trampoline
end


 



# all of the functions below return a subtype of Message.  iter is the
# iterator for source.
#   Fail() on failure
#   Error(msg, iter) on error (ie no backtracking)
#   Match(iter, result, my_state) on success
#   Call{M}(child::M, iter) to evaluate a child matcher for the first time
#   Resume{M}(child::M, iter, child_state) to resume a child matcher

function match(call, source)
  # called on initial match.
end

function match(m::Example, source, iter, my_state)
  # called when the child match has failed.
end

function yield(m::Example, source, isource, state, result)
  # called when a child match has succeeded
end
```

### Source Protocol

The source is read using the [standard Julia iterator
protocol](http://julia.readthedocs.org/en/latest/stdlib/collections/?highlight=iterator).

[![Build
Status](https://travis-ci.org/andrewcooke/SimpleParser.jl.png)](https://travis-ci.org/andrewcooke/SimpleParser.jl)
Julia 0.3 and 0.4 (trunk).
