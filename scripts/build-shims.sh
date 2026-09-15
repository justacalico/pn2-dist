#!/usr/bin/env bash
# Build the three ABI shims from source with the NDK clang.
# Port of shim/build.ps1 + build_air.ps1 (Windows-only) to bash.
#
# The link-target vendor libs come from the blobs package under linklibs/ -
# lld only needs their symbol tables (--allow-shlib-undefined), but they make
# the output .so record the right DT_NEEDED/SONAME pairs.
set -euo pipefail
R="${PN2_ROOT:?}"
SDK="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
NDK=$(ls -d "$SDK"/ndk/* | sort -V | tail -1)
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
CC="$TC/aarch64-linux-android29-clang"
CXX="$TC/aarch64-linux-android29-clang++"
RD="$TC/llvm-readelf"
LINK="$R/linklibs"

for t in "$CC" "$CXX" "$RD"; do
  [ -x "$t" ] || { echo "missing NDK tool: $t" >&2; exit 1; }
done

cd "$R/shim"

echo "=== libshim_pvr.so ==="
"$CC" -shared -O2 -Wl,--allow-shlib-undefined -Wl,-soname,libshim_pvr.so \
    -o libshim_pvr.so shim_pvr.S shim_events.c "$LINK/libgui.so" -ldl -llog
"$RD" --dyn-syms libshim_pvr.so | grep -E 'getBuiltInDisplay|DisplayEventReceiverC1' | grep -v UND | head -3

echo "=== libshim_air.so ==="
"$CXX" -shared -O2 -fno-exceptions -fno-rtti -nostdlib++ \
    -Wl,--allow-shlib-undefined -Wl,-soname,libshim_air.so \
    -o libshim_air.so shim_air.cpp \
    "$LINK/libgui.so" "$LINK/libui.so" "$LINK/libutils.so" \
    "$LINK/libcamera_client.so" "$LINK/libtinyxml2.so" -llog
# libc++_shared must not leak in: system images ship libc++.so, and an
# LD_PRELOAD that cannot resolve kills every binary in the process
if "$RD" -dW libshim_air.so | grep NEEDED | grep -q libc++_shared; then
  echo "libc++_shared.so still required - shim would break its host" >&2
  exit 1
fi
"$RD" --dyn-syms -W libshim_air.so | grep -c ' UND ' | sed 's/^/  UND imports: /'

echo "=== libskia_stub.so ==="
"$CC" -shared -fPIC -Wl,-soname,libskia.so -o libskia_stub.so stub_skia.c

# 143_build_image2.sh and 267_build_full.sh both pick the pvr shim up from
# these two spots
cp -f libshim_pvr.so "$R/overlay/lib64/libshim_pvr.so"

ls -l libshim_pvr.so libshim_air.so libskia_stub.so "$R/overlay/lib64/libshim_pvr.so"
