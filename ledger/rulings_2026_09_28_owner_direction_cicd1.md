# Owner direction 2026-09-28 (morning) — documentation generation in the cx-flow CI/CD (CICD-1)

**Status: RULED (owner, 2026-09-28 ~08:3xZ, in session; recorded from the integrator's CICD-1
brief, which quotes the owner's words; CXF-1, INT-10, D83a, SITE-1).** The owner's direction was
given with the docs redo it accompanies; the page of 11:5xZ (Letters 71 to 79) already names "the
CICD-1 flow document" as where the steps its decisions add are carried. This page declares the id
that page and the branch cite. It records a direction; the design choices under it are the branch's
and are listed in its evidence, not ruled here.

## The owner's word, as the brief quotes it

"make sure the doc gen is part of our cx flow based cicd. That needs to be a really clean simple
process"

## CICD-1 — every generated document is made, checked and assembled by one cx flow document

Documentation generation is one flow document run by `cx flow run` — generate, then check, then
assemble the site — and the same document is what the developer's regeneration, the post-merge doc
pipeline and the public site's workflow run, each through one make target. The generators and the
checks stay make targets underneath, graded by the full post-merge run as before; the flow is the
one order, the one run record and the one place a failure is read.
