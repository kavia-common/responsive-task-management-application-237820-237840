#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/responsive-task-management-application-237820-237840/backend"
cd "$WORKSPACE"
PORT=3000
BUILD_LOG=/tmp/build.log
SERVE_LOG=/tmp/serve.log
rm -f "$BUILD_LOG" "$SERVE_LOG" || true

# ensure package.json has build script
if ! node -e "try{const j=require('./package.json');process.exit(j.scripts&&j.scripts.build?0:1)}catch(e){process.exit(2)}"; then
  echo "ERROR: package.json build script missing" >&2
  exit 60
fi

# run build (npm preferred)
if command -v npm >/dev/null 2>&1; then
  npm run build >"$BUILD_LOG" 2>&1 || { tail -n 500 "$BUILD_LOG" >&2; echo "ERROR: npm run build failed" >&2; exit 61; }
elif command -v yarn >/dev/null 2>&1; then
  yarn build >"$BUILD_LOG" 2>&1 || { tail -n 500 "$BUILD_LOG" >&2; echo "ERROR: yarn build failed" >&2; exit 61; }
else
  echo "ERROR: neither npm nor yarn available to run build" >&2
  exit 65
fi

if [ ! -d build ]; then
  echo "ERROR: build directory missing after build" >&2
  exit 62
fi

SERVE_PID=""
# prefer local node_modules/.bin/serve
if [ -x ./node_modules/.bin/serve ]; then
  ./node_modules/.bin/serve -s build -l "$PORT" >"$SERVE_LOG" 2>&1 & SERVE_PID=$!
elif command -v serve >/dev/null 2>&1; then
  serve -s build -l "$PORT" >"$SERVE_LOG" 2>&1 & SERVE_PID=$!
elif command -v python3 >/dev/null 2>&1; then
  (cd build && python3 -m http.server "$PORT" --bind 0.0.0.0) >"$SERVE_LOG" 2>&1 & SERVE_PID=$!
else
  echo "ERROR: no server available (serve or python3 missing)" >&2
  exit 63
fi

_cleanup() {
  if [ -n "${SERVE_PID:-}" ]; then
    kill "$SERVE_PID" 2>/dev/null || true
    wait "$SERVE_PID" 2>/dev/null || true
  fi
}
trap _cleanup EXIT

end=$((SECONDS+30))
sleep_interval=1
code=""
while [ $SECONDS -lt $end ]; do
  code=$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" || true)
  if [[ "$code" =~ ^[23] ]]; then
    echo "OK: served (HTTP $code)"
    break
  fi
  sleep $sleep_interval
  if [ $sleep_interval -lt 4 ]; then
    sleep_interval=$((sleep_interval*2))
  fi
done

if [[ ! "$code" =~ ^[23] ]]; then
  echo "ERROR: server did not return 2xx/3xx within timeout; see $SERVE_LOG" >&2
  exit 64
fi

exit 0
