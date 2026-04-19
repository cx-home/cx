CONFORMANCE_CORE    := conformance/core.txt
CONFORMANCE_EXT     := conformance/extended.txt
CONFORM_SUITE       := $(CONFORMANCE_CORE) $(CONFORMANCE_EXT)

LIB_NAME   := libcx
LIB_DYLIB  := rust/target/release/$(LIB_NAME).dylib
LIB_SO     := rust/target/release/$(LIB_NAME).so
DIST_DIR   := dist

.PHONY: all build build-rust build-lib dist test test-rust test-python conform conform-rust bench clean

all: build

# ── Build ──────────────────────────────────────────────────────────────────────

build: build-rust

build-rust:
	cargo build --manifest-path rust/Cargo.toml --release

build-lib: build-rust

# Copy dylib + header into dist/
dist: build-lib
	mkdir -p $(DIST_DIR)/lib $(DIST_DIR)/include
	cp -f include/cx.h $(DIST_DIR)/include/
	@if [ -f $(LIB_DYLIB) ]; then cp -f $(LIB_DYLIB) $(DIST_DIR)/lib/; fi
	@if [ -f $(LIB_SO)    ]; then cp -f $(LIB_SO)    $(DIST_DIR)/lib/; fi
	@echo "dist: $(DIST_DIR)/include/cx.h  $(DIST_DIR)/lib/"

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
	rm -rf $(DIST_DIR)
	find python -name '*.pyc' -delete
	find python -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
