#!/bin/bash
# Prints the entitlements of the SecurityLab app most recently built by Xcode.
set -euo pipefail
APP_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*SecurityLab.app/SecurityLab' -type f -print -quit)"
if [ -z "${APP_BIN}" ]; then
  echo "FAIL 没有找到 SecurityLab。"
  echo "先在 Xcode 里选中这台 iPhone（不要选 Simulator），Product > Run 成功一次，再运行本脚本。"
  exit 1
fi
BUNDLE="$(dirname "$APP_BIN")"
echo "BUNDLE=$BUNDLE"
codesign -d --entitlements :- "$BUNDLE"
echo
echo "PASS 上面的 XML 里要能看到 application-identifier 和 get-task-allow。"
echo "看不到这两行时：scheme 选成了 Simulator。改选真机后再 Run 一次。"
