CONFORMANCE_CORE    := conformance/core.txt
CONFORMANCE_EXT     := conformance/extended.txt
CONFORM_SUITE       := $(CONFORMANCE_CORE) $(CONFORMANCE_EXT)

.PHONY: all build build-rust test test-rust test-python conform conform-rust bench clean

all: build

# ── Build ──────────────────────────────────────────────────────────────────────

build: build-rust

build-rust:
	cargo build --manifest-path rust/Cargo.toml --release

# ── Test ───────────────────────────────────────────────────────────────────────

test: test-rust test-python

test-rust:
	cargo test --manifest-path rust/Cargo.toml

test-python:
	cd python && python -m pytest -q

# ── Conformance ────────────────────────────────────────────────────────────────

conform: conform-rust

conform-rust: build-rust
	cargo test --manifest-path rust/Cargo.toml --test conformance -- --nocapture

# Run a single conformance test by name: make conform-one NAME=001-scalar-int
conform-one: build-rust
	cargo test --manifest-path rust/Cargo.toml --test conformance $(NAME) -- --nocapture

# ── Benchmark ──────────────────────────────────────────────────────────────────

bench: build-rust
	hyperfine --warmup 5 \
	  'rust/target/release/cx --ast < /dev/null' \
	  --export-markdown bench.md

# ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	cargo clean --manifest-path rust/Cargo.toml
	find python -name '*.pyc' -delete
	find python -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
