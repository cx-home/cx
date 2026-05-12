#!/usr/bin/env bash
# tools/bump-version.sh — atomically bump the CX version across all manifests.
#
# Usage:
#   tools/bump-version.sh 0.6.0 0.7.0   # from 0.6.0 to 0.7.0
#   tools/bump-version.sh --check 0.6.0  # verify everything is at 0.6.0
#
# Touches 12 files. All must move together or the release is broken.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
    cat <<EOF
Usage: $0 [--check] <from-version> <to-version>
   or: $0 --check <expected-version>

Examples:
  $0 0.5.0 0.6.0      Bump from 0.5.0 to 0.6.0
  $0 --check 0.6.0    Verify all manifests are at 0.6.0

Files touched (12):
  vcx/cx/cabi.v             const cx_version_str = '...'
  vcx/cmd/main.v            const version = '...'
  vcx/v.mod                 version: '...'
  lang/v/v.mod              version: '...'
  lang/python/pyproject.toml    version = "..."
  lang/rust/cxlib/Cargo.toml    version = "..."
  lang/typescript/cxlib/package.json   "version": "..."
  lang/java/cxlib/pom.xml       <version>...</version>
  lang/kotlin/cxlib/build.gradle.kts   version = "..."
  lang/csharp/cxlib/cxlib.csproj       <Version>...</Version>
  lang/ruby/cxlib/cxlib.gemspec        s.version = '...'
  (Go and Swift use git tags — no static bump.)
EOF
    exit 1
}

CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
    CHECK_ONLY=1
    shift
fi

if [ $# -lt 1 ]; then usage; fi

if [ $CHECK_ONLY -eq 1 ]; then
    EXPECTED="$1"
    FAIL=0
    check_file() {
        local file="$1" pattern="$2"
        if ! grep -q "$pattern" "$ROOT/$file" 2>/dev/null; then
            echo "FAIL: $file does not match expected version $EXPECTED"
            FAIL=1
        else
            echo "  OK : $file"
        fi
    }
    check_file "vcx/cx/cabi.v"                       "cx_version_str = '$EXPECTED'"
    check_file "vcx/cmd/main.v"                      "version = '$EXPECTED'"
    check_file "vcx/v.mod"                           "version: '$EXPECTED'"
    check_file "lang/v/v.mod"                        "version: '$EXPECTED'"
    check_file "lang/python/pyproject.toml"          "version = \"$EXPECTED\""
    check_file "lang/rust/cxlib/Cargo.toml"          "version = \"$EXPECTED\""
    check_file "lang/typescript/cxlib/package.json"  "\"version\": \"$EXPECTED\""
    check_file "lang/java/cxlib/pom.xml"             "<version>$EXPECTED</version>"
    check_file "lang/kotlin/cxlib/build.gradle.kts"  "version = \"$EXPECTED\""
    check_file "lang/csharp/cxlib/cxlib.csproj"      "<Version>$EXPECTED</Version>"
    check_file "lang/ruby/cxlib/cxlib.gemspec"       "s.version *= *'$EXPECTED'"
    if [ $FAIL -eq 1 ]; then
        echo ""
        echo "Version mismatch detected. Run: $0 <from> $EXPECTED"
        exit 1
    fi
    echo ""
    echo "All 11 version locations match $EXPECTED."
    exit 0
fi

if [ $# -lt 2 ]; then usage; fi
FROM="$1"
TO="$2"

bump() {
    local file="$1" pattern_from="$2" pattern_to="$3"
    local full="$ROOT/$file"
    if [ ! -f "$full" ]; then
        echo "WARN: $file not found; skipping"
        return
    fi
    if ! grep -q "$pattern_from" "$full"; then
        echo "WARN: $file does not contain expected '$pattern_from'; check manually"
        return
    fi
    # Use a portable sed (works on macOS BSD sed and GNU sed).
    sed -i.bak "s|${pattern_from}|${pattern_to}|" "$full"
    rm -f "${full}.bak"
    echo "  bumped: $file"
}

bump "vcx/cx/cabi.v"                       "cx_version_str = '$FROM'"        "cx_version_str = '$TO'"
bump "vcx/cmd/main.v"                      "version = '$FROM'"               "version = '$TO'"
bump "vcx/v.mod"                           "version: '$FROM'"                "version: '$TO'"
bump "lang/v/v.mod"                        "version: '$FROM'"                "version: '$TO'"
bump "lang/python/pyproject.toml"          "version = \"$FROM\""             "version = \"$TO\""
bump "lang/rust/cxlib/Cargo.toml"          "version = \"$FROM\""             "version = \"$TO\""
bump "lang/typescript/cxlib/package.json"  "\"version\": \"$FROM\""          "\"version\": \"$TO\""
bump "lang/java/cxlib/pom.xml"             "<version>$FROM</version>"        "<version>$TO</version>"
bump "lang/kotlin/cxlib/build.gradle.kts"  "version = \"$FROM\""             "version = \"$TO\""
bump "lang/csharp/cxlib/cxlib.csproj"      "<Version>$FROM</Version>"        "<Version>$TO</Version>"
bump "lang/ruby/cxlib/cxlib.gemspec"       "s.version     = '$FROM'"         "s.version     = '$TO'"

echo ""
echo "Bumped $FROM → $TO. Verifying..."
echo ""
"$0" --check "$TO"
