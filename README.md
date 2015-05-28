# SimpleParser

This is a simple-to-use parser for Julia that tries to be reasonably
efficient, while remaining fairly simple (both for the end-user and the
maintainer).  It is similar to parser combinator libraries in other languages
(eg Haskell's Parsec).

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
to avoid repeated evaluation (and, possibly, in the future) detect
left-recursive grammars).

The advantages of this approch are:

  * Recursion is avoided

  * Caching can be isolated to within the trampoline

  * Method dispatch on node types leads to idiomatic Julia code (well,
    as idiomatic as possble, for what is a glorified state machine).

It would also have been possible to use Julia tasks (coroutines).  I avoided
this approach because my understanding is (although I have no proof) that
tasks are significantly "heavier".

### Matcher Protocol

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

In addition, typically, each matcher has some associated types that store
state (the matchers themselves describe only the *static* grammar; the state
describes the associated state during matching and backtracking).

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
  # the above will call here
  if compare(c.text, source[iter:])
    Success(c, ChildStateSucceeded(), iter, c.text)
  else
    Failure(c, ChildStateFailed(), iter)
  end
end

function success(p::Parent, s::ParentState, c::Child, cs::ChildState, iter,
source, result)
  # the Successs() message above results in a call here, where we do something
  # with the result
  ...
  # and then perhaps evaluate child2...
  Execute(p, s, p.child2, ChildStateStart(), iter)
end
```

### Source (Input Text) Protocol

The source text is read using the [standard Julia iterator
protocol](http://julia.readthedocs.org/en/latest/stdlib/collections/?highlight=iterator).

[![Build
Status](https://travis-ci.org/andrewcooke/SimpleParser.jl.png)](https://travis-ci.org/andrewcooke/SimpleParser.jl)
Julia 0.3 and 0.4 (trunk).
