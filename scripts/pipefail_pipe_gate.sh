#!/usr/bin/env bash
#
# scripts/pipefail_pipe_gate.sh — RULED: SPG-1 (#916,
# ledger/rulings_2026_08_22_gate_hygiene.md).
#
# Fails on `external_command | grep -q PATTERN` inside a shell script that
# sets `pipefail`. That pipeline fires FALSE failures: `grep -q` exits on
# the first match, the producer is still writing, takes SIGPIPE and exits
# 141, and pipefail promotes 141 to the pipeline's status — so a guard
# reports "not found" for input that actually matched.
#
# It is TIMING-dependent, which is why it earns a gate rather than a
# comment: it hides whenever the producer is fast (small output, warm
# binary, cached pages) and appears when it is slow (freshly built binary,
# cold start, large output). Two independent instances existed before this
# gate — one documented in a comment in scripts/test_playground_smoke.sh,
# one inside the BLOCKING R2.2 release gate, where it would have aborted a
# release cut on a perfectly good artifact (PGL-1a).
#
# `echo`/`printf` producers PASS: a builtin writing a small string finishes
# before `grep` can exit, so nothing receives SIGPIPE.
#
# The escape hatch, for a site that genuinely wants the pipe, is an inline
# marker (the literal token is assembled below so this gate never matches
# its own documentation). It is reported in the summary so it can never be
# silent. The gate landed with ZERO uses; that is the standard to hold
# (cf. EDL-1a).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OK_MARKER='pipefail-pipe''-ok'      # split so the gate never flags itself

violations=0
allowed=0
scanned=0

# is_safe_producer — true when the left side of the pipe is a shell builtin
# that finishes writing before grep can exit. Strips leading keywords,
# operators and case-branch labels first, so `deps)  printf … | grep -q …`
# is recognised as the safe printf it is.
is_safe_producer() {
  local p="$1"
  p="${p#"${p%%[![:space:]]*}"}"
  while :; do
    case "$p" in
      'if '*)    p="${p#if }" ;;
      '! '*)     p="${p#! }" ;;
      'while '*) p="${p#while }" ;;
      'until '*) p="${p#until }" ;;
      'then '*)  p="${p#then }" ;;
      'elif '*)  p="${p#elif }" ;;
      '&& '*)    p="${p#&& }" ;;
      '|| '*)    p="${p#|| }" ;;
      '('*)      p="${p#(}" ;;
      *)
        if [[ "$p" =~ ^[A-Za-z0-9_*?.@%^+=:,/-]+\)[[:space:]]+ ]]; then
          p="${p#*)}"          # a case-branch label
        else
          break
        fi ;;
    esac
    p="${p#"${p%%[![:space:]]*}"}"
  done
  case "$p" in
    echo\ *|echo|printf\ *|printf) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r file; do
  grep -q 'pipefail' "$file" 2>/dev/null || continue
  scanned=$((scanned + 1))
  lineno=0; pending=""; pending_no=0; heredoc_end=""
  while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))

    # Skip HEREDOC BODIES — they are data, not pipelines. Without this a
    # script that DOCUMENTS the bad pattern (this gate included) reads as
    # a violation of it.
    if [ -n "$heredoc_end" ]; then
      trimmed_raw="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ "$trimmed_raw" = "$heredoc_end" ] && heredoc_end=""
      continue
    fi
    if [[ "$raw" != *'<<<'* ]] && [[ "$raw" =~ \<\<-?[[:space:]]*[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]?[[:space:]]*$ ]]; then
      heredoc_end="${BASH_REMATCH[1]}"
      continue
    fi

    # join a pipeline continued past a trailing `|`
    if [ -n "$pending" ]; then
      logical="$pending $(printf '%s' "$raw" | sed 's/^[[:space:]]*//')"
      startno=$pending_no
      pending=""
    else
      logical="$raw"
      startno=$lineno
    fi
    trimmed="$(printf '%s' "$logical" | sed 's/^[[:space:]]*//')"
    case "$trimmed" in '#'*|'') continue ;; esac      # comments and blanks
    if [[ "$logical" =~ \|[[:space:]]*$ ]]; then
      pending="$(printf '%s' "$logical" | sed 's/[[:space:]]*$//')"
      pending_no=$startno
      continue
    fi

    [[ "$logical" =~ \|[[:space:]]*grep[[:space:]]+-[a-zA-Z]*q ]] || continue
    case "$logical" in *'<<<'*) continue ;; esac      # here-string: no upstream process

    # A SAFE producer settles it FIRST. Testing the annotation before this
    # made the gate report its own annotation-detecting line as annotated.
    producer="${logical%%|*}"
    is_safe_producer "$producer" && continue
    if [[ "$logical" == *"$OK_MARKER"* ]]; then
      allowed=$((allowed + 1))
      echo "  ALLOWED $file:$startno (annotated)"
      continue
    fi

    violations=$((violations + 1))
    echo "VIOLATION $file:$startno"
    printf '%s\n' "    $trimmed"
  done < "$file"
done < <(find . -name '*.sh' -not -path './third_party/*' -not -path './.git/*' | sort)

echo ""
if [ "$violations" -ne 0 ]; then
  {
    echo "pipefail-pipe-gate FAILED — see RULED: SPG-1 (#916)."
    echo ""
    echo "A pipeline of the form  <external cmd> | grep -q P  under pipefail fires"
    echo "FALSE failures: grep -q exits on the first match, the producer takes"
    echo "SIGPIPE (exit 141), and pipefail promotes 141 to the pipeline status."
    echo ""
    echo "Use one of the two safe forms instead:"
    echo ""
    echo '  grep -q P <<< "$out"                  # here-string: no upstream process'
    echo '  out="$(cmd)"                          # capture once, then match'
    echo '  case "$out" in *P*) ;; *) fail ;; esac'
    echo ""
    echo "If a site genuinely needs the pipe, annotate it with the ${OK_MARKER} marker and say why."
    echo "pipefail-pipe-gate: $violations violation(s) over $scanned pipefail script(s), $allowed annotated"
  } >&2
  exit 1
fi
echo "pipefail-pipe-gate OK — $scanned pipefail script(s) scanned, 0 violations, $allowed annotated exception(s)"
