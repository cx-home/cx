module composed

// composed — the entry libcx and the wasm playground bundle build from
// (cx-core-code#72 step 3, RULED: STREAM-1). xap composes the platform's V
// products (RS-24) and was that entry; the package repositories' CX sources
// are this front door's to register (vcx/platform_sources), and xap — a
// repository of its own — cannot import a front-door module. So the entry
// is this module: importing both runs both init()s, and every C export of
// code/cx/xap and the products ships exactly as before.
import xap as _
import platform_sources as _
