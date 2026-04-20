CONFORMANCE_CORE    := conformance/core.txt
CONFORMANCE_EXT     := conformance/extended.txt
CONFORMANCE_XML     := conformance/xml.txt
CONFORMANCE_MD      := conformance/md.txt

LIB_NAME   := libcx
LIB_DYLIB  := rust/target/release/$(LIB_NAME).dylib
LIB_SO     := rust/target/release/$(LIB_NAME).so
VCX_DYLIB  := vcx/target/$(LIB_NAME).dylib
VCX_SO     := vcx/target/$(LIB_NAME).so
DIST_DIR   := dist

.PHONY: all build build-rust build-vcx build-lib build-rustlang dist test test-rust test-python test-vcx test-rustlang \
        conform conform-rust conform-vcx conform-md bench clean

all: build

# ── Build ──────────────────────────────────────────────────────────────────────

build: build-rust build-vcx build-rustlang

build-rust:
	cargo build --manifest-path rust/Cargo.toml --release

build-vcx:
	$(MAKE) -C vcx build

build-rustlang: build-vcx
	cargo build --manifest-path rustlang/cxlib/Cargo.toml

build-lib: build-rust build-vcx

# Copy vcx dylib + header into dist/ (V implementation is primary)
dist: build-vcx
	mkdir -p $(DIST_DIR)/lib $(DIST_DIR)/include
	cp -f include/cx.h $(DIST_DIR)/include/
	@if [ -f $(VCX_DYLIB) ]; then cp -f $(VCX_DYLIB) $(DIST_DIR)/lib/libcx.dylib; fi
	@if [ -f $(VCX_SO)    ]; then cp -f $(VCX_SO)    $(DIST_DIR)/lib/libcx.so; fi
	@echo "dist: $(DIST_DIR)/include/cx.h  $(DIST_DIR)/lib/"

# ── Test ───────────────────────────────────────────────────────────────────────

test: test-rust test-python test-vcx test-rustlang

test-rust:
	cargo test --manifest-path rust/Cargo.toml

test-python: build-vcx
	python python/conformance.py

test-rustlang: build-rustlang
	cargo test --manifest-path rustlang/cxlib/Cargo.toml

test-vcx: build-vcx
	$(MAKE) -C vcx conform-all

conform-md: build-vcx
	$(MAKE) -C vcx conform-md

# ── Conformance ────────────────────────────────────────────────────────────────

conform: conform-rust conform-vcx

conform-rust: build-rust
	cargo test --manifest-path rust/Cargo.toml --test conformance -- --nocapture

conform-vcx: build-vcx
	$(MAKE) -C vcx conform-all

# Run a single conformance test by name: make conform-one NAME=001-scalar-int
conform-one: build-rust
	cargo test --manifest-path rust/Cargo.toml --test conformance $(NAME) -- --nocapture

# ── Benchmark ──────────────────────────────────────────────────────────────────

bench: build-rust
	hyperfine --warmup 5 \
	  'rust/target/release/cx --ast < /dev/null' \
	  'vcx/target/cx --ast < /dev/null' \
	  --export-markdown bench.md

# ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	cargo clean --manifest-path rust/Cargo.toml
	$(MAKE) -C vcx clean
	rm -rf $(DIST_DIR)
	find python -name '*.pyc' -delete
	find python -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
