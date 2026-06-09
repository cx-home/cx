// Phase A toolchain probe driver.
//
// Loads the emcc-built echo.js module, marshals a UTF-8 string into
// WASM linear memory via _malloc + stringToUTF8, invokes the
// exported V function cx_echo, and reads the result back via
// UTF8ToString. This is exactly the call shape the eventual
// dist/wasm/cxlib.js will use for every libcx C ABI call.
//
// Usage:  node echo_driver.mjs <path/to/echo.js>
// Exit code is non-zero on any contract mismatch.

import { createRequire } from 'module'
import process from 'process'

const modulePath = process.argv[2]
if (!modulePath) {
  console.error('usage: node echo_driver.mjs <path/to/echo.js>')
  process.exit(2)
}

const require = createRequire(import.meta.url)
const createCxModule = require(modulePath)
const Module = await createCxModule()

const input = 'hello, wasm'
const len = Module.lengthBytesUTF8(input)
const ptr = Module._malloc(len + 1)
Module.stringToUTF8(input, ptr, len + 1)

const probeLen = Module._cx_input_len(ptr)
if (probeLen !== len) {
  console.error(`FAIL: cx_input_len=${probeLen} expected ${len}`)
  process.exit(1)
}

const outPtr = Module._cx_echo(ptr)
const out = Module.UTF8ToString(outPtr)
const expected = `echoed:${input}`
if (out !== expected) {
  console.error(`FAIL: cx_echo returned ${JSON.stringify(out)}, expected ${JSON.stringify(expected)}`)
  process.exit(1)
}

console.log(`OK: cx_input_len=${probeLen}, cx_echo=${JSON.stringify(out)}`)
