#!/usr/bin/env bash
# CI one-shot WASM build. Does the setup the way the author's dev.sh does
# (patches BEFORE gn gen; gn gen run from inside the source tree WITHOUT --root,
# which dev.sh comments "causes issues"), then hands off to the upstream
# build.sh for ninja + gen_exports + compile + copy. build.sh skips its own
# gclient sync (third_party exists) and its own --root gn gen (args.gn exists),
# so only the working code paths run. No in-place sed of build.sh.
set -euxo pipefail

ROOT=/workspace
SRC=$ROOT/packages/pdfium/pdfium-src
OUT=$SRC/out/wasm
PDFIUM=$ROOT/packages/pdfium
mkdir -p "$OUT"
export PATH="$HOME/.cargo/bin:$PATH:/opt/depot-tools"

# 1. gclient sync (same as build.sh) so the toolchain/deps exist before gn gen.
if [[ ! -d "$SRC/third_party/llvm-build" ]]; then
  cat > "$ROOT/.gclient" <<'GCLIENT'
solutions = [
  { "name": "packages/pdfium/pdfium-src",
    "url":  "https://pdfium.googlesource.com/pdfium.git",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
GCLIENT
  ( cd "$SRC" && gclient sync --no-history --shallow --nohooks --deps=builder )
  rm "$ROOT/.gclient"
fi

# 2. Apply the build-system patches BEFORE gn gen (dev.sh order).
cp -f "$PDFIUM/build/patch/build/config/BUILDCONFIG.gn" \
      "$SRC/build/config/BUILDCONFIG.gn"
cp -f "$PDFIUM/build/patch/build/toolchain/wasm/BUILD.gn" \
      "$SRC/build/toolchain/wasm/BUILD.gn"

# 3. gn gen the WORKING dev.sh way: cd into the source tree, no --root.
if [[ ! -f "$OUT/args.gn" ]]; then
  ( cd "$SRC" && gn gen out/wasm \
      --args='is_debug=false treat_warnings_as_errors=false pdf_use_skia=false pdf_enable_xfa=false pdf_enable_v8=false is_component_build=false clang_use_chrome_plugins=false pdf_is_standalone=true use_debug_fission=false use_custom_libcxx=false use_sysroot=false pdf_is_complete_lib=true pdf_use_partition_alloc=false is_clang=false symbol_level=0 target_os="wasm" target_cpu="wasm"' )
fi

# 4. Hand off to the upstream build.sh: it skips sync (third_party present) and
#    its --root gn gen (args.gn present), running only ninja + gen_exports +
#    compile + copy-to-src/vendor.
bash "$PDFIUM/scripts/build.sh"
