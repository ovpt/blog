#!/bin/bash
# L12, L13, and L14. Success is printed as PASS lines. The toy programs are
# supposed to crash under AddressSanitizer; zlib often will not.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="${HOME}/ios-research"
WORK="${ROOT}/memory-labs"
mkdir -p "$WORK"

if command -v xcrun >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1; then
  CC="$(xcrun --find clang)"
  SYM="$(xcrun --find llvm-symbolizer 2>/dev/null || true)"
else
  CC="$(command -v clang)"
  SYM="$(command -v llvm-symbolizer 2>/dev/null || true)"
fi
if [ -z "$CC" ]; then
  echo "FAIL 找不到 clang。在 Mac 上先运行 labs/preflight.sh。"
  exit 1
fi
if [ -n "$SYM" ]; then
  export ASAN_SYMBOLIZER_PATH="$SYM"
fi
export ASAN_OPTIONS="${ASAN_OPTIONS:-abort_on_error=1:detect_leaks=0}"

echo "CC=$CC"

echo "== toy_overflow =="
"$CC" -O1 -g -fsanitize=address toy_overflow.c -o "$WORK/toy_overflow"
set +e
"$WORK/toy_overflow" >"$WORK/toy_overflow.log" 2>&1
toy_status=$?
set -e
if ! grep -q "heap-buffer-overflow" "$WORK/toy_overflow.log"; then
  echo "FAIL toy_overflow 日志里没有 heap-buffer-overflow。把 $WORK/toy_overflow.log 的前 20 行留在笔记里，然后停。不要换编译器。"
  exit 1
fi
if ! grep -q "WRITE of size 8" "$WORK/toy_overflow.log"; then
  echo "FAIL toy_overflow 出现了溢出，但不是这份输入应有的 WRITE of size 8。停止并保留日志。"
  exit 1
fi
echo "PASS toy_overflow exit=${toy_status} log=$WORK/toy_overflow.log"

echo "== toy_fuzz =="
"$CC" -O1 -g -fsanitize=address,fuzzer -DTOY_FUZZ toy_overflow.c -o "$WORK/toy_fuzz"
set +e
"$WORK/toy_fuzz" -artifact_prefix="$WORK/" -max_total_time=20 -runs=100000 >"$WORK/toy_fuzz.log" 2>&1
fuzz_status=$?
set -e
if ! grep -q "heap-buffer-overflow" "$WORK/toy_fuzz.log"; then
  echo "FAIL toy_fuzz 20 秒内没有 heap-buffer-overflow。确认上一行编译没有报错，然后停。"
  exit 1
fi
echo "PASS toy_fuzz exit=${fuzz_status} log=$WORK/toy_fuzz.log"

echo "== zlib =="
ZLIB="${ROOT}/zlib"
if [ ! -f "$ZLIB/configure" ]; then
  rm -rf "$ZLIB"
  if ! git clone --depth=1 https://github.com/madler/zlib.git "$ZLIB"; then
    echo "FAIL zlib git clone 失败。过一分钟后只重试这一条 clone。第二次仍失败就停在 toy_fuzz 的 PASS 行，zlib 以后再做。"
    exit 1
  fi
fi
if sysctl -n hw.ncpu >/dev/null 2>&1; then
  jobs="$(sysctl -n hw.ncpu)"
else
  jobs="$(nproc)"
fi
(
  cd "$ZLIB"
  make distclean >/dev/null 2>&1 || true
  CC="$CC" CFLAGS="-O1 -g -fsanitize=address,fuzzer-no-link" ./configure --static
  make -j"$jobs" libz.a
)
"$CC" -O1 -g -fsanitize=address,fuzzer zlib_fuzz.c "$ZLIB/libz.a" -o "$WORK/zlib_fuzz"
seconds="${LAB_ZLIB_SECONDS:-30}"
set +e
"$WORK/zlib_fuzz" -artifact_prefix="$WORK/" -max_total_time="$seconds" -runs=200000 >"$WORK/zlib_fuzz.log" 2>&1
zlib_status=$?
set -e
if grep -q "AddressSanitizer" "$WORK/zlib_fuzz.log"; then
  echo "PASS zlib asan-report exit=${zlib_status} log=$WORK/zlib_fuzz.log"
  echo "把含 ERROR: AddressSanitizer 的那一段抄进 labs/bug-note.md。结论先写「只有崩溃」。不要根据这篇日志写利用。"
else
  if ! grep -q "DONE" "$WORK/zlib_fuzz.log"; then
    echo "FAIL zlib 日志里既没有 DONE 也没有 AddressSanitizer。保留 $WORK/zlib_fuzz.log 并停止。"
    exit 1
  fi
  echo "PASS zlib no-crash exit=${zlib_status} log=$WORK/zlib_fuzz.log"
  echo "这次没有崩溃是预期结果。流水线已经跑通。"
fi
