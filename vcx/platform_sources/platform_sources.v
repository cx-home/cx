module platform_sources

import code

// platform_sources — the PACKAGE repositories' bundled stdlib sources,
// registered by the front door that composes them (cx-core-code#72 step 3,
// RULED: STREAM-1). A repository with a V module registers its own sources
// from that module's init() (store, net, mail, identity, xsp, fabric, xap); a
// package repository — connector, sso, flow, secrets, ux, agent — ships CX
// source and no V module, so the composer, this repository, registers it here
// under the resolver names its deps.cxd row declares. One table, one owner:
// `code` refuses a second registration of a name, and embeds none of these.
//
// The paths are this repository's own pinned checkouts (deps/, `make
// deps-sync`), relative to this directory. Imported by the platform-profile
// cx (vcx/cmd/platform_verbs_d_cx_platform.v) and by vcx/composed, the entry
// libcx and the wasm playground bundle build from; a cx built without -d
// cx_platform imports neither, and every cx-platform/* name refuses there as
// a platform module (the §4 profile-by-construction rule).
fn init() {
	register('cx-platform/connector', $embed_file('../../deps/cx-platform-connector/stdlib/connector.cx').to_string())
	register('cx-platform/sync', $embed_file('../../deps/cx-platform-connector/stdlib/sync.cx').to_string())
	register('cx-platform/sso', $embed_file('../../deps/cx-platform-sso/stdlib/sso.cx').to_string())
	register('cx-platform/flow', $embed_file('../../deps/cx-platform-flow/stdlib/flow.cx').to_string())
	register('cx-platform/secrets', $embed_file('../../deps/cx-platform-secrets/stdlib/secrets.cx').to_string())
	register('cx-platform/ux', $embed_file('../../deps/cx-platform-ux/x/ux.cx').to_string())
	register('cx-platform/ux-web', $embed_file('../../deps/cx-platform-ux/x/ux-web.cx').to_string())
	register('cx-platform/ux-tui', $embed_file('../../deps/cx-platform-ux/x/ux-tui.cx').to_string())
	register('cx-platform/run', $embed_file('../../deps/cx-platform-agent/x/run.cx').to_string())
	register('cx-platform/llm', $embed_file('../../deps/cx-platform-agent/x/llm.cx').to_string())
	register('cx-platform/mcp', $embed_file('../../deps/cx-platform-agent/x/mcp.cx').to_string())
	register('cx-platform/mcp-server', $embed_file('../../deps/cx-platform-agent/x/mcp-server.cx').to_string())
	register('cx-platform/a2a', $embed_file('../../deps/cx-platform-agent/x/a2a.cx').to_string())
	register('cx-platform/a2a-xap', $embed_file('../../deps/cx-platform-agent/x/a2a-xap.cx').to_string())
	register('cx-platform/adjudicate', $embed_file('../../deps/cx-platform-agent/x/adjudicate.cx').to_string())
	register('cx-platform/tools', $embed_file('../../deps/cx-platform-agent/x/tools.cx').to_string())
}

fn register(name string, src string) {
	code.register_bundled_source(name, src) or { panic(err) }
}

// names answers every resolver name this module registers, in table order —
// what vcx/tests/platform_sources_test.v grades byte-for-byte.
pub fn names() []string {
	return ['cx-platform/connector', 'cx-platform/sync', 'cx-platform/sso', 'cx-platform/flow', 'cx-platform/secrets', 'cx-platform/ux', 'cx-platform/ux-web', 'cx-platform/ux-tui', 'cx-platform/run', 'cx-platform/llm', 'cx-platform/mcp', 'cx-platform/mcp-server', 'cx-platform/a2a', 'cx-platform/a2a-xap', 'cx-platform/adjudicate', 'cx-platform/tools']
}

// source_path answers the front-door-relative file a registered name's
// source is embedded from (empty for a name this module does not register).
pub fn source_path(name string) string {
	return match name {
		'cx-platform/connector' { 'deps/cx-platform-connector/stdlib/connector.cx' }
		'cx-platform/sync' { 'deps/cx-platform-connector/stdlib/sync.cx' }
		'cx-platform/sso' { 'deps/cx-platform-sso/stdlib/sso.cx' }
		'cx-platform/flow' { 'deps/cx-platform-flow/stdlib/flow.cx' }
		'cx-platform/secrets' { 'deps/cx-platform-secrets/stdlib/secrets.cx' }
		'cx-platform/ux' { 'deps/cx-platform-ux/x/ux.cx' }
		'cx-platform/ux-web' { 'deps/cx-platform-ux/x/ux-web.cx' }
		'cx-platform/ux-tui' { 'deps/cx-platform-ux/x/ux-tui.cx' }
		'cx-platform/run' { 'deps/cx-platform-agent/x/run.cx' }
		'cx-platform/llm' { 'deps/cx-platform-agent/x/llm.cx' }
		'cx-platform/mcp' { 'deps/cx-platform-agent/x/mcp.cx' }
		'cx-platform/mcp-server' { 'deps/cx-platform-agent/x/mcp-server.cx' }
		'cx-platform/a2a' { 'deps/cx-platform-agent/x/a2a.cx' }
		'cx-platform/a2a-xap' { 'deps/cx-platform-agent/x/a2a-xap.cx' }
		'cx-platform/adjudicate' { 'deps/cx-platform-agent/x/adjudicate.cx' }
		'cx-platform/tools' { 'deps/cx-platform-agent/x/tools.cx' }
		else { '' }
	}
}
