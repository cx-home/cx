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

# ── Ruby / Go / TypeScript / Java / Kotlin / C# / Swift toolchain paths ──────
RUBY        := /opt/homebrew/opt/ruby/bin/ruby
SWIFT       := /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
SWIFT_FLAGS := SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DOTNET      := DOTNET_ROOT=/opt/homebrew/opt/dotnet/libexec /opt/homebrew/opt/dotnet/libexec/dotnet
JAVA_HOME_ARM64 := /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

.PHONY: all build build-rust build-vcx build-lib build-rustlang \
        build-ruby build-golang build-typescript build-java build-kotlin build-csharp build-swift \
        dist test test-rust test-python test-vcx test-rustlang \
        test-ruby test-golang test-typescript test-java test-kotlin test-csharp test-swift \
        conform conform-rust conform-vcx conform-md bench clean

all: build

# ── Build ──────────────────────────────────────────────────────────────────────

build: build-rust build-vcx build-rustlang build-ruby build-golang build-typescript build-java build-kotlin build-csharp build-swift

build-rust:
	cargo build --manifest-path rust/Cargo.toml --release

build-vcx:
	$(MAKE) -C vcx build

build-rustlang: build-vcx
	cargo build --manifest-path rustlang/cxlib/Cargo.toml

build-ruby: build-vcx
	@echo "Ruby binding: no compile step needed"

build-golang: build-vcx
	cd golang/cxlib && go build ./...

build-typescript: build-vcx
	cd typescript/cxlib && npm install --silent && npm run build

build-java: build-vcx
	mvn -f java/cxlib/pom.xml -q package -DskipTests

build-kotlin: build-vcx
	cd kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle assemble -q

build-csharp: build-vcx
	$(DOTNET) build csharp/cxlib/cxlib.csproj -c Release --nologo -v:m

build-swift: build-vcx
	$(SWIFT_FLAGS) $(SWIFT) build --package-path swift/cxlib

build-lib: build-rust build-vcx

# Copy vcx dylib + header into dist/ (V implementation is primary)
dist: build-vcx
	mkdir -p $(DIST_DIR)/lib $(DIST_DIR)/include
	cp -f include/cx.h $(DIST_DIR)/include/
	@if [ -f $(VCX_DYLIB) ]; then cp -f $(VCX_DYLIB) $(DIST_DIR)/lib/libcx.dylib; fi
	@if [ -f $(VCX_SO)    ]; then cp -f $(VCX_SO)    $(DIST_DIR)/lib/libcx.so; fi
	@echo "dist: $(DIST_DIR)/include/cx.h  $(DIST_DIR)/lib/"

# ── Test ───────────────────────────────────────────────────────────────────────

test: test-rust test-python test-vcx test-rustlang test-ruby test-golang test-typescript test-java test-kotlin test-csharp test-swift

test-rust:
	cargo test --manifest-path rust/Cargo.toml

test-python: build-vcx
	python python/conformance.py

test-rustlang: build-rustlang
	cargo test --manifest-path rustlang/cxlib/Cargo.toml

test-vcx: build-vcx
	$(MAKE) -C vcx conform-all

test-ruby: build-vcx
	$(RUBY) ruby/conformance.rb

test-golang: build-golang
	cd golang/conformance && go run .

test-typescript: build-typescript
	cd typescript/cxlib && npm run conform

test-java: build-java
	mvn -f java/cxlib/pom.xml -q test

test-kotlin: build-kotlin
	cd kotlin/cxlib && JAVA_HOME=$(JAVA_HOME_ARM64) gradle test -q

test-csharp: build-csharp
	$(DOTNET) run --project csharp/conformance/conformance.csproj -c Release

test-swift: build-swift
	$(SWIFT_FLAGS) $(SWIFT) test --package-path swift/cxlib

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
