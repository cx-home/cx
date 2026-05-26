// CX Playground — example library (auto-generated).
// 51 data + 108 program entries — all CLI-verified.

(function () {
  'use strict';

  const data = {
    "atom-element": {
      label: "Element \u2014 single atom",
      input: "[pizza size=large]",
      note:  "The simplest CX shape: one element, one attribute. Switch the Output tab to JSON / XML to see the same value across projections.",
    },
    "scalar-string": {
      label: "Scalar \u2014 string",
      input: "\"hello, world\"",
      note:  "A bare string literal. CX scalars are first-class values; everything in CX is a value.",
    },
    "scalar-int": {
      label: "Scalar \u2014 integer",
      input: "42",
      note:  "Bare integer scalar. Type-inferred at parse time.",
    },
    "scalar-float": {
      label: "Scalar \u2014 float",
      input: "3.14159",
      note:  "Bare float scalar.",
    },
    "scalar-bool-true": {
      label: "Scalar \u2014 boolean true",
      input: "true",
      note:  "Bare boolean literal \u2014 `true` / `false` are reserved scalar names.",
    },
    "scalar-bool-false": {
      label: "Scalar \u2014 boolean false",
      input: "false",
      note:  "Bare boolean literal `false`.",
    },
    "scalar-atom": {
      label: "Scalar \u2014 atom",
      input: ":ok",
      note:  "An atom \u2014 a kebab-case identifier that evaluates to itself (ADR 0033). Use atoms for enum-like markers.",
    },
    "element-empty": {
      label: "Element \u2014 empty body",
      input: "[user]",
      note:  "Element with no attributes and no children. The minimal element shape.",
    },
    "element-attr": {
      label: "Element \u2014 one attribute",
      input: "[user id=42]",
      note:  "Attribute name=value pairs after the element name, before children.",
    },
    "element-multi-attr": {
      label: "Element \u2014 many attributes",
      input: "[user id=42 name=Alice active=true role=admin]",
      note:  "Multiple attributes on one tag; order preserved across projections.",
    },
    "element-quoted-attr": {
      label: "Element \u2014 quoted attribute value",
      input: "[user name=\"Alice O'Brien\" email=\"a@x.com\"]",
      note:  "Attribute values containing spaces or special characters must be quoted.",
    },
    "element-text-child": {
      label: "Element \u2014 text child",
      input: "[paragraph \"This is body text.\"]",
      note:  "An element whose body is a single string \u2014 common for prose / leaf nodes.",
    },
    "element-nested": {
      label: "Element \u2014 single nested child",
      input: "[outer\n  [inner value=42]]",
      note:  "One level of nesting. Indentation is conventional, not significant.",
    },
    "element-many-children": {
      label: "Element \u2014 many siblings",
      input: "[list\n  [item id=1]\n  [item id=2]\n  [item id=3]\n  [item id=4]\n  [item id=5]]",
      note:  "Multiple children of the same element. JSON projects this as an array under `list.item`.",
    },
    "element-mixed": {
      label: "Element \u2014 mixed content",
      input: "[doc\n  [heading \"Welcome\"]\n  [paragraph \"Body text.\"]\n  [footer \"Bye.\"]]",
      note:  "Heterogeneous children \u2014 different element names side by side. The containment tree preserves order.",
    },
    "order": {
      label: "Order \u2014 invoice shape",
      input: "[order id=ord-1001 status=paid\n  [customer name=Alice email=\"a@x.com\"]\n  [item sku=p-01 qty=2 price=12.00]\n  [item sku=p-02 qty=1 price=8.50]]",
      note:  "A realistic order document \u2014 top-level attributes plus structured children. Round-trips cleanly through CX/JSON/XML.",
    },
    "user-profile": {
      label: "User \u2014 profile with addresses",
      input: "[user id=42 name=Alice\n  [address kind=home city=Paris zip=75001]\n  [address kind=work city=London zip=\"WC1A 1AA\"]\n  [phone kind=mobile number=\"+33-1-23-45\"]]",
      note:  "User with multiple typed addresses + phones. The `kind` attribute discriminates child variants.",
    },
    "product-catalog": {
      label: "Catalog \u2014 small product list",
      input: "[catalog\n  [product sku=p-01 name=\"Pizza\" price=12 in-stock=true]\n  [product sku=p-02 name=\"Salad\" price=8.5 in-stock=true]\n  [product sku=p-03 name=\"Pasta\" price=10 in-stock=false]]",
      note:  "A small product catalog \u2014 repeated child element shape with attributes only (no nested bodies).",
    },
    "blog-post": {
      label: "Blog post \u2014 prose document",
      input: "[post\n  [title \"On homoiconicity\"]\n  [author name=Alice slug=alice]\n  [body\n    [paragraph \"CX shares its data and code surface.\"]\n    [paragraph \"That means programs are values.\"]]]",
      note:  "Prose-shaped document \u2014 title + author + body of paragraphs. The body uses nested elements rather than mixed text.",
    },
    "invoice": {
      label: "Invoice \u2014 totals + line items",
      input: "[invoice id=inv-2025-042 issued=2025-05-25\n  [bill-to name=\"Acme Corp\"]\n  [line description=\"Consulting\" hours=20 rate=150]\n  [line description=\"Travel\" amount=420]\n  [total amount=3420 currency=USD]]",
      note:  "Invoice with heterogeneous children \u2014 bill-to, multiple line items, total.",
    },
    "event-calendar": {
      label: "Calendar \u2014 event list",
      input: "[calendar year=2025\n  [event date=2025-05-25 title=\"CX launch\"]\n  [event date=2025-06-01 title=\"Workshop\"]\n  [event date=2025-07-04 title=\"Holiday\"]]",
      note:  "Event calendar \u2014 repeated event children with a date attribute. JSON renders the events as an array.",
    },
    "config": {
      label: "Config \u2014 settings tree",
      input: "[config app=cx env=production\n  [database host=\"db.local\" port=5432 ssl=true]\n  [cache provider=redis ttl=300]\n  [logging level=warn format=json]]",
      note:  "Configuration document \u2014 top-level app/env attributes, nested service blocks. Hostnames are quoted (the `.` is meaningful in attribute paths so bare hostnames need quotes).",
    },
    "svg-like": {
      label: "SVG-like \u2014 graphical primitives",
      input: "[svg width=200 height=100\n  [rect x=10 y=10 width=80 height=80 fill=blue]\n  [circle cx=140 cy=50 r=40 fill=red]\n  [text x=100 y=95 anchor=middle \"CX\"]]",
      note:  "SVG-shaped document \u2014 XML round-trip is exact (CX \u2192 XML produces an SVG you could paste into a browser).",
    },
    "html-fragment": {
      label: "HTML-like \u2014 semantic markup",
      input: "[article\n  [h1 \"Title\"]\n  [section class=intro\n    [p \"Lead paragraph.\"]]\n  [section class=body\n    [p \"Main content.\"]]]",
      note:  "HTML-shaped document. XML projection is valid HTML you could insert into a page.",
    },
    "settings-list": {
      label: "Settings \u2014 flat key-value pairs",
      input: "[settings\n  [pair key=theme value=dark]\n  [pair key=lang value=en]\n  [pair key=tz value=UTC]]",
      note:  "Key-value pairs as repeated `pair` elements. An alternative shape vs attribute-only or map-literal.",
    },
    "tree-with-depth": {
      label: "Tree \u2014 recursive structure",
      input: "[node label=root\n  [node label=a\n    [node label=a1]\n    [node label=a2]]\n  [node label=b\n    [node label=b1]]]",
      note:  "Recursive tree where each level uses the same element name. Common shape for filesystem / org-chart docs.",
    },
    "graph-adjacency": {
      label: "Graph \u2014 adjacency list",
      input: "[graph kind=directed\n  [node id=A]\n  [node id=B]\n  [node id=C]\n  [edge from=A to=B]\n  [edge from=B to=C]\n  [edge from=C to=A]]",
      note:  "Graph as a flat node + edge list. The :kind attribute discriminates directed / undirected.",
    },
    "table-rows": {
      label: "Table \u2014 header + rows",
      input: "[table\n  [columns id name role]\n  [row id=1 name=Alice role=admin]\n  [row id=2 name=Bob   role=editor]\n  [row id=3 name=Carol role=viewer]]",
      note:  "Tabular shape \u2014 column manifest + row records. Round-trips through CSV-style projections (via toJson \u2192 array of objects).",
    },
    "nested-comments": {
      label: "Nested comments \u2014 discussion thread",
      input: "[thread topic=\"Release plan\"\n  [post author=Alice \"Should we ship Friday?\"\n    [post author=Bob   \"Sounds risky.\"\n      [post author=Carol \"Let's do Monday.\"]]\n    [post author=Dave  \"Friday is fine.\"]]]",
      note:  "Discussion / comment thread modelled as nested posts. Containment hierarchy = reply relationship.",
    },
    "sequence-numbers": {
      label: "Sequence \u2014 integers",
      input: "(1, 2, 3, 4, 5)",
      note:  "Ordered sequence of integers. JSON renders as an array; CX preserves the literal form.",
    },
    "sequence-mixed": {
      label: "Sequence \u2014 mixed scalars",
      input: "(1, 2.5, \"three\", true, :four)",
      note:  "Heterogeneous sequence \u2014 CX holds any scalar mix in one container.",
    },
    "sequence-of-elements": {
      label: "Sequence \u2014 of elements",
      input: "([user id=1 name=A], [user id=2 name=B], [user id=3 name=C])",
      note:  "Sequence whose items are elements. The outer container is a flat sequence, not a wrapper element.",
    },
    "map-shop-hours": {
      label: "Map \u2014 shop hours by day",
      input: "{mon: \"09-17\", tue: \"09-17\", wed: \"09-17\", thu: \"09-17\", fri: \"09-21\", sat: \"10-21\", sun: \"closed\"}",
      note:  "Map literal with string keys + values. JSON renders as a flat object.",
    },
    "map-mixed-values": {
      label: "Map \u2014 mixed value types",
      input: "{name: \"Alice\", age: 30, active: true, tags: (:admin, :verified)}",
      note:  "Map with values of mixed types \u2014 string, int, bool, sequence.",
    },
    "map-of-elements": {
      label: "Map \u2014 element values",
      input: "{admin: [user name=Alice], editor: [user name=Bob]}",
      note:  "Map whose values are elements. The map literal nests CX shapes naturally.",
    },
    "durations": {
      label: "Durations \u2014 first-class scalars",
      input: "[timing\n  short=50ms\n  medium=2s\n  long=15m\n  very-long=2h]",
      note:  "Duration scalars: `Nms`, `Ns`, `Nm`, `Nh`. First-class type recognized by `[?sleep]`, `[?timeout]`, etc. (ADR 0039).",
    },
    "instants": {
      label: "Instants \u2014 ISO date attribute",
      input: "[event at=\"2025-05-25T14:30:00Z\"]",
      note:  "ISO-8601 instant as a quoted attribute value \u2014 round-trips verbatim through CX / JSON / XML.",
    },
    "attrs-and-body": {
      label: "Element \u2014 attrs AND text body",
      input: "[link href=\"https://cx-home.github.io\" \"CX Guide\"]",
      note:  "An element can carry both attributes and a body in the same tag \u2014 common for link / button shapes.",
    },
    "self-similar": {
      label: "Self-similar \u2014 wrapper of children",
      input: "[group\n  [group\n    [group label=leaf]]]",
      note:  "Same element name nested at multiple depths. JSON projection turns this into `{group:{group:{group:{...}}}}`.",
    },
    "empty-document": {
      label: "Empty \u2014 wrapper element only",
      input: "[doc]",
      note:  "An empty document \u2014 useful as a placeholder or a default `[?let $doc = [doc] :in \u2026]` seed.",
    },
    "hyphenated-names": {
      label: "Element \u2014 hyphenated names",
      input: "[user-profile is-active=true\n  [contact-info\n    [phone-number kind=mobile value=\"+1-555\"]]]",
      note:  "Element and attribute names support kebab-case (`user-profile`, `is-active`, `phone-number`). The hyphen is part of the identifier.",
    },
    "numbers-various": {
      label: "Numbers \u2014 int / float / negative",
      input: "[stats min=-5 mid=0 max=99.5 ratio=0.001]",
      note:  "Numeric attribute values \u2014 positive / negative / int / float / sub-unit. All round-trip through projections.",
    },
    "booleans-on-attrs": {
      label: "Booleans \u2014 feature flags",
      input: "[user active=true verified=false admin=true blocked=false]",
      note:  "Boolean attributes \u2014 `true` / `false` are typed scalars (not strings).",
    },
    "strings-special": {
      label: "Strings \u2014 quoting variants",
      input: "[note\n  single='single quotes'\n  double=\"double quotes\"\n  apostrophe=\"can't\"]",
      note:  "String quoting \u2014 single OR double quotes. Pick whichever avoids the most escapes.",
    },
    "triple-quote": {
      label: "Strings \u2014 triple-quoted (multiline)",
      input: "[doc\n  body='''line 1\nline 2\nline 3''']",
      note:  "Triple-quoted string allows multi-line content with embedded newlines. Useful for prose / code blocks.",
    },
    "seq-empty": {
      label: "Sequence \u2014 empty",
      input: "()",
      note:  "An empty sequence \u2014 distinct from `null`. JSON renders as `[]`.",
    },
    "map-empty": {
      label: "Map \u2014 empty",
      input: "{}",
      note:  "An empty map \u2014 distinct from `null`. JSON renders as `{}`.",
    },
    "library-catalog": {
      label: "Library \u2014 book catalog",
      input: "[library\n  [book isbn=\"978-0-13-110362-7\" title=\"The C Programming Language\" year=1988]\n  [book isbn=\"978-0-201-83595-3\" title=\"SICP\" year=1996]\n  [book isbn=\"978-1-491-95023-5\" title=\"Programming Rust\" year=2021]]",
      note:  "Bibliographic catalog \u2014 ISBN + metadata. JSON projection arrays the books cleanly.",
    },
    "recipe": {
      label: "Recipe \u2014 instructions + ingredients",
      input: "[recipe name=\"Pizza\" serves=4\n  [ingredient name=flour qty=500 unit=g]\n  [ingredient name=water qty=300 unit=ml]\n  [ingredient name=salt qty=10 unit=g]\n  [step \"Mix flour, water, and salt.\"]\n  [step \"Knead for 10 minutes.\"]\n  [step \"Rise for 2 hours.\"]]",
      note:  "Mixed-shape document \u2014 ingredients (with attrs) + steps (with text body).",
    },
    "playlist": {
      label: "Playlist \u2014 track list",
      input: "[playlist name=\"Focus\" duration=42m\n  [track id=1 title=\"Reverie\"          artist=\"Debussy\" duration=252s]\n  [track id=2 title=\"Gymnop\u00e9die No. 1\" artist=\"Satie\"   duration=228s]\n  [track id=3 title=\"Clair de Lune\"    artist=\"Debussy\" duration=321s]]",
      note:  "Playlist \u2014 track sequence with rich metadata per track. Per-track durations in seconds (composite `4m12s` form isn't parsed at attribute position; use raw seconds).",
    },
    "address-book": {
      label: "Address book \u2014 contact list",
      input: "[contacts\n  [contact id=1 name=Alice\n    [email \"a@x.com\"]\n    [phone \"+1-555-0100\"]]\n  [contact id=2 name=Bob\n    [email \"b@x.com\"]]\n  [contact id=3 name=Carol\n    [phone \"+1-555-0103\"]]]",
      note:  "Contact list \u2014 each entry has heterogeneous child sub-records (email / phone), and some are missing.",
    },
  };

  const program = {
    "for-yield-square": {
      label: "For-comp \u2014 yield squared values",
      input: "[?for $n :in (1, 2, 3, 4, 5)\n  :yield [square :n $n :sq [* $n $n]]]",
      note:  "`[?for $n :in xs :yield EXPR]` is the comprehension form \u2014 iterate `xs`, evaluate `EXPR` per item, collect results. Each `:yield` emits one element into the output sequence.",
    },
    "for-yield-where": {
      label: "For-comp \u2014 :where filter clause",
      input: "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)\n  :where [> $n 5]\n  :yield [big :n $n]]",
      note:  "`:where` filters the iteration. Predicates use the bracket directive form: `[> $n 5]` reads as `$n > 5`. Only items passing the predicate reach `:yield`.",
    },
    "for-yield-conditional": {
      label: "For-comp \u2014 :yield conditional",
      input: "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)\n  :yield [?if [> $n 5] :then [big :n $n] :else [small :n $n]]]",
      note:  "Conditional emit inside `:yield`. Every iteration yields one element; the branch decides which shape.",
    },
    "for-yield-nested": {
      label: "For-comp \u2014 nested iteration",
      input: "[?for $i :in (1, 2, 3)\n  :yield [?for $j :in (1, 2, 3)\n    :yield [pair :i $i :j $j]]]",
      note:  "Nested comprehensions \u2014 outer iteration's `:yield` body itself is a comprehension. Produces a 2D shape (rows of pairs).",
    },
    "par-map-wall-streamed": {
      label: "Map :par \u2014 wall-clock streaming",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?let $_ = [?sleep 500ms] :in [* $n $n]]]\n  :par]",
      note:  "Wall-clock parallelism. Bare `[?sleep 500ms]` really sleeps. Under `make guide-http` mode the 4 workers run on real OS threads \u2014 total ~500ms, completion-order output. Under file:// or generic HTTP V's spawn falls back to inline execution \u2014 total ~2s. The output streams: each item appears as its worker finishes.",
    },
    "par-map-wall-ordered": {
      label: "Map :par :ordered \u2014 wall-clock, source order",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?let $_ = [?sleep 500ms] :in [* $n $n]]]\n  :par :ordered]",
      note:  "Same as `par-map-wall` but with `:ordered` \u2014 output is reassembled in source order regardless of completion timing. Trade-off: order-preservation requires holding completed results in a buffer.",
    },
    "par-for-wall": {
      label: "For :par \u2014 wall-clock comprehension",
      input: "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8)\n      :yield [?let $_ = [?sleep 500ms] :in [item :n $n :sq [* $n $n]]]\n      :par]",
      note:  "`[?for :par]` parallelizes the outermost generator. Under pthreads the 8 sleeps overlap on real threads \u2014 wall-clock ~500ms. Under file:// or generic HTTP execution is sequential \u2014 total ~4s. `[?for]` always streams :yield results in source order.",
    },
    "par-map-mock": {
      label: "Map :par \u2014 :mock sleep (instant)",
      input: "[?map (1, 2, 3, 4, 5, 6, 7, 8)\n  :using [?fn $n [?let $_ = [?sleep 500ms :mock] :in [* $n $n]]]\n  :par :ordered]",
      note:  "Parallel-shape demo with `:mock` sleep \u2014 virtual time advances instantly, no wall-clock wait. Useful for testing parallel composition without real delays.",
    },
    "atom-001-bare-literal-in-code": {
      label: "Atoms \u2014 bare literal in code",
      input: ":ok",
      note:  "Atom literal \u2014 a kebab-case identifier evaluates to itself, the simplest CX value (ADR 0033).",
    },
    "atom-002-returned-from-let": {
      label: "Atoms \u2014 returned from let",
      input: "[?let $status = :ok :in $status]",
      note:  "Atom literal \u2014 a kebab-case identifier evaluates to itself, the simplest CX value (ADR 0033).",
    },
    "cast-string-to-int": {
      label: "Casts \u2014 cast string to int",
      input: "[cast \"42\" :int]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    "cast-string-to-float": {
      label: "Casts \u2014 cast string to float",
      input: "[cast \"3.14\" :float]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    "cast-string-to-bool": {
      label: "Casts \u2014 cast string to bool",
      input: "[cast \"true\" :bool]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    "cast-string-to-atom": {
      label: "Casts \u2014 cast string to atom",
      input: "[cast \"hello\" :atom]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    "cast-int-to-float": {
      label: "Casts \u2014 cast int to float",
      input: "[cast 5 :float]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    "cast-float-to-int-truncate": {
      label: "Casts \u2014 cast float to int truncate",
      input: "[cast 3.7 :int]",
      note:  "Type cast \u2014 `[cast TYPE VALUE]` converts between scalar types per ADR 0033. CXER0290 is the parse / type-mismatch failure mode.",
    },
    "element-whitespace-form-stays-element": {
      label: "Element construction \u2014 element whitespace form stays element",
      input: "[first \"a\"]",
      note:  "Build an element shape from parts. Paren-form `(name :attr v)` is the call-style construction; the bracket form `[name :attr v]` is the literal.",
    },
    "element-construction-dynamic-attr": {
      label: "Element construction \u2014 element construction dynamic attr",
      input: "[?let $l = \"cx\" :in [code lang=$l \"hello\"]]",
      note:  "Build an element shape from parts. Paren-form `(name :attr v)` is the call-style construction; the bracket form `[name :attr v]` is the literal.",
    },
    "element-construction-multi-attr": {
      label: "Element construction \u2014 element construction multi attr",
      input: "[?let $l = \"cx\" :in [?let $h = \"main\" :in [code lang=$l hl=$h \"body\"]]]",
      note:  "Build an element shape from parts. Paren-form `(name :attr v)` is the call-style construction; the bracket form `[name :attr v]` is the literal.",
    },
    "match-multi-001-element-dispatch": {
      label: "Pattern matching \u2014 match multi 001 element dispatch",
      input: "[?let $n = [prose \"hello\"] :in\n  [?match $n\n    :case [prose $p] :yield [p $p]\n    :case [code $c]  :yield [pre $c]\n    :else            :yield ()]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    "match-multi-002-scalar-literal": {
      label: "Pattern matching \u2014 match multi 002 scalar literal",
      input: "[?let $s = 200 :in\n  [?match $s\n    :case 200 :yield :ok\n    :case 404 :yield :not-found\n    :else     :yield :err]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    "match-multi-003-else-arm": {
      label: "Pattern matching \u2014 match multi 003 else arm",
      input: "[?let $s = 500 :in\n  [?match $s\n    :case 200 :yield :ok\n    :case 404 :yield :not-found\n    :else     :yield :err]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    "match-multi-004-no-else-returns-empty": {
      label: "Pattern matching \u2014 match multi 004 no else returns empty",
      input: "[?let $s = 500 :in\n  [?match $s\n    :case 200 :yield :ok\n    :case 404 :yield :not-found]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    "match-multi-007-wildcard": {
      label: "Pattern matching \u2014 match multi 007 wildcard",
      input: "[?let $v = \"surprise\" :in\n  [?match $v\n    :case 200    :yield :http-ok\n    :case _      :yield :other]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    "match-multi-008-scalar-type-strict": {
      label: "Pattern matching \u2014 match multi 008 scalar type strict",
      input: "[?let $v = \"200\" :in\n  [?match $v\n    :case 200   :yield :int-match\n    :case \"200\" :yield :string-match\n    :else       :yield :no-match]]",
      note:  "`[?match]` evaluates the scrutinee then dispatches to the first matching arm (ADR 0029). `:case` matches literal values, `:when` carries a predicate, `:else` is the fallback.",
    },
    "builtin-contains": {
      label: "Builtins \u2014 builtin contains",
      input: "contains(\"hello world\", \"world\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-contains-empty-sub": {
      label: "Builtins \u2014 builtin contains empty sub",
      input: "contains(\"hello world\", \"\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-starts-with": {
      label: "Builtins \u2014 builtin starts with",
      input: "starts-with(\"hello world\", \"hello\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-ends-with": {
      label: "Builtins \u2014 builtin ends with",
      input: "ends-with(\"hello world\", \"world\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-substring": {
      label: "Builtins \u2014 builtin substring",
      input: "substring(\"hello world\", 7, 5)",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-substring-to-end": {
      label: "Builtins \u2014 builtin substring to end",
      input: "substring(\"hello world\", 7)",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-string-length": {
      label: "Builtins \u2014 builtin string length",
      input: "string-length(\"hello\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-normalize-space": {
      label: "Builtins \u2014 builtin normalize space",
      input: "normalize-space(\"  hello   world  \")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-concat": {
      label: "Builtins \u2014 builtin concat",
      input: "concat(\"hello\", \" \", \"world\")",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-distinct": {
      label: "Builtins \u2014 builtin distinct",
      input: "distinct((1, 2, 2, 3, 1, 4))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-reverse": {
      label: "Builtins \u2014 builtin reverse",
      input: "reverse((1, 2, 3, 4))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-head": {
      label: "Builtins \u2014 builtin head",
      input: "head((10, 20, 30))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-tail": {
      label: "Builtins \u2014 builtin tail",
      input: "tail((10, 20, 30))",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "builtin-nth": {
      label: "Builtins \u2014 builtin nth",
      input: "nth((10, 20, 30, 40), 3)",
      note:  "Built-in function. Most builtins follow `[FN arg\u2081 arg\u2082 \u2026]` shape and are pure / total.",
    },
    "matrix-001-retry-retry": {
      label: "Composition matrix \u2014 retry retry",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?test-always-err]]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled.",
    },
    "matrix-002-retry-timeout": {
      label: "Composition matrix \u2014 retry timeout",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?timeout 10ms :body [?let $_ = [?sleep 100ms :mock] :in [ok :value \"x\"]]]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled.",
    },
    "matrix-003-retry-cb": {
      label: "Composition matrix \u2014 retry cb",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?test-cb-open]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled.",
    },
    "matrix-004-retry-fallback": {
      label: "Composition matrix \u2014 retry fallback",
      input: "[?retry :max 1 :backoff constant :delay 1ms :jitter none :body [?fallback :body [err :code \"p\"] :recover-with [err :code \"s\"]]]",
      note:  "Resilience composition \u2014 outer wraps inner. Failures bubble up the stack until handled.",
    },
    "compose-001-retry-over-timeout": {
      label: "Composition \u2014 retry over timeout",
      input: "[?retry :max 3 :backoff constant :delay 10ms :jitter none\n   :body [?timeout 100ms\n            :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]]]",
      note:  "Layered composition of integration directives. Read top-down: outer directive wraps inner.",
    },
    "pipe-001-canonical-form": {
      label: "Pipe \u2014 canonical form",
      input: "[?pipe (1, 2, 3, 4) :through [?fn $xs [?for $x :in $xs :where [> $x 2] :yield $x]]\n                    :through count]",
      note:  "Pipeline \u2014 values flow left to right through each stage. Canonical `[?pipe IN :through F :through G]` \u2261 infix `IN | F | G`.",
    },
    "pipe-002-infix-sugar": {
      label: "Pipe \u2014 infix sugar",
      input: "(1, 2, 3, 4) | [?fn $xs [?for $x :in $xs :where [> $x 2] :yield $x]] | count",
      note:  "Pipeline \u2014 values flow left to right through each stage. Canonical `[?pipe IN :through F :through G]` \u2261 infix `IN | F | G`.",
    },
    "retry-001-happy-path": {
      label: "Retry \u2014 happy path",
      input: "[?retry :max 3 :body [ok :value 42]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    "retry-002-success-on-third-attempt": {
      label: "Retry \u2014 success on third attempt",
      input: "[?retry :max 5\n        :body [?test-err-then-ok :err-count 2 :ok-value [ok :value \"done\"]]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    "retry-003-exhaustion": {
      label: "Retry \u2014 exhaustion",
      input: "[?retry :max 3 :body [?test-always-err]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    "retry-004-on-predicate-bails": {
      label: "Retry \u2014 on predicate bails",
      input: "[?retry :max 5\n        :on [?fn $e [?if [= $e@code \"permanent\"] :then false :else true]]\n        :body [err :code \"permanent\" :message \"give up\"]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    "retry-005-constant-backoff": {
      label: "Retry \u2014 constant backoff",
      input: "[?retry :max 3 :backoff constant :delay 100ms :jitter none\n        :body [?test-always-err]]",
      note:  "`[?retry]` re-evaluates `:body` until success or `:max` attempts. Backoff / jitter configurable per \u00a710.2.1.",
    },
    "timeout-001-completes-within": {
      label: "Timeout \u2014 completes within",
      input: "[?timeout 1s :body [ok :value \"fast\"]]",
      note:  "`[?timeout DUR :body \u2026]` bounds wall-clock for `:body`. Exceeded \u2192 `[err :code \"cx-err:CXER0141\"]`.",
    },
    "timeout-002-deadline-exceeded": {
      label: "Timeout \u2014 deadline exceeded",
      input: "[?timeout 100ms :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]]",
      note:  "`[?timeout DUR :body \u2026]` bounds wall-clock for `:body`. Exceeded \u2192 `[err :code \"cx-err:CXER0141\"]`.",
    },
    "timeout-003-on-timeout-recovery": {
      label: "Timeout \u2014 on timeout recovery",
      input: "[?timeout 100ms\n   :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]\n   :on-timeout [ok :value \"fallback\"]]",
      note:  "`[?timeout DUR :body \u2026]` bounds wall-clock for `:body`. Exceeded \u2192 `[err :code \"cx-err:CXER0141\"]`.",
    },
    "cb-001-closed-passthrough": {
      label: "Circuit breaker \u2014 closed passthrough",
      input: "[?circuit-breaker :threshold 0.5 :window 60s :reset 30s :min-samples 10\n   :body [ok :value 7]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    "cb-002-trips-open": {
      label: "Circuit breaker \u2014 trips open",
      input: "[?for $i :in (1, 2, 3, 4, 5)\n      :yield [?circuit-breaker :threshold 0.5 :window 60s :reset 30s\n                               :min-samples 2 :name \"cb-002\"\n              :body [?test-always-err]]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    "cb-003-half-open-after-reset": {
      label: "Circuit breaker \u2014 half open after reset",
      input: "[?let $a = [?circuit-breaker :threshold 0.0 :window 60s :reset 30s\n                             :min-samples 1 :name \"cb-003\"\n            :body [?test-err-then-ok :err-count 1 :ok-value [ok :value \"probe-ok\"]]]\n :in [?let $_ = [?test-clock :advance 31s]\n      :in [?let $b = [?circuit-breaker :threshold 0.0 :window 60s :reset 30s\n                                       :min-samples 1 :name \"cb-003\"\n                       :body [?test-err-then-ok :err-count 1 :ok-value [ok :value \"probe-ok\"]]]\n           :in ([a $a], [b $b])]]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    "cb-005-below-min-samples-no-trip": {
      label: "Circuit breaker \u2014 below min samples no trip",
      input: "[?for $i :in (1, 2)\n      :yield [?circuit-breaker :threshold 0.5 :window 60s :reset 30s\n                               :min-samples 10 :name \"cb-005\"\n              :body [?test-always-err]]]",
      note:  "`[?circuit-breaker]` opens after `:threshold` failure ratio over `:window`; rejects with CXER0150 until `:reset` elapses.",
    },
    "ratelimit-001-under-limit": {
      label: "Rate limit \u2014 under limit",
      input: "[?for $i :in (1, 2, 3)\n      :yield [?rate-limit :max 5 :per 1s :name \"rl-001\"\n              :body [ok :value $i]]]",
      note:  "`[?rate-limit :max N :per DUR]` admits up to N invocations per window; saturated \u2192 CXER0151.",
    },
    "ratelimit-002-over-limit": {
      label: "Rate limit \u2014 over limit",
      input: "[?for $i :in (1, 2, 3, 4)\n      :yield [?rate-limit :max 2 :per 1s :name \"rl-002\"\n              :body [ok :value $i]]]",
      note:  "`[?rate-limit :max N :per DUR]` admits up to N invocations per window; saturated \u2192 CXER0151.",
    },
    "ratelimit-003-replenish-after-window": {
      label: "Rate limit \u2014 replenish after window",
      input: "[?let $a = [?rate-limit :max 1 :per 1s :name \"rl-003\" :body [ok :value \"a\"]]\n :in [?let $b = [?rate-limit :max 1 :per 1s :name \"rl-003\" :body [ok :value \"b\"]]\n      :in [?let $_ = [?test-clock :advance 1100ms]\n           :in [?let $c = [?rate-limit :max 1 :per 1s :name \"rl-003\" :body [ok :value \"c\"]]\n                :in ([a $a], [b $b], [c $c])]]]]",
      note:  "`[?rate-limit :max N :per DUR]` admits up to N invocations per window; saturated \u2192 CXER0151.",
    },
    "bulkhead-001-under-cap": {
      label: "Bulkhead \u2014 under cap",
      input: "[?bulkhead :max-concurrent 4 :queue 0 :body [ok :value \"ran\"]]",
      note:  "`[?bulkhead :max-concurrent N]` caps concurrent `:body` invocations. Saturated \u2192 CXER0152, or queues per `:queue N`.",
    },
    "bulkhead-002-saturated-no-queue": {
      label: "Bulkhead \u2014 saturated no queue",
      input: "[?test-concurrent :tasks (\n   [?bulkhead :max-concurrent 1 :queue 0 :name \"bh-002\"\n              :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"first\"]]],\n   [?bulkhead :max-concurrent 1 :queue 0 :name \"bh-002\"\n              :body [ok :value \"second\"]])]",
      note:  "`[?bulkhead :max-concurrent N]` caps concurrent `:body` invocations. Saturated \u2192 CXER0152, or queues per `:queue N`.",
    },
    "bulkhead-003-queue-fifo": {
      label: "Bulkhead \u2014 queue fifo",
      input: "[?test-concurrent :tasks (\n   [?bulkhead :max-concurrent 1 :queue 2 :name \"bh-003\"\n              :body [?let $_ = [?sleep 100ms :mock] :in [ok :value \"a\"]]],\n   [?bulkhead :max-concurrent 1 :queue 2 :name \"bh-003\"\n              :body [ok :value \"b\"]],\n   [?bulkhead :max-concurrent 1 :queue 2 :name \"bh-003\"\n              :body [ok :value \"c\"]])]",
      note:  "`[?bulkhead :max-concurrent N]` caps concurrent `:body` invocations. Saturated \u2192 CXER0152, or queues per `:queue N`.",
    },
    "fallback-001-primary-success": {
      label: "Fallback \u2014 primary success",
      input: "[?fallback :body [ok :value \"primary\"] :recover-with [ok :value \"secondary\"]]",
      note:  "`[?fallback :body \u2026 :on-err \u2026]` runs `:body`; on err runs `:on-err` with `$err` bound.",
    },
    "fallback-002-primary-err-secondary-ok": {
      label: "Fallback \u2014 primary err secondary ok",
      input: "[?fallback :body [err :code \"down\"] :recover-with [ok :value \"secondary\"]]",
      note:  "`[?fallback :body \u2026 :on-err \u2026]` runs `:body`; on err runs `:on-err` with `$err` bound.",
    },
    "fallback-003-both-err-no-wrap": {
      label: "Fallback \u2014 both err no wrap",
      input: "[?fallback :body [err :code \"down-primary\"] :recover-with [err :code \"down-secondary\"]]",
      note:  "`[?fallback :body \u2026 :on-err \u2026]` runs `:body`; on err runs `:on-err` with `$err` bound.",
    },
    "sleep-001-mock-explicit": {
      label: "Sleep \u2014 mock explicit",
      input: "[?let $_ = [?sleep 500ms :mock] :in [ok :value \"instant\"]]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    "sleep-002-mock-flag-advances-now-ns": {
      label: "Sleep \u2014 mock flag advances now ns",
      input: "[?timeout 100ms :body [?let $_ = [?sleep 500ms :mock] :in [ok :value \"never\"]]]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    "sleep-003-mock-cancellation-immediate": {
      label: "Sleep \u2014 mock cancellation immediate",
      input: "[?let $f = [?async [?sleep 60s :mock]]\n :in [?let $_ = [?cancel $f] :in [?await $f]]]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    "sleep-004-grammar-mock-flag-parses": {
      label: "Sleep \u2014 grammar mock flag parses",
      input: "[?sleep 1ms :mock]",
      note:  "`[?sleep DUR]` blocks wall-clock by default; `:mock` advances a logical clock instantly without waiting (ADR 0039).",
    },
    "conc-001-channel-send-receive-buffered": {
      label: "Channels \u2014 channel send receive buffered",
      input: "[?let $ch = [?channel :name \"c1\" :buffer 1]\n :in [?let $_ = [?send \"hello\" :to $ch]\n      :in [?receive :from $ch]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    "conc-002-channel-synchronous-rendezvous": {
      label: "Channels \u2014 channel synchronous rendezvous",
      input: "[?let $ch = [?channel :name \"c2\" :buffer 0]\n :in [?test-concurrent :tasks (\n        [?send \"sync\" :to $ch],\n        [?receive :from $ch])]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    "conc-003-send-to-closed": {
      label: "Channels \u2014 send to closed",
      input: "[?let $ch = [?channel :name \"c3\" :buffer 1]\n :in [?let $_ = [?close $ch]\n      :in [?send \"late\" :to $ch]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    "conc-004-receive-drained-closed": {
      label: "Channels \u2014 receive drained closed",
      input: "[?let $ch = [?channel :name \"c4\" :buffer 2]\n :in [?let $_ = [?send \"a\" :to $ch]\n      :in [?let $_ = [?close $ch]\n           :in [?let $first = [?receive :from $ch]\n                :in [?let $second = [?receive :from $ch]\n                     :in ([first $first], [second $second])]]]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    "conc-005-try-send-timeout": {
      label: "Channels \u2014 try send timeout",
      input: "[?let $ch = [?channel :name \"c5\" :buffer 1]\n :in [?let $_ = [?send \"first\" :to $ch]\n      :in [?try-send \"second\" :to $ch :timeout 50ms]]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    "conc-006-try-receive-timeout": {
      label: "Channels \u2014 try receive timeout",
      input: "[?let $ch = [?channel :name \"c6\" :buffer 1]\n :in [?try-receive :from $ch :timeout 50ms]]",
      note:  "`[?channel :name S :buffer N]` is a typed queue. `[?send]` enqueues, `[?receive]` dequeues, `[?close]` signals end-of-stream.",
    },
    "conc-009-worker-happy-path": {
      label: "Workers \u2014 worker happy path",
      input: "[?let $w = [?worker :name \"w1\" :body [ok :value 42]]\n :in [?wait-for :worker $w]]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    "conc-010-worker-handle-lookup-miss": {
      label: "Workers \u2014 worker handle lookup miss",
      input: "[?worker-handle :name \"does-not-exist\"]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    "conc-011-worker-panic": {
      label: "Workers \u2014 worker panic",
      input: "[?let $w = [?worker :name \"w2\" :body [err :code \"kaboom\"]]\n :in [?wait-for :worker $w]]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    "conc-013-worker-handle-lookup-hit": {
      label: "Workers \u2014 worker handle lookup hit",
      input: "[?let $_ = [?worker :name \"w4\" :body [ok :value \"lookupable\"]]\n :in [?let $h = [?worker-handle :name \"w4\"]\n      :in [?wait-for :worker $h]]]",
      note:  "`[?worker]` registers a long-running task with `:body` evaluated under the cooperative `[?test-concurrent]` scheduler.",
    },
    "conc-014-select-first-channel": {
      label: "Select \u2014 select first channel",
      input: "[?let $a = [?channel :name \"sa\" :buffer 1]\n :in [?let $b = [?channel :name \"sb\" :buffer 1]\n      :in [?let $_ = [?send \"from-a\" :to $a]\n           :in [?select\n                 :case [:from $a $msg [picked :ch \"a\" :value $msg]]\n                 :case [:from $b $msg [picked :ch \"b\" :value $msg]]]]]]",
      note:  "`[?select :on ((:receive-from $ch1 :yield \u2026), \u2026)]` waits on multiple channel reads; the first ready wins.",
    },
    "conc-015-select-timeout-case": {
      label: "Select \u2014 select timeout case",
      input: "[?let $a = [?channel :name \"sc\" :buffer 1]\n :in [?select\n        :case [:from $a $msg [picked :ch \"a\" :value $msg]]\n        :case [:timeout 50ms [timeout-fired]]]]",
      note:  "`[?select :on ((:receive-from $ch1 :yield \u2026), \u2026)]` waits on multiple channel reads; the first ready wins.",
    },
    "async-001-await-done": {
      label: "Async \u2014 await done",
      input: "[?let $f = [?async [ok :value 42]]\n :in [?await $f]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    "async-002-await-failed-propagates": {
      label: "Async \u2014 await failed propagates",
      input: "[?let $f = [?async [err :code \"user-fault\" :message \"x\"]]\n :in [?await $f]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    "async-003-await-timeout": {
      label: "Async \u2014 await timeout",
      input: "[?let $f = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]\n :in [?await $f :timeout 50ms]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    "async-004-await-cancelled": {
      label: "Async \u2014 await cancelled",
      input: "[?let $f = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]\n :in [?let $_ = [?cancel $f]\n      :in [?await $f]]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    "async-015-compose-with-timeout": {
      label: "Async \u2014 compose with timeout",
      input: "[?let $f = [?async [?timeout 50ms :body [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]]\n :in [?await $f]]",
      note:  "`[?async EXPR]` returns a future handle; `[?await $f]` resolves it. Futures are lazy \u2014 body runs on first await.",
    },
    "async-005-await-all-success": {
      label: "await-all \u2014 await all success",
      input: "[?let $a = [?async [ok :value 1]]\n :in [?let $b = [?async [ok :value 2]]\n      :in [?let $c = [?async [ok :value 3]]\n           :in [?await-all ($a, $b, $c)]]]]",
      note:  "`[?await-all ($f1, $f2, \u2026)]` waits on every future; returns the sequence of results (or an aggregated CXER0240 err).",
    },
    "async-006-await-all-one-failed": {
      label: "await-all \u2014 await all one failed",
      input: "[?let $a = [?async [ok :value 1]]\n :in [?let $b = [?async [err :code \"down\"]]\n      :in [?let $c = [?async [ok :value 3]]\n           :in [?await-all ($a, $b, $c)]]]]",
      note:  "`[?await-all ($f1, $f2, \u2026)]` waits on every future; returns the sequence of results (or an aggregated CXER0240 err).",
    },
    "async-007-await-all-cancelled-counts": {
      label: "await-all \u2014 await all cancelled counts",
      input: "[?let $a = [?async [ok :value 1]]\n :in [?let $b = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"never\"]]]\n      :in [?let $_ = [?cancel $b]\n           :in [?await-all ($a, $b)]]]]",
      note:  "`[?await-all ($f1, $f2, \u2026)]` waits on every future; returns the sequence of results (or an aggregated CXER0240 err).",
    },
    "async-008-await-any-first-success": {
      label: "await-any \u2014 await any first success",
      input: "[?let $fast = [?async [ok :value \"fast\"]]\n :in [?let $slow = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"slow\"]]]\n      :in [?await-any ($fast, $slow)]]]",
      note:  "`[?await-any (\u2026)]` returns the first successful future; ignores subsequent failures.",
    },
    "async-009-await-any-skips-failed": {
      label: "await-any \u2014 await any skips failed",
      input: "[?let $bad = [?async [err :code \"bad\"]]\n :in [?let $good = [?async [ok :value \"good\"]]\n      :in [?await-any ($bad, $good)]]]",
      note:  "`[?await-any (\u2026)]` returns the first successful future; ignores subsequent failures.",
    },
    "async-010-await-race-first-terminal": {
      label: "await-race \u2014 await race first terminal",
      input: "[?let $err = [?async [err :code \"first-err\"]]\n :in [?let $ok = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"slow\"]]]\n      :in [?await-race ($err, $ok)]]]",
      note:  "`[?await-race (\u2026)]` returns the first future to resolve (success or fail), then cancels the losers.",
    },
    "async-011-await-race-cancels-losers": {
      label: "await-race \u2014 await race cancels losers",
      input: "[?let $fast = [?async [ok :value \"fast\"]]\n :in [?let $slow = [?async [?let $_ = [?sleep 10s :mock] :in [ok :value \"slow\"]]]\n      :in [?let $winner = [?await-race ($fast, $slow)]\n           :in [?let $slow-state = [?await $slow]\n                :in [pair :winner $winner :slow-state $slow-state]]]]]",
      note:  "`[?await-race (\u2026)]` returns the first future to resolve (success or fail), then cancels the losers.",
    },
    "async-012-cancel-honored-at-sleep": {
      label: "Cancel \u2014 cancel honored at sleep",
      input: "[?let $f = [?async [?sleep 10s :mock]]\n :in [?let $_ = [?cancel $f]\n      :in [?await $f]]]",
      note:  "`[?cancel $handle]` requests cancellation. Sleep / check-cancel observe via `current_future_id` and raise CXER0260.",
    },
    "map-001-par-ordered-source-order": {
      label: "Map \u2014 par ordered source order",
      input: "[?map (1, 2, 3, 4) :using [?fn $x [* $x 10]] :par :ordered]",
      note:  "`[?map xs :using fn]` applies `fn` to each element. `:par` parallelizes; `:ordered` preserves source order (ADR 0040).",
    },
    "map-002-sequential": {
      label: "Map \u2014 sequential",
      input: "[?map (1, 2, 3, 4) :using [?fn $x [* $x 10]]]",
      note:  "`[?map xs :using fn]` applies `fn` to each element. `:par` parallelizes; `:ordered` preserves source order (ADR 0040).",
    },
    "sleep-008-map-par-with-mock-sleep": {
      label: "Map \u2014 map par with mock sleep",
      input: "[?map (1, 2, 3, 4)\n  :using [?fn $n [?let $_ = [?sleep 10ms :mock] :in [* $n $n]]]\n  :par :ordered]",
      note:  "`[?map xs :using fn]` applies `fn` to each element. `:par` parallelizes; `:ordered` preserves source order (ADR 0040).",
    },
    "reduce-001-par-associative": {
      label: "Reduce \u2014 par associative",
      input: "[?reduce (1, 2, 3, 4, 5, 6, 7, 8) :using [?fn ($a, $b) [+ $a $b]] :init 0 :par]",
      note:  "`[?reduce xs :using fn :init z]` folds the sequence to one value. `:par` enables associative tree-reduce.",
    },
    "reduce-002-sequential-left-fold": {
      label: "Reduce \u2014 sequential left fold",
      input: "[?reduce (1, 2, 3, 4) :using [?fn ($a, $b) [- $a $b]] :init 10]",
      note:  "`[?reduce xs :using fn :init z]` folds the sequence to one value. `:par` enables associative tree-reduce.",
    },
    "svc-001-get-happy-path": {
      label: "Services \u2014 get happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-001\"\n              [resource :get \"/hello\"\n                 :body [response :status 200 :body \"world\"]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | get(\"/hello\")]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    "svc-002-post-happy-path": {
      label: "Services \u2014 post happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-002\"\n              [resource :post \"/echo\"\n                 :body [response :status 200 :body $request/body]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | post(\"/echo\", [payload :value 42])]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    "svc-003-put-happy-path": {
      label: "Services \u2014 put happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-003\"\n              [resource :put \"/items/:id\"\n                 :body [response :status 200\n                        :body [stored :id $request/path-params/id\n                                      :value $request/body]]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | put(\"/items/7\", [item :name \"widget\"])]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    "svc-004-delete-happy-path": {
      label: "Services \u2014 delete happy path",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-004\"\n              [resource :delete \"/items/:id\"\n                 :body [response :status 200\n                        :body [deleted :id $request/path-params/id]]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | delete(\"/items/9\")]]",
      note:  "`[?service]` defines an HTTP service shape; `[?test-service-client]` orchestrates spawn + client call + stop in one fixture.",
    },
    "svc-015-client-connection-refused": {
      label: "HTTP clients \u2014 client connection refused",
      input: "[?let $c = [?http-client :target \"http://localhost:1\"]\n :in $c | get(\"/\")]",
      note:  "`[?http-client]` issues a request against a `:target`. Integrates with `[?retry]` / `[?timeout]` / `[?circuit-breaker]`.",
    },
    "svc-016-client-tls-handshake-failed": {
      label: "HTTP clients \u2014 client tls handshake failed",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-016\"\n              [resource :get \"/\" :body [response :status 200 :body \"plaintext\"]]]\n   :client-call [?let $c = [?http-client :target $test-target :tls [?test-tls-config]]\n                 :in $c | get(\"/\")]]",
      note:  "`[?http-client]` issues a request against a `:target`. Integrates with `[?retry]` / `[?timeout]` / `[?circuit-breaker]`.",
    },
    "svc-017-client-invalid-response": {
      label: "HTTP clients \u2014 client invalid response",
      input: "[?test-service-client\n   :service [?service :on http :port 0 :name \"svc-017\"\n              [resource :get \"/garbled\"\n                 :body [response :status 200\n                        :headers [[header :name \"Content-Type\" :value \"application/cx\"]]\n                        :body [opts :raw-bytes \"}}}not-cx{{{\"]]]]\n   :client-call [?let $c = [?http-client :target $test-target]\n                 :in $c | get(\"/garbled\")]]",
      note:  "`[?http-client]` issues a request against a `:target`. Integrates with `[?retry]` / `[?timeout]` / `[?circuit-breaker]`.",
    },
  };

  window.cxPlaygroundExamples = { data, program };
})();
