# 50 Ways to Leave Your JSON, YAML, TOML, XML

A guided tour of CX **data** forms, simple to complex, in 50 examples. Pizzeria edition. No program directives — those live in the companion document, *50 More Ways*.

Each example is ≤5 lines of CX. Where the markup/value distinction is genuinely fuzzy, a `→ reads:` callout names the parts.

---

## I. Bare attributes — the logfmt floor (1–2)

**1. The atom**
```
size=large
```
*Just `name=value`. In CX this is a valid document on its own — "logfmt mode," intended for log lines and structured events. The smallest piece of CX.*

**2. Several atoms — a one-line event**
```
time=2026-05-09T12:00:00Z level=INFO svc=oven pizza=Margherita
```
*A whole log line — no brackets, no root, just attributes.*

---

## II. Elements (3–9)

**3. Empty element**
```
[pizza]
```
*Brackets give a name. Empty, but a thing.*

**4. Element with one property**
```
[pizza size=large]
```
*Atom from #1, now attached to a pizza.*

**5. Several properties**
```
[pizza size=large crust=thin price=12]
```
*Keep adding. No commas required between attrs.*

**6. Bare flag (no `=value`)**
```
[pizza name=Hawaiian controversial]
```
*Presence means "yes," absence means "no" — same idea as `--verbose` or HTML's `required`. Here: this pizza is controversial.*

**7. Explicit boolean values**
```
[pizza vegan=true gluten-free=false]
```
*When you want both polarities, write the word.*

**8. Boolean sigil shorthand**
```
[pizza +vegan -nuts -gluten]
```
*`+name` = `name=true`, `-name` = `name=false`. Compact form for many booleans.*

**9. Numbers — int, decimal, negative, hex, underscores**
```
[pizza price=12.50 discount=-2 ovens=4 mask=0xFF00FF batch=1_000_000]
```
*All bare, all auto-typed. Underscores in numbers are readability sugar.*

---

## III. Strings & literals (10–17)

**10. Quoted — single quotes**
```
[pizza name='BBQ Chicken']
```
→ *reads: attribute `name`, value is the string `BBQ Chicken`.*

**11. Quoted — double quotes**
```
[pizza name="Quattro Formaggi"]
```
*Pick the quote that doesn't appear in the value.*

**12. Mix when the value has an apostrophe**
```
[pizza name="Tony's Special"]
```
*Double-quote around an apostrophe; no escaping needed.*

**13. The empty string**
```
[pizza name=Mystery description=""]
```
*Distinct from missing: the attribute is there, just empty.*

**14. Escape sequences inside quotes**
```
[pizza alert='Hot!\nHandle with care.\tCafé é']
```
*Same family as C/JSON: `\n \r \t \uXXXX \UXXXXXXXX \' \\`.*

**15. Entity references (XML-style)**
```
[pizza name='Cheese &amp; Pepper' note='use &lt;tongs&gt;']
```
*`&amp;` `&lt;` `&gt;` work as in XML. Useful when a literal `&` would confuse the parser.*

**16. Null**
```
[pizza discount=null reviewed=null]
```
*A real null value, distinct from "" or "null" the string.*

**17. Date and datetime literals**
```
[promo starts=2026-05-01 ends=2026-05-31 cutoff=2026-05-31T23:59:00Z]
```
*ISO 8601 shapes are auto-typed as `date` / `datetime`.*

---

## IV. Text bodies (18–24)

**18. Plain text body**
```
[motto Hand-tossed since 1987]
```
*After the name, the rest of the bracket is text.*

**19. Attributes plus text body**
```
[pizza name=Margherita Classic since day one.]
```
→ *reads: element `pizza`, attribute `name=Margherita`, then text body `Classic since day one.`*

**20. Multi-line text — preserved as written**
```
[description
  Stone-baked, hand-stretched,
  and ready in 90 seconds.]
```
*Whitespace and newlines inside a text body are kept literally.*

**21. Triple-quoted string `'''…'''` — multi-line literal**
```
[bio '''
  Born in Naples, 1955.
  Started Pepe's in 1987.
  Still on the line every Friday.
''']
```
*Three quotes open and close. Single/double quotes inside need no escaping. Common leading whitespace is stripped.*

**22. Block content `[| … ]` — newlines preserved **and** elements parsed**
```
[poem [|
  Roses are red,
    violets are blue,
  the [em best] pizza
    is waiting for you.
]]
```
*Like a text body, but indentation/newlines are kept verbatim. Unlike triple-quoted, inner elements (`[em best]`) are still real markup.*

**23. Raw text `[# … #]` — nothing inside is parsed**
```
[snippet [# if (x < 10) { return "[pizza]"; } #]]
```
*The CDATA of CX. Brackets, quotes, `<`, `>` — all literal characters. The terminator is `#]`.*

**24. Embedded code in another language**
```
[query language=sql [#
  SELECT name, price FROM pizza
  WHERE price < 15 AND vegan = true;
#]]
```
*Raw text is how you embed SQL/JS/regex without escaping every quote.*

---

## V. Comments (25–28)

**25. `#` line comment**
```
# weekend special — pulled Monday
[pizza name=TruffleSpecial price=24]
```
*`#` comments out the rest of the line. Lives outside elements, like a script header.*

**26. `[- … ]` block comment, inline**
```
[pizza name=Diavola [- TODO confirm price ] price=14]
```
*Element-shaped — fits **inside** brackets where `#` can't reach.*

**27. `[- … ]` block comment, multi-line**
```
[-
  Pricing review:
    - Diavola: bump to 16?
    - Hawaiian: hold at 14
]
```
*Canonical for multi-line notes.*

**28. When to use which**
```
# top-of-file header
[shop [- inline aside on this branch ] port=8080]
```
*`#` for line-scoped headers; `[- … ]` when the comment must nest inside an element or span lines. (Not HTML's `<!-- -->` — CX has its own form.)*

---

## VI. Structure (29–35)

**29. Nesting**
```
[pizza name=Margherita [base tomato]]
```
*Brackets inside brackets.*

**30. Siblings**
```
[pizza [topping cheese] [topping basil] [topping oil]]
```
*Same shape, side by side. No separators required.*

**31. Inline prose with markup — HTML-style**
```
[note Try the [b Margherita] — our [em best seller], hand-tossed [strong daily].]
```
*Prose and tags interleave freely. The same shapes you'd write in HTML.*

**32. A whole article — prose-and-data**
```
[article
  [h1 Pepe's Story]
  [p Founded in [em 1987]. See the [a href=/menu menu].]
  [p Still [strong hand-tossing] every pie.]]
```
*Headings, paragraphs, links, emphasis — CX handles document text as cleanly as XML.*

**33. Deeper nesting — children with their own data**
```
[pizza name=Quattro
  [topping cheese price=2]
  [topping ham    price=3]
  [topping olives price=2]]
```
*Each child carries its own attributes.*

**34. Multiple top-level elements (no required root)**
```
[pizza name=Margherita]
[pizza name=Hawaiian]
[pizza name=Diavola]
```
*A document can be a flat list.*

**35. Multi-document file — `---` between docs**
```
[menu [pizza name=Margherita]]
---
[menu [pizza name=Hawaiian]]
```
*One file, several independent documents. Same separator as YAML.*

---

## VII. Collections — sequence, array, map (36–41)

**36. Sequence `( … )` — flat list**
```
[pizza toppings=(cheese, basil, oil)]
```
→ *reads: attribute `toppings`, value is the sequence of three strings.*

**37. Array `[ … ]` — nested list**
```
[grid cells=[1, 2, 3]]
```
*Arrays preserve structure; sequences flatten. Use arrays when nesting matters.*

**38. Nested arrays**
```
[board cells=[[1, 0, 1],
              [0, 1, 0],
              [1, 0, 1]]]
```
*A matrix is just an array of arrays.*

**39. Map `{ … }` — named key→value**
```
[pizza prices={small: 9, medium: 12, large: 15}]
```
→ *reads: attribute `prices`, value is a map with three entries.*

**40. Collections in body position (not just attributes)**
```
[favorites
  (Margherita, Hawaiian, Diavola)]
```
*Sequences, arrays, and maps can sit inside an element body too.*

**41. Mixed-shape composition**
```
[stats {
  monday: (12, 8, 14),
  tuesday: (10, 9, 11),
  wednesday: (15, 11, 18)
}]
```
*Map of sequences, multi-line. Compose freely.*

---

## VIII. Typed bodies & arrays (42–43)

**42. Explicit type annotation**
```
[count :int 42]
[ratio :decimal 3.14159]
```
*`:type` after the name pins the body's type, overriding auto-typing.*

**43. Typed array as body**
```
[oven-temps :int[] 220 240 260 480]
[tags :[] cheap fast tasty]
```
*`:int[]` for typed; `:[]` for inferred (string array, here).*

---

## IX. Tables (44–46)

**44. Plain table — header + rows**
```
[menu :table[name size price]
  Margherita medium 12
  Hawaiian   large  14
  Diavola    medium 13
]
```
*`:table[…]` declares column names. Each line below is a row.*

**45. Typed columns**
```
[orders :table[item:string qty:int paid:bool when:date]
  Margherita 2 true  2026-05-09
  Hawaiian   1 false 2026-05-09
]
```
*Each column can carry a `:type`. Cells parse accordingly.*

**46. Quoted cells & nulls**
```
[shifts :table[cook hours:int notes]
  Pepe       8 morning
  Maria      6 'closing crew'
  'Jean-Luc' 4 null
]
```
*Quote cells with spaces. `null` is a real null in the cell.*

---

## X. Anchors, aliases, merge (47–48)

**47. Anchor (`&name`) and alias (`[*name]`)**
```
[pizza &classic name=Margherita price=12 [base tomato]]
[menu [*classic] [*classic]]
```
*`&classic` names this element; `[*classic]` drops a full copy in.*

**48. Merge (`*name`) with overrides**
```
[pizza &classic name=Margherita price=12 [base tomato]]
[pizza *classic name=ClassicXL size=large price=16]
```
*`*classic` inherits the anchor's attrs/children; overrides apply on top.*

---

## XI. Finale (49–50)

**49. A recipe — prose, data, table, all together**
```
[recipe name=Margherita serves=2
  [ingredients :table[item amount:string]
    flour      300g
    water      200ml
    yeast      2g
    'San Marzano tomato' 150g
    mozzarella 120g
    basil      'a handful']
  [steps
    [step Mix the dough and rest [em 24 hours] cold.]
    [step Stretch by hand — no rolling pin.]
    [step Bake at [strong 480°C] for 90 seconds.]]
  [notes '''
    A wetter dough gives a softer cornicione.
    Don't skip the cold rest.
  ''']]
```
*Tabular ingredients, prose steps with inline markup, multi-line notes — all in one document, one syntax.*

**50. The whole shop**
```
[?xml version=1.0 encoding=UTF-8]
[shop &flagship name="Pepe's" port=8080 +open
  # opening hours
  [hours mon-fri=11-22 sat=12-23 sun=closed]
  [- menu reviewed 2026-05-01 ]
  [menu :table[name:string size price:decimal vegan:bool]
    Margherita medium 12.00 true
    Hawaiian   large  14.00 false
    Diavola    medium 13.00 false]
  [staff [cook &lead name=Pepe shift=morning +founder]
         [cook *lead name=Maria shift=closing -founder]]
  [contact
    address='123 Forno Lane'
    coords={lat: 40.8518, lon: 14.2681}
    phones=("+39 555 0101", "+39 555 0102")]
  [tagline '''
    Hand-tossed since 1987.
    Still tossing.
  ''']]
```
*XML decl, anchor, sigil flags, line comment, block comment, typed table, merged child, map and sequence attribute values, triple-quoted text. One syntax, everywhere.*

---

**Arc:** bare attribute → element → strings → text bodies → comments → structure → collections → typed arrays → tables → anchors → the whole shop. Every step adds one shape; no shape requires anything the earlier ones don't already give you.

See *50 More Ways to Leave: JSON, YAML, TOML, XML* for the directive / program companion.
