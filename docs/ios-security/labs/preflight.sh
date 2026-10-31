#!/bin/bash
# Checks the Mac side of this guide. Prints PASS or FAIL for each gate.
# A FAIL on WebKit or disk does not block the phone labs.
set -u
fail=0

pass() { echo "PASS  $*"; }
failmsg() { echo "FAIL  $*"; fail=1; }

echo "== iOS research preflight =="

if ! sw_vers >/dev/null 2>&1; then
  failmsg "当前不是 macOS。L2 之后的实验需要一台能从 App Store 安装 Xcode 的 Mac。手机上的 L0 可以先做。"
  exit 1
fi
pass "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"

select_path="$(xcode-select -p 2>/dev/null || true)"
case "$select_path" in
  *Xcode.app*)
    pass "Command Line Tools 指向 $select_path"
    ;;
  "")
    failmsg "没有 xcode-select 路径。安装 Xcode 后打开它，接受协议，再运行本脚本。"
    ;;
  *)
    failmsg "Command Line Tools 指向 $select_path 。打开 Xcode > Settings > Locations，Command Line Tools 选带 Xcode 字样的那一项，再运行本脚本。"
    ;;
esac

if ! xcodebuild -version >/dev/null 2>&1; then
  failmsg "xcodebuild 不能运行。打开 Xcode，接受许可协议，再运行本脚本。"
  exit 1
fi
xver="$(xcodebuild -version | awk 'NR==1 {print $2}')"
pass "Xcode $xver"

major="${xver%%.*}"
rest="${xver#*.}"
minor="${rest%%.*}"
if [ "$major" -gt 26 ] || { [ "$major" -eq 26 ] && [ "${minor:-0}" -ge 2 ]; }; then
  pass "可以做 L17（Xcode >= 26.2，这是 2026-03 起 WebKit 主干的编译要求）"
else
  failmsg "Xcode $xver 低于 26.2。不要运行 build-webkit。L0–L16 和 L18、L19 照常做。"
fi

avail_kb="$(df -k "$HOME" | awk 'NR==2 {print $4}')"
avail_gb="$((avail_kb / 1024 / 1024))"
if [ "$avail_gb" -ge 120 ]; then
  pass "家目录可用 ${avail_gb} GB"
else
  failmsg "家目录可用 ${avail_gb} GB，少于 120 GB。不要编译 WebKit。L12–L15 大约需要 2 GB。"
fi

if python3 --version >/dev/null 2>&1; then
  pass "$(python3 --version)"
else
  failmsg "没有 python3。macOS 自带。如果这条失败，先打开 Xcode 再运行本脚本，不要另行安装 Python。"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "PREFLIGHT_RESULT=all-pass"
else
  echo "PREFLIGHT_RESULT=see-FAIL-lines"
fi
exit "$fail"
