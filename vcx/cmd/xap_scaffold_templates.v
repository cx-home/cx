module main

// The scaffold bodies for `cx xap scaffold <pattern>` (#1487, RULED: COMP-1).
//
// Kept beside the command rather than read from disk, the same arrangement
// `cx xap init` uses: a scaffold never depends on the toolchain's own source
// tree being present.
//
// EVERY BODY IS composition.md §3's SKELETON FOR THAT PATTERN, unchanged.
// What §3 states is a declaration here; what it does not state is an
// authoring TODO here — never a guess, never a plausible default. That is the
// ingest discipline connector.md §6.3 fixes for every skeleton the toolchain
// emits (RULED: 1430-g): an undetectable pagination shape becomes a TODO on
// the verb, anything about idempotency becomes a TODO per act verb, and a
// security scheme outside the closed set becomes a TODO rather than the
// nearest member of it.
//
// The set is CLOSED (composition.md §3): seven patterns, and a composition an
// adopter needs that is not one of them is a decision for the owner, not a
// variation to improvise. `cx xap scaffold` refuses an eighth name and prints
// the seven.

struct XapScaffoldPattern {
	slug    string            // the name on the command line
	section string            // the composition.md section it is drawn from
	title   string            // that section's title
	need    string            // the enterprise need, in one sentence
	modules string            // the modules the pattern uses
	seams   string            // the §2 rows it crosses
	graded  string            // the reference example that grades it
	todos   []string          // what the pattern does NOT fix
	files   map[string]string // emitted name -> body
}

fn xap_scaffold_patterns() []XapScaffoldPattern {
	return [
		XapScaffoldPattern{
			slug:    "poll-transform-sink"
			section: "§3.1"
			title:   "Poll–transform–sink"
			need:    "An outside system is read on a cadence, its records are mapped into another system's nouns, and the result is written to a sink — without either system's declaration learning that the other exists."
			modules: "`connector` (the walk), `flow` (the ordering and the transform step), `journal` or a second connector (the sink)."
			seams:   "S-1 (the verbs), S-6 (the transitions), R-8 and R-9 (the transform reaches no module's state and is where the mapping lives), R-1 (neither feature names `flow`)."
			graded:  "No reference example — composition.md §3.8."
			todos:   [
				"`crm-rest` and `orders-db` are §3.1's example feature names, not part of the pattern: rename them to your own features.",
				"The CADENCE is in neither document. A flow declares no schedule and a capture refuses one (R-6); the deployment or the runner schedules the start.",
				"`mapping/contacts-to-lines` is a pure transform def resolved through the runner's `[env …]` module tree — write it there. A transform step performs no act, opens no connection, reads no store and holds no capability (R-8).",
				"Every value in the deployment binding: the pattern fixes no URL, no backend and no credential handle.",
			]
			files:   {
				"poll-transform-sink.deployment.cxd": "[; poll-transform-sink.deployment.cxd — THE DEPLOYMENT BINDING for composition.md
   §3.1, emitted by cx xap scaffold poll-transform-sink.

   THE SHAPE IS IN THE FEATURE, THE BINDING IS IN THE DEPLOYMENT. Every row
   below is a fact about THIS deployment and none is a fact about the system
   it reaches: the base URL or backend, the credential HANDLE, the budgets and
   the retry envelope. A feature document carrying one of them could not be
   installed twice.

   A CREDENTIAL VALUE IS IN NEITHER DOCUMENT. credential is a HANDLE: it names
   WHERE the value lives, and the value is resolved at the effect point for
   the duration of one request and is never rendered. A value written here
   refuses CXER6310 at validate and again at open.

   THE SPELLING IS A PROPOSAL, NOT A SPECIFICATION'S. connector.md §4.6 says
   WHAT a binding carries and no specification says how it is spelled; the
   shape below is reference/acme/acme.deployment.cxd's, and
   deployment-topology.md §2.1 writes the same facts in the reference
   connectors README proposal. When §4.6 fixes a spelling, follow it.

   EVERY VALUE BELOW IS A TODO. The pattern fixes no URL, no backend, no
   tenant and no handle — and a scaffold guesses none of them
   (connector.md §6.3, RULED: 1430-g). ]
[host tenant='TODO: the tenant this deployment serves'
 [features
  [feature-ref name=crm-rest source='TODO: the path of the source feature package']
  [feature-ref name=orders-db source='TODO: the path of the sink feature package']]
 [connector
  [binding feature=crm-rest gateway=crm-api tenant='TODO: the tenant'
    base-url='TODO: the source base URL for this environment'
    credential='TODO: the credential handle, never a value']
  [binding feature=orders-db gateway=order-store tenant='TODO: the tenant'
    backend='TODO: the sink backend handle for this environment'
    credential='TODO: the credential handle, never a value']]]
"
				"poll-transform-sink.flow.cx": "# poll-transform-sink.flow.cx — the flow document of composition.md §3.1,
# emitted by `cx xap scaffold poll-transform-sink`.
#
# THE NEED. An outside system is read on a cadence, its records are mapped into
# another system's nouns, and the result is written to a sink — without
# either system's declaration learning that the other exists.
#
# SEAMS CROSSED. S-1 (the verbs), S-6 (the transitions), R-8 and R-9 (the transform
# reaches no module's state and is where the mapping lives), R-1 (neither
# feature names `flow`).
#
# WHAT IS DECLARED BELOW is what §3.1 states. What it does not state is a
# TODO and never a guess — the ingest discipline of connector.md §6.3
# (RULED: 1430-g). README.md beside this file lists every one of them.
#
# TODO: rename 'crm-rest' and 'orders-db' to your own features.
# TODO: write 'mapping/contacts-to-lines' as a pure def in the runner's
#       [env …] module tree; a transform step holds no capability.
# TODO: the cadence is the deployment's, not this document's.
[flow name=\"poll-transform-sink\" stall-after=1d
  [args [since::string] [region::string]]
  [step name=\"pull-contacts\"
        [do 'crm-rest/list-contacts' [updated-since \$args/since]]]
  [step name=\"to-order-lines\" needs=\"pull-contacts\"
        [compute 'mapping/contacts-to-lines'
          [contacts \$steps/pull-contacts/result/contact]
          [region \$args/region]]]
  [step name=\"sink-lines\" needs=\"to-order-lines\"
        [do 'orders-db/insert-lines' [lines \$steps/to-order-lines/result/line]]]]
"
			}
		},
		XapScaffoldPattern{
			slug:    "approval-with-pivot"
			section: "§3.2"
			title:   "Approval with pivot and compensation"
			need:    "A sequence in which one step must be admitted by a person, one step cannot be undone, and every step before the irreversible one is reversed automatically when a later step fails."
			modules: "`flow` (the ordering, the offer, the pivot), `authz` (the PEP that admits the approval act), `journal` (the transitions and the compensation entries), the surface (the approval widget and the inbox)."
			seams:   "S-1, S-4, S-5, S-6, S-7; R-12 (the surface reads the record)."
			graded:  "`order-pipeline` — #1472 (reference/connectors/README.md §2.3, cases `order-pipeline-003-approval`, `-004-escalate`, `-006-compensation`, `-007-pivot`)."
			todos:   [
				"COMPENSATION IS NOT IN THIS DOCUMENT: `[compensates]` lives on the command definition, and a failure before the pivot reverses each `:done` step in reverse document order. Declare it there, on every pre-pivot command.",
				"The approval threshold `[> \\\$_/amount 10000]`, the role `role:finance` and the escalation windows are §3.2's example values — yours are a policy decision.",
				"`crm-rest` and `orders-db` are §3.2's example feature names.",
				"Every value in the deployment binding.",
			]
			files:   {
				"approval-with-pivot.deployment.cxd": "[; approval-with-pivot.deployment.cxd — THE DEPLOYMENT BINDING for composition.md
   §3.2, emitted by cx xap scaffold approval-with-pivot.

   THE SHAPE IS IN THE FEATURE, THE BINDING IS IN THE DEPLOYMENT. Every row
   below is a fact about THIS deployment and none is a fact about the system
   it reaches: the base URL or backend, the credential HANDLE, the budgets and
   the retry envelope. A feature document carrying one of them could not be
   installed twice.

   A CREDENTIAL VALUE IS IN NEITHER DOCUMENT. credential is a HANDLE: it names
   WHERE the value lives, and the value is resolved at the effect point for
   the duration of one request and is never rendered. A value written here
   refuses CXER6310 at validate and again at open.

   THE SPELLING IS A PROPOSAL, NOT A SPECIFICATION'S. connector.md §4.6 says
   WHAT a binding carries and no specification says how it is spelled; the
   shape below is reference/acme/acme.deployment.cxd's, and
   deployment-topology.md §2.1 writes the same facts in the reference
   connectors README proposal. When §4.6 fixes a spelling, follow it.

   EVERY VALUE BELOW IS A TODO. The pattern fixes no URL, no backend, no
   tenant and no handle — and a scaffold guesses none of them
   (connector.md §6.3, RULED: 1430-g). ]
[host tenant='TODO: the tenant this deployment serves'
 [features
  [feature-ref name=orders-db source='TODO: the path of the orders feature package']
  [feature-ref name=crm-rest source='TODO: the path of the downstream feature package']]
 [connector
  [binding feature=orders-db gateway=order-store tenant='TODO: the tenant'
    backend='TODO: the orders backend handle for this environment'
    credential='TODO: the credential handle, never a value']
  [binding feature=crm-rest gateway=crm-api tenant='TODO: the tenant'
    base-url='TODO: the downstream base URL for this environment'
    credential='TODO: the credential handle, never a value']]]
"
				"approval-with-pivot.flow.cx": "# approval-with-pivot.flow.cx — the flow document of composition.md §3.2,
# emitted by `cx xap scaffold approval-with-pivot`.
#
# THE NEED. A sequence in which one step must be admitted by a person, one step
# cannot be undone, and every step before the irreversible one is reversed
# automatically when a later step fails.
#
# SEAMS CROSSED. S-1, S-4, S-5, S-6, S-7; R-12 (the surface reads the record).
#
# WHAT IS DECLARED BELOW is what §3.2 states. What it does not state is a
# TODO and never a guess — the ingest discipline of connector.md §6.3
# (RULED: 1430-g). README.md beside this file lists every one of them.
#
# TODO: the threshold, the role and the escalation windows are §3.2's example
#       values — yours are a policy decision.
# TODO: [compensates] lives on each pre-pivot COMMAND definition, never here.
#       A failure before the pivot reverses each :done step in reverse
#       document order; a failure after it is :incomplete and is never
#       compensated.
[flow name=\"approval-with-pivot\" stall-after=1d
  [args [order::string] [amount::decimal]]
  [step name=\"approve-large\" by=:principal to=role:finance
        when=\"\$args[> \$_/amount 10000]\" deadline=1d
        [do 'orders-db/approve-order' [order \$args/order] [amount \$args/amount] [decision]]
        [escalate [notify to=role:finance-lead within=2h]
                  [to role:finance-lead within=4h]]]
  [step name=\"commit-order\" needs=\"approve-large\" pivot=true
        [do 'crm-rest/create-contact' [email \$args/order] [name \$args/order]]]]
"
			}
		},
		XapScaffoldPattern{
			slug:    "async-bulk-export"
			section: "§3.3"
			title:   "Async bulk export"
			need:    "An outside system answers a large read by accepting a job, making the caller wait, and serving a file — three verbs and an ordering, with no verb that requires the ordering."
			modules: "`connector` (the three verbs), `flow` (the ordering and the bounded wait)."
			seams:   "S-1, S-6, S-10; R-1 (the three verbs stand alone)."
			graded:  "No reference example — composition.md §3.8."
			todos:   [
				"`acme` is §3.3's example feature name, and `submit-export` / `poll-export` / `download-export` are its example verbs.",
				"`attempts=20 every=1m` is §3.3's bound, not the vendor's: a bounded re-attempt is admitted only where the verb declares `[idempotent]`, and that claim rests on a person who read the vendor documentation (connector.md §5.4).",
				"This flow supplies the ordering only. An adopter without `flow` orders the same three verbs from a script or a surface — the verbs must not require it (connector.md §12.3, R-1).",
				"Every value in the deployment binding.",
			]
			files:   {
				"async-bulk-export.deployment.cxd": "[; async-bulk-export.deployment.cxd — THE DEPLOYMENT BINDING for composition.md
   §3.3, emitted by cx xap scaffold async-bulk-export.

   THE SHAPE IS IN THE FEATURE, THE BINDING IS IN THE DEPLOYMENT. Every row
   below is a fact about THIS deployment and none is a fact about the system
   it reaches: the base URL or backend, the credential HANDLE, the budgets and
   the retry envelope. A feature document carrying one of them could not be
   installed twice.

   A CREDENTIAL VALUE IS IN NEITHER DOCUMENT. credential is a HANDLE: it names
   WHERE the value lives, and the value is resolved at the effect point for
   the duration of one request and is never rendered. A value written here
   refuses CXER6310 at validate and again at open.

   THE SPELLING IS A PROPOSAL, NOT A SPECIFICATION'S. connector.md §4.6 says
   WHAT a binding carries and no specification says how it is spelled; the
   shape below is reference/acme/acme.deployment.cxd's, and
   deployment-topology.md §2.1 writes the same facts in the reference
   connectors README proposal. When §4.6 fixes a spelling, follow it.

   EVERY VALUE BELOW IS A TODO. The pattern fixes no URL, no backend, no
   tenant and no handle — and a scaffold guesses none of them
   (connector.md §6.3, RULED: 1430-g). ]
[host tenant='TODO: the tenant this deployment serves'
 [features
  [feature-ref name=acme source='TODO: the path of the exporting feature package']]
 [connector
  [binding feature=acme gateway=acme-api tenant='TODO: the tenant'
    base-url='TODO: the vendor base URL for this environment'
    credential='TODO: the credential handle, never a value']]]
"
				"async-bulk-export.flow.cx": "# async-bulk-export.flow.cx — the flow document of composition.md §3.3,
# emitted by `cx xap scaffold async-bulk-export`.
#
# THE NEED. An outside system answers a large read by accepting a job, making the
# caller wait, and serving a file — three verbs and an ordering, with no
# verb that requires the ordering.
#
# SEAMS CROSSED. S-1, S-6, S-10; R-1 (the three verbs stand alone).
#
# WHAT IS DECLARED BELOW is what §3.3 states. What it does not state is a
# TODO and never a guess — the ingest discipline of connector.md §6.3
# (RULED: 1430-g). README.md beside this file lists every one of them.
#
# TODO: 'acme' and its three verbs are §3.3's example names.
# TODO: attempts= and every= are a bound on the WAIT, admitted only where the
#       polled verb declares [idempotent]. Read the vendor's documentation and
#       declare it there, or drop the bound.
#
# This is the case that LOOKS like a dependency on flow and is not: the flow
# supplies the ordering and the bounded wait, and an adopter without flow
# orders the same three verbs from a script or a surface.
[flow name=\"async-bulk-export\" stall-after=1d
  [args [tenant::string]]
  [step name=\"submit\" [do 'acme/submit-export' [tenant \$args/tenant]]]
  [until name=\"await-export\" needs=\"submit\" when=\"\$steps/poll-export/result/@ready\"
         attempts=20 every=1m
    [step name=\"poll-export\"
          [do 'acme/poll-export' [job \$steps/submit/result/job]]]]
  [step name=\"download\" needs=\"await-export\"
        [do 'acme/download-export' [job \$steps/submit/result/job]]]]
"
			}
		},
		XapScaffoldPattern{
			slug:    "inbound-webhook"
			section: "§3.4"
			title:   "Inbound webhook"
			need:    "An outside system pushes; the deployment verifies the signature, refuses a replay, answers back-pressure with a `429` and a `Retry-After`, and records each accepted delivery exactly once."
			modules: "`connector` (the `kind=webhook` adapter, the credential chain run in the verify direction, the budget arithmetic run in reverse), `http` (the mount), `journal` (the landing), `audit` (the record)."
			seams:   "S-9, S-10, S-11, S-12, S-24; R-7 (the bytes are `http`'s)."
			graded:  "`inbound-webhook` — #1468 (reference/connectors/README.md §2.7)."
			todos:   [
				"The NOUNS this feature records: §3.4 fixes none. One `[noun]` per record kind, one `[field]` per property.",
				"The VERBS. A webhook feature records a delivery; the verb that does so is yours to declare, with its own idempotency claim — connector.md §5.4 requires a person to make that claim and neither the ingester nor this scaffold infers it.",
				"`/hooks/orders`, `X-Signature` and `/delivery_id` are §3.4's example route, header and delivery-id path.",
				"The VERIFICATION KEY is a credential handle in the deployment binding and a value in neither document (connector.md §4.6).",
			]
			files:   {
				"inbound-webhook.deployment.cxd": "[; inbound-webhook.deployment.cxd — THE DEPLOYMENT BINDING for composition.md
   §3.4, emitted by cx xap scaffold inbound-webhook.

   THE SHAPE IS IN THE FEATURE, THE BINDING IS IN THE DEPLOYMENT. Every row
   below is a fact about THIS deployment and none is a fact about the system
   it reaches: the base URL or backend, the credential HANDLE, the budgets and
   the retry envelope. A feature document carrying one of them could not be
   installed twice.

   A CREDENTIAL VALUE IS IN NEITHER DOCUMENT. credential is a HANDLE: it names
   WHERE the value lives, and the value is resolved at the effect point for
   the duration of one request and is never rendered. A value written here
   refuses CXER6310 at validate and again at open.

   THE SPELLING IS A PROPOSAL, NOT A SPECIFICATION'S. connector.md §4.6 says
   WHAT a binding carries and no specification says how it is spelled; the
   shape below is reference/acme/acme.deployment.cxd's, and
   deployment-topology.md §2.1 writes the same facts in the reference
   connectors README proposal. When §4.6 fixes a spelling, follow it.

   EVERY VALUE BELOW IS A TODO. The pattern fixes no URL, no backend, no
   tenant and no handle — and a scaffold guesses none of them
   (connector.md §6.3, RULED: 1430-g). ]
[host tenant='TODO: the tenant this deployment serves'
 [features
  [feature-ref name=inbound-webhook source='TODO: the path of this feature package']]
 [connector
  [binding feature=inbound-webhook gateway=hook tenant='TODO: the tenant'
    mount='TODO: the http mount this route is served under'
    credential='TODO: the verification key handle, never a value']]]
"
				"inbound-webhook.feature.cxd": "[; inbound-webhook.feature.cxd — the feature and gateway declarations of
   composition.md §3.4, emitted by cx xap scaffold inbound-webhook.

   THE NEED. An outside system pushes; the deployment verifies the signature,
   refuses a replay, answers back-pressure with a `429` and a
   `Retry-After`, and records each accepted delivery exactly once.

   SEAMS CROSSED. S-9, S-10, S-11, S-12, S-24; R-7 (the bytes are `http`'s).

   WHAT IS DECLARED BELOW is what §3.4 states. What it does not state is
   a TODO and never a guess — the ingest discipline of connector.md §6.3
   (RULED: 1430-g). README.md beside this file lists every one of them.

   THE SHAPE IS HERE, THE BINDING IS IN THE DEPLOYMENT. No base-url, no
   backend handle and no credential value belongs in this document: they are
   facts about a deployment, and a feature document carrying one could not be
   installed twice. ]
[feature name=inbound-webhook version=\"1\"
 [summary 'TODO: one sentence naming the system that pushes to this route.']

 [; TODO: the NOUNS this feature records. One noun per record kind, one field
    per property. §3.4 fixes none of them. ]

 [; TODO: the VERBS. A webhook feature records a delivery; the verb that does
    so is yours to declare, with its own idempotency claim. That claim rests
    on a person who read the vendor documentation, per connector.md §5.4 —
    neither the ingester nor this scaffold infers it. ]

 [; TODO: the route, the signature header and the delivery-id path below are
    §3.4's example values. The verification KEY is a credential handle in the
    deployment binding and a value in neither document. ]
 [source
  [gateway name=hook kind=webhook priority=1 signing=hmac-sha256-header rung=snapshot-diff
    doc='the inbound route; the deployment mounts it and binds the verification key'
    [route path='/hooks/orders' method=post]
    [verify header='X-Signature' over=raw-body replay-window=5m
            delivery-id='/delivery_id' dedup=content-address]]]]
"
			}
		},
		XapScaffoldPattern{
			slug:    "fan-out-over-a-bus"
			section: "§3.5"
			title:   "Fan-out over a bus"
			need:    "One committed act is delivered to consumers that the producer does not name, durably, with each consumer group keeping its own position."
			modules: "`fabric` (the delivery layer, both planes), `connector` (the `kind=bus` adapter), `flow` (the publish and the confirmation), `journal` (the durable plane)."
			seams:   "S-3, S-11, S-23, S-24; R-7."
			graded:  "`order-pipeline` — #1472 (reference/connectors/README.md §2.3, case `order-pipeline-005-bus-round-trip`), which grades one publish and one consume over `kind=bus`. Fan-out across more than one consumer group is graded by `fabric`'s own conformance corpus and by no reference example."
			todos:   [
				"§3.5 states ONE publish step, not a whole document: the flow around it — its name, its `stall-after`, its arguments and the steps `publish-order` waits on — is yours.",
				"The gateway declares only the core attributes (`name=`, `kind=`, `priority=`, `auth=`, `rung=`). Everything kind-specific is the ADAPTER's and is declared by it, never hard-coded (RULED: 1430-d).",
				"WHICH fabric: the deployment binds an embedded fabric in one environment and the bridge in another. That is a binding fact, not a declaration fact.",
				"Every value in the deployment binding.",
			]
			files:   {
				"fan-out-over-a-bus.deployment.cxd": "[; fan-out-over-a-bus.deployment.cxd — THE DEPLOYMENT BINDING for composition.md
   §3.5, emitted by cx xap scaffold fan-out-over-a-bus.

   THE SHAPE IS IN THE FEATURE, THE BINDING IS IN THE DEPLOYMENT. Every row
   below is a fact about THIS deployment and none is a fact about the system
   it reaches: the base URL or backend, the credential HANDLE, the budgets and
   the retry envelope. A feature document carrying one of them could not be
   installed twice.

   A CREDENTIAL VALUE IS IN NEITHER DOCUMENT. credential is a HANDLE: it names
   WHERE the value lives, and the value is resolved at the effect point for
   the duration of one request and is never rendered. A value written here
   refuses CXER6310 at validate and again at open.

   THE SPELLING IS A PROPOSAL, NOT A SPECIFICATION'S. connector.md §4.6 says
   WHAT a binding carries and no specification says how it is spelled; the
   shape below is reference/acme/acme.deployment.cxd's, and
   deployment-topology.md §2.1 writes the same facts in the reference
   connectors README proposal. When §4.6 fixes a spelling, follow it.

   EVERY VALUE BELOW IS A TODO. The pattern fixes no URL, no backend, no
   tenant and no handle — and a scaffold guesses none of them
   (connector.md §6.3, RULED: 1430-g). ]
[host tenant='TODO: the tenant this deployment serves'
 [features
  [feature-ref name=order-events source='TODO: the path of the bus feature package']]
 [connector
  [binding feature=order-events gateway=order-events tenant='TODO: the tenant'
    fabric='TODO: the fabric this environment binds — an embedded fabric in one, the bridge in another'
    credential='TODO: the credential handle, never a value']]]
"
				"fan-out-over-a-bus.feature.cxd": "[; fan-out-over-a-bus.feature.cxd — the feature and gateway declarations of
   composition.md §3.5, emitted by cx xap scaffold fan-out-over-a-bus.

   THE NEED. One committed act is delivered to consumers that the producer does not
   name, durably, with each consumer group keeping its own position.

   SEAMS CROSSED. S-3, S-11, S-23, S-24; R-7.

   WHAT IS DECLARED BELOW is what §3.5 states. What it does not state is
   a TODO and never a guess — the ingest discipline of connector.md §6.3
   (RULED: 1430-g). README.md beside this file lists every one of them.

   THE SHAPE IS HERE, THE BINDING IS IN THE DEPLOYMENT. No base-url, no
   backend handle and no credential value belongs in this document: they are
   facts about a deployment, and a feature document carrying one could not be
   installed twice. ]
[feature name=order-events version=\"1\"
 [summary 'TODO: one sentence naming what this bus carries.']

 [; TODO: the NOUNS carried on the bus, and the publish and consume VERBS.
    §3.5 fixes neither. A consume verb that a bounded re-attempt may retry
    declares idempotent — a person makes that claim, not this scaffold. ]

 [; TODO: order-events is §3.5's example feature name.
    The gateway declares only the core attributes — name, kind, priority,
    auth and rung. Everything kind-specific is the ADAPTER's and is declared
    by it, never hard-coded in the engine (RULED: 1430-d). ]
 [source
  [gateway name=order-events kind=bus priority=1 auth=none rung=snapshot-diff
    doc='the deployment binds an embedded fabric in one environment and the bridge in another']]]
"
				"fan-out-over-a-bus.flow.cx": "# fan-out-over-a-bus.flow.cx — the flow document of composition.md §3.5,
# emitted by `cx xap scaffold fan-out-over-a-bus`.
#
# THE NEED. One committed act is delivered to consumers that the producer does not
# name, durably, with each consumer group keeping its own position.
#
# SEAMS CROSSED. S-3, S-11, S-23, S-24; R-7.
#
# WHAT IS DECLARED BELOW is what §3.5 states. What it does not state is a
# TODO and never a guess — the ingest discipline of connector.md §6.3
# (RULED: 1430-g). README.md beside this file lists every one of them.
#
# §3.5 states ONE STEP, not a whole document. The [flow] around it is a
# TODO in every part the pattern does not fix:
#
# TODO: stall-after= — the pattern fixes no bound.
# TODO: [args …] — the arguments this flow starts with.
# TODO: the steps that precede the publish. needs=\"approve-large\" is §3.5's
#       example predecessor, kept so the shape is visible; name your own.
[flow name=\"fan-out-over-a-bus\"
  [step name=\"publish-order\" needs=\"approve-large\"
        [do 'order-events/publish' [order \$args/order] [tenant \$args/tenant]]]]
"
			}
		},
		XapScaffoldPattern{
			slug:    "incremental-sync"
			section: "§3.6"
			title:   "Incremental sync into a store"
			need:    "A source is read repeatedly without re-reading what has not changed, resumably across a restart, with each record landing exactly once."
			modules: "`sync` (the cursor, the watermark, the dedup index), `connector` (the walk beneath it), `store` (the watermark and the index), `journal` (the deltas), `live` (the view over them)."
			seams:   "S-13, S-15, S-16, S-17, S-18, S-25; R-2 and R-6 (no run and no cadence in the declaration)."
			graded:  "`orders-db` — #1467 (reference/connectors/README.md §2.2, §1.2's `sync` column)."
			todos:   [
				"THERE IS NO SCHEDULE HERE AND THERE WILL NOT BE ONE: a capture declares no `every=`, no `cron=` and no `interval=`, and an attribute naming a cadence refuses CXER6416 (R-6). The deployment owns the cadence.",
				"`key='/id'` and `version='/updated_at'` are §3.6's example paths into the source's records; `overlap=5m` is its example clock skew.",
				"`deletes=unobservable` is a claim about the SOURCE: change it only if the source actually reports deletions.",
				"The NOUNS and VERBS of the feature this `[source]` belongs to.",
			]
			files:   {
				"incremental-sync.deployment.cxd": "[; incremental-sync.deployment.cxd — THE DEPLOYMENT BINDING for composition.md
   §3.6, emitted by cx xap scaffold incremental-sync.

   THE SHAPE IS IN THE FEATURE, THE BINDING IS IN THE DEPLOYMENT. Every row
   below is a fact about THIS deployment and none is a fact about the system
   it reaches: the base URL or backend, the credential HANDLE, the budgets and
   the retry envelope. A feature document carrying one of them could not be
   installed twice.

   A CREDENTIAL VALUE IS IN NEITHER DOCUMENT. credential is a HANDLE: it names
   WHERE the value lives, and the value is resolved at the effect point for
   the duration of one request and is never rendered. A value written here
   refuses CXER6310 at validate and again at open.

   THE SPELLING IS A PROPOSAL, NOT A SPECIFICATION'S. connector.md §4.6 says
   WHAT a binding carries and no specification says how it is spelled; the
   shape below is reference/acme/acme.deployment.cxd's, and
   deployment-topology.md §2.1 writes the same facts in the reference
   connectors README proposal. When §4.6 fixes a spelling, follow it.

   EVERY VALUE BELOW IS A TODO. The pattern fixes no URL, no backend, no
   tenant and no handle — and a scaffold guesses none of them
   (connector.md §6.3, RULED: 1430-g). ]
[host tenant='TODO: the tenant this deployment serves'
 [features
  [feature-ref name=orders-db source='TODO: the path of the source feature package']]
 [connector
  [binding feature=orders-db gateway=orders-db tenant='TODO: the tenant'
    backend='TODO: the source backend handle for this environment'
    credential='TODO: the credential handle, never a value']]]
"
				"incremental-sync.feature.cxd": "[; incremental-sync.feature.cxd — the feature and gateway declarations of
   composition.md §3.6, emitted by cx xap scaffold incremental-sync.

   THE NEED. A source is read repeatedly without re-reading what has not changed,
   resumably across a restart, with each record landing exactly once.

   SEAMS CROSSED. S-13, S-15, S-16, S-17, S-18, S-25; R-2 and R-6 (no run and no cadence
   in the declaration).

   WHAT IS DECLARED BELOW is what §3.6 states. What it does not state is
   a TODO and never a guess — the ingest discipline of connector.md §6.3
   (RULED: 1430-g). README.md beside this file lists every one of them.

   THE SHAPE IS HERE, THE BINDING IS IN THE DEPLOYMENT. No base-url, no
   backend handle and no credential value belongs in this document: they are
   facts about a deployment, and a feature document carrying one could not be
   installed twice. ]
[feature name=orders-db version=\"1\"
 [summary 'TODO: one sentence naming the source this feature reads.']

 [; TODO: the NOUNS this source yields and the VERBS that read them. §3.6
    fixes neither. ]

 [; THERE IS NO SCHEDULE HERE AND THERE WILL NOT BE ONE. A capture declares
    no every, no cron and no interval, and an attribute naming a cadence
    refuses CXER6416. The deployment owns the cadence; sync owns the
    watermark.

    TODO: key and version are §3.6's example paths into a record, overlap is
    its example clock skew, and deletes=unobservable is a claim about THIS
    source — change it only if the source actually reports deletions. ]
 [source
  [gateway name=orders-db kind=db priority=1 auth=basic rung=snapshot-diff
    [paginate style=cursor max-pages=50 path='/id' param=cursor]
    [capture mode=polling-diff kind=instant key='/id' version='/updated_at'
             since-param=since overlap=5m deletes=unobservable]]]]
"
			}
		},
		XapScaffoldPattern{
			slug:    "agent-surface"
			section: "§3.7"
			title:   "Agent surface over verbs"
			need:    "An agent is given a system's verbs as described tools, decides what to do, and never sees or argues with how it is done."
			modules: "the feature's grammar (the verbs), `x/tools` (the projection), `authz` (the PEP at the effect point), the `xap` host (the serving surface)."
			seams:   "S-12, S-26, S-27, S-28; R-14 (an agent cannot reach a host the deployment did not bind)."
			graded:  "`crm-rest` — #1466 (reference/connectors/README.md §1.2's agent-surface column: six verbs project as six tool descriptors, and a verb without a `[summary]` refuses CXER6325 before an agent sees it)."
			todos:   [
				"EVERY verb needs a `[summary]`: it becomes the tool descriptor's description, and a verb without one refuses CXER6325 where the author is looking, before an agent sees it.",
				"The `[intent]` slots become the tool's input schema — name every slot the verb actually takes.",
				"`effect=` decides `read-only` on the descriptor. An act verb also needs its own idempotency claim, made by a person (connector.md §5.4).",
				"`list-contacts`, `contact` and `acme-api` are §3.7's example verb, noun and gateway.",
			]
			files:   {
				"agent-surface.deployment.cxd": "[; agent-surface.deployment.cxd — THE DEPLOYMENT BINDING for composition.md
   §3.7, emitted by cx xap scaffold agent-surface.

   THE SHAPE IS IN THE FEATURE, THE BINDING IS IN THE DEPLOYMENT. Every row
   below is a fact about THIS deployment and none is a fact about the system
   it reaches: the base URL or backend, the credential HANDLE, the budgets and
   the retry envelope. A feature document carrying one of them could not be
   installed twice.

   A CREDENTIAL VALUE IS IN NEITHER DOCUMENT. credential is a HANDLE: it names
   WHERE the value lives, and the value is resolved at the effect point for
   the duration of one request and is never rendered. A value written here
   refuses CXER6310 at validate and again at open.

   THE SPELLING IS A PROPOSAL, NOT A SPECIFICATION'S. connector.md §4.6 says
   WHAT a binding carries and no specification says how it is spelled; the
   shape below is reference/acme/acme.deployment.cxd's, and
   deployment-topology.md §2.1 writes the same facts in the reference
   connectors README proposal. When §4.6 fixes a spelling, follow it.

   EVERY VALUE BELOW IS A TODO. The pattern fixes no URL, no backend, no
   tenant and no handle — and a scaffold guesses none of them
   (connector.md §6.3, RULED: 1430-g). ]
[host tenant='TODO: the tenant this deployment serves'
 [features
  [feature-ref name=crm-rest source='TODO: the path of the feature package whose verbs an agent is given']]
 [connector
  [binding feature=crm-rest gateway=acme-api tenant='TODO: the tenant'
    base-url='TODO: the vendor base URL for this environment'
    credential='TODO: the credential handle, never a value']]]
"
				"agent-surface.feature.cxd": "[; agent-surface.feature.cxd — the feature and gateway declarations of
   composition.md §3.7, emitted by cx xap scaffold agent-surface.

   THE NEED. An agent is given a system's verbs as described tools, decides what to
   do, and never sees or argues with how it is done.

   SEAMS CROSSED. S-12, S-26, S-27, S-28; R-14 (an agent cannot reach a host the
   deployment did not bind).

   WHAT IS DECLARED BELOW is what §3.7 states. What it does not state is
   a TODO and never a guess — the ingest discipline of connector.md §6.3
   (RULED: 1430-g). README.md beside this file lists every one of them.

   THE SHAPE IS HERE, THE BINDING IS IN THE DEPLOYMENT. No base-url, no
   backend handle and no credential value belongs in this document: they are
   facts about a deployment, and a feature document carrying one could not be
   installed twice. ]
[feature name=crm-rest version=\"1\"
 [summary 'TODO: one sentence naming the system whose verbs an agent is given.']

 [; TODO: the NOUNS. list-contacts reads a contact below; declare that noun
    with one field per property. ]

 [; EVERY VERB NEEDS A SUMMARY. The tool descriptor an agent sees is the
    projection: name is the qualified verb, description is the verb's summary,
    the input schema comes from the intent slots, and read-only is
    effect = observe. A verb with no summary refuses CXER6325 where the author
    is looking, before an agent ever sees it.

    The agent sees a tool with a schema and never a gateway, a cursor, a token
    or a Retry-After. Every annotation it sees is a hint; enforcement is the
    PEP's and the effect point's.

    TODO: list-contacts, contact and acme-api are §3.7's example names, and an
    act verb needs its own idempotency claim, made by a person. ]
 [verbs
  [verb name=list-contacts effect=observe via=acme-api
   [summary 'List the contacts the tenant can see.']
   [intent [do :list-contacts [updated-since]]]
   [reads contact]]]]
"
			}
		},
	]
}
