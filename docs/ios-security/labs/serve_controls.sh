#!/bin/bash
# Serves the two control pages used by lab L15.
set -euo pipefail
cd "$(dirname "$0")"
echo "保持这个窗口开着。"
echo "Mac Safari 打开 http://127.0.0.1:8741/sop-control.html"
echo "然后打开 http://127.0.0.1:8741/csp-control.html"
echo "结束时在这个窗口按 Control-C。"
exec python3 -m http.server 8741 --bind 127.0.0.1
