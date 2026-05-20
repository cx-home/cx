# 50 More Ways to Leave: JSON, YAML, TOML, XML

A guided tour of CX **directives** — interpolation, paths, filters, conditionals, iteration, functions, modules — simple to complex, in 50 examples. Pizzeria edition, continuing from *50 Ways to Leave Your JSON, YAML, TOML, XML*.

Each example pairs a tiny data input with a directive snippet. Directives are written in CXL (CX's expression language) and read top-to-bottom alongside the data.

---

## I. Interpolation — `[?= … ]` (1–4)

**1. A literal value**
```
[?=42]
```
*`[?=expr]` evaluates and prints. Here, the number 42.*

**2. A literal string**
```
[?='Hand-tossed since 1987']
```
*Same form; strings and numbers interpolate identically.*

**3. Read an attribute — `@name`**
```
[pizza name=Margherita]
[?=@name]
```
*`@name` is CXPath for "the attribute named `name`." Prints `Margherita`.*

**4. Find anywhere — `//`**
```
[order [pizza name=Margherita]]
[?=//pizza/@name]
```
*`//pizza` matches a `pizza` element at any depth.*

---

## II. Templating positions (5–8)

**5. Inside body text**
```
[pizza name=Margherita]
[receipt Thanks for ordering [?=@name]!]
```
*A directive sits inside text. The rest stays as written.*

**6. Inside an attribute value**
```
[user id=42 name=Joe]
[a href=/u/[?=@id]/profile View [?=@name]'s profile]
```
*Interpolation works in attributes and in text. One mechanism, two positions.*

**7. Several on one line**
```
[pizza name=Margherita price=12]
[line [?=@name] — [?=@price]€]
```
*Each `[?=...]` is independent.*

**8. Inside a generated element**
```
[catalog [c cid=42 name=Joe] [c cid=43 name=Ann]]
[?for c :in //c :return [a href=/u/[?=c/@cid] [?=c/@name]]]
```
*Per iteration, build a fully-formed `[a href=… …]` element.*

---

## III. CXPath — paths and axes (9–13)

**9. Child step**
```
[shop [menu [pizza name=Margherita]]]
[?=//shop/menu/pizza/@name]
```
*Child steps separated by `/`. Prints `Margherita`.*

**10. Parent axis — `parent::*`**
```
[shop name="Pepe's" [pizza name=Margherita]]
[?=//pizza/parent::*/@name]
```
*Walks up one element. Prints `Pepe's`.*

**11. Ancestor axis**
```
[a tag=top [b tag=mid [c found]]]
[?for x :in //c/ancestor::* :return [?=x/@tag];]
```
*All ancestors of `c`. Prints `mid;top;`.*

**12. Following-sibling axis**
```
[row [cell n=1] [cell n=2] [cell n=3]]
[?for x :in //cell[@n=1]/following-sibling::* :return [?=x/@n];]
```
*Walks siblings to the right of the matched node.*

**13. Predicate filter — `[@attr=value]`**
```
[menu [pizza name=Margherita] [pizza name=Hawaiian]]
[?=//pizza[@name='Hawaiian']/@name]
```
*Brackets inside CXPath are predicates, not new elements.*

---

## IV. Filters & functions (14–18)

**14. Upper-case**
```
[pizza name=margherita]
[?=[?upper [@name]]]
```
*Wrap a value with `[?fn [args]]` to call a filter.*

**15. Default — fall back when missing**
```
[pizza name=Mystery]
[?=[?default [@price, 0]]]
```
*Graceful fallback; no exception.*

**16. Composed filters — nested**
```
[pizza name='  margherita  ']
[?=[?upper [[?trim [@name]]]]]
```
*Inside-out: trim, then upper.*

**17. String length**
```
[pizza name=Margherita]
[?=[?string-length [@name]]]
```
*Counts characters. Prints `10`.*

**18. Today's date**
```
[?=[?current-date]]
```
*`[?current-date]`, `[?current-dateTime]`, `[?current-time]`.*

---

## V. Operators (19–22)

**19. Pipeline `|>` — left-to-right composition**
```
[pizza name='  margherita  ']
[?=@name |> trim |> upper]
```
*Same result as #16, read top-down instead of inside-out.*

**20. Arrow `=>` — method-call style**
```
[pizza name=MARGHERITA]
[?=@name => lower()]
```
*XQuery's invocation syntax. Reads as `name.lower()`.*

**21. String concatenation `||`**
```
[user first=Ada last=Lovelace]
[?=@first || ' ' || @last]
```
*Join strings with `||`, like SQL.*

**22. Range — `M to N`**
```
[?for n :in 1 to 4 :return [?=n];]
```
*Inclusive range. Prints `1;2;3;4;`.*

---

## VI. Conditionals — `[?if … ]` (23–27)

**23. Positional form**
```
[pizza stock=0]
[?if [@stock > 0, in stock, out of stock]]
```
*Three slots: condition, then, else.*

**24. Labeled form**
```
[pizza stock=5]
[?if @stock > 0 :then in stock :else out of stock]
```
*Same semantics, named slots — usually clearer.*

**25. Skip the else branch**
```
[pizza featured=true]
[?if @featured :then ★ featured!]
```
*False condition → nothing renders.*

**26. Existence check**
```
[pizza [tags vegan]]
[?if [//tags, yes, no]]
```
*A node-set is truthy when non-empty.*

**27. Multi-branch — no else-if ladder**
```
[pizza stock=2]
[?if [[@stock > 100, plenty], [@stock > 10, some], [@stock > 0, last few], [*, sold out]]]
```
*Each `[cond, value]` is a branch; `*` is the catch-all.*

---

## VII. Iteration — `[?for … ]` (28–31)

**28. Positional form**
```
[pizza [topping cheese] [topping basil] [topping oil]]
[?for [t, //topping, [?=t/@name];]]
```
*Slots: variable, source, body.*

**29. Labeled form**
```
[pizza [topping cheese] [topping basil] [topping oil]]
[?for t :in //topping :return [?=t/@name];]
```
*Same semantics with `:in` and `:return`.*

**30. Range loop — generate elements**
```
[?for n :in 1 to 3 :return [slot id=[?=n]]]
```
*Produces `[slot id=1][slot id=2][slot id=3]`.*

**31. Nested for**
```
[shop [pizza name=Margherita [topping cheese] [topping basil]]]
[?for p :in //pizza :return
  [grp [?=p/@name]: [?for t :in p/topping :return [?=t/@name],]]]
```
*Loop over pizzas; inside, loop over each pizza's toppings.*

---

## VIII. Context — `[?with … ]` (32–33)

**32. Positional**
```
[shop [meta owner=Pepe region=IT]]
[?with [//meta, [?=@owner] / [?=@region]]]
```
*Inside `with`, `@owner` and `@region` refer to `meta`. Prints `Pepe / IT`.*

**33. Labeled**
```
[shop [meta owner=Pepe region=IT]]
[?with //meta :return [?=@owner]/[?=@region]]
```
*Named-slot variant.*

---

## IX. Let-binding — `[?let … :be … :return … ]` (34–35)

**34. Bind once, reuse**
```
[pizza price=12]
[?let tax :be @price * 0.22 :return Total: [?=@price + tax]€]
```
*Compute `tax` once, use it where the binding is in scope.*

**35. Bind a pipeline result**
```
[pizza name='  margherita  ']
[?let clean :be @name |> trim |> upper :return Welcome, [?=clean]!]
```
*Pipelines and let-bindings compose naturally.*

---

## X. Functions — `[?def … ]` and `[?use … ]` (36–40)

**36. Define a template fragment**
```
[?def greet :body Hello [?=@name]!]
[pizza name=Pepe]
[?use greet]
```
*The body runs in the calling context.*

**37. With one parameter**
```
[?def shout :params [x] :body LOUD: [?=x]!]
[?shout 'pizza ready']
```
*Once defined, the function is callable as `[?shout …]`.*

**38. Multiple parameters**
```
[?def pair :params [a, b] :body [?=a] / [?=b]]
[?pair 'cheese' 'basil']
```
*Positional params; prints `cheese / basil`.*

**39. Function + iteration**
```
[?def line :params [item] :body sku=[?=item/@sku];]
[order [v sku=A] [v sku=B] [v sku=C]]
[?for x :in //v :return [?line x]]
```
*A reusable per-item template, mapped over a node set.*

**40. Higher-order — `[?focus]` and `[?apply]`**
```
[pizza [v n=5]]
[?let dbl :be [?focus :body [?=_ * 2]]
  :return [?for x :in //v :return [?=[?apply [dbl, x/@n]]]]]
```
*`[?focus]` builds a function from a body (`_` is the implicit arg); `[?apply]` invokes it.*

---

## XI. Runtime configuration — `[?cx … ]` (41–43)

**41. HTML-safe output**
```
[pizza name='<script>alert("free pizza")</script>']
[?cx output-target=html]
[?=@name]
```
*One directive switches the evaluator into context-aware escaping. No XSS from the menu.*

**42. Plain-text output**
```
[?cx output-target=text]
[pizza name='<b>Margherita</b>']
[?=@name]
```
*Useful for terminals and files where escaping would be noise.*

**43. Activate a module**
```
[?cx use-module=cx]
[?=[?cx:canonical [[?cx:parse ['[a   x=1  ]']]]]]
```
*Modules expose new directive namespaces (`cx:`, `log:`, …) once activated.*

---

## XII. Reflection — `cx:` module (44–47)

**44. `cx:parse` — read CX from a string**
```
[?cx use-module=cx]
[?=[?cx:parse ['[pizza name=Margherita]']]]
```
*CX reads its own syntax as data. Code is data.*

**45. `cx:serialize` — emit a value back to text**
```
[?cx use-module=cx]
[?=[?cx:serialize [[?cx:parse ['[a x=1 y=2]']]]]]
```
*Round-trip: parse → serialize. Print is `[a x=1 y=2]`.*

**46. `cx:canonical` — normalize**
```
[?cx use-module=cx]
[?=[?cx:canonical [[?cx:parse ['[a   x=1   y=2]']]]]]
```
*Whitespace and attribute order canonicalized; idempotent.*

**47. `cx:hash` — content digest**
```
[?cx use-module=cx]
[?=[?cx:hash [[?cx:parse ['[pizza name=Margherita]']]]]]
```
*Stable BLAKE2b digest over the canonical form. Same input → same hash, every binding.*

---

## XIII. Composition — `cx:merge` (48)

**48. Three-policy semantic merge**
```
[?cx use-module=cx]
[order [pizza name=Margherita price=12]]
[coupon [pizza price=10]]
[?=[?cx:merge [//order, //coupon]]]
```
*Two trees combined by element identity. Coupon's `price=10` overrides the order's.*

---

## XIV. Observability — `log:` module (49)

**49. Structured logging**
```
[?cx use-module=log log-level=info]
[?log:info ['sale', {pizza: 'Margherita', price: 12}]]
[?log:debug ['suppressed at info level']]
```
*`[?log:level [msg]]` emits a structured event. Second arg is a map of fields.*

---

## XV. Finale (50)

**50. The whole kitchen — config, function, merge, log, render**
```
[?cx use-module=cx output-target=html log-level=info]
[?def line :params [p] :body [li [?=p/@name] — [?=p/@price]€]]
[order [pizza name='<b>Margherita</b>' price=12]]
[coupon [pizza price=10]]
[?log:info ['rendering receipt']]
[ul [?for p :in [?cx:merge [//order, //coupon]]/pizza :return [?line p]]]
```
*Module activation, HTML-safe escaping, function definition, structured logging, semantic merge, iteration. Six lines; the whole arc.*

---

**Arc:** read a value → put it in context → walk paths → filter and combine → branch → loop → factor into functions → swap output mode → reflect / hash / merge / log. Every step adds exactly one capability; data from the companion document flows through unchanged.

See *50 Ways to Leave Your JSON, YAML, TOML, XML* for the data companion.
