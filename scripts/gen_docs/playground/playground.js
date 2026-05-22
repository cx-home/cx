// CX Playground.
//
// Two corpora: pure-data CX examples (round-trip through toCx/toJson/
// toXml) and CX programs (v0.7.6 directive surface, evaluated via
// cxlib.evalProgram). The dropdown groups them via <optgroup>.
//
// Program examples carry both their input data and their program in
// a single textarea, separated by the convention line:
//
//     \n--- program ---\n
//
// liveEvaluate splits on that separator. Data before the separator
// becomes the cx_program_eval input; the program after the separator
// is the source. Pure-data examples have no separator and route
// through the canonical-conversion entries instead.
//
// JSON / XML output panes use a *secondary pass* over the program's
// CX output — `cxlib.toJson(programCxOutput)` produces the clean
// data-projection JSON (`{"item":[1,2,3]}`) rather than the AST-JSON
// projection that `evalProgram(..., 'json', ...)` emits (which is
// useful for renderers but verbose for the playground UX).
//
// Two modes, decided at page-load time by detecting `window.cxlib`:
//
//  • Live mode: libcx-wasm is bundled with the site. The Run button
//    is enabled, the PLANNED notice is retired, and Run routes the
//    *current source textarea* through cxlib.evalProgram / toCx /
//    toJson / toXml — user edits are actually executed.
//
//  • Canned mode (no-wasm fallback): the Run button stays disabled,
//    the PLANNED notice stays, and Run is a re-render of the canned
//    outputs for the selected example. User edits are preserved but
//    never executed.
//
// See docs/concepts/wasm and spec/decisions/0026 for the rollout.
(function () {
  'use strict';

  const PROGRAM_SEP = '\n--- program ---\n';

  const dataExamples = {
    'atom': {
      label: "Atom \u2014 element with one attribute",
      input: "[pizza size=large]",
      cx:    "[pizza size=large]",
      json:  [
        "{",
        "  \"pizza\": {",
        "    \"size\": \"large\"",
        "  }",
        "}"
      ].join('\n'),
      xml:   "<pizza size=\"large\"/>",
    },
    'multi-attr': {
      label: "Attributes \u2014 typed, sized, sigil-flagged",
      input: [
        "[server",
        "  host=api.example.com",
        "  port=:u16=8080",
        "  +tls",
        "  -debug",
        "  ratio=:decimal=3.14159]"
      ].join('\n'),
      cx:    "[server host=api.example.com port=:u16=8080 tls=true debug=false ratio=:decimal=3.14159]",
      json:  [
        "{",
        "  \"server\": {",
        "    \"host\": \"api.example.com\",",
        "    \"port\": \":u16=8080\",",
        "    \"tls\": true,",
        "    \"debug\": false,",
        "    \"ratio\": \":decimal=3.14159\"",
        "  }",
        "}"
      ].join('\n'),
      xml:   "<server host=\"api.example.com\" port=\":u16=8080\" tls=\"true\" debug=\"false\" ratio=\":decimal=3.14159\"/>",
    },
    'sigils': {
      label: "Sigils \u2014 id, type-annotation, bool flags",
      input: [
        "[order #o123 :paid +shipped -refunded",
        "  total=:decimal=24.99",
        "  [line name=Margherita count=2]",
        "  [line name=Pepperoni count=1]]"
      ].join('\n'),
      cx:    "[order #o123 :paid '+shipped -refunded total=:decimal=24.99 ' [line name=Margherita count=2] [line name=Pepperoni count=1]]",
      json:  [
        "{",
        "  \"order\": {",
        "    \"_\": \"+shipped -refunded total=:decimal=24.99 \",",
        "    \"line\": [",
        "      {",
        "        \"name\": \"Margherita\",",
        "        \"count\": 2",
        "      },",
        "      {",
        "        \"name\": \"Pepperoni\",",
        "        \"count\": 1",
        "      }",
        "    ]",
        "  }",
        "}"
      ].join('\n'),
      xml:   "<order xml:id=\"o123\" cx:type=\"paid\">+shipped -refunded total=:decimal=24.99 <line name=\"Margherita\" count=\"2\"/><line name=\"Pepperoni\" count=\"1\"/></order>",
    },
    'text-body': {
      label: "Text body \u2014 element with prose",
      input: "[h1 Hello, World]",
      cx:    "[h1 Hello, World]",
      json:  [
        "{",
        "  \"h1\": \"Hello, World\"",
        "}"
      ].join('\n'),
      xml:   "<h1>Hello, World</h1>",
    },
    'nested': {
      label: "Nested elements \u2014 containment tree",
      input: [
        "[order",
        "  [customer name=Alice]",
        "  [item name=pizza qty=2]",
        "  [item name=salad qty=1]]"
      ].join('\n'),
      cx:    [
        "[order",
        "  [customer name=Alice]",
        "  [item name=pizza qty=2]",
        "  [item name=salad qty=1]",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"order\": {",
        "    \"customer\": {",
        "      \"name\": \"Alice\"",
        "    },",
        "    \"item\": [",
        "      {",
        "        \"name\": \"pizza\",",
        "        \"qty\": 2",
        "      },",
        "      {",
        "        \"name\": \"salad\",",
        "        \"qty\": 1",
        "      }",
        "    ]",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<order>",
        "  <customer name=\"Alice\"/>",
        "  <item name=\"pizza\" qty=\"2\"/>",
        "  <item name=\"salad\" qty=\"1\"/>",
        "</order>"
      ].join('\n'),
    },
    'mixed-content': {
      label: "Mixed content \u2014 prose + inline markup",
      input: [
        "[article",
        "  [h1 New Haven Story]",
        "  [p Founded in [em 1987]. See the [a href=/menu menu].]",
        "  [p Still [strong hand-tossing] every pie.]]"
      ].join('\n'),
      cx:    [
        "[article",
        "  [h1 New Haven Story]",
        "  [p 'Founded in ' [em 1987] '. See the ' [a href=/menu menu] '.']",
        "  [p 'Still ' [strong hand-tossing] ' every pie.']",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"article\": {",
        "    \"h1\": \"New Haven Story\",",
        "    \"p\": [",
        "      {",
        "        \"_\": \"Founded in . See the .\",",
        "        \"em\": 1987,",
        "        \"a\": {",
        "          \"href\": \"/menu\",",
        "          \"_\": \"menu\"",
        "        }",
        "      },",
        "      {",
        "        \"_\": \"Still  every pie.\",",
        "        \"strong\": \"hand-tossing\"",
        "      }",
        "    ]",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<article>",
        "  <h1>New Haven Story</h1>",
        "  <p>Founded in <em>1987</em>. See the <a href=\"/menu\">menu</a>.</p>",
        "  <p>Still <strong>hand-tossing</strong> every pie.</p>",
        "</article>"
      ].join('\n'),
    },
    'typed-table': {
      label: "Typed table \u2014 columnar with declared types",
      input: [
        "[orders :table[item:string qty:u32 paid:bool when:date]",
        "  Margherita 2 true  2026-05-09",
        "  Hawaiian   1 false 2026-05-09]"
      ].join('\n'),
      cx:    [
        "[orders :table[item:string qty:u32 paid:bool when:date]",
        "  Margherita 2 true 2026-05-09",
        "  Hawaiian 1 false 2026-05-09",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"orders\": null",
        "}"
      ].join('\n'),
      xml:   "<orders cx:type=\"table\"/>",
    },
    'anchor-merge': {
      label: "Anchor + merge \u2014 shared defaults",
      input: [
        "[defaults &shared timeout=30 retries=3]",
        "[server *shared name=api]",
        "[server *shared name=worker retries=5]"
      ].join('\n'),
      cx:    [
        "[defaults &shared timeout=30 retries=3]",
        "[server *shared name=api]",
        "[server *shared name=worker retries=5]"
      ].join('\n'),
      json:  [
        "{",
        "  \"defaults\": {",
        "    \"timeout\": 30,",
        "    \"retries\": 3",
        "  },",
        "  \"server\": [",
        "    {",
        "      \"name\": \"api\"",
        "    },",
        "    {",
        "      \"name\": \"worker\",",
        "      \"retries\": 5",
        "    }",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<defaults cx:anchor=\"shared\" timeout=\"30\" retries=\"3\"/>",
        "<server cx:merge=\"shared\" name=\"api\"/>",
        "<server cx:merge=\"shared\" name=\"worker\" retries=\"5\"/>"
      ].join('\n'),
    },
    'multi-doc': {
      label: "Multi-document \u2014 two roots in one file",
      input: [
        "[menu name=Lunch  [pizza name=Margherita]]",
        "---",
        "[menu name=Dinner [pizza name=Hawaiian]]"
      ].join('\n'),
      cx:    [
        "[menu name=Lunch",
        "  [pizza name=Margherita]",
        "]",
        "---",
        "[menu name=Dinner",
        "  [pizza name=Hawaiian]",
        "]"
      ].join('\n'),
      json:  [
        "[{",
        "  \"menu\": {",
        "    \"name\": \"Lunch\",",
        "    \"pizza\": {",
        "      \"name\": \"Margherita\"",
        "    }",
        "  }",
        "},{",
        "  \"menu\": {",
        "    \"name\": \"Dinner\",",
        "    \"pizza\": {",
        "      \"name\": \"Hawaiian\"",
        "    }",
        "  }",
        "}]"
      ].join('\n'),
      xml:   [
        "<menu name=\"Lunch\">",
        "  <pizza name=\"Margherita\"/>",
        "</menu>",
        "---",
        "<menu name=\"Dinner\">",
        "  <pizza name=\"Hawaiian\"/>",
        "</menu>"
      ].join('\n'),
    },
    'block-comment': {
      label: "Block comment \u2014 [- ... -]",
      input: [
        "[- Site-wide configuration; this comment does not render. -]",
        "[site name=acme port=8080]"
      ].join('\n'),
      cx:    [
        "[- Site-wide configuration; this comment does not render. -]",
        "[site name=acme port=8080]"
      ].join('\n'),
      json:  [
        "{",
        "  \"site\": {",
        "    \"name\": \"acme\",",
        "    \"port\": 8080",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<!-- Site-wide configuration; this comment does not render. --->",
        "<site name=\"acme\" port=\"8080\"/>"
      ].join('\n'),
    },
    'line-comment': {
      label: "Line comment \u2014 # to end of line",
      input: [
        "# top-of-file header",
        "[shop name=NewHaven",
        "  # opening hours \u2014 bare attrs auto-type",
        "  [hours mon-fri=11-22 sat=12-23]]"
      ].join('\n'),
      cx:    [
        "[shop name=NewHaven",
        "  [hours mon-fri=11-22 sat=12-23]",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"shop\": {",
        "    \"name\": \"NewHaven\",",
        "    \"hours\": {",
        "      \"mon-fri\": \"11-22\",",
        "      \"sat\": \"12-23\"",
        "    }",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<shop name=\"NewHaven\">",
        "  <hours mon-fri=\"11-22\" sat=\"12-23\"/>",
        "</shop>"
      ].join('\n'),
    },
    'heading': {
      label: "Heading \u2014 [#] through [######]",
      input: [
        "[# Top-level heading]",
        "[## Section heading]",
        "[### Sub-section heading]"
      ].join('\n'),
      cx:    [
        "[h1 Top-level heading]",
        "[h2 Section heading]",
        "[h3 Sub-section heading]"
      ].join('\n'),
      json:  [
        "{",
        "  \"h1\": \"Top-level heading\",",
        "  \"h2\": \"Section heading\",",
        "  \"h3\": \"Sub-section heading\"",
        "}"
      ].join('\n'),
      xml:   [
        "<h1>Top-level heading</h1>",
        "<h2>Section heading</h2>",
        "<h3>Sub-section heading</h3>"
      ].join('\n'),
    },
    'inline-markup': {
      label: "Inline markup \u2014 bold / italic / strike",
      input: [
        "[p This is [**important] and this is [*emphasised].",
        "   The crossed-out [~~text] is no longer current.]"
      ].join('\n'),
      cx:    "[p 'This is ' [strong important] ' and this is ' '. The crossed-out ' [del text] ' is no longer current.']",
      json:  [
        "{",
        "  \"p\": {",
        "    \"_\": \"This is  and this is . The crossed-out  is no longer current.\",",
        "    \"strong\": \"important\",",
        "    \"del\": \"text\"",
        "  }",
        "}"
      ].join('\n'),
      xml:   "<p>This is <strong>important</strong> and this is . The crossed-out <del>text</del> is no longer current.</p>",
    },
    'code-fence': {
      label: "Code fence \u2014 embedded language",
      input: [
        "[``` lang=python",
        "  [| print('hello, world') |]]"
      ].join('\n'),
      cx:    "[code 'lang=python ' [| print('hello, world') |]]",
      json:  [
        "{",
        "  \"code\": \"lang=python  print('hello, world') \"",
        "}"
      ].join('\n'),
      xml:   "<code>lang=python <cx:block> print('hello, world') </cx:block></code>",
    },
    'list': {
      label: "List \u2014 ul + li with link items",
      input: [
        "[ul",
        "  [li [a href=/menu Menu]]",
        "  [li [a href=/hours Hours]]",
        "  [li [a href=/contact Contact]]]"
      ].join('\n'),
      cx:    [
        "[ul",
        "  [li",
        "    [a href=/menu Menu]",
        "  ]",
        "  [li",
        "    [a href=/hours Hours]",
        "  ]",
        "  [li",
        "    [a href=/contact Contact]",
        "  ]",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"ul\": {",
        "    \"li\": [",
        "      {",
        "        \"a\": {",
        "          \"href\": \"/menu\",",
        "          \"_\": \"Menu\"",
        "        }",
        "      },",
        "      {",
        "        \"a\": {",
        "          \"href\": \"/hours\",",
        "          \"_\": \"Hours\"",
        "        }",
        "      },",
        "      {",
        "        \"a\": {",
        "          \"href\": \"/contact\",",
        "          \"_\": \"Contact\"",
        "        }",
        "      }",
        "    ]",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<ul>",
        "  <li>",
        "    <a href=\"/menu\">Menu</a>",
        "  </li>",
        "  <li>",
        "    <a href=\"/hours\">Hours</a>",
        "  </li>",
        "  <li>",
        "    <a href=\"/contact\">Contact</a>",
        "  </li>",
        "</ul>"
      ].join('\n'),
    },
    'prolog': {
      label: "Prolog \u2014 XML declaration",
      input: [
        "[?xml version=1.0 encoding=UTF-8]",
        "[shop name=NewHaven [item name=pizza price=12]]"
      ].join('\n'),
      cx:    [
        "[?xml version=1.0 encoding=UTF-8]",
        "[shop name=NewHaven",
        "  [item name=pizza price=12]",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"shop\": {",
        "    \"name\": \"NewHaven\",",
        "    \"item\": {",
        "      \"name\": \"pizza\",",
        "      \"price\": 12",
        "    }",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
        "<shop name=\"NewHaven\">",
        "  <item name=\"pizza\" price=\"12\"/>",
        "</shop>"
      ].join('\n'),
    },
    'dates': {
      label: "Dates and datetimes \u2014 typed scalars",
      input: [
        "[event",
        "  when=2026-05-21",
        "  starts=2026-05-21T14:30:00Z",
        "  duration=:duration=2h30m]"
      ].join('\n'),
      cx:    "[event when=2026-05-21 starts=2026-05-21T14:30:00Z duration=:duration=2h30m]",
      json:  [
        "{",
        "  \"event\": {",
        "    \"when\": \"2026-05-21\",",
        "    \"starts\": \"2026-05-21T14:30:00Z\",",
        "    \"duration\": \":duration=2h30m\"",
        "  }",
        "}"
      ].join('\n'),
      xml:   "<event when=\"2026-05-21\" starts=\"2026-05-21T14:30:00Z\" duration=\":duration=2h30m\"/>",
    },
    'namespaces': {
      label: "Namespaces \u2014 xmlns binding",
      input: [
        "[svg xmlns=http://www.w3.org/2000/svg viewBox=\"0 0 100 100\"",
        "  [circle cx=50 cy=50 r=40 fill=tomato]]"
      ].join('\n'),
      cx:    [
        "[svg xmlns=http://www.w3.org/2000/svg viewBox='0 0 100 100'",
        "  [circle cx=50 cy=50 r=40 fill=tomato]",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"svg\": {",
        "    \"xmlns\": \"http://www.w3.org/2000/svg\",",
        "    \"viewBox\": \"0 0 100 100\",",
        "    \"circle\": {",
        "      \"cx\": 50,",
        "      \"cy\": 50,",
        "      \"r\": 40,",
        "      \"fill\": \"tomato\"",
        "    }",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\">",
        "  <circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"tomato\"/>",
        "</svg>"
      ].join('\n'),
    },
    'quoted-string': {
      label: "Quoted strings \u2014 escapes and special chars",
      input: [
        "[message",
        "  text=\"She said \\\\\"hello\\\\\" loudly.\"",
        "  path='/usr/local/bin']"
      ].join('\n'),
      cx:    "[message text='She said \\\\' hello\\\\\" loudly.\" path='/usr/local/bin']",
      json:  [
        "{",
        "  \"message\": {",
        "    \"text\": \"She said \\\\\\\\\",",
        "    \"_\": \"hello\\\\\\\\\\\" loudly.\\\" path='/usr/local/bin'\"",
        "  }",
        "}"
      ].join('\n'),
      xml:   "<message text=\"She said \\\\\">hello\\\\\" loudly.\" path='/usr/local/bin'</message>",
    },
    'raw-text': {
      label: "Raw text \u2014 [# ... #] preserves bytes",
      input: [
        "[script lang=js",
        "  [# if (x < 0 && y > 10) { return 'special'; } #]]"
      ].join('\n'),
      cx:    "[script lang=js [# if (x < 0 && y > 10) { return 'special'; } #]]",
      json:  [
        "{",
        "  \"script\": {",
        "    \"lang\": \"js\",",
        "    \"_\": \" if (x < 0 && y > 10) { return 'special'; } \"",
        "  }",
        "}"
      ].join('\n'),
      xml:   "<script lang=\"js\"><![CDATA[ if (x < 0 && y > 10) { return 'special'; } ]]></script>",
    },
  };

  const programExamples = {
    'find-simple': {
      label: "[?find] \u2014 pattern match with binding",
      input: [
        "[doc",
        "  [user [name Alice]]",
        "  [user [name Bob]]",
        "  [user [name Carol]]]",
        "",
        "--- program ---",
        "[?find [user [name $n]] :yield $n]"
      ].join('\n'),
      cx:    [
        "[name Alice]",
        "[name Bob]",
        "[name Carol]"
      ].join('\n'),
      json:  [
        "{",
        "  \"name\": [",
        "    \"Alice\",",
        "    \"Bob\",",
        "    \"Carol\"",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<name>Alice</name>",
        "<name>Bob</name>",
        "<name>Carol</name>"
      ].join('\n'),
    },
    'find-attr-bool': {
      label: "[?find] \u2014 attribute equality predicate",
      input: [
        "[items",
        "  [item active=true  name=pizza]",
        "  [item active=false name=salad]",
        "  [item active=true  name=soda]]",
        "",
        "--- program ---",
        "[?find [item @active=true $i] :yield $i]"
      ].join('\n'),
      cx:    [
        "[item active=true name=pizza]",
        "[item active=true name=soda]"
      ].join('\n'),
      json:  [
        "{",
        "  \"item\": [",
        "    {",
        "      \"active\": true,",
        "      \"name\": \"pizza\"",
        "    },",
        "    {",
        "      \"active\": true,",
        "      \"name\": \"soda\"",
        "    }",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<item active=\"true\" name=\"pizza\"/>",
        "<item active=\"true\" name=\"soda\"/>"
      ].join('\n'),
    },
    'find-pair': {
      label: "[?find] \u2014 yield literal with multiple bindings",
      input: [
        "[doc",
        "  [user [name Alice] [email a@x.com]]",
        "  [user [name Bob]   [email b@x.com]]]",
        "",
        "--- program ---",
        "[?find [user [name $n] [email $e]] :yield [pair :name $n :email $e]]"
      ].join('\n'),
      cx:    [
        "[pair :name [name Alice] :email [email a@x.com]]",
        "[pair :name [name Bob] :email [email b@x.com]]"
      ].join('\n'),
      json:  [
        "{",
        "  \"pair\": [",
        "    {",
        "      \"name\": \"Alice\",",
        "      \"_\": \" :email \",",
        "      \"email\": \"a@x.com\"",
        "    },",
        "    {",
        "      \"name\": \"Bob\",",
        "      \"_\": \" :email \",",
        "      \"email\": \"b@x.com\"",
        "    }",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<pair cx:type=\"name\"><name>Alice</name> :email <email>a@x.com</email></pair>",
        "<pair cx:type=\"name\"><name>Bob</name> :email <email>b@x.com</email></pair>"
      ].join('\n'),
    },
    'find-deep': {
      label: "[?find] \u2014 finds at any depth",
      input: [
        "[org",
        "  [team [member [name Alice]]]",
        "  [team [member [name Bob]]]",
        "  [team [member [name Carol]]]]",
        "",
        "--- program ---",
        "[?find [name $n] :yield $n]"
      ].join('\n'),
      cx:    [
        "[name Alice]",
        "[name Bob]",
        "[name Carol]"
      ].join('\n'),
      json:  [
        "{",
        "  \"name\": [",
        "    \"Alice\",",
        "    \"Bob\",",
        "    \"Carol\"",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<name>Alice</name>",
        "<name>Bob</name>",
        "<name>Carol</name>"
      ].join('\n'),
    },
    'for-seq': {
      label: "[?for] \u2014 comprehension over sequence",
      input: [
        "--- program ---",
        "[?for $x :in (1, 2, 3, 4, 5) :yield [item $x]]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'for-where': {
      label: "[?for] \u2014 filter with :where",
      input: [
        "--- program ---",
        "[?for $x :in (1, 2, 3, 4, 5) :where [> $x 2] :yield $x]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'for-square': {
      label: "[?for] \u2014 transform yielded value",
      input: [
        "--- program ---",
        "[?for $x :in (1, 2, 3, 4) :yield [sq $x [* $x $x]]]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'let-arith': {
      label: "[?let] \u2014 bind and reuse",
      input: [
        "--- program ---",
        "[?let $a = 10 :in [?let $b = 32 :in [+ $a $b]]]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'let-shadow': {
      label: "[?let] \u2014 shadowing in nested scope",
      input: [
        "--- program ---",
        "[?let $x = 5 :in [?let $x = [* $x 2] :in [item $x]]]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'if-truthy': {
      label: "[?if] \u2014 conditional branch",
      input: [
        "--- program ---",
        "[?if [> 5 3] :then [yes [bigger]] :else [no [smaller]]]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'pipe-count': {
      label: "Pipe sugar \u2014 count over sequence",
      input: [
        "--- program ---",
        "(1, 2, 3, 4, 5) | count"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'pipe-upper': {
      label: "Pipe sugar \u2014 string transform",
      input: [
        "--- program ---",
        "\"hello\" | upper"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'pipe-find-first': {
      label: "Pipe sugar \u2014 find then first",
      input: [
        "[doc [user [name Alice]] [user [name Bob]]]",
        "",
        "--- program ---",
        "[?find [user [name $n]] :yield $n] | first"
      ].join('\n'),
      cx:    "[name Alice]",
      json:  [
        "{",
        "  \"name\": \"Alice\"",
        "}"
      ].join('\n'),
      xml:   "<name>Alice</name>",
    },
    'def-double': {
      label: "[?def] \u2014 named closure + invocation",
      input: [
        "--- program ---",
        "[?def double :params [$x] :body [* $x 2]]",
        "[double 21]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'fn-square': {
      label: "[?fn] \u2014 anonymous closure via pipe",
      input: [
        "--- program ---",
        "(1, 2, 3, 4) | [?fn $xs [?for $x :in $xs :yield [* $x $x]]]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'try-catch': {
      label: "[?try] \u2014 error recovery",
      input: [
        "--- program ---",
        "[?try [/ 10 0] :catch [err $e] [recovered]]"
      ].join('\n'),
      cx:    "",
      json:  "null",
      xml:   "",
    },
    'match': {
      label: "[?match] \u2014 single-value pattern test",
      input: [
        "[doc [user kind=admin [name Alice]]]",
        "",
        "--- program ---",
        "[?find [user [name $n]] :yield [welcome $n]]"
      ].join('\n'),
      cx:    "[welcome [name Alice]]",
      json:  [
        "{",
        "  \"welcome\": {",
        "    \"name\": \"Alice\"",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<welcome>",
        "  <name>Alice</name>",
        "</welcome>"
      ].join('\n'),
    },
    'find-yield-tree': {
      label: "[?find] \u2014 build new tree from matches",
      input: [
        "[shop",
        "  [pizza name=Margherita price=12]",
        "  [pizza name=Hawaiian   price=14]",
        "  [pizza name=Diavola    price=13]]",
        "",
        "--- program ---",
        "[?find [pizza @name=$n] :yield [hit $n]]"
      ].join('\n'),
      cx:    [
        "[hit \"Margherita\"]",
        "[hit \"Hawaiian\"]",
        "[hit \"Diavola\"]"
      ].join('\n'),
      json:  [
        "{",
        "  \"hit\": [",
        "    \"Margherita\",",
        "    \"Hawaiian\",",
        "    \"Diavola\"",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<hit>Margherita</hit>",
        "<hit>Hawaiian</hit>",
        "<hit>Diavola</hit>"
      ].join('\n'),
    },
    'multi-find': {
      label: "Pattern composition \u2014 find element + sub-element",
      input: [
        "[doc",
        "  [user [name Alice] [email a@x.com] [age 30]]",
        "  [user [name Bob]   [email b@x.com] [age 25]]]",
        "",
        "--- program ---",
        "[?find [user [name $n] [age $a]] :yield [profile :name $n :age $a]]"
      ].join('\n'),
      cx:    [
        "[profile :name [name Alice] :age [age 30]]",
        "[profile :name [name Bob] :age [age 25]]"
      ].join('\n'),
      json:  [
        "{",
        "  \"profile\": [",
        "    {",
        "      \"name\": \"Alice\",",
        "      \"_\": \" :age \",",
        "      \"age\": 30",
        "    },",
        "    {",
        "      \"name\": \"Bob\",",
        "      \"_\": \" :age \",",
        "      \"age\": 25",
        "    }",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<profile cx:type=\"name\"><name>Alice</name> :age <age>30</age></profile>",
        "<profile cx:type=\"name\"><name>Bob</name> :age <age>25</age></profile>"
      ].join('\n'),
    },
    'ladder-let': {
      label: "[?let] \u2014 let-chain composing pieces",
      input: [
        "[page [meta title='New Haven Pizza' tagline='Hand-tossed since 1987']]",
        "",
        "--- program ---",
        "[?let $title = [?find [meta @title=$t] :yield $t] :in",
        " [?let $tag = [?find [meta @tagline=$tl] :yield $tl] :in",
        "  [page [h1 $title] [p $tag]]]]"
      ].join('\n'),
      cx:    "[page [h1 \"New Haven Pizza\"] [p \"Hand-tossed since 1987\"]]",
      json:  [
        "{",
        "  \"page\": {",
        "    \"h1\": \"New Haven Pizza\",",
        "    \"p\": \"Hand-tossed since 1987\"",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<page>",
        "  <h1>New Haven Pizza</h1>",
        "  <p>Hand-tossed since 1987</p>",
        "</page>"
      ].join('\n'),
    },
  };


  // ── Lookup helpers ──────────────────────────────────────────────
  // Picker option values use 'data:<key>' or 'program:<key>' prefixes
  // so the kind is recoverable from the value alone.
  function lookupExample(key) {
    if (typeof key !== 'string') return null;
    if (key.startsWith('data:')) {
      const ex = dataExamples[key.slice(5)];
      return ex ? { kind: 'data', key, ex } : null;
    }
    if (key.startsWith('program:')) {
      const ex = programExamples[key.slice(8)];
      return ex ? { kind: 'program', key, ex } : null;
    }
    return null;
  }


  const pick      = document.getElementById('cxp-pick');
  const input     = document.getElementById('cxp-input');
  const inputRender = document.getElementById('cxp-input-render');
  const inputCopy = document.getElementById('cxp-input-copy');
  const runBtn    = document.getElementById('cxp-run');
  const reset     = document.getElementById('cxp-reset');
  const sourceLang = document.getElementById('cxp-source-lang');
  const outCx   = document.querySelector('#cxp-out-cx code');
  const outJson = document.querySelector('#cxp-out-json code');
  const outXml  = document.querySelector('#cxp-out-xml code');
  const status  = document.getElementById('cxp-status');
  const tabs    = document.querySelectorAll('.cxp-tab');
  const panes   = document.querySelectorAll('.cxp-pane');
  const vizSourceBtn   = document.getElementById('cxp-viz-source');
  const vizOutputBtn   = document.getElementById('cxp-viz-output');
  const vizSourcePane  = document.getElementById('cxp-viz-source-pane');
  const vizOutputPane  = document.getElementById('cxp-viz-output-pane');
  const vizSourceMount = document.getElementById('cxp-viz-source-mount');
  const vizOutputMount = document.getElementById('cxp-viz-output-mount');
  const sourceRow = document.querySelector('.cxp-source-row');
  const outputRow = document.querySelector('.cxp-output-row');

  if (!pick || !input) return;
  // ── Populate dropdown via <optgroup> (data + program corpora) ──
  function populatePicker() {
    pick.innerHTML = '';
    const dataGroup = document.createElement('optgroup');
    dataGroup.label = 'Data — pure CX (round-trips through toCx/toJson/toXml)';
    for (const [key, ex] of Object.entries(dataExamples)) {
      const opt = document.createElement('option');
      opt.value = 'data:' + key;
      opt.textContent = ex.label;
      dataGroup.appendChild(opt);
    }
    pick.appendChild(dataGroup);
    const progGroup = document.createElement('optgroup');
    progGroup.label = 'Program — v0.7.6 directives (cxlib.evalProgram)';
    for (const [key, ex] of Object.entries(programExamples)) {
      const opt = document.createElement('option');
      opt.value = 'program:' + key;
      opt.textContent = ex.label;
      progGroup.appendChild(opt);
    }
    pick.appendChild(progGroup);
  }
  populatePicker();


  // ── live mode detection (libcx-wasm bundled with the site) ──────────
  // `window.cxlib` is set by /wasm/cxlib.js if the WASM artifacts
  // loaded successfully. The wrapper's `ready` promise resolves once
  // _vinit has run. We capture that promise here and flip the UI
  // state when it lands. Until then the Run button stays disabled and
  // the PLANNED notice stays — exactly the v0.7.0 visual state.
  let liveActive = false;
  // Indirection so setStatus() below can pick up the LIVE-mode
  // default once it flips.
  const statusDefaultHTMLRef = { value: status ? status.innerHTML : '' };

  function activateLiveMode() {
    liveActive = true;
    if (runBtn) {
      runBtn.disabled = false;
      runBtn.removeAttribute('title');
    }
    // Retire the PLANNED notice — swap in a one-line "Powered by
    // libcx.wasm vX.Y.Z" footer per ADR 0026 §D6.
    if (status) {
      const cxlib = globalThis.cxlib;
      const ver = (cxlib && cxlib.version) ? cxlib.version() : 'wasm';
      status.innerHTML = 'Powered by <strong>libcx.wasm ' + ver + '</strong> — '
        + 'edits to the Source pane are evaluated live. '
        + '<a href="concepts/wasm.html">Concepts → WebAssembly Target</a>.';
      status.classList.remove('error', 'info');
      statusDefaultHTMLRef.value = status.innerHTML;
    }
  }

  const liveReady = (typeof globalThis !== 'undefined' && globalThis.cxlib && globalThis.cxlib.ready)
    ? globalThis.cxlib.ready.then(() => true, () => false)
    : Promise.resolve(false);
  liveReady.then(ok => { if (ok) activateLiveMode(); });

  // Status line surfaces transient feedback (Run/Reset/error) on top
  // of the static explanatory default. The default is rich HTML (with
  // a PLANNED badge + <strong> emphasis + a link to concepts/wasm), so
  // we capture the initial innerHTML once and restore that exact
  // markup when transient state clears. Transient text is plain.
  // Pass level='ok'|'error' for the palette flash. Errors stick
  // until the next setStatus call; ok auto-clears after 3s.
  let statusTimer = null;
  function setStatus(msg, level) {
    if (!status) return;
    if (statusTimer) { clearTimeout(statusTimer); statusTimer = null; }
    status.classList.remove('ok', 'error', 'info');
    if (level) status.classList.add(level);
    if (msg) {
      status.textContent = msg;
    } else {
      status.innerHTML = statusDefaultHTMLRef.value;
    }
    if (level && level !== 'error') {
      statusTimer = setTimeout(() => {
        status.classList.remove(level);
        status.innerHTML = statusDefaultHTMLRef.value;
      }, 3000);
    }
  }

  function flashRun(label, cls) {
    if (!runBtn) return;
    const orig = runBtn.dataset.origText || (runBtn.dataset.origText = runBtn.textContent);
    runBtn.textContent = label;
    runBtn.classList.add(cls);
    setTimeout(() => { runBtn.textContent = orig; runBtn.classList.remove(cls); }, 1500);
  }

  function highlightOutputs() {
    if (!window.CXHighlight) return;
    for (const el of [outCx, outJson, outXml]) {
      if (!el) continue;
      const cls = el.className.match(/language-([\w-]+)/);
      const lang = cls ? cls[1] : 'cx';
      el.innerHTML = window.CXHighlight.highlight(el.textContent, lang);
    }
  }

  function highlightInput() {
    if (!inputRender) return;
    const lang = (inputRender.className.match(/language-([\w-]+)/) || [, 'cx'])[1];
    // Append a trailing space so the render box always agrees with
    // the textarea on height after a final newline.
    const text = input.value + (input.value.endsWith('\n') ? ' ' : '');
    if (window.CXHighlight) {
      inputRender.innerHTML = window.CXHighlight.highlight(text, lang);
    } else {
      inputRender.textContent = text;
    }
  }

  function syncScroll() {
    if (!inputRender) return;
    const pre = inputRender.parentElement;
    if (!pre) return;
    pre.scrollTop = input.scrollTop;
    pre.scrollLeft = input.scrollLeft;
  }

  function setInputLang(lang) {
    if (sourceLang) sourceLang.textContent = lang;
    if (inputRender) {
      inputRender.className = inputRender.className.replace(/language-[\w-]+/, 'language-' + lang);
    }
  }

  function load(key) {
    const found = lookupExample(key);
    if (!found) return;
    const ex = found.ex;
    input.value = ex.input;
    setInputLang('cx');
    refreshOutputs(key);
    lastJsonText = ex.json || '';
    highlightInput();
    syncScroll();
    if (vizOutputOn) refreshOutputViz();
    if (vizSourceOn) refreshSourceViz();
  }

  // Refresh the three output tabs without touching the source pane.
  // Today the outputs come from the canned example corpus — a future
  // libcx-wasm build will route the current source through a live
  // evaluator instead. Either way the Source pane preserves user edits.
  function refreshOutputs(key) {
    const found = lookupExample(key); const ex = found && found.ex;
    if (!ex) return;
    if (outCx)   outCx.textContent = ex.cx;
    if (outJson) outJson.textContent = ex.json;
    if (outXml)  outXml.textContent = ex.xml;
    highlightOutputs();
  }

  function setTab(name) {
    tabs.forEach(t => t.classList.toggle('is-active', t.dataset.tab === name));
    panes.forEach(p => p.classList.toggle('is-active', p.id === 'cxp-out-' + name));
  }

  input.addEventListener('input', () => { highlightInput(); syncScroll(); });
  input.addEventListener('scroll', syncScroll);

  // Copy button for the Source pane. Mirrors the global pre>.copy-btn
  // behaviour the scaffold injects for output panes: writes the
  // textarea value to the clipboard, flashes "copied" / "failed", and
  // falls back to a hidden-textarea copy if the async clipboard API
  // is blocked (older browsers, insecure contexts).
  if (inputCopy) {
    inputCopy.addEventListener('click', async () => {
      const text = input.value;
      const flash = (label, cls) => {
        inputCopy.textContent = label;
        inputCopy.classList.add(cls);
        setTimeout(() => { inputCopy.textContent = 'copy'; inputCopy.classList.remove(cls); }, 1500);
      };
      try {
        await navigator.clipboard.writeText(text);
        flash('copied', 'copied');
      } catch (_) {
        try {
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.select();
          document.execCommand('copy');
          document.body.removeChild(ta);
          flash('copied', 'copied');
        } catch (__) {
          flash('failed', 'failed');
        }
      }
    });
  }

  pick.addEventListener('change', () => load(pick.value));
  reset.addEventListener('click', () => load(pick.value));
  // Live evaluation via cxlib (libcx-wasm v0.7.6 surface). The source
  // textarea may carry either pure-data CX (no separator) or a
  // data-then-program pair joined by the PROGRAM_SEP line. We
  // dispatch on the separator's presence — data-only sources route
  // through the canonical-conversion entries (toCx / toJson / toXml);
  // program sources split + route through evalProgram for the CX output,
  // then take a secondary pass through toJson / toXml for the clean
  // data-projection JSON / XML (vs the verbose AST-JSON that
  // evalProgram(..., 'json', ...) would emit).
  function liveEvaluate(/* key */) {
    const src = input.value;
    const cxlib = globalThis.cxlib;
    const idx = src.indexOf(PROGRAM_SEP);
    if (idx < 0) {
      return {
        cx:   cxlib.toCx(src),
        json: cxlib.toJson(src),
        xml:  cxlib.toXml(src),
      };
    }
    const dataPart = src.slice(0, idx).trim();
    const progPart = src.slice(idx + PROGRAM_SEP.length);
    const cxOut = cxlib.evalProgram(progPart, 'cx', dataPart);
    return {
      cx:   cxOut,
      json: cxOut ? cxlib.toJson(cxOut) : '',
      xml:  cxOut ? cxlib.toXml(cxOut) : '',
    };
  }

  function applyOutputs(outputs) {
    if (outCx)   outCx.textContent   = outputs.cx;
    if (outJson) outJson.textContent = outputs.json;
    if (outXml)  outXml.textContent  = outputs.xml;
    highlightOutputs();
  }

  // ── Visualize toggles (gate 17 §D2 + §D3) ───────────────────────
  // Source pane → Mermaid diagram via cxlib.diagram (live wasm only;
  // canned mode shows a placeholder since we can't generate Mermaid
  // from the canned corpus). Output pane → interactive tree from
  // cxlib.toJson AST (works in both modes — canned JSON is parsed
  // directly). Tree→text bridge: clicking a tree node highlights the
  // first substring match in the active Output text tab.
  const diagView = (globalThis.CxDiagramView && vizSourceMount)
    ? new globalThis.CxDiagramView({ onClose: () => setVizSource(false) })
    : null;
  const treeView = (globalThis.CxTreeView && vizOutputMount)
    ? new globalThis.CxTreeView({ onSelect: bridgeHighlight })
    : null;
  let vizSourceOn = false;
  let vizOutputOn = false;
  let lastSource = '';
  let lastJsonText = '';

  function setVizSource(on) {
    vizSourceOn = !!on;
    if (vizSourceBtn) vizSourceBtn.setAttribute('aria-pressed', vizSourceOn ? 'true' : 'false');
    if (vizSourcePane) {
      if (vizSourceOn) vizSourcePane.removeAttribute('hidden');
      else vizSourcePane.setAttribute('hidden', '');
    }
    if (sourceRow) sourceRow.classList.toggle('has-viz', vizSourceOn);
    if (vizSourceOn) {
      if (diagView && !diagView.container) diagView.mount(vizSourceMount);
      refreshSourceViz();
    }
  }

  function setVizOutput(on) {
    vizOutputOn = !!on;
    if (vizOutputBtn) vizOutputBtn.setAttribute('aria-pressed', vizOutputOn ? 'true' : 'false');
    if (vizOutputPane) {
      if (vizOutputOn) vizOutputPane.removeAttribute('hidden');
      else vizOutputPane.setAttribute('hidden', '');
    }
    if (outputRow) outputRow.classList.toggle('has-viz', vizOutputOn);
    if (vizOutputOn) {
      if (treeView && !treeView.container) treeView.mount(vizOutputMount);
      refreshOutputViz();
    }
  }

  function refreshSourceViz() {
    if (!vizSourceOn || !diagView) return;
    const cxlib = globalThis.cxlib;
    if (!liveActive || !cxlib || typeof cxlib.diagram !== 'function') {
      if (vizSourceMount) {
        vizSourceMount.innerHTML =
          '<div class="cxdv-empty">Mermaid diagrams require live libcx.wasm</div>';
      }
      return;
    }
    const src = input.value;
    lastSource = src;
    try {
      const mermaidText = cxlib.diagram(src, 'mermaid');
      diagView.render(mermaidText);
    } catch (err) {
      if (vizSourceMount) {
        vizSourceMount.innerHTML =
          '<pre class="cxdv-error">' +
          String(err && err.message ? err.message : err).replace(
            /[<&>]/g,
            (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[c])
          ) +
          '</pre>';
      }
    }
  }

  function refreshOutputViz() {
    if (!vizOutputOn || !treeView) return;
    // Prefer the live JSON we just emitted; fall back to the active
    // Output JSON tab text (canned-mode path).
    const jsonText = lastJsonText || (outJson ? outJson.textContent : '');
    if (!jsonText) {
      treeView.update(null);
      return;
    }
    let parsed = null;
    try {
      parsed = JSON.parse(jsonText);
    } catch (_) {
      // canned JSON snippets in the corpus are valid; live emit may
      // be empty for some directives — surface "No entities" instead.
      parsed = null;
    }
    treeView.update(parsed);
  }

  function bridgeHighlight(node) {
    // Tree → text direction only (text → tree deferred per audit §D13).
    const active = document.querySelector('.cxp-pane.is-active code');
    if (!active || !node || !node.hint) return;
    const text = active.textContent;
    const idx = text.indexOf(node.hint);
    if (idx < 0) return;
    // Re-highlight from scratch (escape away any prior <mark>).
    const before = text.slice(0, idx);
    const hit = text.slice(idx, idx + node.hint.length);
    const after = text.slice(idx + node.hint.length);
    const esc = (s) => s.replace(/[<&>]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[c]));
    // Re-run syntax highlight on before/after if present, but keep
    // the matched span as a flat <mark> (no per-token re-tokenization).
    const lang = (active.className.match(/language-([\w-]+)/) || [, 'cx'])[1];
    const h = (s) => (window.CXHighlight ? window.CXHighlight.highlight(s, lang) : esc(s));
    active.innerHTML = h(before) + '<mark class="cxp-bridge-hit">' + esc(hit) + '</mark>' + h(after);
    // Scroll the match into view.
    const mark = active.querySelector('mark.cxp-bridge-hit');
    if (mark && mark.scrollIntoView) mark.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }

  if (vizSourceBtn) vizSourceBtn.addEventListener('click', () => setVizSource(!vizSourceOn));
  if (vizOutputBtn) vizOutputBtn.addEventListener('click', () => setVizOutput(!vizOutputOn));

  runBtn.addEventListener('click', () => {
    try {
      const key = pick.value;
      const found = lookupExample(key); const ex = found && found.ex;
      if (!ex) {
        throw new Error(`no example registered for '${key}'`);
      }
      if (liveActive) {
        const outs = liveEvaluate(key);
        applyOutputs(outs);
        lastJsonText = outs.json || '';
        flashRun('evaluated', 'ran');
        setStatus('Source evaluated through libcx.wasm.', 'ok');
      } else {
        // Canned-corpus fallback: re-render the recorded outputs
        // for the selected example. User edits are preserved but
        // not executed — libcx-wasm is not bundled with this site.
        const edited = input.value !== ex.input;
        refreshOutputs(key);
        lastJsonText = ex.json || '';
        flashRun(edited ? 'rendered (no eval)' : 'rendered', 'ran');
        setStatus(
          edited
            ? "Output panes re-rendered from the canned corpus. Your Source edits aren't being executed — libcx-wasm is not built yet."
            : 'Canned outputs re-rendered for the selected example.',
          'ok'
        );
      }
      // Viz refresh happens in the finally block below so a failed
      // live-eval still drives the Source-pane diagram.
    } catch (err) {
      flashRun('failed', 'failed');
      setStatus(`Run failed: ${err && err.message ? err.message : err}`, 'error');
      // eslint-disable-next-line no-console
      console.error('[cx-playground] Run failed:', err);
    } finally {
      // Viz refresh runs in finally so a failed live-eval (Output
      // pane keeps its prior state) still drives the diagram pane
      // — Source-pane Visualize is a property of the source text,
      // not the eval result, and the tree falls back to the
      // previous JSON snapshot when lastJsonText is stale.
      if (vizSourceOn) refreshSourceViz();
      if (vizOutputOn) refreshOutputViz();
    }
  });
  tabs.forEach(t => t.addEventListener('click', () => setTab(t.dataset.tab)));

  // Initial load — surface boot errors visibly rather than silently
  // failing to populate the panes.
  try {
    load(pick.value || 'data:atom');
  } catch (err) {
    setStatus(`Playground failed to initialise: ${err && err.message ? err.message : err}`, 'error');
    // eslint-disable-next-line no-console
    console.error('[cx-playground] init failed:', err);
  }
})();
