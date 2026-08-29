#!/bin/sh
# scripts/portable_links.sh — make a freshly linked macOS artifact loadable
# on a machine that is not this one (#1102).
#
# WHY THIS IS SHELL AND NOT CX (AGENTS.md rule 6 asks for a filed reason):
# it runs as a post-link step INSIDE the build, on the artifact the build is
# producing. A clean build has no usable `cx` at that moment — and the one
# case that matters most is repairing the `cx` binary itself. A build-recipe
# helper cannot depend on the thing it repairs.
#
# THE DEFECT. Building under devbox (Nix) resolves `-lsqlite3` to the Nix
# store, and a Nix dylib's install name is its ABSOLUTE store path:
#
#   /nix/store/<hash>-sqlite-3.53.3/lib/libsqlite3.dylib
#
# That path exists only on the build machine, and the artifacts carry no
# LC_RPATH, so on any other machine dyld fails before `main` — every
# subcommand, not just the sqlite ones. Measured on the shipped v0.17.0
# tarball AND on the installed binary; Linux is unaffected because it links
# by soname.
#
# THE FIX. Repoint each Nix load path at the copy macOS itself provides.
# Done at LINK time rather than at packaging time on purpose: what we test
# is then what we ship, instead of the tested artifact and the shipped one
# differing in exactly the field that broke.
#
# Anything we cannot repoint is REFUSED LOUDLY rather than rewritten to a
# guess. A Nix path repointed at a `/usr/lib` file that does not exist is
# the same defect relocated — still dead in dyld, just harder to find. So
# adding an engine that links a library macOS does not ship (libpq, libssh2)
# fails the build here, which is where it should fail.
set -eu

case "$(uname -s)" in
Darwin) ;;
*) exit 0 ;;
esac

# Libraries macOS provides itself, so a Nix-built reference can be repointed
# at the OS copy. Keep this list short and justified — every addition is a
# claim that the OS ships that library on every supported macOS.
system_provided='libsqlite3.dylib libz.dylib libiconv.2.dylib libc++.1.dylib libcurl.4.dylib'

# A redistributable dylib must not carry an absolute BUILD path as its own
# install name either. The shipped v0.17.0 libcx.dylib carried
# /Users/<maintainer>/git-repos/cx/cx-private/vcx/target/libcx.dylib, which
# every consumer linking against it would bake into their own binary.
# @rpath is the redistributable spelling; the Go binding already passes
# -Wl,-rpath for exactly this.
set_id() {
	case "$1" in
	*.dylib) ;;
	*) return 0 ;;
	esac
	current=$(otool -D "$1" 2>/dev/null | tail -n +2)
	base=$(basename "$1")
	[ "$current" = "@rpath/$base" ] && return 0
	install_name_tool -id "@rpath/$base" "$1" 2>/dev/null || return 1
}

status=0
for artifact in "$@"; do
	[ -f "$artifact" ] || continue
	set_id "$artifact" || { echo "portable-links: FAILED to set the install name of $artifact" >&2; status=1; }
	# Field 1 of every line after the first is a load path.
	for path in $(otool -L "$artifact" 2>/dev/null | tail -n +2 | awk '{print $1}' | grep '^/nix/store/' || true); do
		base=$(basename "$path")
		case " $system_provided " in
		*" $base "*)
			install_name_tool -change "$path" "/usr/lib/$base" "$artifact" 2>/dev/null || {
				echo "portable-links: FAILED to repoint $base in $artifact" >&2
				status=1
			}
			;;
		*)
			echo "portable-links: REFUSING $artifact — it loads $path, and macOS does not provide $base." >&2
			echo "portable-links: repointing it at /usr/lib would ship a dangling path, which is the same defect moved." >&2
			echo "portable-links: either vendor/static-link that library, or add it to system_provided with a reason (#1102)." >&2
			status=1
			;;
		esac
	done
done
exit $status
