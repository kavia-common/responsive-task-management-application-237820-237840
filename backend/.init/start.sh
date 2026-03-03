#!/usr/bin/env bash
set -euo pipefail
# Start-wrapper writer + fallback: atomically write .init/start.sh or print contents for manual creation
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/responsive-task-management-application-237820-237840/backend"
cd "$WORKSPACE"
mkdir -p .init
OUT=.init/start.sh
TMP=$(mktemp)
cat >"$TMP" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/responsive-task-management-application-237820-237840/backend"
cd "$WORKSPACE"
LOG=/tmp/start.log
if ! node -e "try{const j=require('./package.json');process.exit(j.scripts&&j.scripts.start?0:1)}catch(e){process.exit(2)}"; then echo "ERROR: package.json start script missing" >&2; exit 50; fi
if command -v npm >/dev/null 2>&1; then npm run start >"$LOG" 2>&1; elif command -v yarn >/dev/null 2>&1; then yarn start >"$LOG" 2>&1; else echo "ERROR: npm or yarn required" >&2; exit 51; fi
SH
# attempt atomic install: move temp to final and set +x
if mv "$TMP" "$OUT" 2>/dev/null && chmod +x "$OUT" 2>/dev/null; then
  echo "OK: wrote $OUT"
else
  echo "WARN: failed to write $OUT; printing script for manual creation:" >&2
  # print the content so the engineer can create the file manually
  cat "$TMP" >&2 || true
  rm -f "$TMP" || true
  exit 0
fi
