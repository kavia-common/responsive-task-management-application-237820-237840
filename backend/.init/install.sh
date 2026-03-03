#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/responsive-task-management-application-237820-237840/backend"
cd "$WORKSPACE"
LOG=/tmp/npm-install.log
rm -f "$LOG" || true
# ensure npm or yarn present
if command -v npm >/dev/null 2>&1; then
  PM="npm"
elif command -v yarn >/dev/null 2>&1; then
  PM="yarn"
else
  echo "ERROR: no package manager found (npm or yarn required)" >&2
  exit 24
fi
# run deterministic install
if [ "$PM" = "npm" ]; then
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund --silent >"$LOG" 2>&1 || { tail -n 500 "$LOG" >&2; echo "ERROR: npm ci failed" >&2; exit 21; }
  else
    npm install --no-audit --no-fund --prefer-offline --silent >"$LOG" 2>&1 || { tail -n 500 "$LOG" >&2; echo "ERROR: npm install failed" >&2; exit 22; }
  fi
else
  yarn install --silent >"$LOG" 2>&1 || { tail -n 500 "$LOG" >&2; echo "ERROR: yarn install failed" >&2; exit 23; }
fi
# Validate expected binaries declared in devDependencies (common tools); trim output on failure
# Tools to check: jest and serve (scaffold declares these)
for tool in jest serve; do
  if jq -e ".devDependencies and (.devDependencies | has(\"$tool\"))" package.json >/dev/null 2>&1 || grep -q "\"$tool\"" package.json 2>/dev/null; then
    if [ ! -x "./node_modules/.bin/$tool" ]; then
      echo "ERROR: expected $tool in node_modules/.bin but not found" >&2
      echo "Last 500 lines of install log:" >&2
      tail -n 500 "$LOG" >&2 || true
      exit 25
    fi
  fi
done
# success
echo "OK: dependencies installed"
