// scripts/gen_guide/playground/playground.examples.js
//
// Starter examples for the v0.8.0 CX playground — data examples + program
// examples. Loaded via a classic <script src> tag in playground.html BEFORE
// playground.js so this works under file:// (where fetch / XHR / ES modules
// are blocked by browser security but DOM script loads are allowed).
//
// playground.js reads:
//   const dataExamples    = window.cxPlaygroundExamples.data;
//   const programExamples = window.cxPlaygroundExamples.program;
//
// To author a new example, edit the corresponding object literal below.

(function () {
  'use strict';

  // ── Data starters — pure CX, round-trips through toCx/toJson/toXml.
  const data = {
    'atom': {
      label: "Atom — element with one attribute",
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
    'nested': {
      label: "Nested elements — containment tree",
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
    'whole-shop': {
      label: "Whole shop — every data shape in one document",
      input: [
        "[shop &flagship name='New Haven Pizza' +open",
        "  [hours mon-fri=11-22 sat=12-23]",
        "  [menu :table[name:string size price:decimal vegan:bool]",
        "    Margherita medium 12.00 true",
        "    Hawaiian   large  14.00 false]",
        "  [about",
        "    [p Founded in [em 1987]. Still [strong hand-tossing] every pie.]]]"
      ].join('\n'),
      cx:    [
        "[shop &flagship name='New Haven Pizza' open=true",
        "  [hours mon-fri=11-22 sat=12-23]",
        "  [menu :table[name:string size price:decimal vegan:bool]",
        "    Margherita medium 12.00 true",
        "    Hawaiian large 14.00 false",
        "  ]",
        "  [about",
        "    [p 'Founded in ' [em 1987] '. Still ' [strong hand-tossing] ' every pie.']",
        "  ]",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"shop\": {",
        "    \"name\": \"New Haven Pizza\",",
        "    \"open\": true,",
        "    \"hours\": {",
        "      \"mon-fri\": \"11-22\",",
        "      \"sat\": \"12-23\"",
        "    },",
        "    \"menu\": null,",
        "    \"about\": {",
        "      \"p\": {",
        "        \"_\": \"Founded in . Still  every pie.\",",
        "        \"em\": 1987,",
        "        \"strong\": \"hand-tossing\"",
        "      }",
        "    }",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<shop cx:anchor=\"flagship\" name=\"New Haven Pizza\" open=\"true\">",
        "  <hours mon-fri=\"11-22\" sat=\"12-23\"/>",
        "  <menu cx:type=\"table\"/>",
        "  <about>",
        "    <p>Founded in <em>1987</em>. Still <strong>hand-tossing</strong> every pie.</p>",
        "  </about>",
        "</shop>"
      ].join('\n'),
    },
  };

  // ── Program starters — CX code (programs) executed via cxlib.evalCode.
  const program = {
    'find-attr-eq': {
      label: "[?for] — attribute equality predicate",
      // Combined homoiconic source: inert [items ...] document at the
      // top, directive at the bottom. The playground splits the source
      // at run time — leading inert structures become $doc, the
      // trailing [?for] is the program.
      input: [
        "[items",
        "  [item active=true  name=pizza]",
        "  [item active=false name=salad]",
        "  [item active=true  name=soda]]",
        "[?for [item @active=true $i] :yield $i]"
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
    'for-seq': {
      label: "[?for] — comprehension over sequence",
      input: "[?for $x :in (1, 2, 3, 4, 5) :yield [item $x]]",
      cx:    [
        "[item 1]",
        "[item 2]",
        "[item 3]",
        "[item 4]",
        "[item 5]"
      ].join('\n'),
      json:  [
        "{",
        "  \"item\": [",
        "    1,",
        "    2,",
        "    3,",
        "    4,",
        "    5",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<item>1</item>",
        "<item>2</item>",
        "<item>3</item>",
        "<item>4</item>",
        "<item>5</item>"
      ].join('\n'),
    },
    'for-where': {
      label: "[?for] — filter with :where",
      input: "[?for $x :in (1, 2, 3, 4, 5) :where [> $x 2] :yield $x]",
      cx:    [
        "3",
        "4",
        "5"
      ].join('\n'),
      json:  "null",
      xml:   [
        "3",
        "4",
        "5"
      ].join('\n'),
    },
    'let-arith': {
      label: "[?let] — bind and reuse",
      input: "[?let $a = 10 :in [?let $b = 32 :in [+ $a $b]]]",
      cx:    "42",
      json:  "null",
      xml:   "42",
    },
    'if-truthy': {
      label: "[?if] — conditional branch",
      input: "[?if [> 5 3] :then [yes [bigger]] :else [no [smaller]]]",
      cx:    "[yes [bigger]]",
      json:  [
        "{",
        "  \"yes\": {",
        "    \"bigger\": null",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<yes>",
        "  <bigger/>",
        "</yes>"
      ].join('\n'),
    },
    'def-double': {
      label: "[?def] — named closure + invocation",
      input: [
        "[?def :name double ($x) :body [* $x 2]]",
        "[double(21)]"
      ].join('\n'),
      cx:    "42",
      json:  "null",
      xml:   "42",
    },
    // ── v0.8.0 ADR debuts ─────────────────────────────────────────
    'cxpath-predicate': {
      label: "CXPath — attribute predicate over a document (ADR 0028)",
      input: [
        "[users",
        "  [user name=Alice active=true  age=30]",
        "  [user name=Bob   active=false age=25]",
        "  [user name=Carol active=true  age=22]]",
        "[?for $u :in //user[@active=true]",
        "  :yield [active-user name=$u/@name age=$u/@age]]"
      ].join('\n'),
      cx:    [
        "[active-user name=\"Alice\" age=30]",
        "[active-user name=\"Carol\" age=22]"
      ].join('\n'),
      json:  [
        "{",
        "  \"active-user\": [",
        "    {",
        "      \"name\": \"Alice\",",
        "      \"age\": 30",
        "    },",
        "    {",
        "      \"name\": \"Carol\",",
        "      \"age\": 22",
        "    }",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<active-user name=\"Alice\" age=\"30\"/>",
        "<active-user name=\"Carol\" age=\"22\"/>"
      ].join('\n'),
    },
    'match-multi': {
      label: "[?match] — multi-arm :case / :when / :else (ADR 0029)",
      input: [
        "[requests",
        "  [request status=200]",
        "  [request status=404]",
        "  [request status=500]",
        "  [request status=204]]",
        "[?for $r :in //request",
        "  :yield [?match $r/@status",
        "    :case 200 :yield [classify level='ok']",
        "    :case 204 :yield [classify level='no-content']",
        "    :case 404 :yield [classify level='not-found']",
        "    :when ($r/@status >= 500)",
        "              :yield [classify level='server-error']",
        "    :else     :yield [classify level='unknown']]]"
      ].join('\n'),
      cx:    [
        "[classify level=\"ok\"]",
        "[classify level=\"not-found\"]",
        "[classify level=\"server-error\"]",
        "[classify level=\"no-content\"]"
      ].join('\n'),
      json:  [
        "{",
        "  \"classify\": [",
        "    { \"level\": \"ok\" },",
        "    { \"level\": \"not-found\" },",
        "    { \"level\": \"server-error\" },",
        "    { \"level\": \"no-content\" }",
        "  ]",
        "}"
      ].join('\n'),
      xml:   [
        "<classify level=\"ok\"/>",
        "<classify level=\"not-found\"/>",
        "<classify level=\"server-error\"/>",
        "<classify level=\"no-content\"/>"
      ].join('\n'),
    },
    'sleep-mock': {
      label: "[?sleep] — :mock for deterministic logical-clock advance",
      // ADR 0039: bare [?sleep DUR] is wall-clock (Worker-only in
      // the wasm playground); :mock advances env.state.now_ns without
      // blocking. Used here to make a [?timeout] fire deterministically.
      input: [
        "[?timeout 100ms",
        "  :body [?let $_ = [?sleep 500ms :mock] :in [ok :value 'never']]]"
      ].join('\n'),
      cx:    "[err :code \"cx-err:CXER0141\" :elapsed 100ms]",
      json:  "{\n  \"err\": { \"code\": \"cx-err:CXER0141\", \"elapsed\": \"100ms\" }\n}",
      xml:   "<err code=\"cx-err:CXER0141\" elapsed=\"100ms\"/>",
    },
    'map-par-mock': {
      label: "[?map :par] — parallel map with :mock sleep (instant)",
      // Parallel-shape demo that's instant in the browser: each task
      // logically takes 50ms, but :mock makes that virtual — total
      // wall-clock < 1ms. Real parallel speedup needs wall-clock
      // sleeps (see the `map-par-wall` example). Per ADR 0040: :par
      // alone is unordered (faster); add :ordered for source-order
      // output preservation.
      input: [
        "[?map (1, 2, 3, 4, 5, 6, 7, 8)",
        "  :using [?fn $n [?let $_ = [?sleep 50ms :mock] :in [* $n $n]]]",
        "  :par :ordered]"
      ].join('\n'),
      cx:    "(1, 4, 9, 16, 25, 36, 49, 64)",
      json:  "null",
      xml:   "1\n4\n9\n16\n25\n36\n49\n64",
    },
    'for-par-wall': {
      label: "[?for :par] — wall-clock parallel comprehension",
      // The playground runs eval in a Web Worker that opts into
      // wall-clock [?sleep] via cx_wasm_set_wall_sleep(true). Each
      // task takes ~50ms; with :par the outermost generator runs the
      // tasks concurrently. Output order is preserved at parse-time
      // shape, but wall-clock dispatch is parallel.
      input: [
        "[?for $n :in (1, 2, 3, 4, 5, 6, 7, 8)",
        "      :yield [?let $_ = [?sleep 50ms] :in [item :n $n :sq [* $n $n]]]",
        "      :par]"
      ].join('\n'),
      cx:    [
        "[item :n 1 :sq 1]",
        "[item :n 2 :sq 4]",
        "[item :n 3 :sq 9]",
        "[item :n 4 :sq 16]",
        "[item :n 5 :sq 25]",
        "[item :n 6 :sq 36]",
        "[item :n 7 :sq 49]",
        "[item :n 8 :sq 64]"
      ].join('\n'),
      json:  "null",
      xml:   [
        "<item n=\"1\" sq=\"1\"/>",
        "<item n=\"2\" sq=\"4\"/>",
        "<item n=\"3\" sq=\"9\"/>",
        "<item n=\"4\" sq=\"16\"/>",
        "<item n=\"5\" sq=\"25\"/>",
        "<item n=\"6\" sq=\"36\"/>",
        "<item n=\"7\" sq=\"49\"/>",
        "<item n=\"8\" sq=\"64\"/>"
      ].join('\n'),
    },
    'async-future-mock': {
      label: "[?async] / [?await] — fire-and-forget futures (mock)",
      // [?async] returns a future immediately; [?await] blocks until
      // the future is terminal. :mock keeps the demo instant.
      input: [
        "[?let $fast = [?async [?let $_ = [?sleep 50ms :mock]  :in [ok :value 'a']]]",
        " :in [?let $slow = [?async [?let $_ = [?sleep 200ms :mock] :in [ok :value 'b']]]",
        "      :in [?await-all ($fast, $slow)]]]"
      ].join('\n'),
      cx:    "([ok :value \"a\"], [ok :value \"b\"])",
      json:  "null",
      xml:   "(<ok value=\"a\"/>, <ok value=\"b\"/>)",
    },
    'map-par-wall': {
      label: "[?map :par] — wall-clock sleep (shows real delay)",
      // Same shape as map-par-mock, but bare [?sleep 250ms] takes
      // wall-clock time. Under the playground's ASYNCIFY wasm build
      // the main thread yields cooperatively through each sleep so
      // the UI stays responsive; ~1s end-to-end. Per ADR 0040, :par
      // without :ordered is unordered (fastest); :ordered would add
      // completion-tracking + reassembly overhead — not worth it
      // here since the result happens to land in source order under
      // the v0.8.0 single-threaded eval anyway.
      input: [
        "[?map (1, 2, 3, 4)",
        "  :using [?fn $n [?let $_ = [?sleep 250ms] :in [* $n $n]]]",
        "  :par]"
      ].join('\n'),
      cx:    "(1, 4, 9, 16)",
      json:  "null",
      xml:   "1\n4\n9\n16",
    },
    'modify-set': {
      label: "[?modify] — pure-functional :set + :delete (ADR 0030)",
      input: [
        "[doc",
        "  [user id=1 name=Alice banned=false]",
        "  [user id=2 name=Bob   banned=true]",
        "  [user id=3 name=Carol banned=false]]",
        "[?let $clean = [?modify //user[@banned=true] :delete] :in",
        " [?modify $clean //user[@id=1]/@name :set 'Alice (verified)']]"
      ].join('\n'),
      cx:    [
        "[doc",
        "  [user id=1 name='Alice (verified)' banned=false]",
        "  [user id=3 name=Carol banned=false]",
        "]"
      ].join('\n'),
      json:  [
        "{",
        "  \"doc\": {",
        "    \"user\": [",
        "      { \"id\": 1, \"name\": \"Alice (verified)\", \"banned\": false },",
        "      { \"id\": 3, \"name\": \"Carol\", \"banned\": false }",
        "    ]",
        "  }",
        "}"
      ].join('\n'),
      xml:   [
        "<doc>",
        "  <user id=\"1\" name=\"Alice (verified)\" banned=\"false\"/>",
        "  <user id=\"3\" name=\"Carol\" banned=\"false\"/>",
        "</doc>"
      ].join('\n'),
    },
  };

  window.cxPlaygroundExamples = { data, program };
})();
