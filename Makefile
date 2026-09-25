# ── v0.8.0 CX Data Language Guide ─────────────────────────────── BEGIN gen_guide
# Makes `make guide` first-class. Renders
# docs-src/canonical/manifest.cxd + sections/*.cxd into docs/guide/.
# When the v0.8.0 cx binary is not yet runnable, the target stages
# chrome + assets and falls back to source-as-body pages — see
# scripts/gen_guide/README.md for the full pipeline.
-include scripts/gen_guide/guide.mk
# ── v0.8.0 CX Data Language Guide ───────────────────────────────── END gen_guide

# ── LLM onboarding layer (#938) ──────────────────────────────────── BEGIN gen_docs
# Makes `make docs` / `make docs-check` first-class. Renders docs-src/llm/
# templates into docs/llm/ (primer.md, reference-*.md, llms.txt,
# llms-full.txt), pulling every example from a conformance fixture and
# re-recording its output from the live binary. `make docs-check` is the drift
# gate (in TEST_TARGETS + tools/release-verify.sh).
-include scripts/gen_docs/docs.mk
# ── LLM onboarding layer (#938) ────────────────────────────────────── END gen_docs

# ── cxhome.org, the one site (RULED: RS-28, D57a, D58a, RS-30, D86b) ─── BEGIN gen_site
# `make site` assembles site/ from the guide, the landing page and the LLM layer;
# `make site-check` lists it against docs-src/site/manifest.cxd (in TEST_TARGETS);
# `make site-index` renders the landing page, docs/index.html, which `make docs`
# and `make docs-check` also run. .github/workflows/site.yml deploys site/.
-include scripts/gen_site/site.mk
# ── cxhome.org, the one site ─────────────────────────────────────────── END gen_site

# Prefer the patched V toolchain (third_party/v/v) for EVERY recipe that
# invokes `v`. It carries the macOS hardened-runtime libgc / -prod fixes and
# the picoev shared-listener patch (`new_with_listen_fd`) the http
# multi-reactor code needs to compile. Without this, recipes that invoke a
# bare `v` (e.g. `make test-vcx-suite`) pick whatever is first on PATH — under
# devbox that is the unpatched /usr/local/bin/v, which fails to compile the
# `code` module on the http branch. Prepending the submodule dir makes bare
# `v` resolve to the patched binary; if the submodule isn't built yet the dir
# simply contains no `v` and PATH falls through to the system V (the
# documented degraded fallback). Mirrors vcx/Makefile's `V := …/third_party/v/v`.
export PATH := $(CURDIR)/third_party/v:$(PATH)

# #1227 — the nixpkgs clang wrapper's `fortify` hardening PREPENDS -O2 to any
# compile that carries no -O of its own. V's dev builds carry none, so under
# devbox every non-prod build here (the `v test` steps, the *-dev libraries,
# the harness runners) was a full -O2 optimisation of a multi-MB generated TU:
# 22.3 s vs 3.6 s on the SAME generated file with fortify off — the undiagnosed
# cause of dead-end D3 in ledger/dead_ends_700_test_duration.md. -prod builds
# pass -O3/-Os explicitly and an explicit -O wins, so they are unaffected; the
# linux step (plain gcc) was already -O0. Same compiler, same nix store, same
# lockfile — one flag. Guarded on the variable being DEFINED so a non-nix shell
# is untouched (to the wrapper an EMPTY value means "all hardening off").
ifneq ($(origin NIX_HARDENING_ENABLE),undefined)
export NIX_HARDENING_ENABLE := $(filter-out fortify fortify3,$(NIX_HARDENING_ENABLE))
endif

# Explicit handle on the patched V toolchain. The PATH export above is meant to
# make a bare `v` resolve to third_party/v/v, but `v test` recipes have been
# observed re-resolving to the system V (e.g. /usr/local/bin/v) — under which
# the http branch's `code` module fails to compile (it calls the patched
# builtin's cx_region_* / picoev helpers). Recipes that MUST use the patched
# toolchain reference $(V) directly. Mirrors vcx/Makefile's V definition; falls
# back to a bare `v` when the submodule binary isn't built yet.
V := $(if $(wildcard $(CURDIR)/third_party/v/v),$(CURDIR)/third_party/v/v,v)

# #1344 — CLOSE THE JOBSERVER BEFORE RUNNING A TEST BINARY.
#
# Under `-j`, make hands its jobserver pipe to every recipe as fds 3/4 (plus
# dups 5/6), and ANYTHING a recipe spawns inherits them. The process tests
# background `sh -c 'sleep 3600'` as their hung-child fixture and the http
# steps background `cx-dev` servers; when one outlives its step it keeps the
# jobserver open, and the next parallel make in the gate blocks at make's exit
# -- alive, 0% CPU, no children, no output, no timeout. It reads as a slow
# suite. Measured 2026-09-06: a full gate sat wedged AFTER `vcx/tests` had
# reported 62/62 green; profile_gate.v records a 3.5-hour instance.
#
# Verified with a toy Makefile: a backgrounded child inheriting the fds wedges
# `make -j4` even with its stdout on /dev/null and every target already built;
# the SAME leak with fds 3-6 closed completes rc=0. Closing them is a complete
# fix, not a mitigation -- the child may still leak, it just cannot hold make
# hostage.
#
# ONLY for recipes that run a test BINARY. A recipe that invokes a sub-make
# must KEEP fds 3/4, or that make drops to -j1 with "jobserver unavailable"
# and the parallel build silently serializes.
# JS_CLOSE — close GNU make's jobserver descriptors before running a TEST
# BINARY, so a child the test leaks cannot hold them.
#
# #1344 established the mechanism: fd INHERITANCE ALONE is sufficient to wedge
# a later parallel make at 0% CPU with no children and no timeout — no lost
# token, no killed job and no stray signal are needed. #1057 is the same wedge
# on the FAILURE path, and it reproduces in 40 seconds with a four-line toy: a
# `-j4` make with one failing step plus one leaked fd-inheriting child hangs on
# "Waiting for unfinished jobs...." until a timeout kills it, while the
# identical toy with these fds closed exits 2 promptly with the real red.
# Measured 2026-09-07, both directions.
#
# NEVER put this on a recipe that invokes a SUB-MAKE: that make would drop to
# -j1 with "jobserver unavailable" and the parallel build would silently
# serialize.
#
# Applied to every step that runs a test binary, not only the three that had a
# known leak, because the wedge's victim is the NEXT make rather than the step
# that leaked — so "this step has no server fixture today" is not a property
# worth betting a 90-minute gate on.
# #1542: the `2>/dev/null` is SCOPED to the closes with a brace group. Written
# as `exec 3<&- … 2>/dev/null`, a bare `exec` with only redirections applies
# them to the SHELL, permanently — so every recipe carrying JS_CLOSE ran with
# its stderr pointed at /dev/null for the rest of the line, and every
# diagnostic after it was lost. Measured:
#
#   sh -c 'exec 3<&- 4<&- 5<&- 6<&- 2>/dev/null || true; echo x >&2'   → nothing
#   sh -c '{ exec 3<&- 4<&- 5<&- 6<&- ; } 2>/dev/null || true; echo x >&2' → x
#
# The group's redirect lasts only for the group, while `exec`'s fd closes are
# the shell's and outlive it — so the "bad file descriptor" noise the redirect
# exists to swallow is still swallowed, and the recipe keeps its stderr. Under
# `SHELL='sh -x'` the difference is the whole trace of every test step: the
# nested-make hunt of #1520 could see nothing past this line.
JS_CLOSE := { exec 3<&- 4<&- 5<&- 6<&- ; } 2>/dev/null || true;

# cx-core-data's pinned checkout (RULED: RS-7, RS-12): its V modules are
# compiled from here through -path (CX_V_SEARCH, beside DEPS_CX) and its
# data-language corpus, fixtures/ and the vcx/cx and vcx/fixtures in-module
# tests are graded from here. None of it is tracked in this tree; deps.cxd
# names the sha and deps-present refuses a tree without it.
CXD := deps/cx-core-data
CONFORMANCE_CORE := $(CXD)/conformance/core.cxd
CONFORMANCE_EXT := $(CXD)/conformance/extended.cxd
CONFORMANCE_XML := $(CXD)/conformance/xml.cxd
CONFORMANCE_MD := $(CXD)/conformance/md.cxd

LIB_NAME := libcx
VCX_DYLIB := deps/cx-core-code/vcx/target/$(LIB_NAME).dylib
VCX_SO := deps/cx-core-code/vcx/target/$(LIB_NAME).so
DIST_DIR := dist
PREFIX ?= /usr/local

UNAME_S := $(shell uname -s)

# ── Python / Go toolchain paths ──────────────────────────────────────────────
# Python: prefer a modern interpreter when the default python3 is too old
# (Xcode ships 3.9; the binding + emscripten need >= 3.10).
PYTHON ?= $(shell if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then echo python3; elif [ -x /opt/homebrew/bin/python3 ]; then echo /opt/homebrew/bin/python3; else echo python3; fi)

.PHONY: all build build-wasm build-playground build-vcx build-vcx-dev build-lib build-lib-arrow \
 build-vscode \
 publish-org \
 release-all \
 dist install uninstall install-cli uninstall-cli verify-cli promote-cli \
 test test-no-parallel test-vcx \
 test-vcx-stream \
 test-xpath-parity test-xpath-parity-cx \
 abi-c-test \
 conform conform-vcx conform-md bench bench-streaming bench-cxparse \
 bench-code-pattern-compile bench-code-streaming bench-code-http bench-code-gates \
 bench-lazy-ceiling \
 bench-streamed-alloc \
 clean

all: build

# ── Build ──────────────────────────────────────────────────────────────────────

# The four active bindings (V, Python, Go, Rust) left cx-private whole
# (RULED: RS-12, RS-8; #1591 item K3): cx-home/cx-binding-{python,go,rust,v}.
# cx does not consume them (no deps.cxd row), so their build/test targets
# retire from this Makefile with them; only libcx/the V build stay.
build: build-vcx


# ── Gate lock (#1339 follow-up, owner-authorized 2026-09-06) ─────────────────
#
# "No builds anywhere while a gate runs" was a standing rule and it was broken
# on 2026-09-06 by a session that had NO WAY TO KNOW a gate was running: two
# `make build-vcx` runs in sibling worktrees landed inside a full `make test`,
# which then deadlocked. Etiquette cannot carry a machine-wide invariant across
# independent sessions, so this makes it mechanical.
#
# MACHINE-wide, not repo-wide, deliberately: every worktree shares one V
# toolchain and one CPU budget, so a build in ANY of them perturbs a gate in
# ANY other. /tmp is the only location all of them agree on.
#
# The lock records the owning PID. `make test` exports CX_GATE_OWNER, which
# recursive sub-makes INHERIT — that is what lets the gate's own hundreds of
# `build-vcx` calls through while blocking every build from outside it. No
# ancestry walk needed.
#
# Fails OPEN on anything it cannot establish (unreadable lock, dead owner):
# a lock bug that blocks every build in every worktree would be worse than the
# problem it solves. Override with CX_GATE_LOCK_OVERRIDE=1.
CX_GATE_LOCK := /tmp/cx-gate.lock

# ── QUEUE, don't refuse (#1346) ──────────────────────────────────────────────
# A blocked caller WAITS for the lock instead of failing. Refusing is right for
# a person at a keyboard and wrong for an unattended session, which then needs
# somebody to notice and retry — and retrying is exactly the poll-and-hand-nurse
# loop the lock exists to remove. Observed twice on 2026-09-06: a session queued
# behind a sibling gate by hand, and the moment that gate exited a THIRD one
# started, because nothing was holding a place in line. A gate is ~90 minutes
# and the caller behind it wants a quiet box anyway, so waiting is not a
# failure here.
#
#   CX_GATE_LOCK_WAIT unset  wait as long as it takes (the default: queue)
#   CX_GATE_LOCK_WAIT=0      the pre-#1346 fail-fast, for a person at a keyboard
#   CX_GATE_LOCK_WAIT=N      wait at most N seconds, then refuse as before
#
# The budget is spent in SHORT steps with the last one clamped to what is left,
# not checked once per poll interval: the implementation this replaces waited
# 10 s for `CX_GATE_LOCK_WAIT=6` because the check sat next to a `sleep 10`.
# Nothing about the lock FILE changes — same path, same two lines (pid, cwd),
# same stale-pid reclaim, same CX_GATE_LOCK_OVERRIDE — so gate-lock-status and
# every existing reader still read it.
CX_GATE_LOCK_WAIT ?=
CX_GATE_LOCK_POLL := 2
CX_GATE_LOCK_ANNOUNCE := 300

# GATE_LOCK_WAIT_LOOP — block until $(CX_GATE_LOCK) is free (or reclaimable),
# then fall through; refuse with exit 1 when the budget runs out. Shared by
# check-gate-lock and by the acquisition in `test` / `test-docs`, which is why
# it is a define and not three copies: the three copies it replaces had already
# drifted (only one of them cleared a stale lock).
#
# $(1) is the caller's name, used in every message so a queued session says who
# it is and who it is waiting for.
#
# An EMPTY owner line means an acquirer is between create and write. The
# pre-#1346 code failed open there, which would let a waiter start inside a run
# that was a millisecond from holding the lock; here it is a short GRACE — the
# gap is one `printf` wide — and only a lock that stays unreadable past the
# grace still fails open, which is the property that keeps a lock bug from
# blocking every build on the box.
define GATE_LOCK_WAIT_LOOP
	gl_waited=0; gl_said=0; gl_blank=0; gl_budget='$(CX_GATE_LOCK_WAIT)'; \
	while :; do \
	  if [ ! -f "$(CX_GATE_LOCK)" ]; then break; fi; \
	  gl_owner=$$(sed -n 1p "$(CX_GATE_LOCK)" 2>/dev/null); \
	  gl_where=$$(sed -n 2p "$(CX_GATE_LOCK)" 2>/dev/null); \
	  if [ -z "$$gl_owner" ]; then \
	    gl_blank=$$((gl_blank + 1)); \
	    if [ $$gl_blank -gt 2 ]; then \
	      echo "$(1): lock file unreadable after $$gl_blank looks — proceeding (fails open)"; \
	      break; \
	    fi; \
	    sleep 1; continue; \
	  fi; \
	  gl_blank=0; \
	  if [ "$$gl_owner" = "$(CX_GATE_OWNER)" ]; then break; fi; \
	  if ! kill -0 "$$gl_owner" 2>/dev/null; then \
	    rm -f "$(CX_GATE_LOCK)" 2>/dev/null || true; \
	    echo "$(1): cleared a stale lock (pid $$gl_owner gone)"; \
	    break; \
	  fi; \
	  if [ "$$gl_budget" = "0" ] || { [ -n "$$gl_budget" ] && [ $$gl_waited -ge $$gl_budget ]; }; then \
	    echo "$(1): a post-merge run is active (pid $$gl_owner, $$gl_where)."; \
	    echo "  A step started now perturbs it — the http/pty steps fail under"; \
	    echo "  concurrent load and a -j storm can deadlock. Wait for it, or run"; \
	    echo "  your step under the pre-merge runner:"; \
	    echo "    CX_BUILD_SLOT=\$$HOME/git-repos/cx/.build-slot-impl sh scripts/build-slot.sh make <target>"; \
	    echo "  If you are certain the run is dead:  make gate-lock-status"; \
	    echo "  To QUEUE instead of refusing, leave CX_GATE_LOCK_WAIT unset."; \
	    exit 1; \
	  fi; \
	  if [ $$gl_said -eq 0 ]; then \
	    echo "$(1): queued behind the post-merge run (pid $$gl_owner, $$gl_where) — waiting$$(if [ -n "$$gl_budget" ]; then printf ' up to %ss' "$$gl_budget"; fi)."; \
	    gl_said=1; \
	  fi; \
	  gl_step=$(CX_GATE_LOCK_POLL); \
	  if [ -n "$$gl_budget" ]; then \
	    gl_left=$$((gl_budget - gl_waited)); \
	    if [ $$gl_left -lt $$gl_step ]; then gl_step=$$gl_left; fi; \
	  fi; \
	  sleep $$gl_step; \
	  gl_waited=$$((gl_waited + gl_step)); \
	  if [ $$((gl_waited % $(CX_GATE_LOCK_ANNOUNCE))) -lt $$gl_step ]; then \
	    echo "$(1): still queued behind pid $$gl_owner after $$gl_waited s."; \
	  fi; \
	done
endef

# GATE_LOCK_TAKE — queue for the lock, then claim it ATOMICALLY. `set -C`
# (noclobber) makes the create O_EXCL, so two sessions that leave the wait loop
# in the same instant cannot both believe they hold it; the loser goes back to
# waiting. The pre-#1346 acquisition was a plain `>` redirection after a
# separate existence test, which is a check-then-act race — rare, and its
# consequence is two concurrent gates, the exact thing the lock is for.
# $(1) is the caller's name.
define GATE_LOCK_TAKE
	while :; do \
	  $(call GATE_LOCK_WAIT_LOOP,$(1)); \
	  if ( set -C; printf '%s\n%s\n' "$(CX_GATE_OWNER)" "$(CURDIR)" > "$(CX_GATE_LOCK)" ) 2>/dev/null; then break; fi; \
	  gl_o=$$(sed -n 1p "$(CX_GATE_LOCK)" 2>/dev/null); \
	  if [ "$$gl_o" = "$(CX_GATE_OWNER)" ]; then break; fi; \
	  if [ -z "$$gl_o" ] || ! kill -0 "$$gl_o" 2>/dev/null; then \
	    rm -f "$(CX_GATE_LOCK)" 2>/dev/null || true; \
	  fi; \
	done
endef

# GATE_LOCK_TRAP — release the lock ON SIGNAL, not only on the last recipe line
# (#1346 part 2). A gate stopped with Ctrl-C left the lock sitting until the
# next caller happened to look and reclaim it in passing (twice on 2026-09-06);
# the reclaim is a safety net, not a release. Prefixed to every long-running
# line of `test` / `test-docs`, because each recipe line is its own shell and a
# single header trap would not reach the lines below it.
#
# INT TERM HUP only — deliberately NOT EXIT. An intermediate line finishing
# NORMALLY must leave the lock in place for the lines after it; trapping EXIT
# here would hand the box away in the middle of the gate, which is the opposite
# of what this lock is for.
GATE_LOCK_TRAP := trap 'rm -f "$(CX_GATE_LOCK)"' INT TERM HUP;

.PHONY: gate-lock-status
gate-lock-status:
	@if [ -f "$(CX_GATE_LOCK)" ]; then \
	  owner=$$(sed -n 1p "$(CX_GATE_LOCK)" 2>/dev/null); \
	  where=$$(sed -n 2p "$(CX_GATE_LOCK)" 2>/dev/null); \
	  if kill -0 "$$owner" 2>/dev/null; then \
	    echo "gate-lock: HELD by pid $$owner in $$where"; \
	  else \
	    echo "gate-lock: stale (pid $$owner gone) — next build clears it"; \
	  fi; \
	else \
	  echo "gate-lock: free"; \
	fi

# check-gate-lock refuses a step that would start inside somebody else's
# post-merge run.
#
# EXEMPT: a step running under the PRE-MERGE RUNNER (RULED: INT-1, 2026-09-12).
# The delivery grammar's §6 protects the MAIN CHECKOUT from a merge while a run
# is active; it does not ask a worktree to stop building. The two runners are
# separate by design — the post-merge run holds ~/git-repos/cx/.build-slot, a
# pre-merge run holds ~/git-repos/cx/.build-slot-impl — so a pre-merge step has
# already serialized against everything the lock was written to protect. Before
# INT-1 the lock refused every `make` in every worktree with an EXIT=2 that
# never named the caller's branch; four pre-merge runs were lost to it on
# 2026-09-12. The test is on the runner directory the caller is holding, which
# scripts/build-slot.sh exports as CX_BUILD_SLOT: anything but `.build-slot`
# itself is a pre-merge runner and passes.
#
# Since #1346 a step that is NOT exempt QUEUES rather than exiting 1 — see
# GATE_LOCK_WAIT_LOOP above for the budget and its spellings. The two early
# exits (override, pre-merge runner) are unchanged and still cost nothing.
.PHONY: check-gate-lock
check-gate-lock:
	@if [ -n "$(CX_GATE_LOCK_OVERRIDE)" ]; then exit 0; fi; \
	if [ -n "$(CX_BUILD_SLOT)" ] && [ "$(notdir $(CX_BUILD_SLOT))" != ".build-slot" ]; then exit 0; fi; \
	if [ ! -f "$(CX_GATE_LOCK)" ]; then exit 0; fi; \
	$(call GATE_LOCK_WAIT_LOOP,check-gate-lock)

# ── deps-present (RULED: RS-7, RS-12, #1591 item 11) ────────────────────────
# A BUNDLED SOURCE THAT IS NOT IN THIS REPOSITORY. Since the first extraction,
# `cx-platform/sso`'s module source is `deps/cx-platform-sso/stdlib/sso.cx` —
# the checkout `deps.cxd` pins and `make deps-sync` fetches — and
# deps/cx-core-code/vcx/code/stdlib_bundle.v embeds it into all four profile builds from there.
#
# So the build has a precondition it never had, and this is where it is stated.
# `$embed_file` would refuse the missing path on its own, loudly enough, but
# five hundred lines into a V compile and in V's words, not ours; and the
# failure a reader must never see is the OTHER one — a `cx` that came out of a
# tree with no `deps/` and quietly does not answer `[?lib 'cx-platform/sso']`.
# That build cannot happen: the embed is a compile-time constant, so there is
# no arm in which the module is dropped. This target is the sentence that says
# which pin is missing and what to run, before V starts.
#
# It is DERIVED, not a second list: every `repo=` row of registry/modules.cxd
# names its own pinned paths, and a row added there is covered here the day it
# lands. The derivation is `grep`, not `cx`, on purpose — this runs BEFORE the
# binary that would read the registry exists.
#
# It is the BUILD-TIME half of one mechanism (#1589 item 23): embed from
# deps/, nothing copied. The pin-time half is scripts/bundle_check.cx at the
# end of `deps-sync` and `deps-check`, which applies the table
# conformance/bundle_sources.cxd grades — the same `missing-pinned-source`
# class, plus the questions only a cx can answer (is the repository pinned at
# all; is its source committed here by mistake). This half stays `grep` so a
# `make clean` tree with its deps/ still rebuilds with no cx present
# (scripts/reproduce_release.sh does exactly that).
#
# THE V HALF (RULED: RS-7, RS-12). A V repository's modules are not embedded,
# they are COMPILED from the pin through -path (CX_DEPS_VPATH, beside
# DEPS_CX). V has no `$embed_file` to fail on here: a module missing from the
# search path is "cannot import module", or worse, a like-named module found
# somewhere else. So for every deps.cxd row carrying a v-fork= this refuses,
# before V starts, a tree whose deps/<repo>/vcx/ holds no module, a search path
# that does not name that root, and — the silent case — a directory under vcx/
# named like a pinned module that tracks no file: a copy left behind by the
# module's own leave, which V would find first (vcx/ is its v.mod folder).
# sync-cmd-split — `module main` is split across two physical trees now that
# cx-core-code owns cmd/'s anchor (main.v) while this repository keeps the
# platform-profile and flow companions that never leave it (flow.v,
# flow_serve.v, platform_verbs_d_cx_platform.v, the xap_*.v module-main
# stay-files, RS-8, D73a): `v` refuses two directory targets ("Too many
# targets"), so the pinned checkout's own vcx/cmd/ gains a SYMLINK per
# stay-file instead of a second compile root — deps/ is gitignored, so this
# never touches a tracked byte of the pin, and a stale symlink from an older
# pin is cleared first (find -type l).
.PHONY: sync-cmd-split
sync-cmd-split:
	@[ -d deps/cx-core-code/vcx/cmd ] || exit 0; \
	find deps/cx-core-code/vcx/cmd -maxdepth 1 -type l -delete; \
	for f in vcx/cmd/*.v; do \
	  ln -sf "$(CURDIR)/$$f" "deps/cx-core-code/vcx/cmd/$$(basename $$f)"; \
	done
	@# Every artifact this recipe (or an ordinary build) leaves untracked in the
	@# pin checkout -- the stay-file symlinks just made, this repository's own
	@# nested deps/ mirror (already covered by the pin's OWN tracked .gitignore,
	@# named here anyway so this file is a complete account), vcx/target/ (build
	@# output; 0 files under it are ever tracked there) and a test's
	@# __snapshots__/ -- goes in deps/cx-core-code/.git/info/exclude, a
	@# per-checkout, never-committed ignore list (RULED: RS-7, RS-8). `git status`
	@# of the pin is then clean by construction after this target runs, so
	@# `deps-sync`'s checkout-drift refusal (which the spec's "has local changes"
	@# means literally -- any uncommitted change, not only a tracked one, #1591's
	@# Risks) never fires on the front door's OWN byproducts; a genuine edit to a
	@# TRACKED file still shows in `git status` and still refuses, unchanged.
	@if [ -d deps/cx-core-code/.git ]; then \
	  exf=deps/cx-core-code/.git/info/exclude; \
	  mkdir -p "$$(dirname "$$exf")"; \
	  [ -f "$$exf" ] || : > "$$exf"; \
	  awk '/^# BEGIN sync-cmd-split$$/{skip=1} /^# END sync-cmd-split$$/{skip=0; next} !skip' "$$exf" > "$$exf.tmp"; \
	  { cat "$$exf.tmp"; \
	    echo "# BEGIN sync-cmd-split"; \
	    for f in vcx/cmd/*.v; do echo "vcx/cmd/$$(basename $$f)"; done; \
	    echo "deps/"; \
	    echo "vcx/target/"; \
	    echo "__snapshots__/"; \
	    echo "# END sync-cmd-split"; \
	  } > "$$exf"; \
	  rm -f "$$exf.tmp"; \
	fi
	@# cx-core-code's own test helpers (testenv.cx_bin() and friends) compute
	@# "my own repo root" from @VMODROOT (correct: deps/cx-core-code is its own
	@# git checkout) and then reach OTHER pins — deps/cx-core-data's corpus, most
	@# often — by walking UP AND BACK DOWN into "deps/<repo>/...", exactly the
	@# nested layout a STANDALONE build of this repository has (its own deps.cxd
	@# pins cx-core-data too). The front door's assembled build keeps every pin
	@# as a SIBLING of deps/cx-core-code instead (one fetch, not two), so this
	@# nested deps/ is populated with symlinks to those siblings -- never itself,
	@# which would loop.
	@if [ -d deps/cx-core-code ] && [ ! -L deps/cx-core-code/deps ]; then \
	  mkdir -p deps/cx-core-code/deps; \
	  for d in deps/*/; do \
	    r=$$(basename "$$d"); \
	    [ "$$r" = cx-core-code ] && continue; \
	    [ -e "deps/cx-core-code/deps/$$r" ] || ln -s "$(CURDIR)/deps/$$r" "deps/cx-core-code/deps/$$r"; \
	  done; \
	fi
	@# extraction_gate_probe (and CX_CORPUS_MERGED below) walk ONE directory
	@# recursively, no -path-style search list -- a MERGED view, symlinks only,
	@# never the real conformance/ (other steps' `git ls-files`-based counts
	@# must not see it): cx-core-code's moved corpus PLUS whatever conformance/
	@# still carries directly.
	@mkdir -p deps/cx-core-code/vcx/target/conformance-merged
	@find deps/cx-core-code/vcx/target/conformance-merged -maxdepth 1 -type l -delete
	@for e in conformance/*.cxd conformance/*.md conformance/llm deps/cx-core-code/conformance/*; do \
	  [ -e "$$e" ] || continue; \
	  ln -sf "$(CURDIR)/$$e" "deps/cx-core-code/vcx/target/conformance-merged/$$(basename $$e)"; \
	done
.PHONY: deps-present
deps-present: sync-cmd-split
	@missing=""; \
	for f in $$(grep '\[module ' registry/modules.cxd | grep -v 'status=planned' | grep -oE 'source=deps/[^] ]+' | sed 's/^source=//' | sort -u); do \
	  [ -f "$$f" ] || missing="$$missing $$f"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "deps-present: FAILED — a pinned repository's bundled source is not in this tree:" >&2; \
	  for f in $$missing; do echo "    $$f" >&2; done; \
	  echo "  registry/modules.cxd declares it under a repo= row and deps.cxd pins that repository." >&2; \
	  echo "  Run \`make deps-sync\` (or \`make union\`, which does it first). The build does NOT" >&2; \
	  echo "  continue without it: a cx binary missing a bundled module is not a smaller cx." >&2; \
	  exit 1; \
	fi; \
	vbad=""; \
	for r in $$(grep -oE '\[dep [^]]*v-fork=[0-9a-f]+' deps.cxd | grep -oE 'repo=[^] ]+' | sed 's/^repo=//' | sort -u); do \
	  root="deps/$$r/vcx"; \
	  if ! ls "$$root"/*/*.v >/dev/null 2>&1; then \
	    vbad="$$vbad~$$root is not there -- deps.cxd pins $$r as a V repository (v-fork=) and its modules are compiled from it"; \
	  else case "|$(CX_DEPS_VPATH)|" in *"|$(CURDIR)/$$root|"*) ;; \
	    *) vbad="$$vbad~$$root is not on the V search path [$(CX_DEPS_VPATH)] -- the Makefile did not derive this row from deps.cxd";; esac; \
	  fi; \
	  for m in "$$root"/*/; do m=$$(basename "$$m"); \
	    [ -n "$$(git -C "deps/$$r" ls-files "vcx/$$m" 2>/dev/null | head -1)" ] || continue; \
	    if [ -d "vcx/$$m" ] && [ -z "$$(git ls-files "vcx/$$m" 2>/dev/null | head -1)" ] && git rev-parse --git-dir >/dev/null 2>&1; then \
	      vbad="$$vbad~vcx/$$m is on disk and tracks nothing -- a stale copy of a module that left this tree; V searches vcx/ before the pin, so it would compile in place of $$root/$$m (remove it)"; \
	    fi; \
	  done; \
	done; \
	if command -v "$(DEPS_CX)" >/dev/null 2>&1; then \
	  cxv=$$("$(DEPS_CX)" --allow-all scripts/deps_sync.cx --vpath --dir "$(CURDIR)/deps" 2>/dev/null); \
	  if [ -n "$$cxv" ] && [ "$$cxv" != "$(CX_DEPS_VPATH)" ]; then \
	    vbad="$$vbad~the V search path this Makefile derives [$(CX_DEPS_VPATH)] is not what \`cx deps sync --vpath\` answers [$$cxv] -- spec §3.3 read two ways"; \
	  fi; \
	fi; \
	if [ -n "$$vbad" ]; then \
	  echo "deps-present: FAILED — a pinned V repository cannot be compiled from its pin:" >&2; \
	  echo "$$vbad" | tr '~' '\n' | sed '/^$$/d; s/^/    /' >&2; \
	  echo "  Run \`make deps-sync\` first. A build that compiled an older in-tree copy, or nothing, in" >&2; \
	  echo "  place of the pinned module is the failure this refusal exists to prevent (RULED: RS-7)." >&2; \
	  exit 1; \
	fi

build-vcx: check-gate-lock deps-present
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx build

# Unoptimised dev build of libcx + cx (no -prod/-Os). Functionally
# identical for tests but compiles far faster; the test path depends on
# this instead of the -prod `build-vcx`. Shipped artifacts use `build-vcx`.
build-vcx-dev: check-gate-lock deps-present
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx build-dev CX_DFLAGS='$(CX_DFLAGS)'

# ── The §4 PROFILE MATRIX as ordinary build steps (#1449, RULED: 1449-a) ─────
# These used to be built nowhere: `test-profile-gate` built the whole matrix
# from scratch inside the SERIAL TAIL of `make test`, after the -j block had
# drained, and `test-extraction-gate` and `abi-gc-gate` each ran their own
# `$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx build-data-dev` inside the block — two concurrent recursive
# sub-makes writing the same two artifacts, with nothing sequencing them.
#
# Both halves are fixed by naming the builds ONCE, here, as targets that
# depend on `build-vcx` and on nothing else. Inside any single make invocation
# the DAG then has exactly one node per artifact, so the data profile is built
# once and both gates wait on it; and the profile matrix runs inside the -j
# block, where it is ordinary parallel work, instead of at the head of the
# serial tail. The vcx recipes carry the same relink guard `build-vcx` does
# (#1449 at LIB_CORE_BUILD_ID), so the tail's own recursive build finds every
# artifact current and skips it — make's freshness, not a second copy of the
# list.
#
# `build-profiles-dev` re-enters vcx for the FULL matrix rather than naming the
# embed/cli half here: the data half hits its guard and costs two `find`s, and
# a hand-copied list one recipe away from vcx's own is exactly the drift the
# roster gates exist to stop.
#
# CONCURRENT profile builds (#1590). The five dev artifacts are independent —
# distinct output paths under target/profiles/, distinct `-d` sets, a build-id
# guard each (#995, #1449) — and inside the storm they already build side by
# side under the storm's `-j`. Outside it (a pre-merge `make test-profile-gate`,
# `make test-extraction-gate`, `devbox run baseline`'s first build) the two
# recipes below re-entered vcx SERIALLY: measured on dev2 (28 cores, VJOBS=14),
# the five builds took 51 s one after another. So each re-entry carries `-j`
# when — and only when — no jobserver is already in force: under the storm,
# MAKEFLAGS carries the parent's jobserver and the sub-make joins it, which is
# what it did before; forcing `-j` there would detach it from the storm's
# budget and print `warning: -jN forced in submake`. PROFILE_BUILD_JOBS caps
# the fan-out (five is the artifact count; there is nothing to gain above it).
# The DAG is unchanged: build-profile-data is still one node, so the two gates
# and the matrix never write the data artifacts concurrently (the #1449 rule).
PROFILE_BUILD_JOBS ?= 5
PROFILE_BUILD_J = $(if $(findstring jobserver,$(MAKEFLAGS)),,-j$(PROFILE_BUILD_JOBS))
.PHONY: build-profile-data build-profiles-dev
build-profile-data: build-vcx
	@$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx $(PROFILE_BUILD_J) build-data-dev

build-profiles-dev: build-profile-data
	@$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx $(PROFILE_BUILD_J) build-profiles-dev

# v0.7.5 — build libcx.wasm + libcx.js (emscripten
# loader) + cxlib.js (hand-written wrapper). Produces dist/wasm/.
# Opt-in: not invoked by the default `build` target so contributors
# without emcc on PATH aren't blocked. The guide CI step invokes
# this before scripts/gen_guide/scaffold.sh so the playground page
# bundles the WASM artifacts. Depends on the patched V at
# third_party/v/v (carries the wasm32-emcc vmemcpy fix); falls back
# to system V at the cost of broken Option payloads — see
# the patched-V README at third_party/v/README.md (P1).
build-wasm:
	DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps OUTDIR=$(CURDIR)/dist/wasm ./deps/cx-core-code/scripts/wasm/build_libcx_wasm.sh

# Gate 17 — stage the playground bundle under dist/playground-preview/
# so scripts/test_playground_smoke.sh has a docroot to boot Python's
# http.server against. The layout matches the URL probes the smoke
# script issues: playground.{html,js,css} at the root, wasm artifacts
# under dist/wasm/ (nested), so a `cd dist/playground-preview &&
# python3 -m http.server` exposes /playground.html, /playground.js,
# /playground.css, /dist/wasm/libcx.js, /dist/wasm/cxlib.js — the
# exact set the smoke check curl-probes. Depends on build-wasm so the
# wasm artifacts exist before we copy. When emcc is unavailable,
# build-wasm fails noisily upstream and this target is never reached;
# scripts/test_playground_smoke.sh then reports its documented
# "playground-preview not built" failure.
build-playground:
	@echo "[build-playground] (re)building libcx-async + libcx-pthreads variants"
	@# Two wasm variants — cxlib.js dynamically loads one or the other
	@# at runtime based on crossOriginIsolated + SharedArrayBuffer
	@# availability (cxlib.js §init, ~line 47-70):
	@#   - libcx-async (SINGLE_FILE=1 ASYNCIFY=1 PTHREADS=0) — generic
	@#     HTTP + file:// + GitHub Pages. SINGLE_FILE inlines the wasm
	@#     so file:// double-click works (Chrome blocks sibling fetch
	@#     on null-origin pages).
	@#   - libcx-pthreads (SINGLE_FILE=0 ASYNCIFY=1 PTHREADS=1) — when
	@#     COOP+COEP headers permit SharedArrayBuffer; real parallel
	@#     :par via Web Workers. Needs separate .wasm for pthread
	@#     workers to share the module instance via SAB.
	@# ASYNCIFY=1 lets wall-clock [?sleep DUR] yield through the JS
	@# event loop on the main thread without freezing the UI. The
	@# default `make build-wasm` keeps ASYNCIFY=0 so CLI/binding
	@# consumers don't pay it.
	@# ASYNCIFY_MODE=2 selects JSPI (-sASYNCIFY=2) instead of the
	@# classic binaryen Asyncify rewriter (#930): the classic rewriter
	@# under emcc 5.0.7 costs ~7x host stack per CX eval level, which
	@# shrank the recursion window to ~10-11 levels and broke the
	@# diagram walkers on stock example [64]. JSPI removes the
	@# instrumentation entirely — sync exports get full depth (the
	@# #319 guard trips catchably at ~40 levels) and the single-file
	@# bundle drops 36MB → 13MB. Requires a JSPI-capable browser
	@# (Chromium 137+); cxlib.js routes the async lanes through
	@# WebAssembly.promising wrappers when Module.cxAsyncifyMode == 2.
	@# Build recipe mirrors scripts/gen_guide/guide.mk (build-playground-
	@# wasm-for-guide) so `build-playground` and `guide` stay consistent.
	@# libcx-sync: plain (ASYNCIFY=0) compatibility bundle for hosts
	@# WITHOUT the JSPI API (Safari; Firefox where still flag-gated).
	@# The JSPI bundles abort at instantiation there, so cxlib.js
	@# selects this one when WebAssembly.Suspending is absent — full
	@# recursion window, wall-clock [?sleep] raises catchable CXER0270
	@# (mock sleeps work). No pthreads.
	@SINGLE_FILE=1 ASYNCIFY=1 ASYNCIFY_MODE=2 PTHREADS=0 OUT_NAME=libcx-async    DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps OUTDIR=$(CURDIR)/dist/wasm ./deps/cx-core-code/scripts/wasm/build_libcx_wasm.sh
	@SINGLE_FILE=0 ASYNCIFY=1 ASYNCIFY_MODE=2 PTHREADS=1 OUT_NAME=libcx-pthreads DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps OUTDIR=$(CURDIR)/dist/wasm ./deps/cx-core-code/scripts/wasm/build_libcx_wasm.sh
	@SINGLE_FILE=1 ASYNCIFY=0                 PTHREADS=0 OUT_NAME=libcx-sync     DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps OUTDIR=$(CURDIR)/dist/wasm ./deps/cx-core-code/scripts/wasm/build_libcx_wasm.sh
	@echo "[build-playground] staging dist/playground-preview/"
	@rm -rf dist/playground-preview
	@mkdir -p dist/playground-preview/playground
	@mkdir -p dist/playground-preview/playground/vendor
	@mkdir -p dist/playground-preview/wasm
	@mkdir -p dist/playground-preview/dist/wasm
	@cp scripts/gen_guide/playground/playground.html dist/playground-preview/
	@cp scripts/gen_guide/playground/playground.js dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/playground.css dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/playground.examples.js dist/playground-preview/playground/
	@cp scripts/gen_guide/playground/jspi_probe.html dist/playground-preview/playground/
	@# highlight/ + assets/ make the preview docroot FAITHFUL to the shipped
	@# page (#1007's offline run surfaced two ERR_FILE_NOT_FOUND here that
	@# docs/guide does not have — the smoke gate must test the real layout).
	@mkdir -p dist/playground-preview/highlight dist/playground-preview/assets
	@cp scripts/gen_guide/highlight/*.js dist/playground-preview/highlight/ 2>/dev/null || true
	@cp -R scripts/gen_guide/assets/. dist/playground-preview/assets/ 2>/dev/null || true
	@# The vendored diagram renderer (#1007) — mermaid at a pinned version,
	@# no longer a jsDelivr <script>. It is staged like any other playground
	@# asset because it IS one now; the license travels with it, the way
	@# third_party/re2's does into every release tarball. Copied, not
	@# symlinked, so the preview docroot is self-contained.
	@cp scripts/gen_guide/playground/vendor/mermaid.min.js dist/playground-preview/playground/vendor/
	@cp scripts/gen_guide/playground/vendor/LICENSE-mermaid.txt dist/playground-preview/playground/vendor/
	@cp dist/wasm/cxlib.js dist/playground-preview/wasm/cxlib.js
	@cp dist/wasm/libcx-async.js dist/playground-preview/wasm/libcx-async.js
	@cp dist/wasm/libcx-sync.js dist/playground-preview/wasm/libcx-sync.js
	@if [ -f dist/wasm/libcx-pthreads.js ]; then cp dist/wasm/libcx-pthreads.js dist/playground-preview/wasm/libcx-pthreads.js; fi
	@if [ -f dist/wasm/libcx-pthreads.wasm ]; then cp dist/wasm/libcx-pthreads.wasm dist/playground-preview/wasm/libcx-pthreads.wasm; fi
	@# Smoke-test compatibility: also stage flat copies under dist/wasm/
	@# so scripts/test_playground_smoke.sh (which queries dist/wasm/*
	@# directly) keeps working alongside the absolute-URL layout that
	@# matches docs/guide/ deployment.
	@cp dist/wasm/cxlib.js dist/playground-preview/dist/wasm/cxlib.js
	@cp dist/wasm/libcx-async.js dist/playground-preview/dist/wasm/libcx-async.js
	@cp dist/wasm/libcx-sync.js dist/playground-preview/dist/wasm/libcx-sync.js
	@if [ -f dist/wasm/libcx-pthreads.js ]; then cp dist/wasm/libcx-pthreads.js dist/playground-preview/dist/wasm/libcx-pthreads.js; fi
	@if [ -f dist/wasm/libcx-pthreads.wasm ]; then cp dist/wasm/libcx-pthreads.wasm dist/playground-preview/dist/wasm/libcx-pthreads.wasm; fi
	@# Staleness gate (#992). The three builds above are unconditional, so
	@# reaching here with a stale artifact means one of them silently did
	@# not produce what it claimed — which is exactly the failure that
	@# shipped a 0.13.0 engine into a v0.17 playground for five releases.
	@# The gate refuses rather than staging it.
	@$(MAKE) --no-print-directory wasm-fresh-gate
	@echo "[build-playground] OK — dist/playground-preview/ ready (libcx-async + libcx-pthreads + libcx-sync staged)"

# ── playground engine staleness gate (#992) ───────────────────────────────────
# Two signals, either of which means the playground would run an engine that is
# not this tree's: an artifact older than vcx/ + stdlib/ + VERSION + the build
# script, or an artifact whose own cx_version() export disagrees with VERSION.
# Run it directly to ask "is my playground current?"; `build-playground` runs it
# as a post-condition, and `guide` runs it in --warn mode (guide reuses the
# existing bundle by design, but must never do so silently).
.PHONY: wasm-fresh-gate
wasm-fresh-gate:
	@OUTDIR=$(CURDIR)/dist/wasm ./deps/cx-core-code/scripts/wasm/check_wasm_fresh.sh

# One shared prerequisite for every step that RUNS the playground bundle: build
# it when stale, prove it fresh, once. Two steps each doing "check || build"
# under -j raced on 2026-09-14 (run on 226a4ae27): one built, the other read
# dist/wasm/cxlib.js mid-write and its shard died on "Unexpected end of
# input". A prerequisite serializes the build ahead of both.
.PHONY: wasm-bundle-fresh
wasm-bundle-fresh:
	@OUTDIR=$(CURDIR)/dist/wasm ./deps/cx-core-code/scripts/wasm/check_wasm_fresh.sh >/dev/null 2>&1 || $(MAKE) build-playground
	@OUTDIR=$(CURDIR)/dist/wasm ./deps/cx-core-code/scripts/wasm/check_wasm_fresh.sh

# Optional Apache Arrow C-Data interop library (libcx_arrow per ADR
# 0015 D9 / spec/abi.md §2.11). Separate from libcx; a binding dlopens
# this library independently — none is built from this tree any more
# (RULED: RS-12, RS-8; #1591 item K3: the four active bindings left whole).
build-lib-arrow: build-vcx
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx lib-arrow

build-lib: build-vcx

# Copy vcx dylib + header into dist/ (V implementation is primary)
dist: build-vcx
	mkdir -p $(DIST_DIR)/lib $(DIST_DIR)/include
	cp -f deps/cx-core-code/include/cx.h $(DIST_DIR)/include/
	@if [ -f $(VCX_DYLIB) ]; then cp -f $(VCX_DYLIB) $(DIST_DIR)/lib/libcx.dylib; fi
	@if [ -f $(VCX_SO) ]; then cp -f $(VCX_SO) $(DIST_DIR)/lib/libcx.so; fi
	@echo "dist: $(DIST_DIR)/include/cx.h $(DIST_DIR)/lib/"

# Install libcx system-wide (default: /usr/local; override with PREFIX=...)
install: dist
	install -d $(PREFIX)/lib $(PREFIX)/include $(PREFIX)/lib/pkgconfig
	@if [ -f $(DIST_DIR)/lib/libcx.dylib ]; then install -m 755 $(DIST_DIR)/lib/libcx.dylib $(PREFIX)/lib/; fi
	@if [ -f $(DIST_DIR)/lib/libcx.so ]; then install -m 755 $(DIST_DIR)/lib/libcx.so $(PREFIX)/lib/; fi
	install -m 644 $(DIST_DIR)/include/cx.h $(PREFIX)/include/
	sed "s|@PREFIX@|$(PREFIX)|g" cx.pc.in > $(PREFIX)/lib/pkgconfig/cx.pc
	@echo "installed libcx → $(PREFIX)/lib/ header → $(PREFIX)/include/ pkg-config → $(PREFIX)/lib/pkgconfig/cx.pc"

uninstall:
	rm -f $(PREFIX)/lib/libcx.dylib $(PREFIX)/lib/libcx.so
	rm -f $(PREFIX)/include/cx.h
	rm -f $(PREFIX)/lib/pkgconfig/cx.pc
	@echo "uninstalled libcx from $(PREFIX)"

# Install the verified CLI separately from the libcx shared library.
install-cli: build-vcx
	install -d $(PREFIX)/bin
	install -m 755 deps/cx-core-code/vcx/target/cx $(PREFIX)/bin/cx
	@echo "installed cx CLI → $(PREFIX)/bin/cx"

uninstall-cli:
	rm -f $(PREFIX)/bin/cx
	@echo "uninstalled cx CLI from $(PREFIX)/bin/cx"

# Smoke-test the staged CLI before promotion.
verify-cli: build-vcx
	./deps/cx-core-code/vcx/target/cx --help >/dev/null
	./deps/cx-core-code/vcx/target/cx --json examples/config.cx >/dev/null
	@echo "verified staged CLI at deps/cx-core-code/vcx/target/cx"

promote-cli: verify-cli install-cli
	@echo "promoted verified cx CLI to $(PREFIX)/bin/cx"

# ── Experience gate (the evaluation-experience checklist) ──────────────────────────

.PHONY: smoke-eval verify-examples verify-readme-blocks \
 verify-doc-blocks verify-doc-links bump-version-check release-verify

# F1, F2, F4, F5, F6, F7, F9 — the experience-gate hard-fail checks.
smoke-eval: build-vcx
	@tools/smoke-eval.sh

# F4 — every example must compile and round-trip cleanly.
# IN THE GATE MATRIX (TEST_TARGETS). It used to run only from
# tools/release-verify.sh, which meant examples/ was graded once per release
# cut and not once per landing — and examples/platform/ raises the stake,
# because its scenarios are the only thing in the tree that RUNS the
# platform command lines (`cx flow validate|diagram|run --ephemeral`,
# `cx xap check-surface`, an SSO login end to end) and compares the whole
# output. A step that only a release cut sees is where a broken example
# lives for a week.
#
# It is offline and deterministic, which is what earns it the place: no
# port, no clock read, no network, no store. Measured at the landing:
# 26 per-file readings and 8 platform scenarios, seconds in total.
verify-examples: build-vcx
	@tools/verify-examples.sh
	# #1477 — the readiness wait and the daemon-start-under-load retry
	# classifier, on planted servers. It runs BESIDE the step rather than as a
	# TEST_TARGETS entry of its own because it is a test of this step's own
	# harness, and the one scenario that binds a port (the sso deployment) is
	# the only thing either piece serves.
	@sh tools/scenario_wait_ready_selftest.sh

# F6 — README's runnable code blocks must run.
verify-readme-blocks: build-vcx
	@tools/verify-readme-blocks.sh

# F7 — per-binding quickstart blocks — RETIRED (RULED: RS-12, RS-8; #1591 item
# K3): the four active bindings left whole, so tools/verify-binding-quickstarts.sh's
# LIVE_BINDINGS table would check zero rows — its own header calls that the
# vacuous-gate failure mode ("no skip branch" was the point). Its own header
# also says removing a binding's row is "the same commit that unwires its test
# target", so the target retires here rather than being kept as a pass-on-nothing.
# The script stays tracked (registry/repos.cxd: repo=cx) but unwired — see
# RESULTS.md's LETTER for what would re-enable it.

# Documentation hygiene — every fenced ```cx block parses. No args =
# the script's defaults (spec/ docs-src/ docs/ README.md).
verify-doc-blocks: build-vcx
	@tools/verify-doc-blocks.sh

# V2 — V FORK divergence inventory (RULED: VC-1). CX builds against a
# permanent fork of the V compiler, so there is no pending-upstream state
# to track: this gate asserts that every commit third_party/v carries
# beyond its upstream base has a documented row in the register, and that
# no register row names a commit the fork has dropped. Red on undocumented
# divergence, in either direction.
#
# It replaced check-v-upstream, which queried the GitHub API for two
# tracked issues — a network dependency that made it advisory-only (CI ran
# it under continue-on-error, so it could never fail anything). This one is
# OFFLINE and deterministic, which is what earns it a place in TEST_TARGETS.
.PHONY: check-v-fork
# #1214: in a git WORKTREE third_party/v is a gitlink with no checkout (the
# worktree recipe symlinks only the built v binary), so the fork check has no
# submodule to inventory — it used to run the ancestry test against the
# SUPERPROJECT's HEAD and red every worktree gate with a bogus verdict, and
# under -j that red truncated the steps after it. The register is a property
# of the TREE (the same pin every worktree shares), proven in the checkout
# that has the submodule populated; in a worktree the step says so and passes.
check-v-fork: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-v-fork: build-vcx
	@if [ ! -e third_party/v/.git ]; then \
	  echo "check-v-fork: SKIP — third_party/v is not a populated submodule here (a worktree); the fork register is proven in the main checkout"; \
	else \
	  "$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_v_fork_patches.cx; \
	fi

# V module-cache soundness gate (#700 wave 2, VC-23) — adversarial proof of
# the -usecache key: for every input that can change a cached object's bytes,
# mutate it -> MISS; byte-identical rerun -> HIT; planted/poisoned objects ->
# detected, never linked. Behavioral assertions (built binaries are RUN and
# compared against current sources), so it stays red-capable against future
# mechanism regressions; `--prove-red` (run manually) forges a provenance
# manifest and requires the gate to catch it. ~2 min wall. CADENCE: run on
# every third_party/v change (alongside check-v-fork), before a release cut,
# and before widening -usecache to more steps — it proves the COMPILER, not
# the tree, so it is not in the default TEST_TARGETS ring. Audit + evidence:
# ledger/audit_2026_08_24_vcache_key_soundness.md.
# IN THE GATE MATRIX since #1337, and FIRST in TEST_TARGETS. The gate already
# existed and already went red on the invalidation class — `sound=10 red=6` on
# the worktree that filed #1337 — but nothing in the matrix ran it, so a stale
# cache surfaced as `address-baseline-gate` dying on an undeclared
# `string_runes` on a branch that adds no `.runes()` call anywhere. A
# prio:high landing was held for a full verification cycle to establish that a
# red gate was a toolchain artifact.
#
# Ordered first deliberately: the point is that a stale cache NAMES ITSELF
# before another step fails on a symbol that has nothing to do with the
# change under test. 81 s against a ~90-minute matrix.
#
# This is #1337 ask 2, taken at its second option ("or add
# check-vcache-soundness to the gate matrix so the real cause is named
# first"). The first option — give every `$(V) run` gate the
# CACHE_ESCAPE_PROBE reclassifier — was NOT taken, and the reason is that
# `VFLAGS_VCX` carries no `-usecache`, so a "cache-free re-run" of those gates
# would differ from the cached run in nothing and the classifier would print a
# verdict it had not earned.
# The build-failure classifier decides whether a failed `$(V) ... run` gate is
# worth a -no-skip-unused re-run (see SKIP_UNUSED_ESCAPE_PROBE). A classifier
# that silently stops matching disables the diagnosis while the gate looks
# unchanged — the vacuous-gate class check-serial-retry-rosters exists for —
# so its matcher is red-proofed from both ends over canned logs, including the
# verbatim \#1337 failure. Every alternative in the signature carries its own
# sample, so deleting one reds and adding one without a sample reds too.
# Pure shell over heredocs: it compiles nothing and needs no build slot.
.PHONY: check-build-failure-classifier
check-build-failure-classifier:
	@sh scripts/classify_v_build_failure.sh --self-test

.PHONY: check-vcache-soundness
check-vcache-soundness:
	@log=deps/cx-core-code/vcx/target/vcache-soundness.log; \
	bash scripts/vcache_soundness_gate.sh > $$log 2>&1; rc=$$?; \
	grep -E '^PROBE|^vcache-soundness' $$log; \
	echo "full log: $$log; GATE-RC=$$rc"; exit $$rc

# V6 — pre-commit lint rules over .cx files. Catches the retired
# v0.7.x syntax forms the v0.8.0 parser rejects, plus the
# cxl-version=/cx-eval-version= rename window deprecation.
check-lint-rules: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-lint-rules:
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_lint_rules.cx

# V6 — install the .githooks/ scripts as repo-local git hooks
# (idempotent). Sets core.hooksPath rather than symlinking each
# hook individually so a new hook script lands without re-running
# the install target.
install-hooks:
	@git config core.hooksPath .githooks
	@echo "[install-hooks] git core.hooksPath set to .githooks"
	@ls -1 .githooks/ | sed 's/^/  - /'

# stdlib documentation freshness gate — CX-native (dog-food), run as
# `cx <file>`. Verifies the co-located [module-doc]/[fn-doc] in stdlib/*.cx:
# presence parity (every public [?def] has a [fn-doc] and vice-versa),
# purity agreement, and that every [fn-doc] example is backed verbatim by
# the module's conformance corpus (conformance/stdlib/<m>.cxd, run green by
# `make test-vcx-suite`). Nonzero exit on drift propagates through make.
# Module-set parity is owned by `make stdlib-catalog-gate`.
# Override the binary with CX_BIN=path (default deps/cx-core-code/vcx/target/cx).
.PHONY: guide-check
guide-check: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
guide-check: build-vcx
	@"$(CX_BIN)" --allow-all scripts/gen_guide/stdlib_docs_check.cx

## guide-render-gate  Run the guide GENERATOR itself and assert it produced the
##                  site. guide-check above grades the doc SOURCES under
##                  --allow-all; it says nothing about whether `make guide`
##                  still runs. #1412: it did not, for a day — the renderer
##                  gained a subprocess spawn at a893c5583 and the recipe's
##                  grants did not, so every `make guide` died on CXER0271
##                  while every gate stayed green, because the generator sat
##                  in no gate at all. tools/release-verify.sh has had a row
##                  since #989, but that runs at the TAG; a generator can be
##                  red for any number of commits before it.
##
## Renders the REAL docs/guide/ (gitignored, so no tree side effect and no
## DIRTY): guide_build.cx hardcodes its output root and takes no output-dir
## argument, and #1412 is not licence to add one. GUIDE_SKIP_CX_BUILD=1 is the
## other half of "no side effect": the build-vcx prerequisite has already put
## the prod binary in place, and without the skip the guide rule would drop a
## DEV binary at deps/cx-core-code/vcx/target/cx in the middle of a gate.
##
## Cost, measured at the #989 row: 27.3-27.8 s wall / 26.5 CPU-s, single
## process — absorbed under -j against a ~3 h gate.
.PHONY: guide-render-gate
guide-render-gate: build-vcx
	@mkdir -p deps/cx-core-code/vcx/target
	@rm -f deps/cx-core-code/vcx/target/.guide-render-gate.stamp
	@touch deps/cx-core-code/vcx/target/.guide-render-gate.stamp
	@$(MAKE) --no-print-directory guide GUIDE_SKIP_CX_BUILD=1
	@for p in docs/guide/index.html docs/guide/codec-xml.html; do \
	  if [ ! -f "$$p" ]; then \
	    echo "guide-render-gate: FAILED — the render exited 0 but $$p does not exist"; exit 1; \
	  fi; \
	  if [ ! "$$p" -nt deps/cx-core-code/vcx/target/.guide-render-gate.stamp ]; then \
	    echo "guide-render-gate: FAILED — $$p is older than the pre-render stamp; this run did not write it (a stale site from an earlier render is not a passing render)"; exit 1; \
	  fi; \
	done
	@rm -f deps/cx-core-code/vcx/target/.guide-render-gate.stamp
	@echo "guide-render-gate OK — the generator rendered docs/guide/, index page and the synthesized codec-xml module page both written by THIS run"

# Directive + syntax reference drift gate — every code.md §4.1 registry
# directive has a [directive-doc], no orphans, and each example is backed
# verbatim by the conformance corpus (mirrors guide-check for the stdlib).
.PHONY: directive-docs-check
directive-docs-check: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
directive-docs-check: build-vcx
	@"$(CX_BIN)" --allow-all scripts/gen_guide/directive_docs_check.cx

# Playground example drift gate (#92) — every entry in
# scripts/gen_guide/playground/playground.examples.js must still run clean on
# the current binary, and the committed file must match a fresh render. The
# generator audits the *composed* form (input + the `[; … ]` note comment) with
# NO capability flags, mirroring the file:// wasm sandbox: a top-level parse/
# eval error fails the gate, an unbalanced bracket in a note (→ unterminated
# comment) fails the gate, and examples needing a wasm-unavailable capability
# carry runnable:false (exempt). --check verifies without rewriting the file.
#
# Since #1170 (RULED: 1170-a) it also gates the ANSWER, not just the run.
# Proving each entry RUNS is not enough: R-A1 retired the bare `[name …]`
# builtin call on 2026-08-25 and fourteen examples silently stopped computing
# what their note claims — `[concat "a" "b"]` builds a data element and echoes
# it, exit 0, gate green, for three release windows. The generator now records
# every audited answer in scripts/gen_guide/playground/examples.out.cxd and
# --check compares it, so a semantics change that retires an example's MEANING
# is a diff a human has to accept instead of a silence. The two claims are
# reported separately, because "the bundle is stale" and "an example computes
# something else" need different fixes.
.PHONY: verify-playground-examples
verify-playground-examples: build-vcx
	@deps/cx-core-code/vcx/target/cx --allow-read --allow-write --allow-subprocess --allow-env \
	  --allow-clock \
	  scripts/gen_guide/playground/gen_examples.cx --check
	@# #1170 §C4 (RULED: 1170-g) — the [expect] check must RED on a wrong
	@# expectation: the fixture corpus carries one right, one wrong and one
	@# absent [expect]; the lint-only run has to exit 1 naming the wrong one,
	@# or the check above is vacuous. Output captured; shown only on failure.
	@#
	@# RULED: CXF-2 (#1522) adds the [grants] pair, and it is asserted in both
	@# directions. 04 names grants and a WRONG expectation: §C4 must red on it
	@# too, so a granted child is graded like any other. 05 names the SAME
	@# grants and the RIGHT expectation, so it must NOT be named: it can only
	@# pass if the child really received `--allow-read --allow-write`, and a
	@# silently dropped [grants] field would make that program answer CXER0271
	@# and land 05 in this list. Green-05-beside-red-04 is the proof.
	@#
	@# #1620 adds the silent-failure pair, asserted by MESSAGE, not by key
	@# alone: the post-merge run on a3b6593e5 printed a FAIL row with nothing
	@# after the key. 06 exits 3 with both streams empty — its FAIL line must
	@# carry `exit 3` and `stderr empty`; 07 answers an err value against a
	@# success [expect] — its EXPECT line must carry the expectation and
	@# `exit 1`. And no row may reach the report as `FAIL with no message`.
	@#
	@# #1625: the run gets a FRESH TMPDIR and must leave it empty — the
	@# generator's per-run scratch dir is removed on every exit path (this run
	@# exits 1 through the lint verdict).
	@gtmp=$$(mktemp -d); \
	out=$$(TMPDIR="$$gtmp" deps/cx-core-code/vcx/target/cx --allow-read --allow-write --allow-subprocess --allow-env \
	  --allow-clock \
	  scripts/gen_guide/playground/gen_examples.cx --lint-only \
	  scripts/gen_guide/playground/tests/expect_red.cxd 2>&1); rc=$$?; \
	left=$$(ls -A "$$gtmp"); rm -rf "$$gtmp"; \
	if [ -n "$$left" ]; then \
	  echo "verify-playground-examples: gen_examples left its scratch behind under TMPDIR: $$left"; exit 1; fi; \
	if [ "$$rc" -ne 1 ] || ! printf '%s' "$$out" | grep -q 'EXPECT 02-expect-wrong'; then \
	  echo "verify-playground-examples: the [expect] check is VACUOUS (rc=$$rc; expected 1 naming 02-expect-wrong)"; \
	  printf '%s\n' "$$out" | tail -8; exit 1; fi; \
	if ! printf '%s' "$$out" | grep -q 'EXPECT 04-expect-wrong-under-grants'; then \
	  echo "verify-playground-examples: the [expect] check does not grade a GRANTED entry (expected it to name 04-expect-wrong-under-grants)"; \
	  printf '%s\n' "$$out" | tail -8; exit 1; fi; \
	if printf '%s' "$$out" | grep -q 'EXPECT 05-expect-right-under-grants'; then \
	  echo "verify-playground-examples: [grants] did not reach the audited child (05-expect-right-under-grants red; its program needs --allow-read --allow-write)"; \
	  printf '%s\n' "$$out" | tail -8; exit 1; fi; \
	l06=$$(printf '%s\n' "$$out" | grep 'FAIL  06-silent-nonzero-exit'); \
	if ! printf '%s' "$$l06" | grep -q 'exit 3' || ! printf '%s' "$$l06" | grep -q 'stderr empty'; then \
	  echo "verify-playground-examples: a silent non-zero exit is not reported WITH a message (expected a FAIL line for 06-silent-nonzero-exit carrying 'exit 3' and 'stderr empty'; got: '$$l06')"; \
	  printf '%s\n' "$$out" | tail -12; exit 1; fi; \
	l07=$$(printf '%s\n' "$$out" | grep 'EXPECT 07-err-answer-vs-expect'); \
	if ! printf '%s' "$$l07" | grep -q 'exit 1' || ! printf '%s' "$$l07" | grep -q "delivery accepted='true'"; then \
	  echo "verify-playground-examples: an err answer against an [expect] is not reported with the expectation and the exit code (expected an EXPECT line for 07-err-answer-vs-expect; got: '$$l07')"; \
	  printf '%s\n' "$$out" | tail -12; exit 1; fi; \
	if printf '%s' "$$out" | grep -q 'FAIL with no message'; then \
	  echo "verify-playground-examples: a FAIL row reached the report with an EMPTY message"; \
	  printf '%s\n' "$$out" | tail -12; exit 1; fi; \
	echo "verify-playground-examples: [expect] red-proof OK (fixture corpus reds exactly 02-expect-wrong and 04-expect-wrong-under-grants; 05 proves [grants] reaches the child; 06 and 07 are named with their exit codes and streams)"

# ── playground diagram validity gate (#992) ───────────────────────────────────
# Every diagram the playground can put on screen must PARSE:
#   example × {auto, instance} × {source, output} × {min, compact, full}
# checked against the very mermaid bundle the page loads — since #1007 that is
# the vendored scripts/gen_guide/playground/vendor/mermaid.min.js, not a CDN
# range and not the gate's own npm copy, so gate and page cannot pin different
# renderers. The emitters are reached where they really live — the `auto` graphs
# from the built wasm engine, the `instance` graphs from playground.js's own
# builder — so the gate cannot go green over a shipped file that has rotted.
#
# Opt-in, like `build-wasm`: it needs `make build-playground` to have produced
# dist/wasm/, plus one npm install for jsdom. Both preconditions FAIL
# LOUD (exit 2) rather than skipping, so this step can never report a vacuous
# pass. It is deliberately NOT in TEST_TARGETS — that step must not require
# emcc or a network fetch — and belongs with scripts/test_playground_smoke.sh as
# the playground release step.
.PHONY: test-playground-mermaid
# RULED: 1170-e / 1170-f. The step grades a bundle it BUILDS or PROVES FRESH,
# never one it finds: `wasm-fresh-gate` (#992) refuses an artifact older than
# vcx/ + stdlib/ + VERSION or whose cx_version() disagrees, so the bundle is
# rebuilt (`build-playground`: both wasm variants the freshness gate names,
# ~2 min) only when that gate says stale (in a gate that is every run; in a
# developer loop usually not), and the step REFUSES if it still reports stale
# or missing. Before this the gate read an untracked, gitignored dist/wasm —
# a two-week-stale bundle produced one false red and could have hidden a real
# one. In TEST_TARGETS since 1170-f, after #1349 landed every constant id.
test-playground-mermaid: wasm-bundle-fresh
	@node scripts/test_playground_mermaid.mjs

# ── playground NAVIGATION gate (#1380) ───────────────────────────────────────
# The shipped page in jsdom, no wasm: every picker option keeps its authored
# [NNN] number, the arrow keys step examples / subcategories FROM THE PICKER
# (where focus sits after a choice) and never from the editor, and the crumb
# names the number. Needs jsdom (scripts/playground-gate), nothing else.
.PHONY: test-playground-nav
test-playground-nav:
	@node scripts/test_playground_nav.mjs

# ── playground WASM TRAP sweep (#1374) ───────────────────────────────────────
# Every example evaluated in the shipped engine under node; a wasm TRAP
# (`table index is out of bounds` — what a V closure does when wasm32 calls
# it — memory out of bounds, unreachable) is a FAIL regardless of any
# wasm-unsupported marker. Refusals and the single-threaded bundle's aborts
# are counted, not failed: parity is test-playground-wasm-eval's (Chrome).
# Same bundle discipline as test-playground-mermaid: build or prove fresh.
.PHONY: test-playground-wasm-traps
test-playground-wasm-traps: wasm-bundle-fresh
	@node scripts/test_playground_wasm_traps.mjs

# ── playground wasm EVALUATION sweep (#1033) ──────────────────────────────────
# Every example in the corpus, evaluated in the engine A READER GETS, either
# produces the same value native cx produces for the same source under the same
# (zero) grants, or is explicitly marked wasm-unsupported in examples.cxd with a
# reason the page shows. A marker that is not justified — marked, but it works —
# is a FAILURE too, so the gate cannot be defeated by marking the corpus
# wholesale.
#
# WHY THIS IS NOT COVERED ELSEWHERE. verify-playground-examples replays the whole corpus
# through NATIVE cx; test-playground-mermaid checks that the DIAGRAMS parse (it
# calls evalCode for its `output` subject but swallows the result into a SKIP).
# So nothing evaluated the corpus in the shipped wasm engine, and 10 examples
# that the engine refuses outright shipped green through two release cuts.
#
# WHY IT DRIVES A BROWSER. Measured, not assumed: node cannot load the bundle
# the page loads. libcx-async/-pthreads are JSPI builds that abort under node,
# and node 22 exposes no JSPI under any flag — so a node harness must use
# libcx-sync, which DISAGREES with the reader's engine (18 refusals vs 10; it
# would have demanded false markers on 8 working examples). The gate asserts it
# got a JSPI bundle rather than quietly measuring the weaker one.
#
# Opt-in like build-wasm and the mermaid gate: it needs `make build-playground`
# to have staged dist/playground-preview/, plus a Chromium-family browser
# (CX_CHROME overrides). Both preconditions FAIL LOUD (exit 2) rather than
# skipping, so this step can never report a vacuous pass. Deliberately NOT in
# TEST_TARGETS — that step must not require emcc or a browser — and belongs with
# test-playground-mermaid and scripts/test_playground_smoke.sh as the playground
# release step. Every wait is bounded (WASM_EVAL_DEADLINE, default 900s); the
# server and browser are reaped on every exit path.
.PHONY: test-playground-wasm-eval
test-playground-wasm-eval:
	@node scripts/test_playground_wasm_eval.mjs

# ── playground TREE PANE gate (#1049) ─────────────────────────────────────────
# A pinned set of examples is loaded into the real page THROUGH THE PAGE'S OWN
# CONTROLS — the picker's `change`, the Detail select's `change`, the Source and
# Tree tabs — and the Tree it draws at each Detail rung is read back out of the
# DOM and compared with scripts/playground-gate/tree_expectations.json: row
# counts, chip counts, the exact `(+K more attrs)` note, the one-row value-leaf
# rule, directives spelled `?name`, and the click bridge round-tripped in both
# directions.
#
# WHY THIS IS NOT COVERED ELSEWHERE. NOTHING RENDERS THE TREE. The mermaid gate
# parses diagrams; the wasm-eval sweep evaluates the corpus; the smoke step
# checks assets. That is exactly how #1001's element branch — reading
# `node.attrs`/`node.items`, fields the cxlib.tree() contract does not carry —
# sat inert as dead code through the whole #992 quality package, with `Detail`
# having no observable effect on the Tree at any rung. #1001's own close-out
# (TD-7) recorded the gap as open rather than glossing it; this closes it.
#
# THE EXPECTATIONS ARE PINNED, NOT DERIVED, and unlike the wasm sweep that is
# forced: there is no second Tree renderer to derive truth from. They live in
# ONE reviewable fixture so a deliberate Tree change re-pins in one place with
# the diff visible (`node scripts/test_playground_tree.mjs --pin`). The raw-JSON
# -walk check is SHAPE-based rather than count-based on purpose — re-pinning the
# counts cannot make the #1001 defect shape pass.
#
# Opt-in like build-wasm and the other two playground gates: it needs `make
# build-playground` staged plus a Chromium-family browser (CX_CHROME overrides),
# and both preconditions FAIL LOUD (exit 2) rather than skipping, so this step
# can never report a vacuous pass. Deliberately NOT in TEST_TARGETS — that step
# must not require emcc or a browser — and belongs with test-playground-mermaid,
# test-playground-wasm-eval and scripts/test_playground_smoke.sh as the
# playground release step. Every wait is bounded (TREE_GATE_DEADLINE, default
# 600s); server and browser are reaped on every exit path.
.PHONY: test-playground-tree
test-playground-tree:
	@node scripts/test_playground_tree.mjs

# stdlib catalog drift gate — verifies the single invariant
#   SPEC_SET == (BUNDLE_SET union DISPATCH_SET)
# i.e. every status=current [module-meta] in the spec pages
# registry/modules.cxd declares (both ring directories since #1427-a)
# is implemented (stdlib/*.cx bundle and/or a *_stdlib_builtin entry in
# deps/cx-core-code/vcx/code/stdlib_dispatch.v), and there are no orphan impls/bundles
# without a current spec. The gate is itself written in CX (dog-food) and
# run as `cx <file>`; its nonzero exit on drift propagates through make.
# Override the binary with CX_BIN=path (default deps/cx-core-code/vcx/target/cx).
# macOS artifact portability gate (#1102) — CX-native, run as `cx <file>`.
# Every SHIPPED Mach-O must load only from /usr/lib and /System, and every
# dylib must carry an @rpath install name. The shipped v0.17.0 artifacts
# carried an absolute /nix/store path from the BUILD MACHINE and died in
# dyld before main on anything else; scripts/portable_links.sh repairs that
# at link time, and this is what stops it coming back. SKIPs off macOS,
# where linking is by soname.
.PHONY: check-portable-links
check-portable-links: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-portable-links: build-vcx
	@"$(CX_BIN)" --allow-all scripts/check_portable_links.cx

.PHONY: stdlib-catalog-gate
stdlib-catalog-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
stdlib-catalog-gate: build-vcx
	@"$(CX_BIN)" --allow-all scripts/stdlib_catalog_gate.cx

# ── ledger-index / ledger-index-check (#1438, RULED: CFG-1) ───────────────────
# Every commit subject ends `(RULED: <id>)` and `ledger/` is the decision store
# those ids point into, but nothing mapped an id to the page and heading that
# carry it — resolving one meant grepping 265 files. `ledger-index` regenerates
# `ledger/README.md` from the store; `ledger-index-check` is the drift step and
# fails when the committed index no longer matches the pages, the same shape as
# `docs-check`. Both need `--allow-write`: the generator writes the index, and
# `write-line` to a standard stream is itself a write capability.
.PHONY: ledger-index ledger-index-check
ledger-index: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
ledger-index: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write --allow-env --allow-subprocess scripts/ledger_index.cx

# `--check` is also the SUBJECT rule (#1447): every id-shaped token in a
# `(RULED: …)` clause on release/0.18 must resolve to a page, because a token
# with no decision behind it dresses a choice nobody took in the store's
# authority. Eleven did on 2026-09-19. `--allow-subprocess` is the `git log`
# that reads the subjects; `--allow-env` is CX_LEDGER_SUBJECTS_FILE, which is
# how the selftest plants subjects without a repository.
ledger-index-check: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
ledger-index-check: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write --allow-env --allow-subprocess scripts/ledger_index.cx --check
	@CX_BIN="$(CX_BIN)" sh scripts/ledger_subject_ids_selftest.sh

# ── primer-platform / primer-platform-check (#1487, RULED: COMP-1) ────────────
# `cx primer` is the door an adopter's agent walks through before it writes a
# line, and its PLATFORM chapter is the material two specifications already
# own: the seam table and the closed set of composition patterns
# (spec/03-approved/platform/composition.md §1-§3) and the runtimes, the
# carrier rule and what changes across a boundary
# (spec/03-approved/platform/deployment-topology.md §1-§4). Transcribed by
# hand it would drift the first time either page moved, so it is PROJECTED:
# `primer-platform` regenerates docs-src/llm/primer-platform.chapter.md, which
# docs-src/llm/primer.md.tmpl carries as its `{{PLATFORM-CHAPTER}}`
# placeholder; `make docs` then folds it into docs/llm/primer.md and
# `make build-vcx` embeds that.
#
# `primer-platform-check` is the drift step, the same shape as
# `ledger-index-check` and `docs-check`: it re-projects in memory and fails
# when the committed chapter and the two pages disagree. A spec change under
# those sections lands with `make primer-platform && make docs` and the
# regenerated files in the same commit. Both need `--allow-write`:
# `write-line` to a standard stream is itself a write capability, and the
# check writes no file.
.PHONY: primer-platform primer-platform-check
primer-platform: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
primer-platform: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/gen_docs/primer_platform.cx

primer-platform-check: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
primer-platform-check: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/gen_docs/primer_platform.cx --check

# ── placement-gate (RULED: 1427-f, OL-15) ─────────────────────────────────────
# registry/modules.cxd is where a module's RING is DECLARED. This step refuses
# a tree where the spec's directory, the corpus's directory, the corpus's
# `ring=` header, or the directory of the V code disagrees with the row — and a
# spec or suite under the ring directories that no row claims. OL-15's "no more
# placement mistakes" is this check: the four places that used to state a
# placement by implication are now compared, on every run, against one that
# states it outright.
.PHONY: placement-gate
placement-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
placement-gate: build-vcx
	@"$(CX_BIN)" --allow-all scripts/placement_gate.cx --self-test
	@"$(CX_BIN)" --allow-all scripts/placement_gate.cx

# ── the repo allocation (#1589, #1591 item 4) ──────────────────────────────
# registry/repos.cxd assigns every tracked path to the repository it moves to
# under the approved multi-repo shape; the step refuses a tree where a tracked
# file has no home, a rule is dead or duplicated, a rule names an undeclared
# repo, a declared repo receives nothing, or a registry module would be torn
# across repos. Reads `git ls-files`, so it needs the exec grant.
repos-allocation-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
repos-allocation-gate: build-vcx
	@"$(CX_BIN)" --allow-all scripts/repos_allocation_gate.cx --self-test
	@"$(CX_BIN)" --allow-all scripts/repos_allocation_gate.cx

# ── the product import graph (RULED: RS-24, owner D28a) ──────────────────────
# vcx/platform splits into one V module per V product, and registry/repos.cxd
# declares, once, which repository compiles each module (`vmodule=`) and which
# repositories it builds on (`pins=`, the Pins column of the #1589 table). The
# step refuses an import under a product directory that runs against a pin, a
# cycle in the pins, a product directory with no repository row, a file
# allocated away from its product directory, and a vmodule that would shadow a
# vlib module. The self-test runs first and carries the planted violation the
# gate was red-proofed on (`import store` in a net file).
.PHONY: product-import-gate
product-import-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
product-import-gate: build-vcx
	@"$(CX_BIN)" --allow-all scripts/product_import_gate.cx --self-test
	@"$(CX_BIN)" --allow-all scripts/product_import_gate.cx

# ── the store→session dependency check (RULED: RS-6, #1591 item 8) ─────────
# RS-6 puts the store SERVER's authentication on the Ring-1 trust primitives
# (did/vc verify, the authz decision) and the daemon's own `[grants]`, so the
# store↔session cycle that would otherwise tear `cx-platform-store` and
# `cx-platform-identity` apart no longer exists. Both surfaces are `module
# platform` today, so no import contract can state the rule and
# `ring-import-gate` (which works on directories) cannot see it: this step
# states it at the file level, with the session symbol set DERIVED from
# stdlib_session.v and deny-by-default on anything session-shaped it does not
# know. The self-test runs first, the way placement-gate's does — a rule that
# has never been red is not a rule.
.PHONY: store-session-dep-gate
store-session-dep-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
store-session-dep-gate: build-vcx
	@"$(CX_BIN)" --allow-all scripts/store_session_dep_gate.cx --self-test
	@"$(CX_BIN)" --allow-all scripts/store_session_dep_gate.cx

# ── the repository dependency pins (#1591 item 10, RULED: RS-7) ────────────
# RS-7 rules the pin transport of the multi-repo shape: "a CX lock document
# plus a CX-written `cx deps sync` (shallow fetch at SHA into an ignored
# `deps/`, read by the V build via `-path`)". `deps.cxd` is the document,
# scripts/deps_sync.cx is the program, and
# spec/03-approved/process/repository-dependency-pins.md is the format.
#
# `deps-check` NEVER warns: a sha the remote no longer has, or a deps/
# checkout that is not at its pin, fails. #1589's Risks records why — the
# previous stale-copy arrangement in this project rotted within weeks because
# nothing failed when it did.
#
# NEITHER TARGET BUILDS `cx` FIRST, and that is not an optimisation. Since the
# first extraction (RULED: RS-12) a pinned repository carries a BUNDLED SOURCE
# the profile builds embed, so `build-vcx` needs `deps/` — and `deps-sync` is
# what makes `deps/`. A `deps-sync: build-vcx` edge is therefore a cycle, and
# it would fail in the one situation the target exists for: a tree that has not
# synced yet. So these two resolve a cx the way a COMPONENT repository's gate
# does (cx-tooling's tooling/repo-template/Makefile, `cx-present`): the one this tree built
# if it is there, otherwise the one on PATH, and a named refusal if there is
# neither. `cx deps sync` reads a document and runs `git`; any released cx can
# do it, and that is the bootstrap.
#
# WHERE IT LOOKS (#1643). A fresh worktree has no deps/cx-core-code/vcx/target/cx of its own, so
# every agent and developer worktree used to hit the refusal first and pass
# CX_BIN= by hand. It now looks where a developer already has one, in this
# order, and SAYS which it used: CX_BIN= when given; this tree's build; the MAIN
# checkout's build (the first row of `git worktree list`); a cx on PATH;
# ~/.local/bin/cx. The refusal stays for a box with none of them.
# scripts/deps_cx_selftest.cx (run by test-deps-pins) proves each place.
DEPS_CX_GIVEN := $(CX_BIN)
DEPS_CX_MAIN = $(shell git -C "$(CURDIR)" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
DEPS_CX_FOUND = $(shell for c in "$(CURDIR)/deps/cx-core-code/vcx/target/cx" "$(DEPS_CX_MAIN)/vcx/target/cx" "$$(command -v cx 2>/dev/null)" "$(HOME)/.local/bin/cx"; do [ -n "$$c" ] && [ -x "$$c" ] && { echo "$$c"; break; }; done)
deps-sync deps-check deps-cx deps-present: CX_BIN ?= $(DEPS_CX_FOUND)

.PHONY: deps-sync deps-check deps-cx
deps-cx:
	@if [ -n "$(DEPS_CX_GIVEN)" ] && [ -x "$(DEPS_CX_GIVEN)" ]; then echo "deps-sync: using $(DEPS_CX_GIVEN) (CX_BIN)" >&2; exit 0; fi; \
	if [ -z "$(DEPS_CX_GIVEN)" ] && [ -n "$(CX_BIN)" ] && [ -x "$(CX_BIN)" ]; then \
	  case "$(CX_BIN)" in \
	  "$(CURDIR)/deps/cx-core-code/vcx/target/cx") why="this tree's build" ;; \
	  "$(DEPS_CX_MAIN)/vcx/target/cx") why="the main checkout's build: git worktree list" ;; \
	  "$(HOME)/.local/bin/cx") why="~/.local/bin/cx" ;; \
	  *) why="cx on PATH" ;; \
	  esac; \
	  echo "deps-sync: using $(CX_BIN) ($$why)" >&2; exit 0; fi; \
	if [ -n "$(CX_BIN)" ]; then \
	  echo "deps-sync: CX_BIN=$(CX_BIN) is not an executable cx" >&2; exit 2; fi; \
	echo "deps-sync: no cx to run the pin transport with — none in this tree, the main checkout, on PATH or at ~/.local/bin/cx." >&2; \
	echo "  This tree cannot build one first: deps.cxd pins a repository whose bundled source the" >&2; \
	echo "  profile builds embed (registry/modules.cxd, repo=), so the build needs deps/ and deps/" >&2; \
	echo "  needs this. Install a released cx, or pass CX_BIN=<path to one>." >&2; \
	exit 2

DEPS_CX = $(if $(CX_BIN),$(CX_BIN),$(if $(wildcard $(CURDIR)/deps/cx-core-code/vcx/target/cx),$(CURDIR)/deps/cx-core-code/vcx/target/cx,cx))

# ── the V search path the pins produce (RULED: RS-7, RS-12) ─────────────────
# RS-7: pins are "read by the V build via `-path`". CX_DEPS_VPATH is the value
# `cx deps sync --vpath` prints for deps.cxd — deps/<repo>/vcx for every V
# repository row, in document order, then @vmodules|@vlib (spec §3.3) — with
# absolute roots, so a V compile started from any directory reads the same ones.
# A pin added to deps.cxd with a v-fork is on every V compile's path with
# nothing else edited. (This branch's cx-platform-net row is what resolves
# cxnet/transport from the pin; core-data's is what resolves cx/cli/fixtures.)
#
# IT IS DERIVED HERE WITHOUT A cx, by the same grep deps-present uses, because a
# `make clean` tree with its deps/ must still build with no cx present
# (scripts/reproduce_release.sh; deps-present's own rule): asking cx at parse
# time made the first build of a fresh tree need one. It is not a second
# reading of §3.3 that can drift: deps-present asks `cx deps sync --vpath`
# whenever a cx is there and refuses a tree where the two disagree.
#
# CX_V_SEARCH puts this tree's vcx/ FIRST, the pinned roots next and V's
# library last. That is the order V itself applies to a file under vcx/ (its
# v.mod folder is searched before any -path entry); spelling it out makes a
# compile of lang/v/ or tools/ resolve `import cx` exactly as vcx/cmd does. A
# module that has LEFT this tree is found in its pin; a stale, untracked copy
# left behind under vcx/ would win, and deps-present refuses that tree.
#
# CX_NATIVE_DEFINES — where the C archives module `cx` links are. vcx/cx/
# regex_re2.v used to reach them as @VMODROOT/target and
# @VMODROOT/../third_party/re2: THIS tree's layout. V resolves @VMODROOT
# from the nearest v.mod above the file and stops at a .git, so inside a pinned
# checkout it names nothing and V refuses the file (measured: "To use
# @VMODROOT, you need to have a v.mod file"). The module now spells both
# archives as $d() values whose defaults are @DIR-relative (its own
# repository's layout), and the build that made them says where they are:
# the same two files as before, vcx/Makefile's re2-shim and re2-static.
# Module `arrow`'s file-I/O build names its shim archive the same way
# (cx_arrow_shim_lib), read only when -d cx_arrow_files compiles that file.
#
# VFLAGS is how both reach every V compile this Makefile starts, including
# `v test`'s per-file compiles and the V programs scripts/ build: V reads it
# ahead of its own arguments.
CX_EMPTY :=
CX_SPACE := $(CX_EMPTY) $(CX_EMPTY)
CX_DEPS_V_REPOS := $(shell grep -oE '\[dep [^]]*v-fork=[0-9a-f]+' deps.cxd 2>/dev/null | grep -oE 'repo=[^] ]+' | sed 's/^repo=//')
export CX_DEPS_VPATH := $(subst $(CX_SPACE),|,$(strip $(foreach r,$(CX_DEPS_V_REPOS),$(CURDIR)/deps/$(r)/vcx) @vmodules @vlib))
export CX_V_SEARCH := $(CURDIR)/vcx|$(or $(CX_DEPS_VPATH),@vmodules|@vlib)
export CX_NATIVE_DEFINES := -d cx_re2_lib_dir=$(CURDIR)/deps/cx-core-code/vcx/target -d cx_re2_static=$(CURDIR)/third_party/re2/obj/libre2.a -d cx_arrow_shim_lib=$(CURDIR)/deps/cx-core-code/vcx/target/libcx_arrow_shim.a
export VFLAGS := -path "$(CX_V_SEARCH)" $(CX_NATIVE_DEFINES)

# CX_GATES_CXD / CX_FRONT_DOOR_ROOT (K7a crossing 2a, RULED: D68a) —
# conformance/gates.cxd, scripts/*.cx, examples/, tooling/ and VERSION are all
# repo=cx; none of them travel with cx-core-code's pin. grader.v's
# gates_path() and profile_gate.v's load_gate_policy() each read the former
# through their own narrow env-var override (pre-existing convention); every
# cx-core-code V test reaching for one of the latter reads
# testenv.front_door_root(), which is CX_FRONT_DOOR_ROOT with an
# @VMODROOT-relative fallback that only ever resolved correctly while vcx/
# sat directly under this repository's own root (i.e. never once cx-core-code
# became its own checkout) — set both so every V test/runner compiled against
# the pin reaches this repository's real copies instead of a path under
# deps/cx-core-code/ that does not exist.
export CX_GATES_CXD := $(CURDIR)/conformance/gates.cxd
export CX_FRONT_DOOR_ROOT := $(CURDIR)

# BOTH END ON THE BUNDLED SOURCES (#1589 item 23): once the pins are fetched
# or verified, scripts/bundle_check.cx judges every bundled CX module against
# them — the table conformance/bundle_sources.cxd grades — and refuses a pinned
# checkout that does not carry the source its registry/modules.cxd row names
# (`missing-pinned-source`), a row naming a repository deps.cxd does not pin
# (`unpinned`), and a pinned source committed into this tree (`tracked-pin`).
deps-sync: deps-cx
	@"$(DEPS_CX)" --allow-all scripts/deps_sync.cx
	@"$(DEPS_CX)" --allow-all scripts/bundle_check.cx

deps-check: deps-cx
	@"$(DEPS_CX)" --allow-all scripts/deps_sync.cx --check
	@"$(DEPS_CX)" --allow-all scripts/bundle_check.cx

# ── test-bundle-sources — the bundled-source table's corpus ───────────────
# conformance/bundle_sources.cxd pins the two legal states and every refusal
# of scripts/bundle_sources.cx — the table scripts/bundle_check.cx applies to
# the real tree at the end of `deps-sync` and `deps-check`;
# scripts/check_bundle_sources_fixtures.cx grades it and runs its own comparator self-test first — #1591: "Every moved gate is
# red-proofed on a synthetic violation before its row moves."
#
# BOTH GRANTS ARE LOAD-BEARING, for the reason test-deps-pins below records:
# a denied write bound to an unused [?let] binding is dropped silently (#1608),
# so under --allow-read alone the grader prints nothing at all.
.PHONY: test-bundle-sources
test-bundle-sources: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
test-bundle-sources: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_bundle_sources_fixtures.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_bundle_sources_fixtures.cx

# ── test-docs-fragment — the per-repository documentation fragment ────────
# conformance/docs_fragment.cxd pins the contract a component repository's
# release meets when it publishes docs/llm/manifest-fragment.cxd, and the
# union's collision refusal (RULED: RS-9: "the closed [output] list of
# docs-src/llm/manifest.cxd becomes the union of per-repository doc
# manifests"). scripts/docs_fragment.cx is the contract;
# scripts/gen_docs/primer_build.cx runs the same functions over every fragment
# under deps/ when `make docs` regenerates. The grader runs its comparator
# self-test first. Both grants load-bearing, as for test-bundle-sources.
.PHONY: test-docs-fragment
test-docs-fragment: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
test-docs-fragment: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_docs_fragment_fixtures.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_docs_fragment_fixtures.cx

# ── test-deps-pins — the deps.cxd corpus ──────────────────────────────────
# conformance/deps_pins.cxd pins the wire form, its canonical bytes and every
# refusal the format names; scripts/check_deps_pins_fixtures.cx grades it, and
# runs its own comparator self-test first — #1591: "Every moved gate is
# red-proofed on a synthetic violation before its row moves."
#
# BOTH GRANTS ARE LOAD-BEARING. Writing to stdout needs --allow-write, and a
# denied write bound to an unused [?let] binding is DROPPED SILENTLY (#1608):
# under --allow-read alone this step graded 13 of 13 cases, exited 0, and
# printed nothing — a step that says nothing on a pass says nothing on a
# failure either. Measured on this branch, 2026-09-22.
# --allow-subprocess (#1617): the deps-02x cases are scenarios run against
# scripts/deps_sync.cx itself — git and the sync as subprocesses, over a
# throwaway remote under a temporary root the grader removes.
# The third line (#1643) is which cx `deps-sync` bootstraps with, on synthetic
# trees: scripts/deps_cx_selftest.cx runs this Makefile's `deps-cx` step under a
# cleared environment, one scenario per place a developer keeps a cx. Its own
# file, not a deps_pins.cxd case: it grades a Makefile step, not the document.
.PHONY: test-deps-pins
test-deps-pins: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
test-deps-pins: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_deps_pins_fixtures.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_deps_pins_fixtures.cx
	@"$(CX_BIN)" --allow-all scripts/deps_cx_selftest.cx

# ── test-migrate-namespace (RULED: RS-4, 1427-i) ─────────────────────────
# conformance/migrate_namespace.cxd pins `cx --migrate-namespace --retired`:
# the file each case's input becomes, the one line per rewritten site the
# run prints, and a second run that changes nothing and says so. The grader
# runs the binary running it, so the step grades the tool this tree builds.
# Its self-test runs first and must see a synthetic case FAIL that rewrites a
# retired name written as a word in a string, and one that leaves a raw
# block's import alone -- the two sites this corpus exists to tell apart.
# All three grants are load-bearing: it writes each case's temporary file and
# stdout, and runs the tool as a subprocess.
.PHONY: test-migrate-namespace
test-migrate-namespace: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
test-migrate-namespace: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_migrate_namespace_fixtures.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess scripts/check_migrate_namespace_fixtures.cx

# ── make union (#1591 item 10, RULED: RS-7) ───────────────────────────────
# The front door's union: SYNC THE PINS, THEN RUN THE SUITE — in that order and
# in one step, so a stale pin fails before a single test compiles rather than
# as a confusing failure an hour in. #1589's integration model: "`cx` is a
# migration lane, not a gate. When any repo releases, `cx` tries the newest
# mutually green set; green ⇒ the pins advance; red ⇒ the pins stay and the
# finding lands on the repo that moved." This target is that attempt.
#
# It is NOT a TEST_TARGETS step and takes no selection-manifest row: it RUNS
# the union rather than being part of it. `make test` remains what a step
# roster grades.
#
# ITS MEANING IS UNCHANGED by #1589 item 23: `deps-sync` then `make test`, in
# that order. `deps-sync` now also judges the bundled CX sources against the
# pins it fetched (scripts/bundle_check.cx), so a pinned checkout missing the
# source a module row names fails here, before a single test compiles.
.PHONY: union
union: deps-sync
	@$(MAKE) test

# ── tools-export golden gate (stream 18, #690) ────────────────────────────────
# `cx tools export` over the M5 module must reproduce its golden byte-for-byte
# — the offline registration step pinned end-to-end (cx-platform/tools
# descriptors → cx-platform/mcp-server adapter → JSON emission). A projection
# change that moves these bytes is deliberate and regenerates the golden via
# the verb itself in the same commit.
#
# THE FIXTURE MOVED AND THE STEP DID NOT (RULED: RS-12, #1591 item 12). The
# module and its golden are cx-platform-agent's now; the VERB is this tree's
# (`vcx/cmd/tools_verb.v`), so the step runs it over the pinned checkout
# deps.cxd names, the test-sso-interop-lane shape. It refuses with exit 2 and
# names `make deps-sync` when the checkout is absent — never a skip.
TOOLS_EXPORT_DIR := deps/cx-platform-agent/conformance/tools-export
.PHONY: tools-export-gate
tools-export-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
tools-export-gate: build-vcx
	@test -f $(TOOLS_EXPORT_DIR)/refund_order.cx || { \
	  echo "tools-export-gate: $(TOOLS_EXPORT_DIR)/ is not there — the fixture lives in the pinned repository now (RS-12); run \`make deps-sync\`" >&2; \
	  exit 2; }
	@out=$$("$(CX_BIN)" tools export $(TOOLS_EXPORT_DIR)/refund_order.cx) || { echo "tools-export-gate: the verb FAILED"; exit 1; }; \
	want=$$(cat $(TOOLS_EXPORT_DIR)/refund_order.tools.json); \
	if [ "$$out" != "$$want" ]; then \
	  echo "tools-export-gate: OUTPUT DIVERGES from $(TOOLS_EXPORT_DIR)/refund_order.tools.json"; \
	  echo "--- got:"; echo "$$out"; echo "--- want:"; echo "$$want"; \
	  exit 1; \
	fi; \
	echo "tools-export-gate OK — refund_order.tools.json reproduced byte-for-byte"

# Format-companion regeneration (#424) — the derived companions under
# examples/ (books.*, config.*, doc.md, comparisons/table_block.csv) are
# GENERATED from their .cx sources; regenerate them here so they cannot
# drift from what the live binary actually emits (gen-docs discipline:
# never hand-edit a companion). Run after any change to the sources or
# to a conversion lane, then commit the results.
# Override the binary with CX_BIN=path (default deps/cx-core-code/vcx/target/cx).
#
# ── LANE NOTES ─────────────────────────────────────────────────────────
#   * books.json/books.xml use the explicit --from=cx conversion lane.
#     Since #443 the `--json FILE` shorthand no longer drops table rows,
#     but it renders the AST-JSON projection (the eval-render shape,
#     "table": {cols, rows}), NOT the semantic JSON image the companion
#     pins — so books.json stays on the conversion lane by design.
.PHONY: examples-regen
examples-regen: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
examples-regen:
	@test -x "$(CX_BIN)" || { echo "examples-regen: no cx binary at $(CX_BIN); run 'make build-vcx' or pass CX_BIN=/path/to/cx"; exit 1; }
	@echo "==> regenerating examples/ format companions with $(CX_BIN)"
	"$(CX_BIN)" --json examples/config.cx > examples/config.json
	"$(CX_BIN)" --yaml examples/config.cx > examples/config.yaml
	"$(CX_BIN)" --toml examples/config.cx > examples/config.toml
	"$(CX_BIN)" --xml  examples/config.cx > examples/config.xml
	"$(CX_BIN)" --yaml examples/books.cx  > examples/books.yaml
	"$(CX_BIN)" --toml examples/books.cx  > examples/books.toml
	"$(CX_BIN)" --from=cx --to=json examples/books.cx > examples/books.json
	"$(CX_BIN)" --from=cx --to=xml  examples/books.cx > examples/books.xml
	"$(CX_BIN)" --md   examples/doc.cx    > examples/doc.md
	"$(CX_BIN)" --csv  examples/comparisons/table_block.cx > examples/comparisons/table_block.csv
	@echo "==> done; review with 'git diff examples/' and commit"

# V7 — bench harness JSON runner. Drives bench-streaming and emits
# a stable JSON shape consumable by scripts/compare_bench.cx.
bench-json: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
bench-json:
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-clock --allow-env scripts/run_bench_json.cx

# V7 — bench regression comparison. Pass BASELINE= and CURRENT= as
# paths to JSON files produced by bench-json. Default threshold is
# 30%; pass STRICT=1 for the 10% threshold.
bench-compare: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
bench-compare:
	@"$(CX_BIN)" --allow-read --allow-write --allow-env scripts/compare_bench.cx \
	  $(or $(BASELINE),bench/baseline.json) \
	  $(or $(CURRENT),bench/current.json) \
	  $(if $(STRICT),--strict,)

# #1249 (RULED: 1249-Q1a) — the perf RATCHET the release cut runs after the
# gate: measure (bench-json → bench/current.json) and compare against the
# committed floor (bench/baseline.json) at the STRICT 10% threshold. Red
# aborts the cut like a red gate; on green tag_release.sh promotes
# bench/current.json to bench/baseline.json in the bump commit, so every cut
# re-pins the floor to its own measurement. Wall-clock and machine-bound, so
# NOT a TEST_TARGETS member — a decision instrument the cut invokes.
#
# #1450 — the ISOLATION guard. Holding the runner is not enough: it serialises
# what goes through it, not the box. With `.build-slot-impl` HELD and six
# pre-merge pipelines compiling beside it, `tooling.fmt_8k_ms` read 1902.1 ms
# against a hot 1304 and four unrelated rows regressed 36-457 %
# (impl/cx-A-1433 run 4, 2026-09-14). Both halves answer the load now:
# run_bench_json.cx REFUSES TO MEASURE over CX_BENCH_MAX_LOAD (default 8 on this
# 12-core box) and records the load either side of the run in the artifact, and
# compare_bench.cx REFUSES TO JUDGE a current reading taken over that bound.
# Both refusals exit 3, which is neither a pass nor a regression — and
# scripts/tag_release.sh WAITS for the box rather than aborting a cut on one.
.PHONY: perf-ratchet
perf-ratchet: build-vcx
	@"$(CURDIR)/deps/cx-core-code/vcx/target/cx" --allow-read --allow-write --allow-subprocess --allow-clock --allow-env scripts/run_bench_json.cx -o bench/current.json
	@$(MAKE) bench-compare STRICT=1 CX_BIN=$(CURDIR)/deps/cx-core-code/vcx/target/cx

# Documentation hygiene — every relative markdown link resolves.
# Source markdown lives in docs-src/ (docs/ is the GENERATED HTML guide /
# Pages site, which has no .md files — pointing the check there made the
# target exit 2 on an empty target list). Coverage includes EVERY published
# root doc (the #426 audit found ROADMAP/SECURITY/CONTRIBUTING rotting
# precisely because only docs-src/ + README were gated) and the approved
# spec tree (#499/#503 found spec/03-approved/ links rotting invisibly
# because the gate never looked there).
verify-doc-links:
	@# A TEST_TARGETS row since INT-11 (#1475), so the step has to be
	@# SELF-SUFFICIENT: it must not need a docs build to have happened first.
	@# The .cxd sources under docs-src/ render into docs/guide/, and the checker
	@# resolves their relative links from THAT directory — which is generated and
	@# gitignored. In a fresh worktree it does not exist, and all 194 of those
	@# links read as broken for that reason alone (measured on this branch: the
	@# step failed before this line, 230 passed / 0 failed after it). The
	@# directory's EXISTENCE is the whole dependency; nothing here reads what a
	@# docs build would put in it.
	@mkdir -p docs/guide
	@tools/verify-doc-links.sh docs-src/
	@tools/verify-doc-links.sh spec/03-approved/
	@tools/verify-doc-links.sh README.md CONTRIBUTING.md ROADMAP.md \
	  SECURITY.md CODE_OF_CONDUCT.md CHANGELOG.md RELEASE_NOTES_v*.md \
	  AGENTS.md $(wildcard CLAUDE.md)
	@# CLAUDE.md is cx-private's (RULED: D82a): the public cx the same filter
	@# makes from this tree does not carry it, and the checker refuses a named
	@# file that is absent, so it is checked where it exists.
	@# docs/llm/ (#938) is the GENERATED LLM layer. It is expected to carry
	@# ZERO relative links: it is served from the published SITE ROOT, where a
	@# repo-relative path resolves to nothing. So this row's job is to stay at
	@# "0 failed" as the layer grows — the moment a template starts emitting
	@# `](…)` paths, they have to resolve in the checkout too.
	@tools/verify-doc-links.sh docs/llm/

# Pre-tag version-string consistency. VERSION (the repo-root file) is the
# single source of truth; scripts/check_version_consistency.cx verifies every
# stamped manifest + derived code surface against it. An explicit
# VERSION=X.Y.Z arg additionally asserts the file holds the version you
# intend to release (catches "forgot to run scripts/bump_version.sh").
bump-version-check: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
bump-version-check: build-vcx
	@if [ -n "$(VERSION)" ] && [ "$(VERSION)" != "$$(cat VERSION)" ]; then \
	  echo "bump-version-check: VERSION file holds $$(cat VERSION), expected $(VERSION) — run scripts/bump_version.sh $(VERSION)"; \
	  exit 1; \
	fi
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_version_consistency.cx

# RULED: PGL-1 (#741) — the R2.2 BLOCKING per-profile install gate, runnable
# WITHOUT a cut. It used to live only inside release.sh phase 2, in the arm
# that --dry-run skips, so its first execution was always the real cut.
.PHONY: release-profile-gate
release-profile-gate:
	@scripts/release_profile_gate.sh

# Full pre-tag check — runs everything in the release process + §0.5.
# Defaults to the VERSION file (single source of truth).
release-verify:
	@tools/release-verify.sh $(or $(VERSION),$(shell cat VERSION))

# ── Test ───────────────────────────────────────────────────────────────────────

# Test fan-out — the C-ABI conformance harness plus every native gate.
# Listed once so `test` and `test-no-parallel` stay in sync.
# The four active bindings (V / Python / Go / Rust, per backlog
# d-2026-05-22-03) LEFT cx-private WHOLE as cx-home/cx-binding-{v,python,go,rust}
# (RULED: RS-12, RS-8; #1591 item K3): `test-v`, `test-python`, `test-go`,
# `test-rust` and `test-binding-api-parity` retired from this list with them —
# cx does not pin any binding, so nothing here can drive one any more. See
# RESULTS.md's LETTER for what (if anything) now covers per-binding testing.
# The six archived bindings (TypeScript / Java / Kotlin / C# / Ruby / Swift)
# moved to lang/_archived/ in v0.8.0 and were never wired into `test`.
TEST_TARGETS := check-no-ai-attribution check-vcache-soundness check-build-failure-classifier test-vcx-timing check-conformance-coverage check-shim-archives abi-c-test check-v-fork check-portable-links check-serial-retry-rosters check-fixture-shard-manifest check-consolidation-manifests test-vcx-suite test-vcx-code test-vcx-cmd test-vcx-cx test-vcx-conform test-vcx-columnar test-vcx-sqlite check-prod-build check-no-legacy-try check-pipefail-pipes check-exec-redirect check-exit-status-probe check-bench-isolation check-no-infix-range check-no-cxl-token check-no-consumer-terms secrets-scan check-version-consistency check-effect-alignment check-null-absence-conflation check-docs-tier1-guardrail check-no-adr-citations check-no-stub-impl check-completions-drift check-editor-surface-parity guide-check guide-render-gate site-check directive-docs-check verify-doc-blocks verify-doc-links verify-examples verify-playground-examples docs-check primer-platform-check ring-import-gate gates-manifest-gate ring-tag-gate cxer-registry-gate spec-freeze-gate test-extraction-gate abi-gc-gate libcx-abi-gate test-profile-gate check-code-spec-consistency check-code-fixtures reader-parity stdlib-catalog-gate placement-gate repos-allocation-gate product-import-gate test-deps-pins test-bundle-sources test-docs-fragment test-migrate-namespace store-session-dep-gate flow-vocabulary-gate flow-dogfood-gate test-flow-umbrella address-baseline-gate tools-export-gate test-code-diagram test-playground-mermaid test-playground-nav test-oriel-lane test-agent-real-lanes test-connector-real-lanes test-sso-interop-lane test-xpath-parity-cx corpus-audit repr-guard check-inmodule-test-roster check-build-input-roster check-selection-manifest fmt-sweep-gate test-playground-wasm-traps ledger-index-check check-profile-gate-selection check-verification-budget check-verification-budget-selftest check-storm-keep-going check-verification-timings

# ── test-changed (#700, ruled 1a 2026-08-09) — the step-input skip manifest ──
# THE DEVELOPMENT-LOOP ENTRY POINT. Runs only the TEST_TARGETS steps whose
# declared input globs intersect BASE..HEAD (+worktree). Deny-by-default: a
# step without a manifest row in scripts/test_changed.sh ALWAYS runs. The full
# `make test` union stays MANDATORY at wave/phase exits — this target never
# substitutes for an exit gate.
#
# BASE defaults to HEAD, i.e. "what I have not committed yet" — the loop a
# developer is actually in, and a ref that always resolves. Widen the window
# explicitly when the work is already committed:
#   make test-changed BASE=origin/release/0.17     # the whole branch's change set
#   make test-changed BASE=HEAD~3
# `make test-changed-dry` prints the SKIP/RUN decision and executes nothing.
# (#700 wave 1, 2026-08-24: BASE had no default, so the entry point AGENTS.md
# documents exited 2 with a usage message unless the caller already knew to
# pass BASE=.)
BASE ?= HEAD
.PHONY: test-changed
test-changed:
	@$(MAKE) deps-sync
	@bash scripts/test_changed.sh $(BASE)

.PHONY: test-changed-dry
test-changed-dry:
	@bash scripts/test_changed.sh $(BASE) --dry-run

# ── -prod strictness gate (#338) — shipped artifacts build with -prod
# (`build-vcx`), which enforces strict map-index checks (`or {}` required on
# sum-type / pointer-carrying map values) that the dev builds tolerate. This
# runs the V checker (no codegen, ~2s) over deps/cx-core-code/vcx/code/ with the `lib` -prod
# flags, wired into TEST_TARGETS so a -prod-only break surfaces on every
# `make test` (the release gate) instead of sitting dark until a cut.
.PHONY: check-prod-build
check-prod-build:
	@$(MAKE) -s -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx check-prod

# ── NO-LEGACY-TRY gate (SAP C3c) — the retired [?try]/[catch]/[on-error]
# surfaces must not reappear in conformance/ + docs-src/ + examples/ + lang/.
# Token-aware, not a raw grep ([?try-send]/[?try-receive] + the CSV dialect
# [on-error "…"] option + the retirement-pinning negatives are allowlisted).
.PHONY: check-no-legacy-try
# ── SIGPIPE-PIPE gate (RULED: SPG-1, #916) — `external cmd | grep -q P`
# inside a pipefail script fires FALSE failures: grep -q exits on the first
# match, the producer takes SIGPIPE (141), pipefail promotes it. Two
# instances existed before this gate, one of them inside the BLOCKING R2.2
# release gate, where it aborted a cut on a good artifact (PGL-1a). Landed
# green with ZERO annotated exceptions; that is the standard to hold.
.PHONY: check-pipefail-pipes
check-pipefail-pipes:
	@scripts/pipefail_pipe_gate.sh

# ── check-exec-redirect (#1542) ───────────────────────────────────────────────
# A bare `exec` carrying only redirections applies them to the SHELL, for the
# rest of the script — `$(JS_CLOSE)` was written that way, so every recipe line
# that opened with it ran with stderr at /dev/null and every diagnostic after it
# was lost, including the whole `SHELL='sh -x'` trace of `test-vcx-suite`. That
# is why #1520's nested `make test` could be reproduced for months and never
# read. Same family as check-pipefail-pipes: a timing-free, grep-able hazard
# whose damage is silence.
.PHONY: check-exec-redirect
check-exec-redirect:
	@scripts/exec_redirect_gate.sh

# ── check-exit-status-probe (#1570) ──────────────────────────────────────────
# Third of the same family, and the quietest of the three: an exit status read
# out of an inner shell that `devbox run` wraps answers 0 for a program that
# exited non-zero. On 2026-09-18 that cost a wrong prio:high issue (#1569,
# withdrawn) in which [$$env:exit N] looked broken and a dozen TEST_TARGETS
# gates looked vacuous — both were fine. A pipeline script that captures the
# status in its OWN file is sound and the gate says so; only the ad-hoc probe
# is refused. The selftest runs beside it because a deny-on-match gate's own
# failure mode is matching nothing (#1542's note).
.PHONY: check-exit-status-probe
check-exit-status-probe:
	@scripts/exit_status_probe_gate.sh
	@sh scripts/exit_status_probe_selftest.sh

# ── check-bench-isolation (#1450) ────────────────────────────────────────────
# `perf-ratchet` itself is wall-clock and machine-bound and is deliberately NOT
# a TEST_TARGETS member. Its ISOLATION GUARD is neither: it plants artifacts
# under mktemp and reads two exit codes, so it is held here like any other step.
# Without it the guard is a sentence in a recipe comment — the same argument
# VCOST-1 makes about a written bound.
.PHONY: check-bench-isolation
check-bench-isolation: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-bench-isolation:
	@CX_BIN="$(CX_BIN)" sh scripts/bench_isolation_selftest.sh

check-no-legacy-try: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-no-legacy-try:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_legacy_try.cx

# ── NO-INFIX-RANGE gate (generator-family reshape, C-gen-1) — the retired
# infix range operators `to`/`by` must not reappear in conformance/ + docs-src/
# + examples/ + lang/. Ranges are the prefix builtin [$range lo hi step?].
# Token-aware, not a raw grep (English to/by prose, to=/by= named args, and the
# colon slice-stride [a:b:s] are not matched; the negatives are allowlisted).
.PHONY: check-no-infix-range
check-no-infix-range: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-no-infix-range:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_infix_range.cx

# ── NO-CXL-TOKEN gate — the retired language name `CXL` must not reappear
# in conformance/ + docs-src/ + examples/ + scripts/ + tooling/ + top-level
# project prose. Token-aware, not a raw grep (live identifiers cxlib / cxl: /
# CXLS / CXLib are not matched; _archive*/_archived/_gate_evidence excluded).
# (Formerly mis-named `check-no-stale-version` — it never checked versions;
# version-number drift is now caught by check-version-consistency below.)
.PHONY: check-no-cxl-token
check-no-cxl-token: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-no-cxl-token:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_cxl_token.cx

# ── NO-CONSUMER-TERMS gate — downstream-consumer identity (names, products,
# business-domain vocabulary) must never appear in tracked content: the public
# release repos are CUT from this one, so anything here flows into them. The
# denylist lives in the script; extend it the day a new consumer engagement
# begins. Standing owner ruling 2026-07-24: all artifacts speak CX-generic
# workload language (users / tracked entities / events / deployments).
.PHONY: check-no-consumer-terms
check-no-consumer-terms:
	@bash scripts/check_no_consumer_terms.sh

# ── SECRETS-SCAN gate (K13, RULED: D59a, RS-28, CXF-1) — the other
# public-flip precondition beside check-no-consumer-terms above: a component
# repository flips public at the v0.18.0 cut only after its own scan for
# private-key blocks, cloud/VCS/chat API tokens, key files and non-empty env
# files finds nothing unallowlisted. --self-test is fixture-first and wired
# in; scripts/secrets_scan_allow.cxd allowlists a known fixture by its exact
# content fingerprint, never by path.
#
# TRACKED FILES ONLY by default, deliberately: this target runs on every
# TEST_TARGETS selection, and --history walks every blob reachable from
# main — MEASURED on this tree's own ~40k-blob history and on
# cx-core-code's ~8k, minutes per run, growing without bound as history
# grows. A per-commit gate that gets slower forever is wrong. `--history` is
# still the tool's own flag, for the deep one-time audit a repository's
# public-flip actually needs (K13 ran it directly against each frozen
# clone, not through this target) — `make secrets-scan-history` below runs
# it against THIS tree when someone deliberately wants that.
.PHONY: secrets-scan
secrets-scan: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
secrets-scan:
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-env scripts/secrets_scan.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-env scripts/secrets_scan.cx --root .

.PHONY: secrets-scan-history
secrets-scan-history: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
secrets-scan-history:
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-env scripts/secrets_scan.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-env scripts/secrets_scan.cx --root . --history

# ── VERSION-CONSISTENCY gate — the repo-root VERSION file is the single source
# of truth for the release version. Every static manifest must equal it and the
# code surfaces (cabi.v/main.v) must DERIVE it from the build define. Catches the
# drift that previously went unnoticed (cx.pc.in at 0.6.1, C-ABI at 0.8.0 while
# the CLI said 0.10.0). Re-stamp with scripts/bump_version.sh.
.PHONY: check-version-consistency
check-version-consistency: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-version-consistency: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_version_consistency.cx

# ── check-null-absence-conflation gate (SAP C1 / spec/core/code.md §9.1.2.1
# rule (b)) — the no-conflation guard: no builtin returns `null` to mean
# "absent." An optional read signals "nothing here" via the absence channel
# (the empty sequence `()`), never `null`. Token-aware: it flags the
# `[returns [or T null]]` declared-optional-return shape in the stdlib def
# surface (spec/03-approved/{stdlib,platform}/*.md + the vcx/code bundle sources); unit-null
# `[returns null]` and param-position `[or T null]` are deliberately not
# flagged. Permanent gate, not migration-only.
.PHONY: check-null-absence-conflation
check-null-absence-conflation: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-null-absence-conflation:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_null_absence_conflation.cx

# ── ALIGNMENT gate (SAP C2 / spec/core/code.md §6.5.1) — the one-way
# capability-alignment invariant: (1) every capability-gated effect point is
# reached only through an `impure` builtin (gated ⇒ impure, by construction in
# builtin_purity_table); (2) every impure-without-capability builtin is in the
# closed, enumerated exception table. NOT symmetric. The V test owns both
# directions + drift canaries (process- prefix, env- minus pure prims, io
# read/write/open). Runs as part of `test-vcx` too; this dedicated target is
# the named gate.
# (#700: effect_alignment_test.v consolidated into the eval_semantics
# umbrella — the named target retargets to the umbrella like its siblings.)
.PHONY: check-effect-alignment
check-effect-alignment: build-vcx
	@$(JS_CLOSE) $(V) -cc cc $(CX_GC) test deps/cx-core-code/vcx/tests/eval_semantics_umbrella_test.v

# ── check-code-spec-consistency (#707 item 4 / code.md §11.4.1 gates 1-3 +
# the clean-room no-impl-anchor / no-dangling-decision checks). The tool
# existed since v0.7.6 but was wired into NEITHER the Makefile NOR CI — its
# gate 3 (registry↔grammar [127e] parity) had been silently dead since the
# formal-files move and nobody noticed. Repaired + wired at I2. Gate 1 runs
# on the code.md bounded-freedom register (BF-* ids), not a blanket token ban.
.PHONY: check-code-spec-consistency
check-code-spec-consistency: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-code-spec-consistency: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_code_spec_consistency.cx > /dev/null && echo "check-code-spec-consistency OK — gates 1-3 + no-impl-anchor + no-dangling-decision green (run the script directly for the JSON report)"

# ── flow-vocabulary-gate (#1323) — the REFUSAL PROSE gate that was missing.
# check-code-spec-consistency compares signatures and stdlib-catalog-gate
# compares catalog rows; neither reads a refusal's REASON. So vocabulary
# round 2 (RULED: WF-18 … WF-26) landed in flow.md §2.3 ahead of its
# implementation and three shipped refusals in stdlib/flow.cx went on
# reciting rules the spec had withdrawn ON THE SAME BRANCH, while five more
# admitted tokens fell through to the generic unknown-attribute sweep naming
# no landing at all — and nothing was red. This is that red: it reads §2.3's
# word table and the module's four refusal/pending tables and holds (A) no
# word §2.3 ADMITS is refused from the register by a row that never cited
# the ruling admitting it, (B) no admitted word the module does not yet
# implement refuses in silence, (C) every pending refusal names its landing
# (cites its WF- ruling and says "not yet implemented" — the shape the W3
# performer-axis refusal already uses). It also fails when its own inputs
# do not parse, so it cannot go green over nothing.
#
# THE GATE MOVED AND THE STEP DID NOT (RULED: RS-12, #1591 item 15). The
# program, flow.md and stdlib/flow.cx are cx-platform-flow's; the step runs the
# program out of the pinned checkout deps.cxd names, from that checkout's root
# (it reads `spec/03-approved/platform/flow.md` and `stdlib/flow.cx` relative
# to where it runs), under THIS tree's binary. It stays here because the
# repository's own `make check` is lint plus `cx corpus`, and the pair it
# holds together is exactly the pair a pin bump moves.
.PHONY: flow-vocabulary-gate
flow-vocabulary-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
flow-vocabulary-gate: build-vcx
	@test -f deps/cx-platform-flow/scripts/flow_vocabulary_gate.cx || { \
	  echo "flow-vocabulary-gate: deps/cx-platform-flow/ is not there — the gate lives in the pinned repository now (RS-12); run \`make deps-sync\`" >&2; \
	  exit 2; }
	@cd deps/cx-platform-flow && "$(CX_BIN)" --allow-read --allow-write scripts/flow_vocabulary_gate.cx

# ── flow-dogfood-gate (#1265, ladder rung 1) — the DOGFOOD FLOW documents.
# `flow.md` §4.16 makes three flows ABOUT THIS REPOSITORY the campaign's
# first users, and rung 1's exit is that they run on `cx flow run`. A flow
# document that lives in the tree and is graded by nothing is the liability
# AGENTS.md rule 2 names: it rots the moment a word of the vocabulary moves,
# and the corpus fixtures cannot catch it because they embed their documents
# inline. This gate reads the REAL documents in flows/ through THIS TREE's
# binary — `cx flow validate` and `cx flow simulate` as subprocesses — and
# holds four properties per document: it validates against its own --env with
# the construct count named here; every simulated path reaches the terminal
# status the table names (green, --build=no, and a RED STEP that is
# `:incomplete` rather than `:compensated`, because the toolchain build is the
# pivot); the `map` fans out over the address the document computes from the
# record; and every *.flow.cx in flows/ is covered by a row, over a non-empty
# case list — so it cannot go green over nothing. It does NOT `cx flow run`
# with real acts: those acts are `make build-vcx` and `make <step>`, and
# running them inside `make test` would nest make in the matrix and hand a
# second make the jobserver. In TEST_TARGETS.
#
# THE DOCUMENTS MOVED AND THE STEP DID NOT (RULED: RS-12, RS-20, #1591 item
# 15). flows/ and the gate program are cx-platform-flow's; the two verbs the
# gate drives them through — `cx flow validate` and `cx flow simulate` — are
# the local profile RS-20 kept in THIS repository. So the step runs the
# program out of the pinned checkout, from its root, and CX_BIN is what
# crosses: the program's own discovery looks for `deps/cx-core-code/vcx/target/cx` under where
# it runs, which in the checkout is nothing, and it must grade this tree's
# binary rather than find another.
.PHONY: flow-dogfood-gate
flow-dogfood-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
flow-dogfood-gate: build-vcx
	@test -f deps/cx-platform-flow/scripts/flow_dogfood_gate.cx || { \
	  echo "flow-dogfood-gate: deps/cx-platform-flow/ is not there — the gate lives in the pinned repository now (RS-12); run \`make deps-sync\`" >&2; \
	  exit 2; }
	@cd deps/cx-platform-flow && CX_BIN="$(CX_BIN)" "$(CX_BIN)" --allow-read --allow-write --allow-env --allow-subprocess scripts/flow_dogfood_gate.cx

# ── test-flow-umbrella — cx-platform-flow's process lanes, out of the pin ──
# deps/cx-core-code/vcx/tests/flow_umbrella_test.v was one file of test-vcx-suite's directory
# until the extraction (RULED: RS-12, #1591 item 15) allocated it to
# cx-platform-flow, and the owner's D54c split it by subject (RULED: RS-31):
# what grades the PACKAGE — eight real `cx` processes advancing one journaled
# run, a run resuming between two invocations, the resolver a real `--env`
# scan builds, a `cx flow serve` runner that boots, binds, ticks and is
# delivered to over HTTP — is the repository's own CX lanes, which a released
# cx runs alone; the `cx flow` command line's own shape (--help, usage exits,
# the stdout/stderr split, the CLI's defaults) stays here, a section of
# deps/cx-core-code/vcx/tests/cli_umbrella_test.v. What this step grades is still THIS tree's
# binary: each lane runs from the checkout's root with CX_BIN naming
# deps/cx-core-code/vcx/target/cx, which it starts for every process. The lane names are the
# contract, so a lane the checkout lacks refuses with exit 2 naming
# `make deps-sync` — a skip and a pass would be the same line. Real sockets
# (the serve lane binds 18700..19499): the shared runner's step.
FLOW_LANES := racing_advancers_lane.cx flow_cli_lane.cx flow_serve_lane.cx
.PHONY: test-flow-umbrella
test-flow-umbrella: build-vcx
	@for t in $(FLOW_LANES); do \
	  test -f deps/cx-platform-flow/lanes/$$t || { \
	    echo "test-flow-umbrella: deps/cx-platform-flow/lanes/$$t is not there — the lanes live in the pinned repository (RULED: RS-12, RS-31); run \`make deps-sync\`" >&2; \
	    exit 2; }; \
	done
	@cd deps/cx-platform-flow && st=0; \
	for t in $(FLOW_LANES); do \
	  CX_BIN="$(CURDIR)/deps/cx-core-code/vcx/target/cx" "$(CURDIR)/deps/cx-core-code/vcx/target/cx" --allow-all lanes/$$t || st=1; \
	done; exit $$st

# ── check-code-fixtures (gate 4; repaired + wired by the #805 gate-truth
# batch — it was RED and in no step, so no stream gate ever ran it). The
# corpus/spec agreement gate over conformance/code.cxd: id-category
# registry, directive registry (§4.1) with retired/PI/intentional-unknown
# discipline, and ENFORCED spec-error-code coverage (every CXER code
# cited, verified covered cross-suite, or pinned to its filed issue —
# #808 rows are the visible debt).
# CX gate (#922, RULED: PYE-5): reads the corpus through THIS TREE's cx
# binary ([$cx:parse]) — the gate exercises the reader it guards. The
# former LIBCX_LIB_DIR pin is obsolete (nothing dlopens cxlib any more);
# the build-vcx dep remains the #902 rule — the shipped artifact is the
# only honest subject for a gate.
.PHONY: check-code-fixtures
check-code-fixtures: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-code-fixtures: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_code_fixtures.cx > /dev/null && echo "check-code-fixtures OK — 1000+ fixtures: ids/directives/error-code coverage green (run the script directly for the JSON report)"

# ── check-docs-tier1-guardrail gate (SAP C6 / SAP §0.1) — the learnability
# guardrail: the canonical guide's beginner sections (quickstart §0 + intro §1)
# show Tier 1 ONLY, and fp.md / the words "monad"/"functor"/"typeclass" never
# appear in beginner material. Makes §0.1's reviewer rule a permanent gate so
# the entry surface cannot silently drift into advanced theory. Token-aware
# (whole-word advanced terms); a deferring mention ("no monads required") is
# allowlistable. Tier 2/3 sections (concepts §9, libraries §16) are out of
# scope by design — they carry the opt-in/advanced markers.
.PHONY: check-docs-tier1-guardrail
check-docs-tier1-guardrail: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-docs-tier1-guardrail:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_docs_tier1_guardrail.cx

# ── NO-ADR-CITATION gate — the spec (spec/core/*.md) is the only source of
# truth. Decision records are archived (under the guarded decisions dir) and
# MUST NOT be cited from the live tree; such a citation pins live code/docs to
# a non-authoritative record and corrupts the single-source model. The gate is
# token-aware; the gate script + the SAP audit report are allowlisted.
.PHONY: check-no-adr-citations
check-no-adr-citations: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-no-adr-citations:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_adr_citations.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_adr_citations.cx

# ── COMPOSITION-SEAMS step (RULED: COMP-1) — the platform's composition is
# stated once, in spec/03-approved/platform/composition.md, and this step is
# that page's §4 executed: it refuses a specification sentence naming a
# dependency the page's §2.2 marks REFUSED (connector -> flow and sync -> flow,
# CK-6; audit -> store; connector -> sched and sync -> sched, the cadence
# refusals). It reads every *.md under the two ring trees, derives a file's
# owning module from its path stem, and skips a line that STATES a refusal —
# the specifications say "never depends on flow" in exactly those words, and a
# check that read that as a violation would be turned off within a week.
#
# A TEST_TARGETS row on the INT-11 pattern: the step is SELF-SUFFICIENT — it
# reads the tracked specification tree and nothing a build or a documentation
# render would have produced. The self-test runs first, so a detector that
# stopped detecting fails before the scan reports clean.
# RETIRED from TEST_TARGETS (RULED: RS-12, RS-8, RS-7, RS-20; #1591 item K3):
# scripts/check_composition_seams.cx and the composition.md/deployment-topology.md
# pages it scans left with cx-platform-xap's extraction. The check is that
# repository's own gate to carry, against its own tree, not a target this
# Makefile can still run.
#
# .PHONY: check-composition-seams
# check-composition-seams: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
# check-composition-seams:
# 	@"$(CX_BIN)" --allow-read --allow-write scripts/check_composition_seams.cx --self-test
# 	@"$(CX_BIN)" --allow-read --allow-write scripts/check_composition_seams.cx

# ── NO-STUB-IMPL gate (global no-stub rule) — the stdlib impl bundle
# (deps/cx-core-code/vcx/code/*.v) must contain no fake-success stub: an effectful prim returning
# a deterministic synthetic success value instead of performing the real effect
# (the failure mode that shipped the http client / net layer as placeholders and
# sailed through the gate because fixtures asserted the fake shape). Flags the
# fake-success confession phrases only; honest fail-closed errors
# (mk_err(... not yet implemented / unsupported ...)) are NOT flagged — refusing
# an effect is correct, faking it is the bug. A new effect must be real + carry a
# behavioral (real socket/process/file) test, or fail closed.
.PHONY: check-no-stub-impl
check-no-stub-impl: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-no-stub-impl:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_no_stub_impl.cx

# ── ZERO-AI-ATTRIBUTION gate (RULED: RS-33) — the owner's rule: no AI
# attribution anywhere in any repository, ever. Scans every commit message of
# BASE..HEAD (BASE defaults to origin/release/0.18) and every tracked text
# file for a Co-Authored-By-Claude trailer, the anthropic.com noreply
# address, a "Generated with" credit line, and the robot-face "Generated"
# line. The self-test (a scratch repo with one attributed commit and one
# attributed file) runs first, so a detector that stopped detecting fails
# before the scan ever reports clean.
.PHONY: check-no-ai-attribution
check-no-ai-attribution: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-no-ai-attribution:
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-env scripts/check_no_ai_attribution.cx --self-test
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-env scripts/check_no_ai_attribution.cx

# ── RING IMPORT GATE (partition spec §3, phase I0) — the ring import contract,
# enforced grep-level, zero-tolerance. Lands BEFORE any code moves so the seam
# can never regress silently. As of I0 it gates the structurally-clean Ring-0
# sink invariant (vcx/cx imports nothing internal — the §7 byte-for-byte
# extraction precondition); the Ring-1/2 split inside vcx/code is gated at I3.
.PHONY: ring-import-gate
ring-import-gate:
	@bash scripts/ring_import_gate.sh
	@bash scripts/ring_import_gate_selftest.sh

# ── GATES MANIFEST GATE (corpus audit G17) — validate conformance/gates.cxd:
# it parses, every gate= value is in-enum, and every [module name=X] row
# resolves (suite-aware) to a real fixture. Nothing else validated this policy
# file, and it governs whether every OTHER fixture blocks its gate.
# Since D49a (#1633) it is also the DRIFT check of that file: a suite's status
# lives on its [test-suite] element and the register is derived from the
# elements — scripts/gates_register_check.cx refuses a row that disagrees,
# after `cx corpus` has graded its corpus, conformance/gates_register.cxd.
# Reads deps/cx-core-code/vcx/target/cx (or CX_BIN); it does not build it.
.PHONY: gates-manifest-gate
gates-manifest-gate:
	@bash scripts/gates_manifest_gate.sh

# ── DIAGNOSTICS CENSUS (RULED: CXF-3, #1522) — the diagnostics corpus
# audit, written in CX (RULED: CXF-1). For every refusal code: its §9.6
# band, its emission sites, the corpus cases that assert it and the three
# columns judged from each expectation text (form / position / fix), plus
# the class (silent / no-case / weak / covered). REPORTS, never fails: the
# fix batches own the gate, so this target is NOT in TEST_TARGETS on the
# audit branch. The document is the evidence the audit page quotes.
.PHONY: diagnostics-census
diagnostics-census: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
diagnostics-census: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write scripts/diagnostics_census.cx _gate_evidence/diagnostics_census.cxd

# ── CXER REGISTRY GATE (corpus-audit G18; remediation register R3.7) —
# every emitted CXER code must have a governance §9.6 registry row and no
# registry-internal band overlap. --strict = the mechanical certainties.
.PHONY: cxer-registry-gate
cxer-registry-gate:
	@bash scripts/cxer_registry_report.sh --strict

# ── SPEC-FREEZE GATE (remediation register R4.1) — no commit after the
# audit epoch may touch normative spec AND implementation together without
# a RULED: token referencing a recorded ruling (rulings-before-edits, R4.2).
.PHONY: spec-freeze-gate
spec-freeze-gate:
	@bash scripts/spec_freeze_gate.sh
	@bash scripts/spec_freeze_gate_selftest.sh

# ── EXTRACTION GATE (partition spec §7, phase I2) — the Ring-0 byte-for-byte
# rule, executable: the extracted artifacts must match the monolith over the
# full Ring-0-tagged corpus — outputs, canonical bytes, hashes, error codes.
# Two steps:
#   ABI step — deps/cx-core-code/vcx/tests/runners/extraction_gate/probe/ dlopens ONE artifact,
#     feeds every Ring-0 case input through a fixed C-ABI battery (conversions
#     matrix, canonical/hash/fmt/lint, ast-bin/data-bin/events + decoder
#     round-trips, diff/eq pairs, schema validate, the streaming-write event
#     interpreter) and emits a deterministic transcript; the transcript from
#     libcx.dylib and the one from libcx-core.dylib must be BYTE-IDENTICAL
#     (`cmp`). Errors are records too, so error-text identity is asserted.
#     One artifact per process — the GC-carrying dylibs never co-load.
#     Before the corpus walk it also records `cx_codec_inventory` — the
#     artifact's OWN codec registry (RULED: CR-3, #1130) — so a registry
#     that differs between the two libraries reds the `cmp` with ZERO
#     fixtures required, and VERIFIES (per artifact, not in the compared
#     transcript) that every symbol-gated cx_features bit is set exactly
#     when its symbol is exported (RULED: CR-6, #1129 — the two masks now
#     legitimately differ, so the assertion is truthfulness, not equality).
#     Vacuous-pass defense (audit F-15 / remediation R3.8): the probe
#     enforces the case-count floor below AND refuses any zero-record
#     Ring-0 case that is not an intentional exclusion. Intentional
#     exclusion is DERIVED from the probe's own battery table: a case whose
#     input format has no ABI battery (md, html, url — the C ABI carries no
#     cx_md_*/cx_html_*/cx_url_* family) cannot be driven here and is
#     covered by the CLI step and the cx-only conformance runner. Every
#     format that HAS a battery keeps the full zero-record check.
#   CLI step — deps/cx-core-code/vcx/tests/runners/extraction_gate/cli/ runs monolith cx and
#     data-profile cx over the shared surface (verbs + EXPLICIT --from=
#     convert; the bare-FILE run-vs-data reading is a ruled profile
#     difference, spec §4) requiring stdout+stderr+rc identical, plus the
#     17 monolith-verb profile refusals on the data binary (#426 discipline).
#     Same case-count floor.
# Dev-shape builds (same codegen semantics as -prod minus optimization);
# the release cut re-runs this against the prod-shape artifacts.
#
# RULED: VC-24 — the harness builds under $(CX_GC), cx's memory model, like
# everything else. These three runner binaries (probe, cli_gate, and
# abi-gc-gate below) carried a hard-coded `-gc boehm` from daf3f921b
# (2026-08-06) with no rationale in the commit or the comment, overriding the
# `-gc e` default that had been cx's since a27d61b6b. CX has one collector;
# the gate harness is not exempt. If a `-gc e` host ever fails HERE it is a
# vgc dlopen-host defect (two statically-linked vgc runtimes in one process
# share a pthread_once signal-handler install and keep per-image __thread
# state) — that gets FILED and fixed on its own landing, never absorbed by a
# silent Boehm override.
# Floor = the Ring-0 census recorded at I2 (partition_I2_extraction.md);
# raise it when Ring-0 cases are added, never lower it silently.
EXTRACTION_GATE_FLOOR := 1564
# CLI-step shard count (RULED: VC-32). This step was the gate's serial floor:
# 10,579 invocation pairs = 21,158 process spawns issued two at a time, 717 s at
# ~1 core, 91% of the extraction gate and 12 of `make test`'s ~21 minutes.
#
# It runs as PROCESSES, not threads: a bounded thread pool deadlocked vgc's
# stop-the-world, because a thread parked in a blocking read never reaches a
# safepoint (#973). Shards have separate heaps, and the parent is single-threaded
# with inherited stdio so it never blocks reading a child's pipe.
#
# MEASURED 2026-08-25, same binary, cleared scratch: serial 721 s, --jobs=8
# 103 s (7.0x), and both produce the IDENTICAL verdict digest over the same
# case set — which is what that measurement was FOR: proving the sharded mode
# and the serial mode reach the same verdict.
#
# LAST DELIBERATE MEASUREMENT: 2026-08-30, digest
# c59db6df923cbe46cbaca261fe761896b7359e2d9508deca821be915d725aa41 over 2,081
# Ring-0 cases / 11,755 invocation pairs. It moved from
# 07de4e13ae9706744c68b8207c712a33d8c21da662e10cce554ba64fe5f91a0e (1,838
# cases / 10,579 pairs, 2026-08-25) because the corpus legitimately GREW twice
# in the #1126 codec/Ring campaign: the first `[in-json …]` cases (conv-052..055,
# RULED: CR-4 #1127 — json input was ungradeable before the reader became
# Ring-0) and then the first `[in-html …]`/`[in-url …]` cases (conv-056..059,
# the D21 corpus floor). The html/url pair add no CLI comparisons — this step's
# input map drives xml/json/yaml/toml/md — so the digest is unchanged between
# those two waves.
#
# STILL c59db6df… AFTER CR-8 (2026-08-30, #1133), MEASURED: 2,081 cases /
# 11,755 pairs, unchanged. CR-8 added the registry-generic `cx_convert` ABI
# entry; it touches the ABI step only, and this step's input map and comparison
# set are untouched — a digest that had MOVED here would have meant an
# unintended CLI-surface change and was the thing to check for.
#
# MOVED, 2026-08-31, ergonomics BUG WAVE (#1144 umbrella): digest
# 322753e91b685e71b8680ad6951d850f34cca6f58890a83577fe42e55b79f8b2 over 2,251
# Ring-0 cases / 12,763 invocation pairs, from c59db6df… (2,081 / 11,755). The
# account, because a moved digest owes one:
#   • #1104 added THREE `[in-xml …]` cases (conv-060 duplicate-attribute
#     position, conv-061 the reserved `cx:`/`xml:` names, conv-062 the
#     Namespaces-spec boundary that still parses). This step's input map drives
#     xml, so all three add CLI comparisons — and the first two are REFUSALS,
#     which is the class this step most wants pinned across profiles.
#   • The rest of the case growth is the wave's `[in-code …]` corpus (#1145
#     strict array/map kinds, #1146 the callable kind × site matrix, #1147 the
#     emit-boundary steps). Those are program-eval cases, so they raise the
#     Ring-0 census the probe counts without adding CLI comparisons.
#   • ABI step: 2,251 cases through both artifacts, transcripts byte-identical
#     (6,240,317 bytes), ABI-excluded still 0 — the direction that set is
#     allowed to move.
# No comparison was REMOVED. The floor (1564) is untouched: it is a minimum,
# and this wave only added cases.
#
# The ABI step's own numbers DID move, deliberately: the probe's md/html/url
# battery (`cx_convert`, 2 targets per case) plus one fixture-independent
# unknown-format refusal record put 19 new records in each transcript, and the
# cmp'd transcript grew 5,816,561 → 5,819,181 bytes (+2,620). The number that
# matters is the other one printed on that line: ABI-excluded fell 9 → 0. Those
# 9 were the md/html/url cases the bespoke `cx_X_to_Y` families could not reach;
# the intentional-exclusion set is now EMPTY, and it should only ever move in
# that direction.
#
# WHAT THIS NUMBER IS, AND IS NOT. It is ADVISORY DOCUMENTATION of the last
# deliberate measurement, not the enforcement. Enforcement is the comparison
# itself: every invocation pair must agree on stdout+stderr+rc, and the ABI
# step's two transcripts must be byte-identical under `cmp`. Those fail on a
# real divergence whatever this comment says.
#
# The digest's JOB is to make a change in WHAT IS COMPARED visible. It prints
# in the OK line on every run, so when it moves you owe an account of why:
# name the cases or comparisons added or removed, and update the block above
# with the new digest, the pair count, the date, and the reason. A moved digest
# with no such account is the failure mode to fear (a hollow gate looks green;
# measured once already, 271 comparisons reading a stale fixture). A moved
# digest WITH one is ordinary corpus growth — and a comment that forbids ever
# re-blessing turns into false authority the moment the corpus grows, which is
# exactly what happened between 2026-08-25 and now.
#
# SHARD COUNT (#1590). The default is the box's CORE COUNT — `TEST_JOBS`, the
# same detection the storm's `-j` uses — not the 8 the sharded mode shipped
# with: 8 was the 12-core devbox's number, and a 28-core box ran 8 shards with
# 20 cores idle. `EXTRACTION_GATE_JOBS=N` in the environment or on the make line
# caps it; `EXTRACTION_GATE_JOBS=1` is the serial mode, for a box sharing its
# cores with a load-sensitive run (INT-8). The verdict does not depend on N:
# every shard walks the same index sequence and the parent merges by index, so
# the transcript — and its digest — is byte-identical for any N (proven by the
# red-proof rows in _gate_evidence/pipeline_1590/RESULTS.md).
EXTRACTION_GATE_JOBS ?= $(TEST_JOBS)
LIBCX_ART      := deps/cx-core-code/vcx/target/$(LIB_NAME).$(if $(filter Darwin,$(shell uname -s)),dylib,so)
LIBCX_CORE_ART := deps/cx-core-code/vcx/target/libcx-core.$(if $(filter Darwin,$(shell uname -s)),dylib,so)
.PHONY: test-extraction-gate
# #902 — depends on the SHIPPED library (build-vcx), not build-vcx-dev.
# These gates dlopen $(LIBCX_ART); pinning them to the -prod artifact makes
# "which build is under test" a decision instead of a race, and it is the
# only honest subject for a gate — the dev library is not what ships.
test-extraction-gate: build-vcx build-profile-data
	@mkdir -p deps/cx-core-code/vcx/target/extraction_gate
	@$(V) -n -w -cc cc $(CX_GC) -o deps/cx-core-code/vcx/target/extraction_gate/probe deps/cx-core-code/vcx/tests/runners/extraction_gate/probe/
	@$(V) -n -w -cc cc $(CX_GC) -o deps/cx-core-code/vcx/target/extraction_gate/cli_gate deps/cx-core-code/vcx/tests/runners/extraction_gate/cli/
	@deps/cx-core-code/vcx/target/extraction_gate/probe $(LIBCX_ART) deps/cx-core-code/vcx/target/conformance-merged --min-cases=$(EXTRACTION_GATE_FLOOR) > deps/cx-core-code/vcx/target/extraction_gate/transcript_monolith.txt
	@deps/cx-core-code/vcx/target/extraction_gate/probe $(LIBCX_CORE_ART) deps/cx-core-code/vcx/target/conformance-merged --min-cases=$(EXTRACTION_GATE_FLOOR) > deps/cx-core-code/vcx/target/extraction_gate/transcript_core.txt
	@cmp deps/cx-core-code/vcx/target/extraction_gate/transcript_monolith.txt deps/cx-core-code/vcx/target/extraction_gate/transcript_core.txt \
	  && echo "extraction-gate ABI step OK — libcx-core transcript byte-identical to libcx ($$(wc -c < deps/cx-core-code/vcx/target/extraction_gate/transcript_monolith.txt | tr -d ' ') bytes)" \
	  || { echo "extraction-gate ABI step FAILED — transcripts diverge (see deps/cx-core-code/vcx/target/extraction_gate/)"; exit 1; }
	@deps/cx-core-code/vcx/target/extraction_gate/cli_gate --self-test
	@deps/cx-core-code/vcx/target/extraction_gate/cli_gate deps/cx-core-code/vcx/target/cx deps/cx-core-code/vcx/target/profiles/data/cx deps/cx-core-code/vcx/target/conformance-merged --min-cases=$(EXTRACTION_GATE_FLOOR) --jobs=$(EXTRACTION_GATE_JOBS)

# ── ABI GC-LIVENESS GATE (remediation R3.8 discovery) — a dlopen'd libcx
# built with -gc e must actually COLLECT: V only emitted vgc_init() in
# generated main() paths, so shared artifacts ran with gc_enabled=0 —
# unbounded embedder heap growth + a degenerate empty-pool span scan
# (~75x slower large parses through the ABI than in the cx binary).
# The gate churns each artifact past the pacer goal under VGC_GCTRACE=1
# and requires at least one gc cycle. Runs on both Ring artifacts.
# ── address-baseline-gate (#651/#516 stream-2 C9; RULED: L100) — the Tier-2
# byte-identity guard for the ONE-walk retirement. Recomputes every corpus
# def's Tier-2 address and diffs against the recorded baseline
# (deps/cx-core-code/vcx/tests/runners/address_baseline/tier2_addresses.txt). A moved or
# vanished address FAILS — no re-bless is available to this stream. Refresh
# the baseline deliberately with `make address-baseline-capture` only when
# NEW corpus defs are added (never to absorb a move).
.PHONY: address-baseline-gate
address-baseline-gate:
	@$(JS_CLOSE) log=deps/cx-core-code/vcx/target/address-baseline-gate.log; \
	  SU_RERUN='$(V) -no-skip-unused $(VFLAGS_VCX) run deps/cx-core-code/vcx/tests/runners/address_baseline/address_baseline.v'; \
	  if $(V) $(VFLAGS_VCX) run deps/cx-core-code/vcx/tests/runners/address_baseline/address_baseline.v > "$$log" 2>&1; then \
	    cat "$$log"; \
	  else \
	    cat "$$log"; \
	    $(SKIP_UNUSED_ESCAPE_PROBE); \
	  fi

.PHONY: address-baseline-capture
address-baseline-capture:
	@$(JS_CLOSE) $(V) $(VFLAGS_VCX) run deps/cx-core-code/vcx/tests/runners/address_baseline/address_baseline.v --capture

.PHONY: abi-gc-gate
# #902 — depends on the SHIPPED library (build-vcx), not build-vcx-dev.
# These gates dlopen $(LIBCX_ART); pinning them to the -prod artifact makes
# "which build is under test" a decision instead of a race, and it is the
# only honest subject for a gate — the dev library is not what ships.
abi-gc-gate: build-vcx build-profile-data
	@mkdir -p deps/cx-core-code/vcx/target/extraction_gate
	@$(V) -n -w -cc cc $(CX_GC) -o deps/cx-core-code/vcx/target/extraction_gate/abi_gc_gate deps/cx-core-code/vcx/tests/runners/abi_gc_gate/
	@deps/cx-core-code/vcx/target/extraction_gate/abi_gc_gate $(LIBCX_ART)
	@deps/cx-core-code/vcx/target/extraction_gate/abi_gc_gate $(LIBCX_CORE_ART)

# ── LIBCX ABI GATE (I3, partition spec §8 freeze direction) — the split
# changes module boundaries, never the export surface. Baseline captured at
# the I3 branch cut (7a38b6a6, `nm -gU` over the dev-shape libcx): 713
# exported symbols = 166 cx_* (the intentional ABI, incl. the two
# cx_iowatch_* C→V callbacks) + vendored C statics (zstd/re2 shim). V does
# NOT export module-mangled internals, so the full-list diff is stable
# across module splits — any diff means the shipped surface moved.
# Darwin-only for now: the baseline is per-platform (Mach-O vs ELF export
# semantics differ); a Linux baseline joins if/when the linux step runs
# TEST_TARGETS (it builds only today).
.PHONY: libcx-abi-gate
# #888: the gate checks the CX EXPORT SURFACE (cx_*/vgc_*, pinned) and
# HEADER/BINARY AGREEMENT (every include/cx.h entry point is exported).
# Vendored statics (re2/abseil/zstd — 543 symbols, toolchain-vintage
# dependent) are counted as an advisory, never asserted: the old full-nm
# diff went red on any dependency rebuild with no CX change. Symbol names
# are underscore-normalized, so one baseline serves Darwin AND Linux —
# the platform SKIP is retired.
# #902 — depends on the SHIPPED library (build-vcx), not build-vcx-dev.
# These gates dlopen $(LIBCX_ART); pinning them to the -prod artifact makes
# "which build is under test" a decision instead of a race, and it is the
# only honest subject for a gate — the dev library is not what ships.
libcx-abi-gate: build-vcx
	@tools/libcx-abi-gate.sh $(LIBCX_ART)

# ── I4 PROFILE CORPUS GATE (#651/#516, spec §4/§7) — each §4 profile builds
# and passes its ring-tagged corpus: the vcx recipe builds the full profile
# matrix (data/embed/cli; platform = the default build) and runs the
# profile_gate runner at the cli and embed engine compositions with binary
# probes. The data profile's corpus clause is test-extraction-gate (I2).
.PHONY: test-profile-gate
# #1449 — the matrix is a prerequisite, not the first thing the recipe does:
# inside one make invocation that puts the profile builds on the same DAG node
# `build-profiles-dev` occupies in the -j block, so a selection that runs this
# step beside test-extraction-gate builds each artifact once.
# #1560 (RULED: VCOST-1): `PROFILE_GATE_FILES="a.cxd b.cxd"` grades only the
# named corpus files. UNSET, the step is exactly what it was and grades
# everything — the unselected target and the union are untouched, and a selected
# run is an ADDITIONAL entry point rather than a narrowing of the merge gate.
# The selection a branch owes is
# `sh scripts/profile_gate_files_for_branch.sh origin/release/0.18`, whose rules
# are pinned by `make check-profile-gate-selection`.
PROFILE_GATE_FILES ?=
test-profile-gate: build-profiles-dev
	@$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx test-profile-gate PROFILE_GATE_FILES="$(PROFILE_GATE_FILES)"

.PHONY: check-profile-gate-selection
check-profile-gate-selection:
	@sh scripts/profile_gate_selection_selftest.sh

# ── check-verification-budget (#1562, RULED: VCOST-1) ─────────────────────────
# The owner's sentence — the fixture grader <= 20 min, a selected post-merge run
# <= 20 min, the union <= 60 min — as a STEP, because "a written bound has to be
# a step or it is a wish". The bounds live in scripts/verification_budget.cxd,
# one row each carrying the measurement that set it and the issue that last
# moved it; the measurements live in deps/cx-core-code/vcx/target/verification_timings.cxd, left
# behind by whatever ran. An IDLE measurement over its bound fails the run; a
# LOADED one is advisory with the load printed beside it; an absent one is
# reported and fails nothing. A bound moves only in a commit that names why.
#
# `--allow-env` is issue 1582: the timings PATH is read from
# $CX_VERIFICATION_TIMINGS when it is set, so the self-test plants under its own
# mktemp directory instead of at the path this step reads beside it in the same
# -j storm. Unset here, so this step reads the one real path as it always did.
.PHONY: check-verification-budget
check-verification-budget: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-verification-budget:
	@"$(CX_BIN)" --allow-read --allow-write --allow-env scripts/check_verification_budget.cx

.PHONY: check-verification-budget-selftest
check-verification-budget-selftest: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-verification-budget-selftest:
	@CX_BIN="$(CX_BIN)" sh scripts/verification_budget_selftest.sh

# ── check-storm-keep-going (RULED: RUN-2) ────────────────────────────────────
# The -j storm of `make test` runs with `-k`, so ONE failed run names EVERY red
# step instead of the first one. The selftest proves the semantics on two tiny
# planted targets through a scratch makefile (and its control, the same
# makefile without `-k`, proves the fixture discriminates) and then reads the
# real recipe: the storm line carries `-k` and the three serial tail lines
# still follow it as their own recipe lines, so a red storm still stops the
# gate before the tail.
.PHONY: check-storm-keep-going
check-storm-keep-going:
	@sh scripts/storm_keep_going_selftest.sh

# ── check-verification-timings (issue 1583, RULED: RUN-5) ────────────────────
# #1562's budget step shipped with no WRITER: every bound read NOT MEASURED and
# the step judged nothing. scripts/verification_timings_lib.sh is the writer the
# post-merge runner and the fixture grader both call; this step is its selftest,
# on planted files under mktemp and never at the real timings path.
.PHONY: check-verification-timings
check-verification-timings:
	@sh scripts/verification_timings_selftest.sh

# ── PER-RING GATE STEPS (#700 structural relief, activated at I4) — run the
# steps that cover the ring you touched instead of the full battery. Each
# step is a SUPERSET of the ones below it (a Ring-1 change can still break
# Ring 0). These are inner-loop dev steps; `make test` stays the merge gate.
#   test-ring0 — Ring-0 surfaces: vcx/cx in-module tests, the byte-identity
#                extraction gate, the libcx ABI freeze, the import/tag gates.
#   test-ring1 — + the evaluator: code+platform in-module tests, the §4
#                profile corpus gate (cli/embed compositions over the ring≤1
#                eval corpus), fmt conformance, effect alignment.
#   test-ring2 — + the platform battery: the full V suite (daemons, store,
#                fabric, xap) + conform-all. Near `make test` scope minus
#                the binding/doc/tooling gates.
.PHONY: test-ring0 test-ring1 test-ring2
test-ring0: test-vcx-cx test-extraction-gate libcx-abi-gate ring-import-gate ring-tag-gate gates-manifest-gate
test-ring1: test-ring0 test-vcx-code test-profile-gate check-effect-alignment
	@$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-fmt
test-ring2: test-ring1 test-vcx-suite test-vcx-cmd
	@$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-all

# ── RING QUERY (corpus audit §2 tagging mechanics; C8 repair, I0) — the
# ring-step corpus query, dog-food CX. Parameters via env: RING=0|1|2,
# LANE=doc|eval|both, FORMAT=summary|ids|count. `ring-tag-gate` is the
# no-parameter run wired into TEST_TARGETS: it hard-fails (exit 2) when any
# suite header lacks ring= — an untagged suite silently falls out of every
# ring step, which is exactly how C8's blanket-tag defect went unseen.
.PHONY: ring-query ring-tag-gate
ring-query: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
ring-query:
	@"$(CX_BIN)" --allow-read --allow-env --allow-write scripts/ring_query.cx
ring-tag-gate: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
ring-tag-gate: build-vcx
	@FORMAT=count "$(CX_BIN)" --allow-read --allow-env --allow-write scripts/ring_query.cx >/dev/null && echo "ring-tag-gate OK — every suite header carries ring=, and every suite under a ring DIRECTORY agrees with it (RULED: 1427-c); steps queryable via 'make ring-query'"

# Distribution-spec §9 checkable absences (fixture §11.8): the xap-dist engine
# (vcx/xap/stdlib_xap_dist.v) composes the store/did/vc/compose surfaces and
# ships NO parallel primitive — no own hashing, no archive format, no
# transport, no second compose gate.
# RETIRED from TEST_TARGETS (RULED: RS-12, RS-8, RS-7, RS-20; #1591 item K3):
# scripts/check_xap_dist_absences.cx left with cx-platform-xap's extraction,
# checking xap's own dist engine against xap's own absences list -- that
# repository's gate now, not this Makefile's.
#
# .PHONY: check-xap-dist-absences
# check-xap-dist-absences: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
# check-xap-dist-absences:
# 	@"$(CX_BIN)" --allow-read --allow-write scripts/check_xap_dist_absences.cx

# ── Shell-completion drift gate (#423) — the bash/zsh/fish completions in
# cx-tooling's tooling/completions/ (read from deps/cx-tooling/, the pin: they left
# with cx-tooling and the step stays here because it grades THIS tree's verb
# table, RULED: RS-12, D59a) must mention every subcommand in the vcx/cmd/main.v
# dispatch table (and none it doesn't have), and the `cx diagram` flag surface
# must match vcx/cmd/diagram.v (--format=mermaid|svg|png + -o; the fabricated
# --format=graphviz / --output= / --depth= surface must never reappear).
.PHONY: check-completions-drift
check-completions-drift: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
check-completions-drift:
	@"$(CX_BIN)" --allow-read --allow-write scripts/check_completions_drift.cx

# ── check-tmlanguage-sync / sync-tmlanguage (#423) RETIRED here (RULED: RS-12, D59a):
# both TextMate grammar copies left with cx-tooling, and the byte-identity check
# between them is that repository's own `make check` now -- it reads nothing of
# this tree.

# check-editor-surface-parity (#1171) — the editor surfaces vs the directive
# registry, held by a checked-in register that may only SHRINK.
#
# cx-tooling's `tooling/EDITOR_SURFACE_PARITY.md` (read with the three editor
# surfaces from deps/cx-tooling/, RULED: RS-12, D59a) carries one row per registry directive and
# one cell per surface column, each `yes` or `defer: #1171`. The gate re-derives
# every column from the surface itself and fails on ANY disagreement in BOTH
# directions — a `yes` the surface lacks, AND coverage the register still
# defers, which is what forces paying the debt down to update the register.
#
# Same shape as check-inmodule-test-roster (#1209) / check-build-input-roster
# (#1065), including their load-bearing arm: a derivation that produces NOTHING
# refuses to vouch rather than passing over an empty set.
#
# Two surfaces deliberately have NO column — tree-sitter and the Neovim
# vim-syntax both match a generic directive region, so a presence column would
# read 80/80 forever including for directives that do not exist. The register's
# header records that reasoning; the gate substitutes the one honest mechanical
# check available for Neovim (the head character class).
.PHONY: check-editor-surface-parity
check-editor-surface-parity: build-vcx-dev
	@deps/cx-core-code/vcx/target/cx-dev --allow-read --allow-write scripts/check_editor_surface_parity.cx

# registry-publish / registry-serve RETIRED here (RULED: RS-12, RS-8, D59a,
# D77d; #1591 item K3): registry/publish.cx, registry/keys/cx-home.cxd and
# registry/store/ left whole for cx-registry (RS-25-shaped gap — a
# ships=none package repo carries no V toolchain of its own yet, so unlike
# test-connector-real-lanes there is no lane to re-point the two targets
# through; cx-private's deps.cxd carries no row for cx-registry either,
# since this repo consumes none of its namespaces, RS-7). Run these two
# dev conveniences from a checkout of cx-home/cx-registry against a `cx`
# binary once that repository's own Makefile carries them (flagged, not
# fixed, in _gate_evidence/pipeline_xdecreg/RESULTS.md).

# Default parallelism: detected core count, override with `make test TEST_JOBS=N`.
# Measured speedup on a warm build: ~10× wall-clock vs sequential (342s → 33s).
TEST_JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8)

# Default `test` runs targets in parallel. `--output-sync=target` keeps each
# target's logs grouped instead of interleaved across processes.
# --output-sync needs GNU make >= 4.0 (Apple ships 3.81); pass it only
# when the running make advertises the feature.
OUTPUT_SYNC := $(if $(filter output-sync,$(.FEATURES)),--output-sync=target,)
test: export CX_GATE_OWNER := $(shell echo $$PPID)
test:
	# Take the machine-wide gate lock, QUEUEING behind a live holder rather
	# than refusing (#1346): a second gate wants a quiet box anyway, and the
	# session that used to be told "no" had nothing to do but retry by hand.
	# Released by the last line of this recipe on a normal finish, and by the
	# GATE_LOCK_TRAP prefix on every long line below when the gate is
	# INTERRUPTED — Ctrl-C, SIGTERM or a hangup — so the box is free the
	# instant the gate stops instead of at whatever time somebody next tries
	# to build. A trap cannot be installed once for the whole recipe (each
	# line is its own shell), which is why it is a prefix and not a header;
	# a hard kill or a crash still leaves the file, and that remains
	# check-gate-lock's stale-pid reclaim to clear.
	# The pins first (RULED: RS-7, RS-12): a head that pins a repository builds its
	# bundled sources from deps/<repo>/, and build-vcx REFUSES at deps-present when
	# they are absent — the post-merge run on 625389bda red in two minutes for it.
	# deps-sync is idempotent and fast at the pinned sha; it never warns.
	@$(MAKE) deps-sync
	@$(call GATE_LOCK_TAKE,make test)
	#
	# STEP-START / STEP-END (RULED: RUN-5, issue 1583). Every top-level line of
	# this recipe brackets itself with
	#
	#     STEP-START <utc> <name>
	#     STEP-END   <utc> <name> exit=<n>
	#
	# in the run log. Before this the 04:01Z pass on 84825d79f could only be
	# broken down by FILE MODIFICATION TIMES — the log carried no timestamps at
	# all — and "the serial tail was 02:37→04:01Z, the unselected profile gate
	# about seventy minutes of it" was an inference from mtimes rather than a
	# measurement. Five names, one per line below: prebuild, storm,
	# profile-gate, timing, diagram. The status is captured and re-raised with
	# `exit`, so a red line still fails the recipe exactly as it did.
	# Serial pre-build BEFORE the parallel fan-out: every step's recursive
	# `$(MAKE) build-vcx` then hits the vcx Makefile's up-to-date guard and
	# skips the relink — without this, concurrent sub-makes RELINKED
	# target/cx while sibling steps were exec'ing it (the v0.16.0 cut's
	# 'Exec format error' / empty-output-rc-0 class; see the guard's note).
	#
	# This covers the PROD half only. The dev half — nine `test-vcx-*` steps
	# whose `build-vcx-dev` prerequisite runs inside the storm — used to write
	# that SAME target/cx and clobber it back (#1312); it now writes
	# target/cx-dev, so the two halves no longer share a mutable artifact and
	# this pre-build is sufficient on its own.
	@$(GATE_LOCK_TRAP) echo "STEP-START $$(date -u +%FT%TZ) prebuild"; $(MAKE) build-vcx; cx_step_rc=$$?; echo "STEP-END $$(date -u +%FT%TZ) prebuild exit=$$cx_step_rc"; exit $$cx_step_rc
	# test-profile-gate runs SERIALLY AFTER the -j storm, not inside it. The
	# original reason (sup-011's "#951 load-race" under gate-wide -j) is gone
	# with #1228 — that was a deterministic evaluator defect, fixed — so the
	# serial tail now rests on the build-vcx relink guard above alone; folding
	# the profile gate back into the storm is #1227's measured call, not this one.
	# The Makefile-level serial retries work precisely because they run
	# after the storm drains; the profile gate gets the same quiet context.
	# Nothing is masked: a deterministic failure still reds the serial run,
	# and the runner's classifier + named re-grade govern inside it.
	#
	# Its BUILDS do not need that context (#1449, RULED: 1449-a). The three
	# profile binaries and the embed libcx are ordinary V compiles with no
	# probe and no wall-clock claim in them, and the quiet-context argument
	# above is about a load-induced binary PROBE failure — so they ride in the
	# storm as `build-profiles-dev` and the serial tail starts with binaries in
	# hand. Measured on the post-merge run on 44f328b0e: the tail was 18.5 min
	# of a 45.5-min run, the matrix builds at the head of it. The guard on each
	# profile recipe (vcx/Makefile, LIB_CORE_BUILD_ID) is what makes the tail's
	# own build a no-op rather than a second compile.
	#
	# `-k` (RULED: RUN-2). `make` stops at the first red step, so ONE failed
	# post-merge run named ONE class and the next run found the next one: on
	# 2026-09-18 ten failed runs at about 1.5 h each found seventeen classes,
	# under two per run, and the fix branch for a red head could only carry
	# what the last log happened to name. With `-k` the storm runs every step
	# it can and the log names EVERY red one, so the fix branch carries them
	# all before the next tip. Nothing else moves: the sub-make's status is
	# still non-zero on a red storm, so this recipe line still fails and the
	# three serial tail lines below still run only after a GREEN storm.
	@$(GATE_LOCK_TRAP) echo "STEP-START $$(date -u +%FT%TZ) storm"; $(MAKE) -k -j$(TEST_JOBS) $(OUTPUT_SYNC) build-profiles-dev $(filter-out test-profile-gate test-vcx-timing test-code-diagram,$(TEST_TARGETS)); cx_step_rc=$$?; echo "STEP-END $$(date -u +%FT%TZ) storm exit=$$cx_step_rc"; exit $$cx_step_rc
	@$(GATE_LOCK_TRAP) echo "STEP-START $$(date -u +%FT%TZ) profile-gate"; $(MAKE) test-profile-gate; cx_step_rc=$$?; echo "STEP-END $$(date -u +%FT%TZ) profile-gate exit=$$cx_step_rc"; exit $$cx_step_rc
	# #1216: the WALL-CLOCK assertions (the #1055 boot budget, the #816 try-send /
	# try-receive upper bounds) run serially AFTER the storm too — they are
	# properties of the binary, not of the box's load, and inside the -j
	# umbrellas they red on eight of nine gates in one day while measuring
	# 113 ms alone. Lower bounds ("timeout= actually waits") stay in the
	# umbrellas: load can only ADD time.
	@$(GATE_LOCK_TRAP) echo "STEP-START $$(date -u +%FT%TZ) timing"; $(MAKE) test-vcx-timing; cx_step_rc=$$?; echo "STEP-END $$(date -u +%FT%TZ) timing exit=$$cx_step_rc"; exit $$cx_step_rc
	# #1345 — test-code-diagram carries a 60 s wall-clock EMITTER budget, so it
	# belongs in the same serial tail for the same reason. Measured 2026-09-06,
	# same commit and binary: inside the -j12 storm `erd-001-empty` — the EMPTY
	# diagram case — blew the 60 s budget twice and errored; the whole 52-case
	# step runs 52/52 in 4.6 s alone. Taking over a minute on the empty case
	# while the full step finishes in five seconds is starvation, not work.
	#
	# An absolute budget that only holds on an idle box is not a property of the
	# binary, which is exactly what #1216 concluded for the two steps above; this
	# one was simply missed when they moved.
	@$(GATE_LOCK_TRAP) echo "STEP-START $$(date -u +%FT%TZ) diagram"; $(MAKE) test-code-diagram; cx_step_rc=$$?; echo "STEP-END $$(date -u +%FT%TZ) diagram exit=$$cx_step_rc"; exit $$cx_step_rc
	@rm -f "$(CX_GATE_LOCK)"

# Sequential fallback — useful for debugging output-order issues, sanitizer
# runs that want low concurrency, or environments where `-j` parallelism
# causes resource contention.
test-no-parallel: $(TEST_TARGETS)

# ── test-docs — the DOC PIPELINE (RULED: INT-10) ──────────────────────────────
# The post-merge pipeline is `make test` on the head (delivery grammar §4). On
# 2026-09-13 three of the ten post-merge runs graded heads that could not change
# a compiled test's outcome — two ledger-only heads and the docs half of a
# third — for about two hours of the ONE post-merge runner. INT-10's answer is
# this target: when the head's diff against the last head that PASSED is
# confined to documentation, the runner runs THESE seven steps instead of the
# whole TEST_TARGETS matrix.
#
# Which paths count is NOT decided here and not in the spec either — it is
# scripts/head_is_docs_only.sh, with scripts/head_is_docs_only_selftest.sh
# beside it, so the list has a test. This target only has to be the pipeline
# that list selects.
#
# The seven steps are every TEST_TARGETS row that reads documentation, the
# ledger, the approved spec tree or the version stamps — `verify-doc-links`
# joined that list with INT-11 (#1475), so the full run grades what this run
# grades — plus `verify-readme-blocks`, which the release gate runs and
# TEST_TARGETS does not:
#
#   verify-doc-blocks        every fenced cx block in docs-src/ still runs
#   verify-doc-links         every relative markdown link still resolves
#   verify-readme-blocks     the README's own blocks still run
#   docs-check               the generated docs/ layer is not stale
#   spec-freeze-gate         a spec+impl commit carries its recorded ruling
#   ledger-index-check       ledger/README.md still matches the decision store
#   check-version-consistency  every stamped manifest still matches VERSION
#
# Four of them need the binary, so the serial `build-vcx` pre-build comes first
# for the same reason it does in `test:` — concurrent sub-makes relinking
# target/cx while a sibling step execs it is the v0.16.0 'Exec format error'
# class.
#
# The LOCK is taken exactly the way `test` takes it. A doc run is still a
# post-merge run: it holds the main checkout, it must not start inside another
# gate, and check-gate-lock's stale detection (`kill -0` on the recorded pid)
# is what releases a killed one. Nothing about INT-10 makes a doc run a second
# concurrent gate.
DOC_TARGETS := verify-doc-blocks verify-doc-links verify-readme-blocks docs-check \
  spec-freeze-gate ledger-index-check check-version-consistency primer-platform-check

.PHONY: test-docs
test-docs: export CX_GATE_OWNER := $(shell echo $$PPID)
test-docs:
	@$(MAKE) deps-sync
	@$(call GATE_LOCK_TAKE,make test-docs)
	@$(GATE_LOCK_TRAP) $(MAKE) build-vcx
	@$(GATE_LOCK_TRAP) $(MAKE) -j$(TEST_JOBS) $(OUTPUT_SYNC) $(DOC_TARGETS)
	# The summary line is the shape scripts/gate-status.sh reads under "finished
	# steps" (`: <n> passed`) — a doc run writes no V-test summary, so without
	# this the run reader had nothing to show for a run that had finished every
	# step. The lock is released by the LAST recipe line, as in `test`.
	@echo "test-docs: $(words $(DOC_TARGETS)) passed, 0 failed (doc pipeline — RULED: INT-10)"
	@rm -f "$(CX_GATE_LOCK)"

# ── gate 37.10 — code_diagram / code_tree conformance ────────────
# Runs conformance/code_diagram.cxd through `cx code-diagram` and
# `cx code-tree` with structural-equivalence comparison. An all-SKIP
# run FAILS (RULED: PYE-6) and a missing binary is exit 2 — this tree's
# build or CX_BIN, never PATH (#929).
# #774: this checker is the ONLY gate that sees the ERD attribute-type
# rows and the diagram structure (the roundtrip suites in the eval-fixtures
# step compare trees, not emitted types), and for a long time it was wired
# into NO union target — so a real regression sat green for a whole stream.
# It is in TEST_TARGETS now. CX gate (#922, RULED: PYE-5): the former
# LIBCX_LIB_DIR pin is obsolete — nothing dlopens cxlib any more; the
# gate drives the tree's own cx binary end to end.
.PHONY: test-code-diagram
test-code-diagram: CX_RUNNER ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
test-code-diagram: build-vcx
	@"$(CX_RUNNER)" --allow-read --allow-write --allow-env --allow-subprocess scripts/check_code_diagram_fixtures.cx

# ── reader parity — ONE READER (RULED: CXF-5, #1521; epic #1522) ──────────
# CX has three doors into the same bytes: the DATA parser (vcx/cx/parser.v,
# which libcx's C ABI exports and the V fixture grader reads through), the
# PYTHON binding over that same libcx, and the PROGRAM reader
# (vcx/cx/program_lexer.v + program_parser.v). #1521 measured them answering
# three different things for one `[title …]` line — a swallow, a refusal, and a
# different refusal — and the only step that noticed was a case COUNT in the
# Python smoke. This step reads the corpus FILES through all three doors and
# fails naming the file and the first divergent case id. It is the standing
# form of CXF-5's rule, and it is in TEST_TARGETS.
#
# NOT a second copy of cxparse_full_corpus_diff_test.v: that census diffs the
# data and program readers over the `in_cx` SECTIONS of the corpus and locks
# bucket counts. This one reads the `.cxd` documents themselves — the position
# the defect lived in, which no step read.
#
# No `$(JS_CLOSE)` here, deliberately: its `exec … 2>/dev/null` silences the
# recipe shell's stderr for the whole line, and V's test runner reports a failed
# assertion there — a step whose contract is to NAME the file and the divergence
# printed eight lines of build chatter and nothing else until this came off.
.PHONY: reader-parity
reader-parity: build-vcx
	@$(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test vcx/tests/reader_parity_test.v

# ── gate 28.5a — CXPath / XPath 3.1 alignment, CX side (RULED: VC-7, #945) ─
# The half of the old gate 28.5 that needs no Docker and is real new signal:
# every case in conformance/xpath_31_parity.cxd evaluated by THIS tree's cx and
# graded against an expectation DERIVED from that same binary. Before VC-7 those
# 23 cases had no conformance/gates.cxd row and no step read them, so they ran
# NOWHERE while the register showed a gate. Normative reference:
# spec/02-working/cxpath_alignment.md. In TEST_TARGETS.
.PHONY: test-xpath-parity-cx
test-xpath-parity-cx: CX_RUNNER ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
test-xpath-parity-cx: build-vcx
	@"$(CX_RUNNER)" --allow-read --allow-write --allow-env --allow-subprocess scripts/check_xpath_parity_fixtures.cx

# ── gate 28.5b — the Saxon-HE cross-check (MANUAL, RULED: VC-7, #945) ─────
# Deliberately NOT in TEST_TARGETS and deliberately NOT automated: it needs
# Docker + network + the third-party saxonica/saxonhe:12 image, so wiring it
# would make `make test` fail or hang on any host without them. It is the only
# implementation-vs-external compliance check in the tree, which is why VC-7
# kept it rather than retiring it. Running it prints the operator recipe and the
# preconditions and exits 2 — it does not "skip cleanly", because a clean skip
# is what let the old breakage sit unexamined for months. The CX side of the
# same corpus is gate 28.5a above and DOES run in every `make test`.
# Full contract: conformance/GATE_REGISTER.md rows 28.5a/28.5b and the header of
# scripts/test_xpath_parity.sh.
.PHONY: test-xpath-parity
test-xpath-parity: build-vcx
	@CX_BIN=$(CURDIR)/deps/cx-core-code/vcx/target/cx bash scripts/test_xpath_parity.sh

# ── v0.8.0 gates 28.6 + 28.9 — Layer-1 binding-API parity ────────────────
# RETIRED (RULED: RS-12, RS-8; #1591 item K3): the four active bindings this
# gate ran (V / Python / Go / Rust, per d-2026-05-22-03) left cx-private whole
# as cx-home/cx-binding-{v,python,go,rust} — `lang/<lang>/binding_api_driver/`
# is gone from this tree, and the step's only inputs with it. cx does not pin
# any binding (no deps.cxd row), so nothing in this repository can drive all
# four any more. No successor runs the FOUR-WAY parity check today: each
# binding repo's own `make check` is deps-check alone (its build is OWED,
# per its own REPORT-REPO.md) and has no per-binding test wired in yet either
# — see RESULTS.md's LETTER. `scripts/test_binding_api_parity.sh`,
# `scripts/check_binding_api_jsonl.cx` and `scripts/compile_binding_api_fixtures.cx`
# stay tracked here (registry/repos.cxd: repo=cx, not a binding path) but are
# unwired and unreachable from any Makefile target until a future decision
# gives the front door (`cx`) its own pin on all four to re-drive them.
#
# Pin the Python binding to the freshly-built libcx (vcx/target) so the gate
# tests THIS build, not whatever libcx is installed system-wide. The cxlib
# loader (lang/python/cxlib/cx.py) checks /usr/local/lib and /opt/homebrew/lib
# BEFORE the repo build, so a stale installed libcx.dylib silently shadows the
# fresh one — which is exactly how a pre-`[; …]`-migration install made the
# gate report spurious comment-parse failures. LIBCX_LIB_DIR (loader priority 2)
# wins over the system paths. Go/Rust already pin vcx/target via rpath.
#
# C-level ABI conformance test (Phase 7.74c-abi-c-test). Compiles a
# small C harness against libcx + libcx_arrow under UBSan, then runs
# it. Catches the boundary-surface bugs binding rollouts have surfaced
# (size-header garbage, double-free on Export error, NULL-input
# rejection) at the source instead of via N binding rollouts. See
# spec/abi.md §1.5 / §2.10 / §2.11 for the surface;
# deps/cx-core-code/tests/abi/c_abi_test.c for what is exercised.
#
# Sanitizer choice: UBSan only by default. Apple clang's AddressSanitizer
# runtime on macOS 26 (Tahoe) deadlocks during AsanInitInternal —
# malloc re-enters the asan interceptor before init completes, the
# spin lock yields forever in StaticSpinMutex::LockSlow. The bug is
# in __sanitizer_mz_malloc → AsanInitFromRtl, present whether or not
# MallocNanoZone is disabled. Until Apple ships a fix or we adopt
# Homebrew LLVM as a build dep, ASan stays disabled here. UBSan
# alone reliably catches the integer-overflow / null-deref / out-of-
# bounds-load classes the boundary surface is most likely to expose.
# To opt back into ASan when running on Linux or with Homebrew clang,
# set ABI_C_TEST_SAN=address,undefined when invoking make.
ABI_C_TEST_BIN := deps/cx-core-code/vcx/target/c_abi_test
ABI_C_TEST_SAN ?= undefined
ifeq ($(UNAME_S),Darwin)
 ABI_LIB_PATH_VAR := DYLD_LIBRARY_PATH
 ABI_ARROW_LIB := deps/cx-core-code/vcx/target/libcx_arrow.dylib
else
 ABI_LIB_PATH_VAR := LD_LIBRARY_PATH
 ABI_ARROW_LIB := deps/cx-core-code/vcx/target/libcx_arrow.so
endif
#
# #984 — the harness also pins the LIBRARY's version stamp against the built
# artifact. The two derived inputs come from the ONE implementation of the rule
# (vcx/Makefile's CX_VERSION / CX_RELEASE, read back through print-%, the #979
# precedent) rather than being re-derived here; the harness independently
# restates what libcx must then report. --no-print-directory: `make -C`
# otherwise brackets the value with Entering/Leaving lines.
MAKE_PRINT_VCX = $(shell $(MAKE) -s --no-print-directory -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx print-$(1) 2>/dev/null | tail -1 | tr -d '[:space:]')
abi-c-test: build-vcx build-lib-arrow
	$(CC) -std=c11 -Wall -Wextra -Werror -g -O1 \
	 -fsanitize=$(ABI_C_TEST_SAN) \
	 -I deps/cx-core-code/include -I $(CXD)/vcx/arrow \
	 deps/cx-core-code/tests/abi/c_abi_test.c \
	 -L deps/cx-core-code/vcx/target -lcx -ldl \
	 -o $(ABI_C_TEST_BIN)
	CX_EXPECT_VERSION='$(call MAKE_PRINT_VCX,CX_VERSION)' \
	 CX_EXPECT_RELEASE='$(call MAKE_PRINT_VCX,CX_RELEASE)' \
	 $(ABI_LIB_PATH_VAR)=deps/cx-core-code/vcx/target $(ABI_C_TEST_BIN) $(ABI_ARROW_LIB)

# test-rust / test-rust-arrow / test-rust-parquet / test-rust-arrow-conformance
# RETIRED with the Rust binding (RULED: RS-12, RS-8; #1591 item K3):
# cx-home/cx-binding-rust now owns lang/rust/, cx does not pin it, and this
# tree has no rustc/cargo target left to drive.

# conform-all now covers EVERY suite in one process (the runner's
# default list was extended at the #795 batch, 2026-08-15 — the
# transparency/chunked/compression/schema/atoms/delimited/yaml/
# conversions suites were previously OUTSIDE every union target, the
# #743-battery unwired-gate class; and the per-suite `conform`
# aggregate fan-out OOM-killed the parallel union with 27 concurrent
# `v run` compiles). The Arrow step rides its own runner/target.
# ── the cheap consistency gates, folded into the development step (#1101) ──
#
# WHY. `make test-vcx` is what sessions and handoff notes call "the exit
# gate", but it is a strict SUBSET of `make test`. Two gates sat RED on
# release/0.18 and survived a release-branch cut because of that:
# guide-check (since #1078 — two zip [fn-doc] examples never backed by a
# fixture) and check-v-fork (since the dynamic-Huffman fork commit).
#
# These six cost seconds each next to the V compiles, so there is no reason
# a development step should skip them. They run against the DEV binary
# test-vcx already built — depending on build-vcx here would drag a whole
# prod relink into the fast step, which is the cost that kept them out.
#
# The expensive gates stay in `make test` alone: test-profile-gate (which
# caught two of the three defects in the #1090 step), check-prod-build,
# docs-check, and the language-binding steps. test-vcx is a BETTER subset
# now, not the full matrix — a wave still exits on `make test`.
.PHONY: test-vcx-gates
test-vcx-gates: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
test-vcx-gates: build-vcx-dev
	@"$(CX_BIN)" --allow-all scripts/check_v_fork_patches.cx
	@"$(CX_BIN)" --allow-all scripts/check_portable_links.cx
	@"$(CX_BIN)" --allow-all scripts/gen_guide/stdlib_docs_check.cx
	@"$(CX_BIN)" --allow-all scripts/gen_guide/directive_docs_check.cx
	@"$(CX_BIN)" --allow-all scripts/stdlib_catalog_gate.cx
	@bash scripts/cxer_registry_report.sh --strict

test-vcx: build-vcx-dev test-vcx-gates test-vcx-suite test-vcx-code test-vcx-cmd test-vcx-cx
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-all
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-fmt
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-data-bin-arrow
	# #1134 — see the test-vcx-conform block below. diff.cxd / lint.cxd left
	# conform-all's suite list (34 vacuous PASSes) and are graded by their own
	# runner here, which no `make test` step reached before.
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-diff
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-lint
	# RULED: R5.8 (#860) — the corpus/spec agreement gates run IN THIS STEP now.
	# Both were in TEST_TARGETS but not a test-vcx dependency, so a green full
	# `make test-vcx` never executed them: check-code-spec-consistency sat red
	# from 2026-08-17 (a directive-extractor bug plus an unallowlisted impl
	# anchor) straight through a run recorded as green. A gate in the roster but
	# not in a step that runs is indistinguishable from no gate.
	$(MAKE) check-code-spec-consistency
	$(MAKE) check-code-fixtures
	# RULED: R6.3 (#832) — spec-freeze-gate runs IN THIS STEP now, wired only
	# after R6.1/R6.2 made it green (R5.8's order). It sat in TEST_TARGETS
	# while 13 violations accumulated across six work streams over three days
	# of green test-vcx runs — the discipline did not decay, the feedback loop
	# was disconnected.
	$(MAKE) spec-freeze-gate

# ── test-vcx-conform (RULED: VC-22) — the conformance aggregates, as their
# OWN step. `test-vcx` used to be the single TEST_TARGETS row for the whole V
# side: five ring test steps PLUS these three aggregates. That umbrella made
# ring-precise selection impossible — a change anywhere under vcx/ selected
# all five ring steps, because the gate could only see one node.
#
# TEST_TARGETS now names the five ring steps individually, so
# scripts/test_changed.sh can skip the ones a change cannot reach. These three
# aggregates were the ONLY work the old umbrella contributed that no other
# TEST_TARGETS row already carries (check-code-spec-consistency,
# check-code-fixtures and spec-freeze-gate are their own rows), so they get a
# step rather than being dropped — splitting the umbrella must not narrow the
# release gate by one target.
#
# `test-vcx` itself is UNCHANGED and stays the human entry point: `make
# test-vcx` still runs everything the V side owns in one command.
#
# #1134 — conform-diff / conform-lint are step members now. conform-all's
# runner used to list diff.cxd / lint.cxd and print PASS for all 34 of their
# cases WITHOUT running them (it has no branch for their assertion shape), so
# this step's count included 34 fictions. Dropping the suites from that list
# made the count honest and revealed the other half of the defect: the runner
# that DOES grade them — tests/runners/diff_lint/diff_lint_conform.v, reached
# only through `make -C vcx conform` — was in no `make test` step at all
# (`conform` is invoked by `conform-vcx`, which is not in TEST_TARGETS). The
# vacuous count was therefore standing in for the real gate. Both halves land
# together: the fiction is gone AND the two suites are graded here.
.PHONY: test-vcx-conform
# #1212: this is the DOCUMENT step — conform-all's runner refuses [in-code …]
# fixtures by design (#1134), so conformance/code.cxd (the largest corpus) and
# conformance/stdlib/*.cxd are graded by test-vcx-code's eval step and the
# profile gate, diff/lint by their own runner below, and every other suite by a
# named step. check-conformance-coverage (in TEST_TARGETS) asserts that map on
# every gate; the banner says it so a green here is read for what it covers.
test-vcx-conform: build-vcx-dev
	@echo "test-vcx-conform covers the DOCUMENT suites (conform-all's list) + fmt + data-bin-arrow + diff + lint + streaming-write; code.cxd and stdlib/*.cxd are the eval step's (test-vcx-code, test-profile-gate) — see check-conformance-coverage"
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-all
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-fmt
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-data-bin-arrow
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-diff
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-lint
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-streaming-write

# Convenience wrapper: run the full V suite ONCE, stream live output to a
# log, then print a digest of just the FAIL lines + per-file counts + the
# skipped-with-reason steps (#318 — absent prerequisites, counted separately,
# never failures). Uses `bash -o pipefail` so the recipe exits with the real
# `test-vcx` status (a plain `... | grep` would mask failures behind grep's
# exit code).
.PHONY: test-vcx-summary
test-vcx-summary:
	@bash -o pipefail -c '$(MAKE) test-vcx 2>&1 | tee /tmp/cx-test-vcx.log'; st=$$?; \
	echo "──── failures / skips / counts ────"; \
	grep -iE '^FAIL|[0-9]+ passed, [0-9]+ failed|[0-9]+ errored|^SKIP |step\(s\) SKIPPED' /tmp/cx-test-vcx.log || true; \
	echo "full log: /tmp/cx-test-vcx.log"; exit $$st

# ── V-side unit + fixture-runner suite ────────────────────────────────────
# Runs the entire deps/cx-core-code/vcx/tests/ corpus: the conformance fixture-runners
# (code_*_test.v against conformance/code.txt et al.) plus the per-feature
# unit tests (CXPath axes, [?match], [?modify], atoms, [?def], [?lib]/
# [?const]/lockfile, [?expr], purity, code_diagram/code_tree, the C ABI
# surface, stdlib modules, net/http real-socket behavior, …). Test files are
# named for what they cover — NO version prefix (the single VERSION file is
# the only place a version lives). Wired into TEST_TARGETS via the `test-vcx`
# umbrella above.
# v0.9.0 — the V-impl gate compiles the vcx test corpus under cx's default
# memory model, architecture E (`-gc e`): Perceus RC front line + precise STW vgc
# backstop. CX_GC is overridable (e.g. `make CX_GC='-gc boehm' test-vcx-suite`) to
# A/B against the prior collector. Only the FORK `$(V)` implements `-gc e`; the
# bare-`v` lang/v reference paths below stay on the upstream default.
CX_GC ?= -gc e
# Default DB engines (#520) — mirrors vcx/Makefile CX_ENGINES: the shipped
# artifact carries sqlite + redis, so the test gate compiles the suite with the
# same gates. This makes the $if-gated engine tests (deps/cx-core-code/vcx/code/sql_test.v,
# redis steps) and the engine-dependent conformance fixtures
# (conformance/platform/db.cxd success/denial steps) actually run — the gate
# tests the BEHAVIOR the artifact ships. Override CX_ENGINES='' to gate an
# engine-free build (then db.cxd's engine steps are expected red; see the
# fixture doc-comment).
CX_ENGINES ?= -d cx_db_sqlite -d cx_db_redis
# `v test dir/` compiles EACH `*_test.v` as its own standalone executable, and
# with no cache every one recompiles the whole graph (builtin + os + all vcx
# modules) from scratch — the dominant cost is the per-file clang subprocess.
# `-usecache` C-compiles each unchanged module ONCE and reuses the object across
# every test binary (and across re-runs): the first file pays a cold tax, the
# rest reuse the shared `vcx`/`builtin`/`os` objects. Cache-safe with `-gc e` —
# the cache salt folds in the gc defines + `cc` + cflags + lookup path
# (third_party/v/vlib/v/pref/default.v), so different flags get distinct buckets.
# Overridable to A/B: `make CX_CACHE= test-vcx-suite` disables it.
CX_CACHE ?= -usecache
# #318 — a step whose environment prerequisite is absent (e.g. deps/cx-core-code/vcx/target/cx
# not built in a bare out-of-tree checkout) SELF-SKIPS with a named reason via
# vcx/testenv (exit 0, never failing-as-regression) and records the reason in
# this ledger. Plain `v test` suppresses passing-step output, so the digest is
# printed LOUDLY after the run — skips are counted separately, never silently.
#
# ── The ledger is a DIRECTORY, one file per writer (#1013) ───────────────────
# It used to be a single append-target file that test-vcx-suite truncated at
# the top of its own recipe. That is a lost-update race under `make -j`: the
# writers are three independent make targets — test-vcx-suite (via the
# vcx/testenv steps it runs), test-vcx-columnar, and, since #989,
# test-vcx-sqlite — and nothing ordered the truncation before the appends. A
# sqlite or columnar self-skip that landed BEFORE test-vcx-suite reached its
# `rm -f` was erased, so the digest under-reported. stdout still carried the
# SKIP line, so nothing went fully silent — which is exactly why it could sit
# there: the digest, the surface a reader is told to trust for the count, was
# the only thing wrong.
#
# Two properties fix it, and both are needed:
#
#   (1) NO SHARED WRITE TARGET. Every writer owns one file named after itself
#       and TRUNCATES it (`>`), never appends to a file another writer touches.
#       Concurrency is then irrelevant — there is no interleaving to lose. It
#       also de-duplicates: a step re-run by the classified serial retry below
#       overwrites its own line instead of logging the skip twice.
#
#   (2) A RESET THAT HAPPENS-BEFORE EVERY WRITE. Clearing the directory inside
#       one writer's recipe would reintroduce (1)'s race at directory level, so
#       the reset is its own .PHONY target that every skip-producing step names
#       as a prerequisite. make runs a shared prerequisite exactly once per
#       invocation and completes it before any dependent recipe starts, under
#       -j included — so the ordering is a property of the dependency graph
#       rather than of recipe timing.
#
# The digest merges the directory at read time (`cat` + `wc -l` over the
# merge), which is what the old single-file consumer did to the concatenation
# it was hoping for.
CX_SKIP_DIR := deps/cx-core-code/vcx/target/test-skips.d
# Writers name their own file; `$(call CX_SKIP_FILE,<writer>)` builds the path.
CX_SKIP_FILE = $(CX_SKIP_DIR)/$(1)

# skip-ledger-reset — property (2) above. Ordered before every writer by being
# a prerequisite of each, so it can never race an append. Cheap and idempotent:
# the whole point is that it runs once, early, and is never re-entered.
.PHONY: skip-ledger-reset
skip-ledger-reset:
	@rm -rf $(CX_SKIP_DIR)
	@mkdir -p $(CX_SKIP_DIR)

# ── fixtures-census-reset (#1448, RULED: 1448-a) ────────────────────────────
# The same property, and the same argument, as skip-ledger-reset above. Each
# grader shard writes deps/cx-core-code/vcx/target/fixtures/<shard>.census and
# scripts/fixtures_census.sh sums them into #1026's one `stdlib corpus: …`
# line; a census left over from an EARLIER run would be summed into this one,
# and a total that counts cases nobody graded this run is worse than no total,
# because it is believed. One file per writer, so no writer can lose another's
# line and none can race; the truncation is a prerequisite of the suite rather
# than a line inside one writer's recipe, which is exactly the lost-update the
# skip ledger paid for under `make -j`.
.PHONY: fixtures-census-reset
fixtures-census-reset:
	@rm -rf deps/cx-core-code/vcx/target/fixtures
	@mkdir -p deps/cx-core-code/vcx/target/fixtures

.PHONY: test-vcx-suite
# On a suite failure the recipe retries EXACTLY the steps that failed, each
# under the retry class it belongs to — never a fixed proxy list (#572: the
# old shape retried only the socket steps on ANY failure, so an unrelated
# failure that coincided with green socket retries was mislabeled "load
# flake" and the gate exited 0 on a step nobody re-ran):
#   • a step in SUITE_SERIAL_RETRY (real-socket contention: ephemeral-port /
#     deadline races, each repeatedly proven green in isolation) → one
#     serial retry, same flags;
#   • any step whose -j run died in a C compilation error → one serial
#     retry WITHOUT -usecache (#572: a stale cache layer can inject a
#     duplicate V-runtime symbol, e.g. ___v_thread_wait; cache-free green
#     proves the artifact — the cache-key root fixes LANDED as #700 wave 2
#     (canonical keys, provenance manifests, inline-vs-linked discipline) and
#     #971 removed the muldefs mask; the retry stays as defense-in-depth
#     until a measured run justifies removing it);
#   • anything else → a real failure, no retry, gate stays red.
#   • code_eval_fixtures_test.v was on this roster 2026-08-23 → 2026-09-03 for
#     the "#951 supervise load-race" — which #1228 showed was a deterministic
#     evaluator defect (a monitor [?receive] ignoring deadline=), fixed at
#     6e80897b0; six full gates after the fix retried nothing, so that entry
#     was RETIRED. It is BACK 2026-09-13 (#1432, RULED: 1432-a) for a
#     DIFFERENT cause — the timing / early-exit class below, an exit with no
#     assertion at all, not a case answering wrong. A case that FAILS there is
#     still a real failure: the retry re-runs the step, and a deterministic
#     wrong answer fails again.
SUITE_SERIAL_RETRY := deps/cx-core-code/vcx/tests/env_retention_test.v \
                      deps/cx-core-code/vcx/tests/process_pty_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_1_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_2_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_3_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_4_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_5_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_6_test.v \
                      deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_7_test.v

# ── the grader's SHARDS carry its roster row too (#1448, RULED: 1448-a) ─────
# 1448-a split the eval lane's stdlib walk out of code_eval_fixtures_test.v and
# across code_eval_fixtures_shard_<k>_test.v so the V runner's parallel jobs
# carry it. The #1432 class below is a property of the GRADER, not of the file
# it happened to live in — an early exit with no assertion while a parallel step
# relinks libcx.dylib can happen in any of them — so every shard inherits the
# row. A roster that named only the driver would have silently dropped the
# class for five of six processes; `check-serial-retry-rosters` holds every row
# to an existing file, and `check-fixture-shard-manifest` holds the shard set
# and the manifest to each other.

# ── http_umbrella_test.v joined the real-socket class (#1445), historical ──
# The post-merge run on ca5cb0996 (2026-09-13 22:48Z–23:09Z) failed ONLY at
# http_umbrella_test.v:1687 test_directive_resource_sees_post_body — "directive
# POST #0 got no response" — with the 15-minute load average at 27 (six
# pre-merge pipelines building after a session restart). The merge under test
# touched the Makefile rosters, bench/repr/run.sh and a ledger page: nothing
# under vcx/ or http. The same file had passed on 1076e6f57 minutes earlier and
# in every run that day; the re-run on the same head (23:11Z–23:53Z, load under
# 5) passed. A real-socket request that gets no response under that load is the
# class the row above already names; the assertion and its timeouts are not
# changed. RETIRED FROM THIS ROSTER (RULED: RS-12, RS-24, #1591 item 20):
# http_umbrella_test.v, http_h2_serve_test.v, http_client_tls_transport_test.v,
# net_dtls_test.v, net_real_socket_test.v and net_udp_read_deadline_test.v left
# with cx-platform-net's leave step — its own CI grades them now, from the
# same pin this tree compiles cxnet from.

# ── connector_live_test.v / connector_webhook_test.v RETIRED FROM THIS ROSTER
# (RULED: RS-12, RS-8, RS-27; #1591 item K3) — deps/cx-core-code/vcx/tests/connector_* left with
# cx-platform-connector's extraction, byte-identical, into the pinned
# repository's own deps/cx-core-code/vcx/tests/. The lane still boots `reference/acme/
# acme.mock.cx` — an in-tree [?http-service] — on a loopback port, so it still
# binds a port and contends for one under -j exactly as the http/smtp/imap
# rows above do; a `ships=package` repo carries no V toolchain of its own
# (RS-25), so THE LANE MOVED AND THE STEP DID NOT (the test-sso-interop-lane
# shape): `make test-connector-real-lanes` below runs it out of
# deps/cx-platform-connector/vcx/tests/, against this tree's binary, with no
# serial-retry wrapper of its own (the sso/agent lane precedent).

# ── The TIMING / EARLY EXIT UNDER LOAD class (#1432, RULED: 1432-a) ─────────
# Two rows above carry this class rather than a socket or a daemon cause. Both
# come from the post-merge run on 5193e3752 (2026-09-13 03:20Z–03:51Z), which
# ran at load averages of 190–218 because two pre-merge pipelines were building
# at -j on the same box. Four steps failed; the two with a class passed their
# serial retry, and these two had none, so the run failed on them:
#
#   • deps/cx-core-code/vcx/code/code_module_umbrella_test.v — test_retry_without_delay_does_not_
#     suspend read `42ms elapsed` against its 40 ms bound. That row is a WALL
#     CLOCK control (it keeps test_retry_backoff_really_suspends's 60 ms floor
#     from being met by any slow evaluator), so under a load of 200 it measures
#     the machine. Nothing in that head's merges (#1394 routes, #1405/#1292,
#     release notes) touches the retry path. The 40 ms bound is NOT loosened —
#     widening it is what would make the pair vacuous (1432-a).
#
#   • deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v — `FAIL [11/66] C: 405943.8 ms,
#     R: 13832.684 ms` with NO assertion text. The grader runs 20+ minutes over
#     4583 fixtures, so a 13.8 s exit is a process that DIED, not a case that
#     answered wrong; the run log shows a parallel step relinking libcx.dylib /
#     cx in the same minute. The same tree's fixtures passed on the branch.
#     The grader now states the cx build identity (the .buildid stamp and its
#     #1056 .writer sidecar) in its first line and re-reads it at its first
#     failure, so a stamp that MOVED between the two reads names a mid-run
#     relink in the grader's own log instead of in a cross-step correlation.
#
# Both keep every assertion they had: the class re-RUNS the step, so a
# deterministic failure fails again on the retry and the run stays red.

# ── The MEMORY GAUGE UNDER LOAD class (#1431, RULED: 1431-a) ────────────────
# The two rosters above hold `v test` steps, matched against the paths the
# suite reports. `repr-guard` is neither — it is its own target running one
# script — so it needs its own roster row, and it needs one for the same
# reason the others do: it is an INSTRUMENT whose reading moves with machine
# load, and a reading is not a regression.
#
# bench/repr measures live bytes ÷ input bytes after a forced collection. The
# ratio was chosen over an RSS or a duration precisely because it survives a
# loaded box (RP-5(a)(ii); measured identical under eight saturating CPU
# burners), and that holds — up to a point far past eight. The post-merge run
# on 984cd3c99 read xml at 8.941x against the 8.35x bound at a load average of
# ~300 (a full-union test-changed at -j12 plus five agents building); the merge
# was LEDGER-ONLY, byte-identical to 469ec08e7, whose run passed the same step
# four hours earlier, and the retry on the same head passed. Under -gc e the
# collection point moves with scheduler pressure, so at that load the gauge
# reports the machine.
#
# The class is therefore ONE serial re-measurement, and it is deliberately
# narrow: only a BOUND EXCEEDANCE re-measures. A driver that exits non-zero, a
# measurement that does not parse, or a second exceedance is a real failure and
# reds the run — the ratchet keeps its teeth, and `BOUND_xml` is NOT re-pinned
# to accommodate a load reading (RP-5: the ratchet is never loosened for a
# regression, and a bound widened for load cannot catch one).
#
# The sibling gauge is cmp-005-fd-streaming-write-bounded-memory (#1364), which
# answered FAIL / PASS / PASS on three runs of identical code until 1364-a moved
# it into a process of its own. It carries no roster row because it is not a
# step: it is one fixture inside the conformance runner, and its isolation fix
# is where its load sensitivity was addressed.
GAUGE_SERIAL_RETRY := bench/repr/run.sh

# The retry ROSTERS above say WHICH steps get a serial retry. This says WHY,
# PER STEP. The emitted line used to read "serial retry (known real-socket
# contention step)" for every step in either roster, which became a false
# statement the moment code_eval_fixtures_test.v joined on 2026-08-23 (its cause
# was then believed to be a supervise load-race — retired with #1228 — and it
# held no socket) and stays false while process_pty_test.v is on it. A log
# line that asserts a single cause for a heterogeneous roster sends whoever
# reads it after a red gate looking in the wrong place.
#
# The default branch is deliberately LOUD rather than a guessed cause: a step in
# a roster with no declared reason still GETS ITS RETRY — the retry mechanism is
# load-bearing and is not weakened here — but the log says the reason is
# undeclared instead of inventing one.
RETRY_REASON_CASE = case "$$rel" in \
	  deps/cx-core-code/vcx/tests/process_pty_test.v) \
	    reason="\#1125 pty master read races under the -j12 suite storm (empty child output); green in isolation and in the prior full run" ;; \
	  deps/cx-core-code/vcx/tests/store_remote_umbrella_test.v) \
	    reason="\#1425 daemon start under the -j12 suite storm (the readiness window expires before the listener line); green in isolation and in every prior full run" ;; \
	  deps/cx-core-code/vcx/tests/connector_live_test.v) \
	    reason="real-socket contention: ephemeral-port / deadline race under -j" ;; \
	  vcx/store/store_admin_plane_test.v|vcx/store/store_grpc_live_test.v|vcx/store/store_lazy_load_test.v) \
	    reason="real-socket contention: live store/grpc endpoint under -j (\#648)" ;; \
	  deps/cx-core-code/vcx/code/code_module_umbrella_test.v) \
	    reason="\#1432 timing under load: test_retry_without_delay_does_not_suspend is a WALL-CLOCK control row (delay=0 must cost < 40 ms) and read 42 ms at load 190-218 while two pipelines built at -j; nothing in that head touched the retry path, and the bound is NOT loosened" ;; \
	  deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v|deps/cx-core-code/vcx/tests/code_eval_fixtures_shard_*_test.v) \
	    reason="\#1432 early exit under load: the grader runs 20+ minutes over 4583 fixtures, and the failing run exited after 13.8 s with NO assertion while a parallel step relinked libcx.dylib/cx; the step's first line and its first failure now name the cx build identity, so a mid-run relink says so itself" ;; \
	  deps/cx-core-code/vcx/tests/env_retention_test.v) \
	    reason="\#1597 memory gauge under load: the bytes twelve connector loads retain over what two retain, read after forced collections, moves with the -gc e collection point under a -j storm (3.6 in the -j28 storm on 7ac722830, 98.4x in the storm on 684a12502, 0.05 idle); the 3.0 bound is NOT loosened" ;; \
	  bench/repr/run.sh) \
	    reason="\#1431 memory gauge under load: live-bytes/input-bytes moves with the -gc e collection point under a -j storm (read 8.941x against 8.35x at load ~300 on a LEDGER-ONLY head byte-identical to one that passed the same step four hours earlier; the retry passed)" ;; \
	  *) \
	    reason="NO REASON DECLARED for this step -- retried anyway; declare it in RETRY_REASON_CASE in the Makefile" ;; \
	esac

# The profile gate grades the SAME supervise fixtures as
# code_eval_fixtures_test.v but is not a `v test` step, so no roster above
# reaches it. It used to carry its own serial re-grade class (#1054) for the
# "#951 supervise load-race"; #1228 showed that race was a deterministic
# evaluator defect and fixed it, and the class was RETIRED with #1228 — the
# runner reports every failure once and stays red.

# The cache-free class is NO LONGER A RETRY — it is a DIAGNOSTIC that never
# changes the verdict (#700 wave 2 part ii). It was written when the -usecache
# key was unsound by reputation, so "cache-free green proves the artifact" was
# the best available answer. Part (i) made the key PROVABLY sound
# (make check-vcache-soundness, 16 behavioural probes, red-proven), which
# inverts the conclusion: if a cached build fails where a cache-free build
# passes, the cache produced a failure the soundness gate did not catch. That
# is a gate ESCAPE — the single most valuable signal this tree can emit about
# the cache — and turning it green is how it stays hidden.
#
# This is not hypothetical. 2026-08-25, rolling -usecache onto the first
# NON-TEST binary build surfaced `ld: symbol(s) not found` for
# builtin__closure__closure_init: three mechanisms each assumed the closure
# runtime was inside builtin.o while it was in no object at all (fork fix
# 46f1be51d5, gate probe H11). A verdict-flipping retry on that step would
# have reported green and the defect would still be in the tree.
#
# So the cache-free run still HAPPENS — it is the classifier, and its outcome
# is the diagnosis — but `st` is never cleared by it:
#   cache-free PASSES  → GATE ESCAPE, loud, red, with the capture recipe;
#   cache-free FAILS   → an ordinary real failure, red.
# The serial-retry (socket / pty) class is untouched and still flips its
# verdict: those steps hold real sockets and their flakiness is environmental,
# not a statement about compiler correctness.
# NOTE for editors: this is a make VARIABLE, so a bare `#` starts a make
# comment and silently truncates the line it is on (measured while writing
# this: the banner became `GATE ESCAPE (`). Issue numbers here must be
# written `\#700`, the same idiom RETRY_REASON_CASE above uses for `\#1125`.
# ── SKIP-UNUSED ESCAPE PROBE (\#1337) ────────────────────────────────────────
# The cache-free re-run above is the right classifier for a step that runs
# WITH $(CX_CACHE). It is the wrong one for a `$(V) ... run` gate, and that
# distinction is the whole of \#1337's second ask.
#
# `VFLAGS_VCX := -cc cc -path ...` carries NO -usecache, and has not since the
# single commit that ever wrote that line. So when address-baseline-gate died
# on `call to undeclared function 'string_runes'`, the cache was off in the
# failing run AND in the "cache-free" re-run the issue reports as a
# discriminator — the same command twice, which makes its greenness a NON-
# REPRODUCTION rather than a discriminator. A cache-free re-run of these gates
# differs from the failing run in NOTHING, which is exactly why ask 2's first
# option was declined. That reasoning was right about the cache and wrong
# about the remedy.
#
# What IS on for every one of these builds is -skip-unused: for the C backend
# and any build that is not -build-module, V sets skip_unused unconditionally
# (third_party/v/vlib/v/pref/pref.v, the `res.backend == .c` block). Pruning a
# symbol the translation unit still references is precisely this failure
# class, and the fork already carries two patches in it — upstream's
# "markused: fix undeclared C identifier for alias array type" (5f6bc5ab07)
# and CX's own use_cache interface mitigation in vlib/v/markused/markused.v,
# whose comment reads "the wrapper references an undeclared function -> C
# error". Neither covers a cache-free program TU.
#
# STATE THIS PLAINLY: markused is the best-supported hypothesis for that
# symptom, NOT a measured cause. It has not reproduced since. This probe
# exists so the NEXT occurrence names itself instead of costing another full
# verification cycle, which is what \#1337 says the first one cost.
#
# Discipline, identical to CACHE_ESCAPE_PROBE: the verdict STAYS RED either
# way. The re-run is the classifier, never a retry, and it only happens when
# the log actually carries a C symbol-level failure — re-running the whole
# graph on an ordinary red (a moved address) would cost a full rebuild and
# classify nothing. scripts/classify_v_build_failure.sh owns that decision and
# self-tests it.
# NOTE for editors: this is a make VARIABLE, so a bare `#` starts a make
# comment and silently truncates the line it is on. Issue numbers here must be
# written `\#1337`, the same idiom CACHE_ESCAPE_PROBE above uses.
SKIP_UNUSED_ESCAPE_PROBE = \
	if sh scripts/classify_v_build_failure.sh "$$log"; then \
	  echo "──── -no-skip-unused DIAGNOSTIC (verdict stays RED; classifying only) ────"; \
	  if eval "$$SU_RERUN" > "$$log.noskip" 2>&1; then \
	    echo "════ SKIP-UNUSED ESCAPE (\#1337): FAILED with -skip-unused, PASSES with -no-skip-unused ════"; \
	    echo "     markused pruned a symbol the generated translation unit still references."; \
	    echo "     DO NOT re-run to get green, and do not add -no-skip-unused to the gate:"; \
	    echo "     that hides a real codegen defect behind a slower build."; \
	    echo "     Capture and file against \#1337:"; \
	    echo "       - $$log        (the pruned failure, with the undeclared symbol)"; \
	    echo "       - $$log.noskip (the same build, nothing pruned)"; \
	    echo "     Then add the reproducer to third_party/v as a markused regression test."; \
	  else \
	    echo "──── real failure, not a markused artifact (fails with -no-skip-unused too) ────"; \
	  fi; \
	else \
	  echo "──── ordinary red: no C symbol-level failure in $$log, so no re-run ────"; \
	fi; \
	exit 1

CACHE_ESCAPE_PROBE = \
	echo "──── cache-free DIAGNOSTIC (verdict stays red; classifying): $$rel ────"; \
	if $(V) -cc cc $(CX_GC) $(CX_ENGINES) test "$$rel"; then \
	  echo "════ GATE ESCAPE (\#700): $$rel FAILED under $(CX_CACHE) and PASSES cache-free ════"; \
	  echo "     The module cache produced a failure make check-vcache-soundness does not catch."; \
	  echo "     DO NOT re-run to get green. Capture and file against \#700:"; \
	  echo "       - $$log (the cached failure)"; \
	  echo "       - make check-vcache-soundness   (expect green — that is the point: a hole)"; \
	  echo "       - the failing cc/ld symbols, and the cache namespace for this step"; \
	  echo "     Then add a probe to scripts/vcache_soundness_gate.sh that goes RED on it."; \
	else \
	  echo "──── real failure, not a cache artifact (fails cache-free too): $$rel ────"; \
	fi; \
	st=1

# A retry roster is matched against the step paths the suite REPORTS, so a
# row naming a file that no longer exists matches nothing and silently
# disables its retry class — the class stops applying and the gate looks
# unchanged. That is the vacuous-gate failure mode, and here it would
# disable a mitigation while the gate looks unchanged (it absorbed the
# "#951 supervise load-race" for five months — a defect, #1228, not noise).
# Consolidation (#700) deletes step files by design, so this is now a live
# hazard rather than a theoretical one: assert every roster row exists,
# before the suite runs.
#
# GAUGE_SERIAL_RETRY (#1431) is checked here on the same terms: its row is not
# a `v test` step path but the script `repr-guard` runs, and a row naming a
# script that moved would silently disable that class exactly as a stale test
# path does. Every roster the tree has is bound by this one target.
#
# And every row DECLARES WHY (FIX-1, #1597): RETRY_REASON_CASE's default arm
# still retries a row with no reason, loudly, but a loud line in a failed run's
# log is found after the run failed. The post-merge run on 684a12502 printed
# "NO REASON DECLARED" for env_retention_test.v, which had joined
# SUITE_SERIAL_RETRY (5672a1d2e) without its row here. A roster row whose
# reason is the default arm is refused BEFORE the suite runs, beside the
# missing-file refusal.
.PHONY: check-serial-retry-rosters
check-serial-retry-rosters:
	@missing=""; undeclared=""; \
	for t in $(SUITE_SERIAL_RETRY) $(CODE_SERIAL_RETRY) $(GAUGE_SERIAL_RETRY); do \
	  [ -f "$$t" ] || missing="$$missing $$t"; \
	  rel=$$t; $(RETRY_REASON_CASE); \
	  case "$$reason" in "NO REASON DECLARED"*) undeclared="$$undeclared $$t" ;; esac; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "check-serial-retry-rosters: retry roster names file(s) that do not exist —"; \
	  echo "  a row matching no step silently disables its retry class:"; \
	  for t in $$missing; do echo "    $$t"; done; \
	  echo "  fix the roster in Makefile (SUITE_SERIAL_RETRY / CODE_SERIAL_RETRY / GAUGE_SERIAL_RETRY)."; \
	  exit 1; \
	fi; \
	if [ -n "$$undeclared" ]; then \
	  echo "check-serial-retry-rosters: retry roster row(s) with NO declared reason —"; \
	  echo "  the retry would print 'NO REASON DECLARED' in a failed run's log:"; \
	  for t in $$undeclared; do echo "    $$t"; done; \
	  echo "  declare each in RETRY_REASON_CASE in the Makefile (the issue and the class)."; \
	  exit 1; \
	fi; \
	echo "check-serial-retry-rosters OK — every retry-roster row names an existing step and declares its reason"

# ── check-fixture-shard-manifest (#1448, RULED: 1448-a) ─────────────────────
# The same shape, one level down. 1448-a partitions the module corpus —
# conformance/{stdlib,platform,x,xap}/*.cxd plus extended.cxd and
# xml_codec.cxd — across the grader's shard test files so the V runner's
# parallel jobs carry a walk that was the run's 16-29 minute critical path. The partition introduces
# exactly one new failure mode — a corpus file in NO shard is graded by nothing
# while every step stays green — and this refuses it, together with a file in
# two shards, a row naming a file that does not exist, a shard row naming a
# test file that does not exist, and a shard test file with no manifest row.
.PHONY: check-fixture-shard-manifest
check-fixture-shard-manifest:
	@bash scripts/check_fixture_shard_manifest.sh

# ── fixtures (#1448, RULED: 1448-a) — the grader's ONE-COMMAND form ─────────
# Before the shard split a pre-merge pipeline graded the corpus with one line
# and read the census off its stdout. The corpus is now graded by the driver
# plus the shards, so this target is that line: all of them in parallel under
# the pipelines' own flags (`-cc cc -gc e -d cx_db_sqlite -d cx_db_redis` —
# without the two engine defines db.cxd's cases 010-023 fail by construction),
# each one's output printed in manifest order, and the aggregated
# `stdlib corpus: …` census line last. No build prerequisite, exactly as the
# direct invocation had none: the grader links the `cx` module as SOURCE and
# only READS deps/cx-core-code/vcx/target/cx's build-identity stamp (#1432).
#
# #1513: `make fixtures FIXTURE_FILES="conformance/xap/xap-on.cxd …"` grades
# only the named corpus files, each through the shard that owns it, and prints
# the census restricted to them under one `FIXTURE-FILES=` line. A name no
# shard owns FAILS the step. Unset, the target is what it was — which is what
# the post-merge run, and any branch touching the grader, deps/cx-core-code/vcx/code/,
# stdlib/*.cx or the V pin, keeps running (INT-5, INT-21). The selection for a
# branch is `sh scripts/fixture_files_for_branch.sh origin/release/0.18`.
FIXTURE_FILES ?=
.PHONY: fixtures
fixtures:
	@FIXTURE_FILES="$(FIXTURE_FILES)" sh scripts/run_fixture_shards.sh

# ── check-no-nested-make (#1520) ──────────────────────────────────────────────
# No step of the suite may spawn a nested `make test`. Measured twice on
# 2026-09-17: inside a SELECTED run a child `make test` started 72 minutes into
# `test-vcx-suite` and ran the whole TEST_TARGETS union for an hour and a half,
# and in the second sighting it wrote the machine-wide gate lock and failed the
# release's own run at check-gate-lock in five seconds.
#
# The probe runs a SUITE_FILES selection with `make` shadowed by a shim that
# records every argv and REFUSES a `test` goal, then asserts none asked for one.
# `NESTED_MAKE_SUITE_FILES` names the selection (default: the three
# subprocess-heavy files); `NESTED_MAKE_KEEP=1` leaves `argv.log` behind.
#
# DELIBERATELY NOT IN TEST_TARGETS, and the reason is the defect itself: this
# target RUNS `test-vcx-suite`, so inside `make test` it would nest a suite in
# the matrix — the shape #1520 is about. It is a step the integrator or an agent
# runs on purpose, and under a full-union selection it names the spawner in one
# line of its own log.
NESTED_MAKE_SUITE_FILES ?=
NESTED_MAKE_KEEP ?=
.PHONY: check-no-nested-make
check-no-nested-make: build-vcx
	@deps/cx-core-code/vcx/target/cx --allow-read --allow-write --allow-subprocess --allow-env \
	  scripts/check_no_nested_make.cx \
	  $(if $(NESTED_MAKE_SUITE_FILES),--suite-files="$(NESTED_MAKE_SUITE_FILES)",) \
	  $(if $(NESTED_MAKE_KEEP),--keep,)

# #700 consolidation absorbs a step file's tests into an umbrella and REMOVES
# the original; every fix made to the umbrella afterwards then lives only
# there. So a restored original is a loaded gun: regenerating from it
# re-derives the section from pre-absorption bytes and drops those fixes with
# no diagnostic (#1012). `audit all` asserts the one-way rule across every
# manifest — no live row an umbrella already carries, no absorbed original
# back in the tree — which is a standing property of the tree, not just of a
# regeneration, so it belongs in the gate and not only in the driver.
.PHONY: check-consolidation-manifests
check-consolidation-manifests:
	@scripts/consolidate_tests.sh audit all
	@bash scripts/consolidate_tests_selftest.sh

# ── #1212: every conformance suite is claimed by a named step ────────────────
.PHONY: check-conformance-coverage
check-conformance-coverage:
	@bash scripts/check_conformance_coverage.sh

# ── #1272 (RULED: 1272-a1): the §1.2 feature runtime contract has a REVISION ──
# The gate refuses a tree whose §1.2 normative body moved without the author
# saying which kind of move it was (a bump, or an editorial re-pin), and refuses
# a drift between the spec's declaration and the V constant generated from it.
# `-repin` is the deliberate act that records the decision; `-regen` only
# refreshes the generated constant.
# RETIRED from TEST_TARGETS (RULED: RS-12, RS-8, RS-7, RS-20; #1591 item K3):
# scripts/check_contract_revision.sh and scripts/gen_contract_revision.sh left
# with cx-platform-xap's extraction -- xap's OWN contract revision, checked
# and regenerated against xap's own tree there, not this Makefile's targets.
#
# .PHONY: check-contract-revision contract-revision-regen contract-revision-repin
# check-contract-revision:
# 	@bash scripts/check_contract_revision.sh
#
# contract-revision-regen:
# 	@bash scripts/gen_contract_revision.sh
#
# contract-revision-repin:
# 	@bash scripts/gen_contract_revision.sh --repin

# ── #1216: the wall-clock step ──────────────────────────────────────────────
# vcx/timing/*_test.v hold the assertions whose SUBJECT is elapsed time (boot
# budget, zero-wait polls). They sit BESIDE deps/cx-core-code/vcx/tests/ because `v test <dir>`
# recurses into every subdirectory except `testdata`, and they run serially
# from the `test:` tail after the -j fan-out drains — the same quiet context
# the profile gate gets. A red here is a real regression: nothing else is
# running. Not in the -j union (filtered out in `test:`); `test-no-parallel`
# runs it in TEST_TARGETS order.
test-vcx-timing: build-vcx-dev
	@$(JS_CLOSE) $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test deps/cx-core-code/vcx/timing/

# SUITE_FILES (#1516, RULED: RUN-1) — what `v test` is pointed at. The default
# is the DIRECTORY, so `make test-vcx-suite`, `make test` and every exit run are
# the union they have always been. `scripts/test_changed.sh` overrides it with
# the test files whose own path, an imported vcx/ module, or the corpus shard
# that grades a changed module actually moved: one row over 76 files and 35
# minutes was the pace of every post-merge run. The retry classifier below reads
# the SAME log and is indifferent to how many files produced it.
SUITE_FILES ?= deps/cx-core-code/vcx/tests/

test-vcx-suite: build-vcx-dev check-serial-retry-rosters check-fixture-shard-manifest fixtures-census-reset skip-ledger-reset
	@$(JS_CLOSE) log=deps/cx-core-code/vcx/target/test-suite-run.log; stf=deps/cx-core-code/vcx/target/test-suite-status; \
	{ $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test $(SUITE_FILES) 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  failed=$$(grep -aE '^FAIL ' $$log | grep -aoE '[^ ]+_test\.v$$' | sort -u); \
	  want=$$(grep -aE '^Summary for all V _test\.v files: [0-9]+ failed,' $$log | tail -1 | sed -E 's/[^0-9]*([0-9]+) failed.*/\1/'); \
	  have=$$(printf '%s\n' $$failed | grep -c '_test\.v$$' || true); \
	  if [ -n "$$want" ] && [ "$$have" -ne "$$want" ]; then \
	    echo "retry classifier: extracted $$have failed step(s) but the suite summary says $$want — refusing the partial retry roster (binary-log suppression class)"; \
	    exit 1; \
	  fi; \
	  if [ -n "$$failed" ]; then \
	    st=0; \
	    for t in $$failed; do \
	      rel=$${t#$(CURDIR)/}; \
	      case " $(SUITE_SERIAL_RETRY) " in \
	        *" $$rel "*) \
	          $(RETRY_REASON_CASE); \
	          echo "──── serial retry ($$reason): $$rel ────"; \
	          $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test "$$rel" || st=1 ;; \
	        *) \
	          if grep -aq 'C compilation error' $$log; then \
	            $(CACHE_ESCAPE_PROBE); \
	          else \
	            echo "──── real failure (no retry class applies): $$rel ────"; st=1; \
	          fi ;; \
	      esac; \
	    done; \
	    if [ $$st -eq 0 ]; then \
	      echo "──── every failed step passed on its classified SERIAL retry (socket / pty steps) ────"; \
	    fi; \
	  fi; \
	fi; \
	skips=$$(cat $(CX_SKIP_DIR)/* 2>/dev/null); \
	if [ -n "$$skips" ]; then \
	  echo "──── $$(printf '%s\n' "$$skips" | wc -l | tr -d ' ') step(s) SKIPPED with a named reason (absent prerequisite, counted separately — NOT failures) ────"; \
	  printf '%s\n' "$$skips"; \
	fi; \
	if [ "$(SUITE_FILES)" = "deps/cx-core-code/vcx/tests/" ]; then \
	  bash scripts/fixtures_census.sh || st=1; \
	else \
	  echo "test-vcx-suite: SELECTED run (SUITE_FILES=$(SUITE_FILES)) — NO whole-corpus census, and this line is here so nobody reads one into it. The census sums the grader shards, only the union runs all of them, and \`make test\` plus every exit run are still the union (#1516)."; \
	fi; \
	exit $$st

# White-box unit tests that live INSIDE the `code` module (deps/cx-core-code/vcx/code/*_test.v) —
# they exercise unexported internals (e.g. store_cxpack_flush / store_put_canonical
# / the object-graph persistence) that the black-box deps/cx-core-code/vcx/tests/ corpus cannot
# reach. `v test` only runs the directory it is given, so deps/cx-core-code/vcx/tests/ does not pull
# these in; this dedicated target wires the in-module suite into the gate (under
# the same default -gc e memory model as test-vcx-suite).
#
# Same classified-retry contract as test-vcx-suite (#648: this target had NO
# retry class, so a live-socket step flaking under -j parallel load failed the
# umbrella with no re-run — store_admin_plane_test.v, repeatedly green in
# isolation, is the proven case).
#
# store_grpc_parity_test.v was dropped from this roster 2026-08-24: the file
# has not existed since abaea9b9b retired the store HTTP data plane, so the row
# matched no step and was doing nothing. check-serial-retry-rosters (below)
# is what found it, and is what stops the next one.
#
# code_module_umbrella_test.v joined 2026-09-13 (#1432, RULED: 1432-a) under
# the "timing / early exit under load" class documented beside the rosters
# above — its wall-clock control row read 42 ms against 40 ms at a load average
# of 200. No bound moved.
# store_admin_plane_test.v, store_grpc_live_test.v and store_lazy_load_test.v
# RETIRED from this roster (RULED: RS-12, RS-8; #1591 item K3): vcx/store/ left
# with the extraction of cx-platform-store; check-serial-retry-rosters would
# otherwise refuse these three rows as naming files that no longer exist here
# (the same shape check-inmodule-test-roster's directory check catches for
# CODE_TEST_DIRS above). The repository's own gate carries whatever retry
# discipline these tests still need.
CODE_SERIAL_RETRY := deps/cx-core-code/vcx/code/code_module_umbrella_test.v

# I3 module split (#651/#516): the in-module tests now live in TWO
# modules — vcx/code (Ring 1) and vcx/platform (Ring 2, where the
# store/journal/grpc/service subjects moved). One step runs both.
.PHONY: test-vcx-code
# CODE_TEST_DIRS — the directories whose in-module tests this step runs. RS-24
# (owner D28a) splits vcx/platform into one V module per V product, each in
# its own vcx/<m>/ (registry/repos.cxd `vmodule=`), and a product's white-box
# tests move with it. `v test` runs only what it is given, so every product
# directory is listed here — check-inmodule-test-roster refuses a declared
# vmodule missing from the list — and a directory with no test yet costs
# nothing: V reports "0 total" and exits 0. A `status=extracted` vmodule is
# the opposite failure mode and check-inmodule-test-roster exempts it: the
# directory does not exist here any more (its whole product, code and
# in-module test, moved to the repository — `deps/<repo>/vcx/<m>/`), and a
# MISSING path mixed into one `v test a/ b/ missing/` invocation makes V
# print its usage banner and exit 0 having run NOTHING — a silent-pass, not
# a red, and worse than the "0 total" case this comment used to rely on
# (found removing cx-platform-db's vcx/cxdb/, RULED: RS-12, RS-8, #1591 item
# K3). The extracted product's own `v test` runs from the pin, same as its
# `cx corpus`.
#
# vcx/code/ itself LEFT WHOLE with cx-core-code (K7a, RULED: RS-12, RS-7), the
# same shape as every other extracted vmodule above -- but unlike those, this
# tree keeps grading it FROM THE PIN rather than dropping the entry: RS-32
# left "cx-core-code runs its own in-module gate" open (no gate of its own
# exists there yet), so until it does, `deps/cx-core-code/vcx/code/` is this
# step's one directory, the same way mail's real-socket lanes grade from
# their pins. Repoint (or drop, once cx-core-code ships its own gate) then.
CODE_TEST_DIRS := deps/cx-core-code/vcx/code/
test-vcx-code: build-vcx-dev check-serial-retry-rosters
	@$(JS_CLOSE) log=deps/cx-core-code/vcx/target/test-code-run.log; stf=deps/cx-core-code/vcx/target/test-code-status; \
	{ $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test $(CODE_TEST_DIRS) 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  failed=$$(grep -aE '^FAIL ' $$log | grep -aoE '[^ ]+_test\.v$$' | sort -u); \
	  want=$$(grep -aE '^Summary for all V _test\.v files: [0-9]+ failed,' $$log | tail -1 | sed -E 's/[^0-9]*([0-9]+) failed.*/\1/'); \
	  have=$$(printf '%s\n' $$failed | grep -c '_test\.v$$' || true); \
	  if [ -n "$$want" ] && [ "$$have" -ne "$$want" ]; then \
	    echo "retry classifier: extracted $$have failed step(s) but the suite summary says $$want — refusing the partial retry roster (binary-log suppression class)"; \
	    exit 1; \
	  fi; \
	  if [ -n "$$failed" ]; then \
	    st=0; \
	    for t in $$failed; do \
	      rel=$${t#$(CURDIR)/}; \
	      case " $(CODE_SERIAL_RETRY) " in \
	        *" $$rel "*) \
	          $(RETRY_REASON_CASE); \
	          echo "──── serial retry ($$reason): $$rel ────"; \
	          $(V) -cc cc $(CX_GC) $(CX_ENGINES) $(CX_CACHE) test "$$rel" || st=1 ;; \
	        *) \
	          if grep -aq 'C compilation error' $$log; then \
	            $(CACHE_ESCAPE_PROBE); \
	          else \
	            echo "──── real failure (no retry class applies): $$rel ────"; st=1; \
	          fi ;; \
	      esac; \
	    done; \
	    if [ $$st -eq 0 ]; then \
	      echo "──── every failed step passed on its classified SERIAL retry (socket / pty steps) ────"; \
	    fi; \
	  fi; \
	fi; exit $$st

# test-vcx-cxstore RETIRED (RULED: RS-12, RS-8; #1591 item K3): vcx/cxstore/
# left whole with the extraction of cx-platform-store — the content-addressed
# object store internals this target's `v test vcx/cxstore/*_test.v` glob
# graded (pack/seqtree/bloom/index/gc/reflog/repo/planner/retention/mmap/
# compression + the cx adapter + round-trip). A directory-glob target left
# pointing at a directory that no longer exists is not the CODE_TEST_DIRS
# silent-pass shape (a `v test path/*_test.v` glob that matches nothing is a
# build error, not a quiet 0), but it is still dead: the repository's own gate
# grades these tests now, from the same pin this tree compiles cx-platform-
# store from. Dropped from TEST_TARGETS below; the target itself removed.

# The in-module Ring-0 test roster (#1209). Listed EXPLICITLY, never globbed:
# vcx/cx/parser_multidoc_test.v segfaults under the shipped `-gc e` model
# (module-internal-test-only RC double-free of the multi-doc Document tree;
# production paths and external-linkage tests are green) — that exclusion is
# #737, and it is why this cannot be `test vcx/cx/`.
#
# An explicit list with no guard ROTS: between I2 and #1209 three tests were
# added here and named by no step, so they ran nowhere for months — including
# name_pool_contract_test.v, which is #1178's parser-quadratic contract. The
# roster is a variable and `check-inmodule-test-roster` now fails on any
# vcx/cx/*_test.v that is in neither list, so the next addition cannot be
# forgotten silently. Delete both lists and glob the directory when #737 closes.
CX_INMODULE_TESTS := $(CXD)/vcx/cx/program_interior_comments_test.v $(CXD)/vcx/cx/program_layout_test.v $(CXD)/vcx/cx/program_fmt_guard_test.v $(CXD)/vcx/cx/program_emit_head_ascription_test.v $(CXD)/vcx/cx/directive_emit_surface_test.v $(CXD)/vcx/cx/anchor_resolve_test.v $(CXD)/vcx/cx/numeric_exact_fast_test.v $(CXD)/vcx/cx/atom_test.v $(CXD)/vcx/cx/token_golden_test.v $(CXD)/vcx/cx/version_stamp_test.v $(CXD)/vcx/cx/html_url_codec_test.v $(CXD)/vcx/cx/span_jump_test.v $(CXD)/vcx/cx/feature_compat_test.v $(CXD)/vcx/cx/name_pool_contract_test.v $(CXD)/vcx/cx/schema_extensions_test.v $(CXD)/vcx/cx/node_api_test.v
CX_INMODULE_TESTS_EXCLUDED := $(CXD)/vcx/cx/parser_multidoc_test.v

# check-build-input-roster (#1065) — forwards to vcx/, where the per-artifact
# input rosters live. It proves each guard watches every module its artifact
# actually compiles, re-derived from `v -print-v-files` under that artifact's
# own defines. Same shape as the roster gate below (#1209): a hand-maintained
# list is one import away from being wrong, and here the failure is a STALE
# BINARY under a green guard, which has escaped twice.
.PHONY: check-build-input-roster
check-build-input-roster:
	@$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx check-build-input-roster

# check-selection-manifest (#1516, RULED: RUN-1) — the third roster of the same
# family: every TEST_TARGETS entry has an input-glob row in
# scripts/test_changed.sh. Deny-by-default keeps a rowless step RUNNING, so the
# failure this guards is not a wrong answer but a silent one — thirteen steps
# ran on every head for months because nothing compared the two lists.
# The selftest runs HERE (10 s), the way check-consolidation-manifests runs its
# own: a fixture no step executes proves nothing about the tree it was written
# for, and the selection rules are exactly the kind of thing that rots quietly.
.PHONY: check-selection-manifest
check-selection-manifest:
	@bash scripts/check_selection_manifest.sh
	@sh scripts/test_changed_selftest.sh

.PHONY: check-inmodule-test-roster
check-inmodule-test-roster:
	@missing=""; \
	for t in $(CX_INMODULE_TESTS) $(CX_INMODULE_TESTS_EXCLUDED); do \
	  [ -f "$$t" ] || missing="$$missing $$t"; \
	done; \
	if [ -n "$$missing" ]; then \
	  echo "check-inmodule-test-roster: roster names file(s) that do not exist —"; \
	  for t in $$missing; do echo "    $$t"; done; \
	  echo "  fix CX_INMODULE_TESTS / CX_INMODULE_TESTS_EXCLUDED in Makefile."; \
	  exit 1; \
	fi; \
	unlisted=""; \
	for f in $(CXD)/vcx/cx/*_test.v; do \
	  case " $(CX_INMODULE_TESTS) $(CX_INMODULE_TESTS_EXCLUDED) " in \
	    *" $$f "*) ;; \
	    *) unlisted="$$unlisted $$f" ;; \
	  esac; \
	done; \
	if [ -n "$$unlisted" ]; then \
	  echo "check-inmodule-test-roster: in-module test(s) that NO step runs —"; \
	  for f in $$unlisted; do echo "    $$f"; done; \
	  echo "  \`v test\` only runs what it is given, so a vcx/cx/*_test.v missing"; \
	  echo "  from CX_INMODULE_TESTS executes nowhere and guards nothing (#1209)."; \
	  echo "  Add it to CX_INMODULE_TESTS, or to CX_INMODULE_TESTS_EXCLUDED with"; \
	  echo "  the issue that owns the exclusion."; \
	  exit 1; \
	fi; \
	unrun=""; \
	for m in $$(grep -E "vmodule=[a-z_][a-z0-9_]*" registry/repos.cxd | grep -v "status=extracted" | grep -oE "vmodule=[a-z_][a-z0-9_]*" | cut -d= -f2); do \
	  [ -d "vcx/$$m" ] || continue; \
	  case " $(CODE_TEST_DIRS) " in \
	    *" vcx/$$m/ "*) ;; \
	    *) unrun="$$unrun vcx/$$m/" ;; \
	  esac; \
	done; \
	orphaned=""; \
	for d in $(CODE_TEST_DIRS); do \
	  [ -d "$$d" ] || orphaned="$$orphaned $$d"; \
	done; \
	if [ -n "$$unrun" ]; then \
	  echo "check-inmodule-test-roster: product module director(ies) whose in-module tests NO step runs —"; \
	  for d in $$unrun; do echo "    $$d"; done; \
	  echo "  registry/repos.cxd declares each as a V product (vmodule=, RULED: RS-24) and a"; \
	  echo "  product's white-box tests live beside it; add the directory to CODE_TEST_DIRS."; \
	  echo "  (a status=extracted row, or one whose vcx/<m>/ does not exist on disk, is exempt:"; \
	  echo "  its directory left for deps/<repo>/vcx/<m>/.)"; \
	  exit 1; \
	fi; \
	if [ -n "$$orphaned" ]; then \
	  echo "check-inmodule-test-roster: CODE_TEST_DIRS names director(ies) that do not exist —"; \
	  for d in $$orphaned; do echo "    $$d"; done; \
	  echo "  \`v test a/ b/ missing/\` prints its usage banner and exits 0 having run NOTHING"; \
	  echo "  the moment one path is missing (found removing cx-platform-db's vcx/cxdb/, RULED:"; \
	  echo "  RS-12, RS-8) — a silent pass, not a red. Drop the directory from CODE_TEST_DIRS."; \
	  exit 1; \
	fi; \
	echo "check-inmodule-test-roster OK — every vcx/cx/*_test.v is run or explicitly excluded, and every product directory (vmodule=) is in test-vcx-code's CODE_TEST_DIRS"

# White-box unit tests INSIDE the Ring-0 `cx` module (vcx/cx/*_test.v) plus
# the `fixtures` test-support module (vcx/fixtures/ — the corpus loader,
# moved out of shipped libcx at I2). These steps ran NOWHERE before I2:
# `v test` only runs the directory it is given, and no target named vcx/cx —
# five in-module tests sat outside every gate (found wiring this step).
# Files are listed explicitly, not the directory glob:
# vcx/cx/parser_multidoc_test.v is EXCLUDED — it segfaults under the shipped
# `-gc e` model (module-internal-test-only RC double-free of the multi-doc
# Document tree; production paths and external-linkage tests are green).
# That exclusion is #737; delete the list and glob the directory when it
# closes.
.PHONY: test-vcx-cx
test-vcx-cx: build-vcx-dev
	@$(JS_CLOSE) $(V) -cc cc $(CX_GC) test $(CX_INMODULE_TESTS)
	@$(JS_CLOSE) $(V) -cc cc $(CX_GC) test $(CXD)/vcx/fixtures/

# White-box unit tests that live INSIDE the CLI module (vcx/cmd/*_test.v) —
# they assert on the cmd module's own constants (e.g. the `cx scaffold`
# templates, #306/#448) that neither deps/cx-core-code/vcx/tests/ nor deps/cx-core-code/vcx/code/ can import.
# `v test` only runs the directory it is given, so without this target the
# cmd suite had NO gate consumer (#448 wired it in).
.PHONY: test-vcx-cmd
# -d cx_platform: the cmd step tests the DEFAULT (platform-profile) shape —
# the shipped binary's composition (I4; a bare cmd/ compile is the cli
# profile, where CX_ENGINES would be inert).
# Same cache-free DIAGNOSTIC as test-vcx-suite/test-vcx-code (see
# CACHE_ESCAPE_PROBE above): this is the ONLY vcx test step besides those that
# runs -usecache ($(CX_CACHE)). A cached-only C-compile/link failure is now a
# GATE ESCAPE against the proven key, reported red with the capture recipe —
# not retried to green. The historical case this step recorded (a fresh symbol
# added to code/ while the cmd step reused a pre-change cached object, the S6.3
# pushdown symbols) is precisely a provenance failure that part (i)'s manifests
# now make impossible, and if it recurs the gate needs a probe, not a retry.
test-vcx-cmd: build-vcx-dev
	@$(JS_CLOSE) log=deps/cx-core-code/vcx/target/test-cmd-run.log; stf=deps/cx-core-code/vcx/target/test-cmd-status; \
	{ $(V) -cc cc $(CX_GC) -d cx_platform $(CX_ENGINES) $(CX_CACHE) test vcx/cmd/ 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  if grep -aqE 'C compilation error|linker command failed|symbol\(s\) not found|duplicate symbol' $$log; then \
	    echo "──── cache-free DIAGNOSTIC (verdict stays red; classifying): vcx/cmd ────"; \
	    if $(V) -cc cc $(CX_GC) -d cx_platform $(CX_ENGINES) test vcx/cmd/; then \
	      echo "════ GATE ESCAPE (#700): vcx/cmd FAILED under $(CX_CACHE) and PASSES cache-free ════"; \
	      echo "     The module cache produced a failure make check-vcache-soundness does not catch."; \
	      echo "     DO NOT re-run to get green. Capture $$log + the gate output + the failing"; \
	      echo "     symbols, file against #700, and add a RED-going probe to"; \
	      echo "     scripts/vcache_soundness_gate.sh."; \
	    else \
	      echo "──── real failure, not a cache artifact (fails cache-free too): vcx/cmd ────"; \
	    fi; \
	  fi; \
	fi; \
	exit $$st

# ── Columnar (Parquet / Arrow-IPC) [$store] backend gate — #129 D5 (#76) ──
# The columnar document backend (document+file://…?encoding=parquet) lives behind
# `-d cxstore_columnar`; its Arrow file I/O lives behind `-d cx_arrow_files`
# (libcx_arrow + libparquet via the C++ shim). It is therefore NOT in the default
# `make test` gate — that gate stays green Arrow-free, and an ungranted/absent-Arrow
# caller gets an honest E_STORE_UNRESOLVED_BACKEND (the gated-substrate posture).
# This DEDICATED target builds the shim and runs the spec §9 acceptance gate
# (store_columnar_test.v) with BOTH flags + Apache Arrow discovered via pkg-config,
# so the backend is genuinely exercised (no unconsumed seam). CI runs this target on
# a runner where Apache Arrow is installed (brew install apache-arrow / apt
# libarrow-dev libparquet-dev). Mirrors test-python-arrow's build-the-lib-first shape.
ifeq ($(UNAME_S),Darwin)
  COLUMNAR_ARROW_PKGCONFIG := /opt/homebrew/opt/apache-arrow/lib/pkgconfig
else
  COLUMNAR_ARROW_PKGCONFIG :=
endif
.PHONY: test-vcx-columnar
test-vcx-columnar: build-vcx-dev skip-ledger-reset
	# THREE lines, and the split is #1476's whole subject. GNU make EXECUTES a
	# recipe line containing $(MAKE) even under `-n` — documented, and correct
	# for a recursive make, which inherits -n through MAKEFLAGS and dry-runs in
	# turn. What is not correct is what this recipe used to be: one `if … then
	# $(MAKE) … && $(V) … test … ; fi` line, so `make -n test` executed the
	# whole conditional, COMPILED AND RAN two V tests, aborted the listing
	# before the serial tail, and did it outside the gate lock (-n skips
	# check-gate-lock's recipe, which contains no $(MAKE), but not this one).
	# Measured again on 2026-09-18 by an agent reading the -j goal list.
	#
	# So: the skip decision on its own line, the sub-make on its own line, and
	# the V test on a line that contains no $(MAKE) at all — which is what make
	# needs in order to honor -n for it. The three lines are sequenced through
	# the skip ledger rather than through shell control flow, and that ledger is
	# reset per run by the `skip-ledger-reset` prerequisite above, so the file's
	# presence means "this run skipped", never "some earlier run did".
	@$(JS_CLOSE) if ! PKG_CONFIG_PATH="$(COLUMNAR_ARROW_PKGCONFIG):$$PKG_CONFIG_PATH" pkg-config --exists arrow parquet 2>/dev/null; then \
	  line="SKIP test-vcx-columnar: Apache Arrow/Parquet not discoverable via pkg-config (absent prerequisite, #318 — brew install apache-arrow / apt libarrow-dev libparquet-dev)"; \
	  echo "$$line"; mkdir -p $(CX_SKIP_DIR); echo "$$line" > $(call CX_SKIP_FILE,test-vcx-columnar); \
	fi
	@$(JS_CLOSE) if [ ! -f "$(call CX_SKIP_FILE,test-vcx-columnar)" ]; then $(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx arrow-shim; fi
	@$(JS_CLOSE) if [ ! -f "$(call CX_SKIP_FILE,test-vcx-columnar)" ]; then \
	  PKG_CONFIG_PATH="$(COLUMNAR_ARROW_PKGCONFIG):$$PKG_CONFIG_PATH" $(V) -cc cc -enable-globals $(CX_GC) -d cxstore_columnar -d cx_arrow_files test deps/cx-platform-store/vcx/store/store_columnar_test.v deps/cx-platform-store/vcx/store/store_columnar_lineage_test.v; \
	fi
	# vcx/store/ RETIRED (RULED: RS-12, RS-8; #1591 item K3) — same fix as
	# test-vcx-sqlite below: these two files moved with cx-platform-store's
	# extraction and are read from the pinned checkout.

# ── sqlite [$store] backend gate — #77 / #220 (concurrent-writer durability) ──
# The sqlite:// store backend lives behind `-d cxstore_sqlite` (links libsqlite3).
# It runs the gated in-module suite — the round-trip/dedup/integrity tests plus
# the #220 concurrent-writer stress (32-wide burst through the daemon dispatch
# path → no crash, cold reopen intact). On macOS the system libsqlite3 ships no
# headers, so they come from Homebrew sqlite.
#
# IN TEST_TARGETS since #989. It was held out on the reasoning that `make test`
# must stay green on a box without sqlite headers — but 41f44e97c then landed
# #891's shared-open protection behind a step no gate ran, so the protection
# could rot without anything noticing, which is the cost the exclusion was
# actually buying. The header worry is answered the way #318 answers it for
# test-vcx-columnar, three targets up: PROBE the prerequisite and SELF-SKIP with
# a named reason into $(CX_SKIP_DIR) when it is absent (skips are counted
# separately and printed loudly — never silently, never as failures). A box with
# sqlite runs the step; a box without says so out loud.
#
# GATE-DURATION EVIDENCE (#700 dead-ends register — a step may not join the ring
# on assertion; ledger/dead_ends_700_test_duration.md). MEASURED on the
# reference machine, this recipe's own `v test` (the build-vcx-dev prerequisite
# is shared with every other vcx step, so it is not marginal cost), 3/3 green on
# every run:
#
#   cold caches, contended    231.1 s elapsed | comptime 674.9 CPU-s | runtime 1.6 s
#   warm, uncontended          38.1 s elapsed | comptime 108.7 CPU-s | runtime 4.4 s
#   THIS recipe at HEAD,
#   after a full build-dev      73.7 s elapsed | comptime 218.1 CPU-s | runtime 1.2 s
#
# The third row is the one to budget against — the shape a gate run actually
# sees, and it reproduced within 3% across a rebase (75.8 s / 224.0 CPU-s on the
# earlier base). Sized the way the register's POST-CLOSE ADDENDUM requires: by
# CPU, not by serial length. The gate is THROUGHPUT-bound (1,154 s wall x 12
# cores against 182 CPU-min is ~9.5x parallelism, already near the 15.2-min CPU
# floor), so a step's own duration is NOT its cost — its CPU-min is. This step
# adds 3.6 CPU-min (+2.0% of 182), projecting to ~+23 s of gate wall; the warm
# and cold extremes bracket that at +1.0% and +6.2%.
#
# The estimate in #989 ("seconds") was low by 6-60x, and the reason is worth
# recording: the RUNTIME is milliseconds (1.2-4.4 s for all three suites), but V
# recompiles the whole platform module once per test FILE, so the step is ~99%
# compile. A step's runtime is not its gate cost.
#
# What it buys: the ONLY gate coverage of the sqlite backend, including #891's
# shared-open protection and the #220 concurrent-writer durability contract.
# Before this the alternative was not a cheaper step, it was no coverage.
ifeq ($(UNAME_S),Darwin)
  SQLITE_CFLAGS := -I/opt/homebrew/opt/sqlite/include
  SQLITE_LDFLAGS := -L/opt/homebrew/opt/sqlite/lib
  SQLITE_PKGCONFIG := /opt/homebrew/opt/sqlite/lib/pkgconfig
else
  SQLITE_CFLAGS :=
  SQLITE_LDFLAGS :=
  SQLITE_PKGCONFIG :=
endif
.PHONY: test-vcx-sqlite
test-vcx-sqlite: build-vcx-dev skip-ledger-reset
	@$(JS_CLOSE) if ! PKG_CONFIG_PATH="$(SQLITE_PKGCONFIG):$$PKG_CONFIG_PATH" pkg-config --exists sqlite3 2>/dev/null; then \
	  line="SKIP test-vcx-sqlite: libsqlite3 development headers not discoverable via pkg-config (absent prerequisite, #318 — brew install sqlite / apt libsqlite3-dev)"; \
	  echo "$$line"; mkdir -p $(CX_SKIP_DIR); echo "$$line" > $(call CX_SKIP_FILE,test-vcx-sqlite); \
	else \
	  $(V) -cc cc $(CX_GC) -d cxstore_sqlite -cflags "$(SQLITE_CFLAGS)" -ldflags "$(SQLITE_LDFLAGS)" test deps/cx-platform-store/vcx/store/store_sqlite_test.v deps/cx-platform-store/vcx/store/store_sqlite_encryption_test.v deps/cx-platform-store/vcx/store/store_concurrent_writer_test.v; \
	fi
	# vcx/store/ RETIRED (RULED: RS-12, RS-8; #1591 item K3): the three files
	# above moved with cx-platform-store's extraction; this recipe reads them
	# from the pinned checkout deps.cxd fetches (`build-vcx-dev`'s own
	# `deps-present` prerequisite already refuses a run with no checkout).
	# Found stale because pkg-config is absent on this box (a DIFFERENT #318
	# skip masked it): a direct compile against deps/cx-platform-store/vcx/
	# store/{store_sqlite_test.v,store_sqlite_encryption_test.v,store_
	# concurrent_writer_test.v} with the same flags, sqlite headers found via
	# Homebrew directly, passed 3/3.

# V module search path. `lang/v/native/` + `lang/v/conformance.v` import
# `cx` and `code` modules whose source lives under `vcx/`. The historical
# fix was to symlink `lang/v/cx → ../../vcx/cx` and `lang/v/code →
# ../../vcx/code`; that broke on Windows (where symlinks need developer
# mode + a git config flag) and required a Makefile bootstrap step.
#
# Cross-platform replacement: V's `-path` flag prepends a directory to
# the module-resolver search order. Setting it via `VFLAGS` propagates
# through `v test`'s per-file fork; setting it via `-path` directly on
# `v run` also works. `@vlib` and `@vmodules` are the V-runtime
# placeholders (stdlib + `$VMODULES`).
#
# Since net's cxnet and core-data's cx/cli/fixtures both left this tree
# (RULED: RS-12) the path is CX_V_SEARCH: vcx/ first, then every pinned
# root `cx deps sync --vpath` names, then V's library -- see the block
# beside DEPS_CX. VFLAGS_VCX carries the native link inputs too, because a
# recipe that sets VFLAGS replaces the exported value rather than adding to it.
V_MODULE_PATH := $(CX_V_SEARCH)
# `-cc cc` (clang): cx's patched builtin uses C11 atomics + `@[thread_local]` TLS
# that tcc cannot compile on macOS (the V default cc for non-prod). Carried through
# every `v test` / `v run` that uses VFLAGS_VCX so the conformance corpus builds.
VFLAGS_VCX := -cc cc -path "$(V_MODULE_PATH)" $(CX_NATIVE_DEFINES)
# VFLAGS is already `export`ed beside DEPS_CX (-path "$(CX_V_SEARCH)" plus the
# native defines) — every script this Makefile shells out to, including
# scripts/run_fixture_shards.sh which invokes `v test` itself and reads no
# Makefile variable, inherits the pinned search path from the environment.

# test-v / test-vcx-api RETIRED with the V binding (RULED: RS-12, RS-8;
# #1591 item K3): cx-home/cx-binding-v now owns lang/v/ whole (native +
# the archived lang/_archived/v-cffi/ FFI approach); cx does not pin it.

test-vcx-stream: build-vcx
	v test deps/cx-core-code/vcx/tests/stream_test.v

# test-go / test-go-api / test-go-arrow / test-go-arrow-conformance RETIRED
# with the Go binding (RULED: RS-12, RS-8; #1591 item K3): cx-home/cx-binding-go
# now owns lang/go/ whole; cx does not pin it, and no go toolchain target is
# left in this tree to drive (the #743 dylib/STW note above moves with it).

conform-md: build-vcx
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform-md

# ── Conformance ────────────────────────────────────────────────────────────────

conform: conform-vcx

conform-vcx: build-vcx
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx conform

# ── Examples (transform showcase) / Demos ────────────────────────────────────
# `examples`/`demos` and every example-*/demo-* target RETIRED with the four
# active bindings (RULED: RS-12, RS-8; #1591 item K3): each ran a
# `lang/<lang>/examples/` file that left with its binding repo, and none had
# a non-binding member — an empty umbrella target is a skip dressed as a
# pass, so the names are gone rather than kept as no-ops.

# ── Publish ───────────────────────────────────────────────────────────────────
# THE ALLOWLIST MIRROR RETIRED with the split (RULED: RS-11): "Public or private
# is a setting per repository. The allowlist mirror (`scripts/publish.sh`,
# `.publishignore*`, the guard) retires with the split; `cx-private` becomes
# `cx` when it is no longer private." There is no second tree to copy into any
# more — this repository IS the one that ships — so `publish`, `publish-dry-run`,
# `publish-push` and the `release` target that composed them are gone, with
# scripts/publish.sh, scripts/publish_push.sh, .publishignore and the curated
# public Makefile and workflows under scripts/public/. The site files the mirror
# used to install (CNAME, the quickstart `install` script) moved to docs/, the
# site root itself.
#
# THE cx-v MIRROR RETIRED AT THE CUT (RULED: D81a): `cx-home/cx-v` is
# archived with a README pointer at `cx-home/v` (the V fork, tracked branch
# `cx-patches-0.18`, pinned by every V repository's `deps.cxd` `v-fork=`), and
# takes no further pushes or tags — one fork, one pin, no second copy to drift.
# `publish-v`/`publish-v-push`/`tag-public` (scripts/publish_v.sh,
# publish_v_push.sh, tag_public.sh) retired with it. WHAT REMAINS HERE IS NOT
# THE cx MIRROR: `publish-org` syncs the org profile README, best-effort.

publish-org:
	@bash scripts/publish_org.sh

release-all: publish-org

# ── The ONE end-to-end local release command ─────────────────────────────────
# gate (make test + verify-doc-links) → bump → build → tag → push → GitHub
# release → publish mirrors (release-all). The `release`/`release-all` targets
# above are the building blocks it composes. Preview first:
#   make cut-release ARGS='--dry-run vX.Y.Z'
#   make cut-release ARGS='vX.Y.Z'
# See scripts/release.sh --help. (Local because org CI runners are unavailable;
# .github/workflows/release.yml is the CI equivalent once they're restored.)
cut-release:
	@bash scripts/release.sh $(ARGS)

# ── Editor tooling ────────────────────────────────────────────────────────────
#
# Since v0.7.0 the language server is built into the `cx` binary itself —
# `cx lsp` speaks JSON-RPC 2.0 over stdio (see vcx/cmd/lsp.v and
# cx-tooling's tooling/lsp/README.md). Editor integration is `cx` on $PATH plus
# cx-tooling's example configs at tooling/lsp/{vscode,neovim,helix}.example.*.
#
# `make build-vscode` produces a publishable .vsix wrapping the VS Code
# extension at cx-tooling's tooling/vscode/, built in its pinned checkout
# (deps/cx-tooling/; the extension left with cx-tooling, RULED: RS-12, D59a).
# The .vsix bundles the TextMate grammar,
# snippets, language configuration, and the esbuild-bundled extension
# (LSP-client glue compiled into out/extension.js); it does NOT bundle
# a `cx` binary — users install that separately. `npm run package`
# (vsce, a devDependency) runs the typecheck + bundle via
# vscode:prepublish. Needs node >= 18.13.

build-vscode:
	cd deps/cx-tooling/tooling/vscode && npm ci --silent && npm run package

# ── Benchmark ──────────────────────────────────────────────────────────────────

# #608 — xap/fabric throughput harness (CX-native scenarios + shell
# orchestration). Emits a canonical [bench-report …] to
# deps/cx-core-code/vcx/target/bench-report.cx; gates nothing. BENCH_K scales the run.
.PHONY: bench-xap
bench-xap: BENCH_K ?= 500
bench-xap: build-vcx-dev
	@bench/xap/run.sh $(BENCH_K)

bench: CX_BIN ?= $(CURDIR)/deps/cx-core-code/vcx/target/cx
bench: build-vcx
	@"$(CX_BIN)" --allow-read --allow-write --allow-subprocess --allow-clock \
	   --allow-env bench_report.cx

# bench-python RETIRED with the Python binding (RULED: RS-12, RS-8;
# #1591 item K3): cx-home/cx-binding-python now owns lang/python/ whole.

# Y6 — Streaming evaluator throughput. Standalone V runner; surfaces
# buffered vs streaming MB/s for a representative ?for-over-large-
# sequence workload. Uses the patched V at third_party/v/ (carries
# the macOS hardened-runtime libgc source-compile bypass + vlang/v
# #27178/#27179 fixes) so -prod can be safely enabled on macOS.
# Falls back to system V if the submodule isn't present.
PATCHED_V := $(if $(wildcard $(CURDIR)/third_party/v/v),$(CURDIR)/third_party/v/v,v)
bench-streaming: build-vcx
	$(PATCHED_V) -prod run deps/cx-core-code/vcx/tests/runners/streaming_bench.v

# cxparse unification — parser perf baseline / per-phase N3 gate
# (spec/02-inprogress/cxparse_unification_PLAN.md §6). MUST use the patched V:
# the PATH/devbox V bundles a boehm GC source-compile that corrupts the heap
# during collection and segfaults in -prod on macOS (the patched V carries the
# hardened-runtime libgc bypass — same reason bench-streaming uses $(PATCHED_V)).
bench-cxparse: build-vcx
	VFLAGS='-path "$(V_MODULE_PATH)" $(CX_NATIVE_DEFINES)' $(PATCHED_V) -prod run deps/cx-core-code/vcx/tests/runners/cxparse_baseline_bench.v

# T1 — Evaluator-feature microbench. Covers the v0.7.0 evaluator
# surface additions (FLWOR clauses, ?fn calls, partial application,
# pipeline/arrow operators, ?match, regex via RE2, range).
# Output is parsed by scripts/run_bench_json.cx into the
# T1.* benchmark keys for the V7 perf regression gate.
bench-eval: build-vcx
	v run deps/cx-core-code/vcx/tests/runners/eval_features_bench.v

# ── v0.8.0 §11.6 release-gate harnesses ────────────────────────────────────────
#
# Each target runs one of the three perf gates blocking the v0.8.0 tag
# (conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded), spec/code.md §11.4.4). Exit code
# is 0 on PASS, non-zero on FAIL; CI consumes the gate verdict line.
# The benches print their threshold + measured numbers so PASS/FAIL is
# self-evident in logs. Env knobs documented in each .v file header.

# Gate 14 — pattern compilation (depth-8, 32-binding pattern):
# p99 parse-time MUST be ≤ 1 ms.
#
# `-prod` is load-bearing here for the same reason it is on gate 15 (#804,
# #835): the recipe depends on `build-vcx`, which builds the SHIPPED artifacts
# optimised — but the bench links the evaluator as V SOURCE and compiles it
# fresh, so without `-prod` the gate measured an unoptimised build of the very
# code under test. Measured on gate 15's corpus, the same shape of workload:
# 2.6 MB/s unoptimised vs 13.3 optimised, a 5.1x measurement error. Both gates
# passed either way, so this only ever moved them in the passing direction —
# but a gate that measures a build CX does not ship is not measuring the
# threshold it claims to.
bench-code-pattern-compile: build-vcx
	$(PATCHED_V) -enable-globals -prod run deps/cx-core-code/vcx/tests/runners/code_pattern_compile_bench.v

# Gate 15 — streaming throughput on JSON-shape workloads:
# mean MUST be ≥ 200 MB/s + no trial below 80 % of mean.
#
# `-prod` is load-bearing, not decoration (#804). The recipe depends on
# `build-vcx`, which builds the SHIPPED artifacts optimised — but the bench
# links the evaluator as V SOURCE and compiles it fresh, so without `-prod`
# the gate measured an unoptimised build of the engine, which is not the
# artifact CX ships. Same corpus, same program, same threshold: 2.6 MB/s
# unoptimised vs 13.3 MB/s optimised. A perf gate has to measure the build
# under test; this is a measurement repair, and the §11.4.4 floor is
# untouched by it.
bench-code-streaming: build-vcx
	$(PATCHED_V) -enable-globals -prod run deps/cx-core-code/vcx/tests/runners/code_streaming_throughput_bench.v

# #804 leg-2 CEILING probe — not a gate, a decision instrument. Walks the
# gate-15 corpus doing only what a never-forced lazy record would do
# (scan the child, write its canonical image) and reports the upper bound
# any forcing discipline can reach. Answers, before the code is written,
# whether leg 2's architecture can clear the §11.4.4 floor at all. Re-run
# it when leg 2 lands: the real number must sit under this ceiling, and
# how far under is the discipline's measured cost.
bench-lazy-ceiling: build-vcx
	$(PATCHED_V) -enable-globals -prod run deps/cx-core-code/vcx/tests/runners/lazy_record_ceiling_probe.v

# #804 leg-9 ALLOCATION CENSUS — the instrument that answers "what generates
# the garbage", which sampling cannot. `sample` attributes CPU; collection work
# is triggered by allocation VOLUME but paid at whatever safepoint the mutator
# next reaches, so a call tree charges it to whoever polled rather than to
# whoever produced it. This meters bytes directly (vgc's monotone
# `gc_total_allocated`) across a ladder of rungs that each stop one stage
# earlier, so consecutive differences are one stage's allocation.
#
# It exists because leg 8 assumed a removed allocation would compound through
# the collector and it did not. Run it BEFORE choosing the next optimisation,
# and again after, with the same rung. Not a gate — a decision instrument.
#
# One rung per process (`LEG9_SHAPES=<name>`): three rungs in one process
# pollute each other's heap state and the jitter reads 45-70% of mean instead
# of ~90%. `LEG9_INPUT_MB` defaults to 64 — do not lower it below 16 or vgc's
# 1 MiB accounting flush swamps the reading (the probe says so itself).
bench-streamed-alloc: build-vcx
	$(PATCHED_V) -enable-globals -prod run deps/cx-core-code/vcx/tests/runners/streamed_for_alloc_probe.v

# Gate 16 — HTTP service throughput (in-process substrate per §1.2):
# mean MUST be ≥ 10K req/s AND p99 ≤ 10 ms.
#
# `-prod` is load-bearing here for the same reason it is on gate 15 (#804,
# #835): the recipe depends on `build-vcx`, which builds the SHIPPED artifacts
# optimised — but the bench links the evaluator as V SOURCE and compiles it
# fresh, so without `-prod` the gate measured an unoptimised build of the very
# code under test. Measured on gate 15's corpus, the same shape of workload:
# 2.6 MB/s unoptimised vs 13.3 optimised, a 5.1x measurement error. Both gates
# passed either way, so this only ever moved them in the passing direction —
# but a gate that measures a build CX does not ship is not measuring the
# threshold it claims to.
bench-code-http: build-vcx deps-present
	$(PATCHED_V) -enable-globals -prod run deps/cx-platform-net/vcx/tests/runners/code_http_throughput_bench.v

# HTTP backend-direction isolation bench — settles whether the ~10k
# req/s ceiling is transport-bound (net.http socket stack) or
# interpreter-bound (code.eval + env.clone) before any backend rewrite.
# Two-point: in-process code.eval leg vs real net.http listener on :0
# with a trivial no-op handler. Prints a ratio + verdict, no PASS/FAIL.
#
# `-prod` for the #835 reason, and it matters MORE here than on a pass/fail
# gate: this bench exists to decide whether the ~10k req/s ceiling is
# transport-bound or interpreter-bound, and an unoptimised build inflates the
# INTERPRETER leg specifically — so the unoptimised verdict is biased toward
# the answer the bench is supposed to test for.
bench-code-http-isolation: build-vcx deps-present
	$(PATCHED_V) -enable-globals -prod run deps/cx-platform-net/vcx/tests/runners/code_http_isolation_bench.v

# Gate 7 — concurrency soak. Loops a buffered send/receive workload
# detecting deadlocks (per-iter wall-clock cap) and registry leaks
# across an extended run. Default is a 30 s smoke; release candidate
# runs the full 24 hours via `GATE7_DURATION_SEC=86400`.
bench-code-soak: build-vcx
	$(PATCHED_V) -enable-globals run deps/cx-core-code/vcx/tests/runners/code_concurrency_soak.v

# Gate 8 — async cancellation battery. 10 000-iteration battery
# against the canonical [?cancel] → [?await] pattern; zero non-
# deterministic failures required.
bench-code-cancel: build-vcx
	$(PATCHED_V) -enable-globals run deps/cx-core-code/vcx/tests/runners/code_async_cancel_battery.v

# abi.md §4 performance-budget driver (#805/AF-6 — the table's FIRST
# measuring artifact). In-process ABI-call timing, full call semantics;
# budgets verbatim from the spec, never trued; exit 1 on any red cell.
# First honest verdict (2026-08-13): six conversion cells RED at
# 7.9-16.7x over budget (the #804 engine ceiling extends here);
# cx_events_next PASS at ~9 ns/event. 100 MB tier opt-in: ABI_S4_100MB=1.
bench-abi-s4: build-vcx
	$(PATCHED_V) -enable-globals run deps/cx-core-code/vcx/tests/runners/abi_s4_bench.v

# Aggregate runner — drives all three v0.8.0 perf gates back-to-back.
# Exit code is the FIRST failing gate's exit code (make stops on
# first non-zero); use individual targets to triage in isolation.
bench-code-gates: bench-code-pattern-compile bench-code-streaming bench-code-http

# ── v0.8.0 §11.6 gate-evidence targets (5 / 6 / 9 / 12 / 28.7 / 28.8 / 30.5) ──
#
# Each target below corresponds to a §11.6 release gate that the master
# gate-check (`scripts/gate_check.sh`) invokes by name. The
# underlying test files all exist and already pass via the `test-vcx-suite`
# umbrella; these targets are narrowly-scoped gate-evidence pointers so
# the gate-check can verify each gate's coverage in isolation rather
# than relying on the umbrella having run a moment earlier. Per
# conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded).

# ── Gate 5 — resilience composition matrix ────────────────────────────────
# Drives the 67 resilience fixtures in conformance/code.txt (31 single-
# directive + 36 composition matrix) via deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v
# whose `supported_fixtures` whitelist covers all 67. The fixture runner
# parses each block, evaluates in_code with $doc bound, and compares the
# rendered result against out_text. Asserts at runtime that at least one
# fixture executed. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 5.
# 1448-a REMOVED this target's by-construction red. It used to say: VFLAGS_VCX
# carries no `-d cx_db_sqlite -d cx_db_redis`, but the same
# code_eval_fixtures_test.v also walked every module corpus file, and
# db.cxd's cases 010-023 need those engines — so the target red 14 ENFORCED db
# fixtures (E_STORE_UNRESOLVED_BACKEND "this build carries no sqlite engine",
# and `no callable "redis-open"`) and exited 2 on a perfectly healthy tree.
# The module walk now lives in the shard files, and this file grades code.cxd,
# the packages and the four fast-path differs — none of which need a db engine.
# The §11.6 gate-5 corpus is in code.cxd, so this target grades exactly what
# its header claims and its exit code means what it says.
#
# To verify a module suite you added, run `make fixtures` (every shard plus this
# driver, under the pipelines' flags) and read the census line — never this
# target, which no longer reaches the module corpus directories at all.
.PHONY: test-vcx-resilience-matrix
test-vcx-resilience-matrix: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v

# #63/#58 concurrency-soundness gate. Stresses the cooperative-safepoint collector
# (now the default) under multi-reactor HTTP + concurrent [?worker] threads and
# asserts ZERO sweep-while-live via the passive detector oracle (0xbf1) + crash
# count. The gate builds its own detector binary and has proven detection power
# (RED on the legacy -d vgc_legacy_stw collector, GREEN on the default). Skips the
# HTTP stressor gracefully if `wrk` is absent. See scripts/concurrency_soundness_gate.sh.
.PHONY: test-vcx-concurrency-soundness
test-vcx-concurrency-soundness:
	zsh scripts/concurrency_soundness_gate.sh

# ── Gate 6 — service + client round-trip ──────────────────────────────────
# Drives the 21 services + clients fixtures in conformance/code.txt via
# the same deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v whose `supported_fixtures`
# whitelist covers all 21 program-svc-NNN fixtures (HTTP verbs + status
# codes + TLS + streaming body + graceful-stop + handle lookup). Per
# conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 6.
# Since 1448-a that file grades code.cxd, the packages and the differs; the
# module-corpus walk is in the shard files (`make fixtures`).
.PHONY: test-vcx-services
test-vcx-services: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test deps/cx-core-code/vcx/tests/code_eval_fixtures_test.v

# ── Gate 9 — diagram round-trip (SVG / PNG / Mermaid) ─────────────────────
# Diagram round-trip coverage already lives under `test-code-diagram`
# (drives conformance/code_diagram.txt through cx_code_diagram +
# cx_code_tree with structural-equivalence — 29/29
# fixtures). This target is the §11.6-named alias plus the V-side
# diagram unit tests that exercise the emitter + round-trip directly.
# Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 9.
.PHONY: test-vcx-diagram-roundtrip
test-vcx-diagram-roundtrip: build-vcx
	$(MAKE) test-code-diagram
	VFLAGS='$(VFLAGS_VCX)' v test deps/cx-core-code/vcx/tests/code_diagram_roundtrip_test.v \
		deps/cx-core-code/vcx/tests/code_units_umbrella_test.v

# ── Gate 12 — reference renderer (CLI + web + LSP) ────────────────────────
# Drives the V-side renderer test suite — `code_render_test.v` covers
# the production code renderer (deps/cx-core-code/vcx/code/render.v: body-quote selection,
# attribute serialisation, scalar typing, directive shape, structural
# vs. text round-trips); `path_renderer_test.v` covers the
# PathNode → source emitter introduced for the CXPath value kind. LSP CodeLens
# tests are not yet authored; this target tracks the V-side renderer
# coverage. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 12.
.PHONY: test-renderer
test-renderer: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test deps/cx-core-code/vcx/tests/code_units_umbrella_test.v \
		deps/cx-core-code/vcx/tests/parser_units_umbrella_test.v

# ── Gate 28.7 — CXPath axis coverage (all 12 axes) ────────────────────────
# Drives the V-side per-axis test files: forward axes (21 tests:
# child / descendant / descendant-or-self / following-sibling / following
# / attribute / self / parent), reverse axes (17 tests: ancestor /
# ancestor-or-self / preceding-sibling / preceding), misc/expression
# scaffolding (21 tests: predicates, unions, integer-literal predicate,
# attribute-axis short-form), and dispatcher integration (3 tests:
# `[?find …/axis::…]` end-to-end). 62 tests total exercising the
# 12-axis vocabulary. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 28.7.
# (test-cxpath-axis-coverage RETIRED at the #795 batch, 2026-08-15 — its
# files died with the placeholder axis engine at the #805 sweep; see
# vcx/Makefile's conform-ns-cxpath retirement note.)

# ── Gate 28.8 — [?modify] action coverage (all 11 actions) ────────────────
# Drives the V-side modify test files: `modify_eval_test.v` covers
# the structural evaluator with one positive case per
# action (:set / :delete / :using / :rename / :set-attr / :delete-attr /
# :append / :prepend / :insert-before / :insert-after / :replace) plus
# action-chain semantics, focus-miss-skip-not-error, pure-functional
# invariant, multi-match focus, and Z79g path-aware dispatcher hop;
# `modify_node_test.v` + `_codec_test.v` cover the ModifyNode shape
# + binary codec round-trip; `modify_parser_test.v` covers the
# `[?modify]` directive parser. Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate
# 28.8 (structural-sharing perf budget lives at gate 30.5).
.PHONY: test-modify-action-coverage
test-modify-action-coverage: build-vcx
	VFLAGS='$(VFLAGS_VCX)' v test deps/cx-core-code/vcx/tests/eval_semantics_umbrella_test.v \
		deps/cx-core-code/vcx/tests/node_units_umbrella_test.v \
		deps/cx-core-code/vcx/tests/modify_node_codec_test.v

# ── Gate 30.5 — [?modify] structural-sharing perf budget ──────────────────
# Drives deps/cx-core-code/vcx/tests/runners/code_modify_sharing_bench.v — single-match
# `:set` heap delta + 1000-match `:set-attr` heap delta + identity-hash
# invariant. Budget: < 1 KB new heap per matched node on
# 10 MB doc. v0.8.0 ships with sharing-ratio + identity invariants
# enforced; the absolute-byte budgets are ADVISORY per the bench
# header's Element + Attribute diet analysis (post-diet residual cost
# is spine-frame overhead that closes to v0.9.0+ with HAMT-backed
# items containers). Per conformance/GATE_REGISTER.md (the living register; the archived status doc is superseded) gate 30.5.
bench-code-modify-sharing: build-vcx
	$(PATCHED_V) -enable-globals run deps/cx-core-code/vcx/tests/runners/code_modify_sharing_bench.v

# ── Rosetta corpus cadence audit ──────────────────────────────
#
# `make corpus-audit` re-audits every program under corpus/rosetta/ against
# the current HEAD: runs each `NN-*.cx` via deps/cx-core-code/vcx/target/cx, classifies the
# live status (green / workaround / blocked / missing), and diffs against
# the table in corpus/rosetta/AUDIT.md. Exits 0 on full agreement, 1 on
# drift — drift is the cadence signal that a Wave-N fix has re-classified
# a program (or that AUDIT.md is stale). Closure of the
# task tracker's W1-H #32 item.
#
# Override knobs: CX_BIN=path (default deps/cx-core-code/vcx/target/cx),
# CORPUS_DIR=path (default corpus/rosetta).
.PHONY: corpus-audit
corpus-audit: build-vcx
	@bash scripts/corpus_audit.sh


# ── `cx fmt` corpus sweep (#1348) ───────────────────────────────────────────
#
# TWO sweeps, because one cannot be both: `fmt-sweep` is the CORRECTNESS
# census over every tracked `.cx` file INCLUDING `fixtures/bench/`, and
# `fmt-sweep-timed` is the wall-clock pass over the non-bench files, whose
# count stays comparable across runs. #1348 recorded that every fmt corpus
# measurement so far excluded the bench blobs because one 10 MB file made a
# 90 s sweep take half an hour — "which means the ONE class of input where
# formatter cost is worth measuring is the one class never measured".
#
# The correctness pass feeds every file as a copy with one leading blank line
# prepended, so `output == input` means the formatter DECLINED and cannot mean
# "already canonical". Without that, `cx fmt F == F` is the vacuous probe the
# #1318/#1320 record warns about: `cx fmt` fails closed by returning the
# SOURCE at exit 0, so a sweep comparing a file to itself scores every silent
# decline as a pass.
#
# A REPORT by default. `--max-declined N` / `--max-errors N` make it a
# ratchet, and it becomes a gate step once the census is a committed number.
#
# CX_SWEEP_BIN is the binary MEASURED and the binary that runs the sweep — one
# variable for both, because a census of one binary produced by another is a
# census of neither. It defaults to the shipped `deps/cx-core-code/vcx/target/cx`, which is what
# #1348's own figures were taken with; a step that only wants the correctness
# verdict can point it at `deps/cx-core-code/vcx/target/cx-dev`.
CX_SWEEP_BIN ?= deps/cx-core-code/vcx/target/cx
.PHONY: fmt-sweep fmt-sweep-timed
# --allow-clock is load-bearing for the timed pass and NOT optional: a denied
# clock capability makes `[$time:monotonic-now]` answer ABSENCE rather than
# fail, so every `ms` column came out empty and the total with it (measured in
# lane_A_1348). Granted to both recipes because either can be handed `--timed`
# through FMT_SWEEP_ARGS.
fmt-sweep: build-vcx
	@$(CX_SWEEP_BIN) --allow-read --allow-write --allow-subprocess --allow-clock \
	  scripts/fmt_corpus_sweep.cx --bin $(CX_SWEEP_BIN) $(FMT_SWEEP_ARGS)

fmt-sweep-timed: build-vcx
	@$(CX_SWEEP_BIN) --allow-read --allow-write --allow-subprocess --allow-clock \
	  scripts/fmt_corpus_sweep.cx --bin $(CX_SWEEP_BIN) --timed --no-bench $(FMT_SWEEP_ARGS)

# ── fmt-sweep-gate (RULED: 1348-c) — the census as a GATE ────────────────────
#
# The sweep above is a REPORT. This is the same instrument with the numbers
# committed, and it is in TEST_TARGETS: the Makefile note at the top of this
# section said it "becomes a gate step once the census is a committed number",
# and #1348's census is that number.
#
# The ERROR verdict is gated by a NAMED ROSTER, not by a count. A count has no
# lower bound: fix one of the five files that are supposed to fail and the
# total drops below the budget while the step stays green, and a genuinely new
# error is invisible until it is the sixth. The roster reds BOTH ways — a file
# that errors and is not listed, and a listed file that has STOPPED erroring.
# The second is the half a count cannot express, and it is load-bearing: a
# roster entry for a real gap (`tooling/vscode/test/grammar/basic.cx`, #1347's
# family, until it left with cx-tooling, RULED: RS-12) makes this step say the
# line must go when the gap is fixed. Same shape as the #1350 golden MANIFEST (`99c25169d`).
#
# DECLINED stays a count, ratcheted at the committed census, and it is a
# ONE-WAY ratchet by convention: whoever lowers it edits the number down in the
# same landing. UNSTABLE reds at >0 with or without --ratchet, because §7 says
# fmt_source fails closed rather than returning an unsettled candidate, so
# there is no number to ratchet against.
#
# Census measured at 3ef4d597e, the landing base:
#   SWEEP-FILES=272  FORMATTED=173  DECLINED=94  UNSTABLE=0  ERROR=5
# Re-measured at the examples/platform/ landing:
#   FORMATTED=181  DECLINED=105  UNSTABLE=0  ERROR=5  (see #1391)
# It is 272/94 and not the 271/93 of #1348's own census at 12abdac33 because
# #1317 added `bench/flow/served.cx`, which declines.
# 2026-09-09 (#1058 T1.9, RULED: 1058-T1.9-a) — def-body comments are placed:
#   SWEEP-FILES=272  FORMATTED=174  DECLINED=93  UNSTABLE=0  ERROR=5
# One file un-declines; the rest of the def-bearing corpus still declines on
# the layout's other limits (a head wider than the bound, a comment inside the
# last child of a form that fits), which are not this ruling's.
# RAISED 93 -> 105 by the examples/platform/ landing, and the reason is on
# the record rather than in a commit message: `cx fmt` FAILS CLOSED, silently,
# on any file where a bracketed or collection value stands in ARGUMENT or
# ATTRIBUTE position, and twelve of the new example programs are ordinary CX that
# does exactly that. Minimal repros, each a whole file that comes back
# unchanged at exit 0:
#
#     [x total=[* 2 3]]
#     [$scim:schemas {}]
#     [$array:first ('a','b')]
#
# The same operator as a CHILD (`[x [* 2 3]]`) and the same map in a `[?let]`
# binding both format. So it is the POSITION, not the construct — which is
# also why the census reads as 93 stubborn legacy files when it is one hole
# with 93 instances (`stdlib/flow.cx`, every `x/*.cx`, every
# `spec/03-approved/xap/demos/**/*.cx`, and `cx xap init`'s own generated
# `compose.cx`). Filed as #1391.
#
# Contorting the examples to dodge the hole was the alternative and it was
# rejected: `total=[* $qty $unit]` is how one multiplies, and an example
# written around a formatter limitation teaches the limitation. This number
# comes back down — by far more than twelve — when #1391 closes.
#
# RAISED 105 -> 107 by #1403's two new programs, scripts/sso_interop/idp.cx
# and scripts/sso_interop/rp_drive.cx. Same hole, measured the same way
# (declined=107 on the first sweep after they landed, +2 exactly): both carry
# bracketed values in argument position that #1391 declines —
# `[$crypto:jwt-sign $claims [$ec1-private] {alg: 'ES256', kid: 'ec-1'}]` and
# `[$http:get $url {follow-redirects: false}]` among them. Rewriting either to
# dodge the formatter would mean not calling the stdlib the way the stdlib is
# called, which is the one thing an interop step must not do.
#
# 107 -> 108 with #1396's scripts/sso_interop/proxy.cx, the forward proxy the
# step's three proxy rows run through: ONE more file, measured declined=108 on
# the first sweep after it landed. The same hole again — a collection in
# argument position, `[$http:request $method $target {headers: ..., body: ...,
# follow-redirects: false}]`.
#
# At the INT-2 batch the head had ratcheted 108 -> 111 for #1394's three new
# .cx files (stdlib/sso.cx, the sso deployment, scripts/sso_interop/deploy_drive.cx
# — a collection or bracketed call in ARGUMENT or ATTRIBUTE position, the very
# hole #1391 closes below); the batch's own sweep measures where they land.
#
# 108 -> 31 by #1391 (RULED: 1391-a), measured on the whole 297-file corpus:
#
#   SWEEP-FILES=297 FORMATTED=244 DECLINED=31 TREE-REFUSED=17 UNSTABLE=0 ERROR=5
#
# The ruling said "the number comes back down — by more than ten — when the
# hole closes"; it came down by 77. The hole was ONE vacuous comparison. The
# data candidate was SEEDED WITH THE SOURCE and overwritten only when the data
# parse succeeded, so a document the DATA grammar cannot read — a bracketed or
# collection value in ARGUMENT or ATTRIBUTE position — reached the acceptance
# test comparing the input against ITSELF: canonical text equal, shape equal,
# comments equal, by construction. The lane blessed the source as "the data
# format preserved meaning", returned it verbatim at exit 0, and never reached
# the program lane that formats it.
#
# Every DECLINED row in the log now carries the refusal line that names the
# construct and its position (RULED: 1391-a) — a count with no names is what
# let one hole read as 93 stubborn legacy files. The 31 that remain are five
# reasons, and 26 of them are ONE:
#
#   26  the comment layout could not place every comment this file carries
#    2  the comment-bearing layout re-parses to a different program shape
#    1  the comment-bearing layout does not re-parse to the same canonical text
#    1  the data formatter does not carry every comment back
#    1  the canonical form is not its own fixed point (§7)
#
#
# 31 -> 34 at the INT-2 merge (RULED: INT-2, 1391-a), measured on the batch's
# own tree — fmt + #1421 + #1422 on the head — in run 2 of its pipeline:
#
#   SWEEP-FILES=301 FORMATTED=245 DECLINED=34 TREE-REFUSED=17 UNSTABLE=0 ERROR=5
#
# The +3 is the paragraph above coming due: #1394's stdlib/sso.cx and its
# deployment (examples/platform/sso/deployment/deployment.cx) no longer
# decline on the argument-position hole #1391 closed — they decline one
# stratum down, on an interior `[; …]` comment inside a form body the
# comment layout cannot place (sso.cx:232, deployment.cx:74) — and #1422's
# stdlib/audit.cx (audit.cx:359) is a new file in the same class. Its
# third file, scripts/sso_interop/deploy_drive.cx, formats. The class is
# 29 of the 34 now and has its own issue, #1436; the number comes back down
# when that closes. Rewriting the three files' comments to dodge the layout
# was not an option: a comment written where CX allows one must format.
# ── FMT_SWEEP_MAX_TREE_REFUSED (RULED: 1384-a) — the §1 guard's own column ───
#
# TREE-REFUSED is `cx-err:CXER0300`: `cx fmt` produced a canonical form whose
# node tree is NOT the input's, so the source came back and the refusal said
# so with the differing node's PATH and both values. It is its own column
# because it is neither of the other two things — not "a shape fmt cannot
# format" (DECLINED) and not "fmt fell over" (ERROR), but "fmt formatted the
# file and changed the document", which is an open defect with a file name and
# a node path. Folding it into DECLINED would hide a data-changing formatter
# inside a ratchet; folding it into ERROR would red the expected-error ROSTER,
# which exists for files `cx fmt` is SUPPOSED to refuse.
#
# 17 files at the landing, in four classes. NONE of them is silent any more,
# and none was visible before: every one of these formatted at exit 0 and
# changed the document.
#
#   * a SPACE inserted into a text run at a `[` boundary — #1384's OWN defect
#     class in a third shape (3: fixtures/bench/bench_{small,medium,large}.cx).
#     `[tags :string[] internal db cache]` shipped as
#     `[tags :string [] internal db cache]`, so the data reading's one Text
#     node `":string[] internal db cache"` became `":string"` plus an empty
#     array plus the rest. #1384's two shapes are fixed at the cause in this
#     same landing; this one is not, because the run rule cannot cross `[`,
#     which is a structural byte — fixing it needs the emitter to know the
#     atom and the `[]` were GLUED, which is an AST change and not 1384-a's.
#   * an interior COMMENT the formatter RE-ORDERS past the node it documents
#     (9: the two `render-ctx.cx`, both cxstore clients, `home-components.cx`,
#     both `tooling/cxfabric/*.config.cx`, `check_version_consistency.cx`, and
#     `check_v_fork_patches.cx` in the other direction).
#     `tooling/cxfabric/adapter.config.cx` is the clearest: the comment that
#     opens `[webhook-adapter]` and explains `[fabric …]` comes back AFTER it.
#     canonical.md §2.9 requires "comment placement preserved relative to
#     nodes", so the comment is still there and no longer documents anything.
#   * an ATTRIBUTE WRITTEN AFTER BODY TEXT, which the program reading hoists
#     to the head and the data reading reads as part of the text run
#     (2: `design/787/w1/surface.cx`, `spec/…/oriel/data/oriel-theme.cx`).
#   * program surface the data reading can only carry as TEXT or as an
#     unstructured collection (3): a CXPath `/@a` step re-spelled `@a`
#     (`checkout.flow.cx`, `packages/gtin/gtin.cx`) and a `(…)` sequence the
#     data grammar cannot read (`gen_guide/stdlib_docs_check.cx`). The two
#     spellings the ruling GRANTS — the quote character and an underscored
#     integer — are folded out of the comparison, so a file whose only
#     difference was one of those is not here.
#
# This number goes DOWN only. Each class wants its own issue; none is in
# 1384-a's scope, which is the guard plus #1384's own two measured shapes.
#
# 2026-09-16 (#1436 in part, RULED: FMT-1) — four comment-placement strata of
# the DECLINED class are fixed at the layout: a comment inside a DESCENDANT no
# longer leaves an enclosing form free to fit the bound and be written flat; a
# comment before a form's first child, and one trailing its last, are placed
# for every form and not only for a `[?def]`; and a head that already runs past
# the bound no longer refuses the break a comment needs. Measured on the
# branch's own binary, the sweep's own count lines:
#
#   SWEEP-FILES=310 FORMATTED=283 DECLINED=12 TREE-REFUSED=10 UNSTABLE=0 ERROR=5
#
# 12 -> 11 by the sso extraction (RULED: RS-12, #1591 item 11), and the number
# comes down here in the same landing per this block's own convention. The
# sweep is `git ls-files '*.cx'` of THIS repository, so the module and the
# seven example programs that left it are no longer swept; `stdlib/sso.cx` was
# one of the twelve. It is not a formatter improvement and does not read as
# one: the file still declines, in cx-platform-sso, where that repository's
# own `make lint` is what sees it.
#   SWEEP-FILES=306 FORMATTED=289 DECLINED=11 TREE-REFUSED=10 UNSTABLE=0 ERROR=5
#
# TREE-REFUSED 10 -> 9 by the flow extraction (RULED: RS-12, #1591 item 15),
# brought down in the same landing by the same convention: twenty `.cx`
# files left with cx-platform-flow, and one of them,
# examples/platform/flow/checkout/checkout.flow.cx, was the `/@a` -> `@a`
# member of the program-surface class above. Not a formatter improvement; the
# file is refused the same way in the repository that holds it. DECLINED is
# unmoved (stdlib/flow.cx formats). Measured on the branch's own binary:
#   SWEEP-FILES=297 FORMATTED=272 DECLINED=11 TREE-REFUSED=9 UNSTABLE=0 ERROR=5
#
# 11 -> 9 by the agent and ux extractions (RULED: RS-12, #1591 item 12), the same
# convention: `x/mcp-server.cx` and `x/ux-web.cx` were two of the eleven and
# left this repository with the rest of x/. Not a formatter improvement — both
# still decline, in cx-platform-agent and cx-platform-ux.
#   SWEEP-FILES=291 FORMATTED=268 DECLINED=9 TREE-REFUSED=9 UNSTABLE=0 ERROR=5
#
# DECLINED 34 -> 12 and TREE-REFUSED 17 -> 10, and both numbers below move to
# the measurement in the same commit as the fix, which is what FMT-1 says a
# ratchet move is. TREE-REFUSED falls by 9 (nine files whose interior comment
# the layout used to RE-ORDER now keep it where it was) and rises by 2 —
# `design/787/w5/shop/surface.cx` and `spec/…/oriel/surface.cx` stop declining
# and land on the PRE-EXISTING attribute-after-body-text defect the class above
# already names; `cx fmt` still refuses them, so nothing new is data-changing.
#
# #1436 does NOT close here. Seven files still decline on a comment the layout
# cannot place — four of them on a comment inside a MAP literal, whose `, key: `
# gap is the one gap `layout_separators` calls unbreakable (fmt-023 and fmt-037
# pin that as fail-closed today), and three on shapes not yet reduced:
# `design/787/w1/serve.cx`, `spec/…/oriel/tui.cx`, `x/ux-web.cx`. The other
# five declines are the census's OTHER classes, none of them #1436's.
#
# 9 -> 8 by the decisions/registry leave (RULED: RS-12, D59a; #1591 item K3):
# design/787/w1/serve.cx left whole for cx-decisions, one of the three
# not-yet-reduced files named just above (the other two are unmoved). Not a
# formatter improvement; the file still declines, in cx-decisions, where
# that repository's own `make lint` never runs `cx fmt` at all. Measured on
# the branch's own binary: SWEEP-FILES=226 FORMATTED=214 DECLINED=8
# TREE-REFUSED=4 UNSTABLE=0 ERROR=0
FMT_SWEEP_MAX_DECLINED ?= 8
FMT_SWEEP_MAX_TREE_REFUSED ?= 9
FMT_SWEEP_EXPECTED_ERRORS ?= scripts/fmt_corpus_expected_errors.txt
.PHONY: fmt-sweep-gate
fmt-sweep-gate: build-vcx
	@$(CX_SWEEP_BIN) --allow-read --allow-write --allow-subprocess --allow-clock \
	  scripts/fmt_corpus_sweep.cx --bin $(CX_SWEEP_BIN) --ratchet \
	  --max-declined $(FMT_SWEEP_MAX_DECLINED) \
	  --max-tree-refused $(FMT_SWEEP_MAX_TREE_REFUSED) \
	  --expected-errors $(FMT_SWEEP_EXPECTED_ERRORS)


# ── REPR GUARD (#1119 W1, RULED: RP-5) — the CXDM live-memory ratchet ────────
# Parses a ~2 MB corpus per step (json / xml / cx) through the `cx` module,
# forces a collection with the tree still reachable, and asserts
# live bytes ÷ input bytes against a bound pinned to today's measurement with
# headroom. A RATIO, never a time and never an absolute byte count, so the
# verdict holds on a loaded machine and on other hardware — measured identical
# under eight saturating CPU burners. ~0.6 s once the driver is built; the
# driver rebuilds only when vcx/cx, bench/repr/repr.v, or the pinned V moves.
#
# It is in TEST_TARGETS because it is the measurement instrument the rest of
# the representation campaign is judged by: W5-W7 each re-pin these bounds
# DOWNWARD at their exit, and a wave that makes the tree bigger has to red this
# step before it can land. Contract + the numbers: bench/repr/README.md.
#
# `repr-guard` depends on `build-vcx` for one reason: the driver links the same
# vendored RE2 static archive the CLI does (`third_party/re2/obj/libre2.a`), so
# the step's prerequisites ARE build-vcx's. Free inside `make test` (the serial
# pre-build already ran), and it is what makes `make repr-guard` work in a fresh
# worktree, where that archive does not exist yet.
#
# THE RETRY CLASS (#1431, RULED: 1431-a). The step is on GAUGE_SERIAL_RETRY —
# "memory gauge under load", the class defined beside the two `v test` rosters
# above. A run whose ONLY failure is a bound exceedance re-measures once,
# serially (the driver is already built by then, so the second reading costs
# ~0.6 s), and the run fails if the second reading is over too. Anything else
# the script can fail with — an absent V, a driver exiting non-zero, a
# measurement that does not parse — is a real failure with no retry, so the
# class cannot absorb a broken instrument. The bound itself never moves here:
# re-pinning is a wave-exit obligation in run.sh (RP-5), never a reaction to a
# red. Every reading now carries the machine's load average, so the next such
# row is classifiable from the log alone.
.PHONY: repr-guard
repr-guard: build-vcx
	@log=deps/cx-core-code/vcx/target/repr-guard-run.log; stf=deps/cx-core-code/vcx/target/repr-guard-status; \
	mkdir -p deps/cx-core-code/vcx/target; \
	{ bench/repr/run.sh 2>&1; echo $$? > $$stf; } | tee $$log; \
	st=$$(cat $$stf); \
	if [ $$st -ne 0 ]; then \
	  if grep -aq 'exceeds the pinned bound' $$log; then \
	    rel=bench/repr/run.sh; \
	    $(RETRY_REASON_CASE); \
	    echo "──── serial retry ($$reason): $$rel ────"; \
	    bench/repr/run.sh || exit 1; \
	    echo "──── the re-measurement is within every pinned bound; the first reading was load-induced (#1431) ────"; \
	    st=0; \
	  else \
	    echo "──── real failure (no retry class applies): bench/repr/run.sh did not report a bound exceedance ────"; \
	  fi; \
	fi; exit $$st

# ── bench-flow: the cx-platform/flow performance and scale step ────────────────
#
# §9 of spec/03-approved/platform/flow.md (RULED: WF-14), #1265 W1 packet C.
# Floors are set from the first measurement and ratcheted like bench/repr:
# ledger/bench_flow_first_measurement_2026_09_04.md records the numbers, the
# machine and the binary; bench/flow/run.sh carries the floors they set.
#
# DELIBERATELY NOT IN TEST_TARGETS. Half its rows are wall-clock durations
# (transitions/s, latencies, a map's wall time), and `make test` runs its
# targets under `-j` — a duration floor there reds on a busy machine rather
# than on a regression, which is how a gate stops being believed. bench/repr
# earns its TEST_TARGETS seat because its quantity is a RATIO of live bytes.
# The load-insensitive halves of this step ARE gated: the two per-item COUNT
# rows are pinned exactly in conformance/platform/flow.cxd (flow-040), which
# cx-platform-flow's own gate grades with `cx corpus` since the extraction, and
# the racing-advancer count in the repository's lanes/racing_advancers_lane.cx,
# which `test-flow-umbrella` runs out of the pinned checkout in `make test`.
# Run this target deliberately — before a release, and at every #1265 wave
# exit, whose ledger row re-pins what it improved. Contract + numbers:
# bench/flow/README.md.
#
# THE BENCH MOVED WITH THE MODULE (RULED: RS-12, #1591 item 15): bench/flow/,
# the corpus row flow-040 and the umbrella are cx-platform-flow's, read out of
# the pinned checkout. run.sh derives its REPO from its own path, so inside the
# checkout it would look for a `deps/cx-core-code/vcx/target/cx-dev` that is not there; CX_BIN is
# what crosses, and it names THIS tree's dev binary, the one the step builds.
.PHONY: bench-flow
bench-flow: build-vcx-dev
	@test -f deps/cx-platform-flow/bench/flow/run.sh || { \
	  echo "bench-flow: deps/cx-platform-flow/ is not there — the bench lives in the pinned repository now (RS-12); run \`make deps-sync\`" >&2; \
	  exit 2; }
	@CX_BIN="$(CURDIR)/deps/cx-core-code/vcx/target/cx-dev" deps/cx-platform-flow/bench/flow/run.sh

# ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	$(MAKE) -C deps/cx-core-code/vcx DEPS_CXD_PATH=$(CURDIR)/deps.cxd DEPS_ROOT_PATH=$(CURDIR)/deps CX_V_PIN=$(CURDIR)/third_party/v/v DEPS_THIRD_PARTY_PATH=$(CURDIR) DEPS_EXTRA_VPATH=$(CURDIR)/vcx clean
	rm -rf $(DIST_DIR)
	# lang/rust, lang/python cleanup RETIRED with the bindings (RULED: RS-12,
	# RS-8; #1591 item K3) — cx-home/cx-binding-{rust,python} own their own
	# clean targets now.

## test-oriel-lane  ORIEL, the reference XAP, as its own CI step (#869): boot
##                  the store at spec/03-approved/xap/demos/oriel/, run the
##                  five asserting instruments (drive 38, keys 9, voice,
##                  nokernel, diff drift=0), tear down. bench stays
##                  measured-not-asserted. Refuses if :8790 is already served.
##
##                  THE LANE MOVED, THEN THE ESTATE DID TOO (RULED: RS-12,
##                  RS-8, RS-7, RS-20; #1591 items 12 and K3). scripts/
##                  oriel_lane.sh is cx-platform-ux's; the ORIEL estate it
##                  drives (spec/03-approved/xap/demos/oriel/) was this
##                  tree's and is cx-platform-xap's now (K3's leave). So the
##                  step runs the script out of the UX pin, against THIS
##                  tree's binary, with ORIEL_ESTATE naming the XAP pin's
##                  checkout as the root it cds to. Both checkouts refuse by
##                  name with exit 2 and name `make deps-sync` when absent —
##                  never a skip.
.PHONY: test-oriel-lane
test-oriel-lane: build-vcx
	@test -f deps/cx-platform-ux/scripts/oriel_lane.sh || { \
	  echo "test-oriel-lane: deps/cx-platform-ux/ is not there — the lane script lives in the pinned repository now (RS-12); run \`make deps-sync\`" >&2; \
	  exit 2; }
	@test -f deps/cx-platform-xap/spec/03-approved/xap/demos/oriel/serve.cx || { \
	  echo "test-oriel-lane: deps/cx-platform-xap/ is not there — the ORIEL estate lives in the pinned repository now (RS-12, RS-8; #1591 item K3); run \`make deps-sync\`" >&2; \
	  exit 2; }
	@ORIEL_ESTATE="$(CURDIR)/deps/cx-platform-xap" CX_BIN="$(CURDIR)/deps/cx-core-code/vcx/target/cx" bash deps/cx-platform-ux/scripts/oriel_lane.sh

## test-agent-real-lanes  The agent modules' four real-socket lanes as their
##                  own step (RULED: RS-12, #1591 item 12): an MCP client and
##                  server, an A2A server and client, an Ollama-shaped chat
##                  endpoint — each a real loopback round trip between two
##                  cx processes. They were V test files this step copied
##                  under vcx/ to compile against testenv; the owner's D64c
##                  made them CX lanes in cx-platform-agent (RULED: RS-31),
##                  runnable by a released cx alone, so this step runs them
##                  the way the repository does: from the checkout's root,
##                  with CX_BIN naming THIS tree's deps/cx-core-code/vcx/target/cx. The lane
##                  names are the contract; one the checkout lacks refuses
##                  with exit 2 and names `make deps-sync` — never a skip.
##                  Real sockets: the shared runner's step.
AGENT_REAL_LANES := llm_real_lane.cx mcp_real_lane.cx mcp_server_real_lane.cx a2a_real_lane.cx
.PHONY: test-agent-real-lanes
test-agent-real-lanes: build-vcx
	@for t in $(AGENT_REAL_LANES); do \
	  test -f deps/cx-platform-agent/lanes/$$t || { \
	    echo "test-agent-real-lanes: deps/cx-platform-agent/lanes/$$t is not there — the lanes live in the pinned repository (RULED: RS-12, RS-31); run \`make deps-sync\`" >&2; \
	    exit 2; }; \
	done
	@cd deps/cx-platform-agent && st=0; \
	for t in $(AGENT_REAL_LANES); do \
	  CX_BIN="$(CURDIR)/deps/cx-core-code/vcx/target/cx" "$(CURDIR)/deps/cx-core-code/vcx/target/cx" --allow-all lanes/$$t || st=1; \
	done; exit $$st

## test-connector-real-lanes  The connector kit's two real-socket lanes as
##                  their own step (RULED: RS-12, RS-8, RS-27; #1591 item
##                  K3): connector_live_test.v boots `reference/acme/
##                  acme.mock.cx` — an in-tree [?http-service] — and drives
##                  the example connector against it (connector.md §10,
##                  §13.3); connector_webhook_test.v opens a deployment whose
##                  only gateway is `kind=webhook` and drives real deliveries
##                  at it (connector.md §3.10). Both are V test files that
##                  left cx-private whole with the extraction — byte-
##                  identical, into the pinned repository's own deps/cx-core-code/vcx/tests/ —
##                  because they are the ONLY thing that grades the connector
##                  kit's networked half against a cx the front door built,
##                  which is a different question from the component
##                  repository's own gate (`cx lint` plus `cx corpus`,
##                  RS-16, over a released cx). THE LANE MOVED AND THE STEP
##                  DID NOT (RULED: RS-12, #1591 item 11, the test-sso-
##                  interop-lane shape): a `ships=package` repo carries no V
##                  toolchain of its own (RS-25), so `v test` runs the two
##                  files straight out of the pinned checkout, from THIS
##                  tree's root, so every relative path inside them (the
##                  mock, the reference deployment) still resolves here.
##                  Refuses with exit 2 and names `make deps-sync` when the
##                  checkout is absent — never a skip.
CONNECTOR_REAL_LANES := deps/cx-platform-connector/vcx/tests/connector_live_test.v \
                        deps/cx-platform-connector/vcx/tests/connector_webhook_test.v
.PHONY: test-connector-real-lanes
test-connector-real-lanes: build-vcx
	@for t in $(CONNECTOR_REAL_LANES); do \
	  test -f $$t || { \
	    echo "test-connector-real-lanes: $$t is not there — the lanes live in the pinned repository now (RULED: RS-12); run \`make deps-sync\`" >&2; \
	    exit 2; }; \
	done
	@$(JS_CLOSE) $(V) -cc cc $(CX_GC) test $(CONNECTOR_REAL_LANES)

## test-sso-interop-lane  Identity-provider interop as its own CI step
##                  (#1403): boot the in-tree identity provider at
##                  scripts/sso_interop/idp.cx, drive a real relying party
##                  against it (discovery, the issuer mix-up refusal, all
##                  FIVE client-authentication methods including
##                  client_secret_jwt, PKCE, JWKS key selection by kid AND
##                  the §5.1 one bounded re-fetch across a provider that
##                  publishes TWO SUCCESSIVE key sets (#1405), refresh
##                  rotation AND §12.2 revalidation, UserInfo, the RFC
##                  9207 `iss` refusal, the machine grant, SAML over the
##                  wire, and SAML with the assertion ENCRYPTED
##                  end to end), tear down. Refuses if :8793 is already
##                  served. This is the ONLY step that grades the
##                  networked half of the SSO stack.
##
##                  THE LANE MOVED AND THE STEP DID NOT (RULED: RS-12,
##                  #1591 item 11). The script and the four programs it
##                  drives are cx-platform-sso's now; the step runs them
##                  out of the pinned checkout deps.cxd names, against
##                  THIS tree's binary. It stays here because it is the
##                  only thing that grades the networked half against a
##                  cx the front door built: the component repository's
##                  own gate is `cx lint` plus `cx corpus` (RS-16) over a
##                  RELEASED cx, which is a different question. The lane
##                  cds to its own directory, so every path inside it
##                  resolves in the checkout; CX_BIN is what crosses.
.PHONY: test-sso-interop-lane
test-sso-interop-lane: build-vcx
	@test -f deps/cx-platform-sso/scripts/sso_interop_lane.sh || { \
	  echo "test-sso-interop-lane: deps/cx-platform-sso/ is not there — the lane lives in the pinned repository now (RS-12); run \`make deps-sync\`" >&2; \
	  exit 2; }
	@CX_BIN="$(CURDIR)/deps/cx-core-code/vcx/target/cx" bash deps/cx-platform-sso/scripts/sso_interop_lane.sh

# ── <cx-diagram> web-component offline step (#1015) ────────────────────────────
# Sibling of the playground's no-CDN gate (#1007), for the OTHER surface that
# was still script-loading mermaid@10 from jsDelivr: tooling/web/cx-diagram.js,
# cx-tooling's since its leave and staged from its pinned checkout under deps/
# (RULED: RS-12, D59a) beside the one vendored mermaid this tree keeps.
#
# ONE ARTIFACT, NOT TWO PINS — the same discipline #1007 set. The repo keeps a
# single vendored mermaid (scripts/gen_guide/playground/vendor/, pin of record in
# its README: 10.9.8 UMD, SHA-256 recorded). This target does NOT add a second
# 3.3 MB copy to git; it STAGES that one file beside the component, exactly as
# `build-playground` stages the playground's docroot. The component resolves
# `./vendor/mermaid.min.js` against its own script URL, so the staged layout is
# what a consumer copying the pair out would reproduce.
#
# Deliberately its own target rather than a hook in build-playground: the two
# surfaces ship separately, and this one needs no emcc and no wasm.
.PHONY: stage-web-component
stage-web-component:
	@echo "[stage-web-component] staging dist/web-component-preview/"
	@rm -rf dist/web-component-preview
	@mkdir -p dist/web-component-preview/vendor
	@cp deps/cx-tooling/tooling/web/cx-diagram.js dist/web-component-preview/
	@cp deps/cx-tooling/tooling/web/demo.html dist/web-component-preview/
	@cp scripts/gen_guide/playground/vendor/mermaid.min.js dist/web-component-preview/vendor/
	@cp scripts/gen_guide/playground/vendor/LICENSE-mermaid.txt dist/web-component-preview/vendor/
	@echo "[stage-web-component] docroot ready — open dist/web-component-preview/demo.html"

## test-web-component-offline  The #1015 no-CDN gate for <cx-diagram>: the
##                  component carries no off-origin URL, demo.html loads no
##                  off-origin script, and the staged renderer is the ONE
##                  vendored bundle byte-for-byte (never a second pin).
.PHONY: test-web-component-offline
test-web-component-offline: stage-web-component
	@bash scripts/test_web_component_offline.sh

# ── #1370 — the shim archives are linkable by Apple's ld ──────────────────────
# Every object member of deps/cx-core-code/vcx/target/libcx_re2_shim.a (and libcx_arrow_shim.a
# when it exists) begins on an 8-byte boundary. The devbox `ar` pads to 2 and
# Apple's ld refuses such an archive, so a checkout built inside devbox could
# not be linked with the OS toolchain — and nothing said so until the link.
# The shim rules run the same check when they write the archive; this step
# catches the archive a checkout already HAS. Not an archive at all (a build
# that never produced one) is a red too: the step grades the artifact.
.PHONY: check-shim-archives
check-shim-archives: build-vcx-dev
	@sh scripts/check_archive_alignment.sh deps/cx-core-code/vcx/target/libcx_re2_shim.a $(wildcard deps/cx-core-code/vcx/target/libcx_arrow_shim.a)
	@echo "check-shim-archives: every shim archive member is 8-byte aligned"
