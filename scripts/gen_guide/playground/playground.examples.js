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
      // Pattern-as-source [?for] needs $doc bound. The data lives in
      // `data` so cxlib.evalCode(src, 'cx', dataInput) gets the items
      // doc as $doc; `input` is just the program.
      data: [
        "[items",
        "  [item active=true  name=pizza]",
        "  [item active=false name=salad]",
        "  [item active=true  name=soda]]"
      ].join('\n'),
      input: "[?for [item @active=true $i] :yield $i]",
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
