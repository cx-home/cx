# Reference: the CX code language — v0.16.0

> **GENERATED.** Source: `docs-src/llm/reference-code-language.md.tmpl` + the
> conformance corpus. Every output was re-recorded from the `cx` v0.16.0
> binary. Read `primer.md` first.

Ring 1. A program is a document whose elements include directives. Directives
are spelled `[?name …]`; the normative registry is
`spec/03-approved/core/code.md` §4.1, and every directive in it is exercised
by `conformance/code.cxd`.

## Binding

`[?let]` takes any number of `[= $name value]` bindings and one body. The
bindings are sequential: each sees the ones before it. There is no
`let*`, because there is nothing for it to do.

`prog.cx`
```cx
[?let [= $x 9]
  [?let [= $x 1] [= $y $x]
    [pair x=$x y=$y]]]
```

```console
$ cx prog.cx
[pair x=1 y=1]
```

`[?with-scope]` merges a map into scope for a body — the form to reach for
when the names come from data rather than from source.

`prog.cx`
```cx
[?with-scope {a: 1, b: 2} [?test-current-scope]]
```

```console
$ cx prog.cx
'a=1,b=2'
```

## Control flow

`[?if COND [then …] [else …]]`. The clause names are mandatory: `[?if c a b]`
is a syntax error (`cx-err:CXER0001`), not a positional shorthand.

`prog.cx`
```cx
[?if true 'a' 'b']
```

```console
$ cx prog.cx
error: cx-err:CXER0001: [?if] expects [then …] / [else …] clause children after the condition — got a bare positional branch expression; write [?if cond [then thenExpr] [else elseExpr]?]
```

`[else]` may be omitted, and a false condition then yields empty:

`prog.cx`
```cx
[out [ok [?if false [then 'a']]]]
```

```console
$ cx prog.cx
[out [ok ()]]
```

Truthiness is defined per type, not by coercion to boolean: zero and empty
string are falsy, an empty *element* is truthy (it exists), and an empty
match set is falsy — which is what makes the existence idiom work:

`input.cx`
```cx
[app [flag]]
```

`prog.cx`
```cx
[?if //flag [then "on"] [else "off"]]
```

```console
$ cx --data=input.cx prog.cx
'on'
```

## Pattern matching

`[?match VALUE [case PATTERN result] … [else result]]`. Arms are tried in
order. `[when …]` adds a predicate arm, `[where …]` guards a case.

`input.cx`
```cx
[doc]
```

`prog.cx`
```cx
[?let [= $u [user age=20 [name Alice]]] [?match $u
    [case [user $u] [where [>= $u@age 18]] :adult]
    [case [user $u] :minor]]]
```

```console
$ cx --data=input.cx prog.cx
:adult
```

A single-arm match with no `[else]` that does not match RAISES rather than
returning empty — matching is a claim, and a failed claim is an error:

`input.cx`
```cx
[doc]
```

`prog.cx`
```cx
[?match [foo "x"] [bar $b] [yield $b]]
```

```console
$ cx --data=input.cx prog.cx
error: cx-err:CXER0100: [?match] no match for value (single-arm form)
```

## Comprehensions

`[?for]` is the one iteration directive: `[in $x SOURCE]` clauses (more than
one nests), `[where]` filters, `[group-by]` partitions and binds `$count` and
`$group`, `[order-by]` sorts, `[yield]` emits. Patterns in the source
position bind by shape.

`input.cx`
```cx
[users
  [user active=true [name Alice] [email a@x.com]]
  [user active=false [name Bob] [email b@x.com]]
  [user active=true [name Carol] [email c@x.com]]]
```

`prog.cx`
```cx
[?for [user @active=true [email $e]] [yield $e]]
```

```console
$ cx --data=input.cx prog.cx
'a@x.com'
'c@x.com'
```

`input.cx`
```cx
[ignored]
```

`prog.cx`
```cx
[?let [= $orders [orders
  [order region=east [line qty=2 price=10] [line qty=1 price=5]]
  [order region=west [line qty=3 price=4]]
  [order region=east [line qty=1 price=100]]]]
  [?for [in $o $orders/order] [in $l $o/line]
    [= $r [* $l@qty $l@price]]
    [group-by $o@region]
    [yield [row region=$key revenue=[$sum $group/r] n=$count]]]]
```

```console
$ cx --data=input.cx prog.cx
[row region=east revenue=125 n=3]
[row region=west revenue=12 n=1]
```

## CXPath

Paths are values: `$doc/child`, `/rooted`, `//descendant`, with predicates.
They work as a `[?for]` source, as an `[?if]` condition (truthy iff the match
set is non-empty), and anywhere a value is expected.

`input.cx`
```cx
[users
  [user [name Alice] [email a@x.com]]
  [user [name Bob]   [email b@x.com]]]
```

`prog.cx`
```cx
//user
```

```console
$ cx --data=input.cx prog.cx
[user [name 'Alice'] [email 'a@x.com']]
[user [name 'Bob'] [email 'b@x.com']]
```

`input.cx`
```cx
[users
  [user active=true  [name Alice]]
  [user active=false [name Bob]]
  [user active=true  [name Carol]]]
```

`prog.cx`
```cx
//user[= $_@active true]
```

```console
$ cx --data=input.cx prog.cx
[user active=true [name 'Alice']]
[user active=true [name 'Carol']]
```

`input.cx`
```cx
[users
  [user active=true  [name Alice]]
  [user active=false [name Bob]]
  [user active=true  [name Carol]]]
```

`prog.cx`
```cx
[$count //user[= $_@active true]]
```

```console
$ cx --data=input.cx prog.cx
2
```

## Functions

`[?def name [attrs] (params) body]` defines; `[?fn (params) body]` is the
anonymous form. Definitions are order-independent and mutually recursive.
`scope=public` exports. `pure`/`impure` is checked. `[returns T]` and `::T`
annotations document by default and are enforced under `--strict`.

`input.cx`
```cx
[doc]
```

`prog.cx`
```cx
[?def greet
  scope=public
  [returns string]
  ($name::string)
  [$concat "hello, " $name]]
[$greet "world"]
```

```console
$ cx --data=input.cx prog.cx
'hello, world'
```

`input.cx`
```cx
[doc]
```

`prog.cx`
```cx
[?def even-p ($n)
  [?if [= $n 0] [then true]
                [else [$odd-p [- $n 1]]]]]
[?def odd-p ($n)
  [?if [= $n 0] [then false]
                [else [$even-p [- $n 1]]]]]
[$even-p 10]
```

```console
$ cx --data=input.cx prog.cx
true
```

Defs are first-class values, so a def name is usable wherever a function is:

`prog.cx`
```cx
[?def dbl ($x) [* $x 2]]
[?map (1, 2, 3) [using $dbl]]
```

```console
$ cx prog.cx
(2, 4, 6)
```

Nesting a `[?def]` inside another is refused (`cx-err:CXER0204`) — definitions
are module-level:

`input.cx`
```cx
[doc]
```

`prog.cx`
```cx
[?let [= $f [?fn () [?def inner ($x) [* $x 2]]]] [$f]]
```

```console
$ cx --data=input.cx prog.cx
error: cx-err:CXER0204: cx-err:CXER0204 E_NESTED_DEF: `[?def inner]` is not permitted inside a function body (definitions are top/module-level only)
```

## Pipes

`[?pipe]` threads a value through stages. There is a canonical form and infix
sugar; both parse to the same thing.

`input.cx`
```cx
[ignored]
```

`prog.cx`
```cx
[?pipe (1, 2, 3, 4) [?fn $xs [?for [in $x $xs] [where [> $x 2]] [yield $x]]]
                    $count]
```

```console
$ cx --data=input.cx prog.cx
2
```

`input.cx`
```cx
[ignored]
```

`prog.cx`
```cx
[?pipe (1, 2, 3, 4) [?fn $xs [?for [in $x $xs] [where [> $x 2]] [yield $x]]] $count]
```

```console
$ cx --data=input.cx prog.cx
2
```

## Iterators and reduction

The iterator family is lazy: `[?map]`, `[?filter]`, `[?take]`, `[?drop]`,
`[?zip]`, `[?enumerate]`, `[?chunks]` build a pipeline, and a consumer forces
it. `[?reduce]` folds; `[par]` marks an associative fold as parallelisable.

`input.cx`
```cx
[ignored]
```

`prog.cx`
```cx
[?to-sequence [?take 3 [?map (10, 20, 30, 40, 50) [using [?fn $i [+ $i 1]]]]]]
```

```console
$ cx --data=input.cx prog.cx
(11, 21, 31)
```

`input.cx`
```cx
[ignored]
```

`prog.cx`
```cx
[?reduce (1, 2, 3, 4) [using [?fn ($a $b) [- $a $b]]] [init 10]]
```

```console
$ cx --data=input.cx prog.cx
0
```

An `[?reduce]` declared `ordered` where the operation is not is refused
rather than silently reordered:

`input.cx`
```cx
[ignored]
```

`prog.cx`
```cx
[?reduce (1, 2, 3) [using [?fn ($a $b) [+ $a $b]]] [init 0] [ordered]]
```

```console
$ cx --data=input.cx prog.cx
error: cx-err:CXER0100: [?reduce] takes a single positional source slot
```

## Transformation

`[?modify]` rewrites a document by matching positions and replacing them. It
is the transform half of the language, and the reason CX does not need a
separate template dialect.

`prog.cx`
```cx
[?let [= $d [teams
              [team name="alpha" [member id=1]]
              [team name="beta" [member id=2]]]]
 [?let [= $flag "alpha"]
  [?modify $d //team[= $_@name $flag]/member [set-attr flagged true]]]]
```

```console
$ cx prog.cx
[teams [team name=alpha [member id=1 flagged=true]] [team name=beta [member id=2]]]
```

## Errors

An error is the value `[err code=… message=… …]`. It is produced, returned,
bound, and inspected like any other value; it propagates out of the call that
made it and through anything constructed from it.

`prog.cx`
```cx
[?let [= $seq [?for [in $x ("a")] [yield $x]]]
  [section [div [$concat $seq "-x"]]]]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0100 message='concat: an argument does not satisfy the builtin signature (scalar kind/type — code.md §6.5)']
```

A literal `[err …]` written in *data* stays data — the propagation rule is
about computed positions, not about the head name:

`prog.cx`
```cx
[foo [err code='x' message='y']]
```

```console
$ cx prog.cx
[foo [err code=x message=y]]
```

`[?else VALUE FALLBACK]` is the recovery idiom. There is no `try`/`catch`
directive; `[?try]` and `[?chain]` were retired from the surface and now
appear only in negative fixtures.

## Capabilities

Every effect names the capability it needs, and a denial is an ordinary error
value carrying the flag that would have granted it:

`prog.cx`
```cx
[?lib 'cx-stdlib/io']
[$io:read-file "/var/log/app.log"]
```

```console
$ cx prog.cx
[err code=cx-err:CXER0271 message='E_CAP_DENIED: read capability required for io-read-file; none granted (grant via --allow-read)']
```

The nine capabilities are `read write net env clock random subprocess eval
secret-reveal`. `--allow-common` is all but `secret-reveal`; `--allow-all`
includes it.
