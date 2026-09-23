#!/bin/sh
# SSO + flow + XAP, composed — one component's output is the next one's
# input, which is the only thing that makes this a composition rather than
# three examples in a row.
#
#   1. actor.cx runs an OpenID Connect login against the in-tree mock
#      identity provider and answers the principal it established.
#   2. that principal becomes the flow run's --actor, so the run id is the
#      content address over (the document, THAT principal, the args) and the
#      record names who the work was done for.
#   3. the XAP wiring layer is what governs the same domain in a deployment:
#      the grammar the features joined, and the authority that admits an act.
#
# `cx` renders a string VALUE with its quotes, which is correct for a value
# and wrong for a shell variable, so step 1's answer is unquoted here in the
# open rather than by a flag that does not exist.
# The flow run's --allow-read names the flow checkout example because
# `order.env.cx` takes its `orders.cx` as a path-form `[?lib]` — and a
# path-form module read off disk charges `read`, judged by the granted roots
# (#1539, RULED: 1061-a (5)). Since the flow extraction (RULED: RS-12) that
# example is cx-platform-flow's and is read out of the checkout deps.cxd pins,
# so the root is `deps/cx-platform-flow/examples/platform/flow` — the narrowest
# that covers it, and narrower than the `examples/platform` it replaced.
#
# actor.cx needs a SECOND root, and the reason is the extraction (RULED:
# RS-12): the mock identity provider it imports is cx-platform-sso's now, so
# it is read out of the checkout deps.cxd pins. The grant names that checkout
# exactly — `deps/cx-platform-sso/examples/platform/sso` — and nothing wider.
# Two roots rather than one repo-root grant, because the whole point of a
# granted root is that it is the narrowest one that covers the read.
set -u
CX="${CX:-cx}"

echo '$ cx --allow-read=../.. --allow-read=../../../../deps/cx-platform-sso/examples/platform/sso actor.cx'
"$CX" --allow-read=../.. --allow-read=../../../../deps/cx-platform-sso/examples/platform/sso actor.cx; rc=$?
echo
echo "exit=$rc"

ACTOR=$("$CX" --allow-read=../.. --allow-read=../../../../deps/cx-platform-sso/examples/platform/sso actor.cx | tr -d "'")
echo
echo "# the principal the login established, unquoted for the command line:"
echo "ACTOR=$ACTOR"

echo
echo '$ cx flow run ../../../../deps/cx-platform-flow/examples/platform/flow/checkout/checkout.flow.cx --env order.env.cx --ephemeral --actor="$ACTOR" --sku=SKU-88 --qty=3 --unit=9.50 --allow-read=../../../../deps/cx-platform-flow/examples/platform/flow'
"$CX" flow run ../../../../deps/cx-platform-flow/examples/platform/flow/checkout/checkout.flow.cx --env order.env.cx --ephemeral \
      --actor="$ACTOR" --sku=SKU-88 --qty=3 --unit=9.50 --allow-read=../../../../deps/cx-platform-flow/examples/platform/flow; rc=$?
echo "exit=$rc"

echo
echo '$ cx --allow-read ../../xap/storefront/compose.cx'
( cd ../../xap/storefront && "$CX" --allow-read compose.cx ); rc=$?
echo
echo "exit=$rc"
