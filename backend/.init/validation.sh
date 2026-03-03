#!/usr/bin/env bash
set -euo pipefail

# Environment validation and safe PATH persistence
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/responsive-task-management-application-237820-237840/backend"
cd "$WORKSPACE"
NODE_MIN=16
OUT_LOG=/tmp/env-versions.log
PROFILE_FILE=/etc/profile.d/node_env.sh
: > "$OUT_LOG"

# Node presence and version parse
node_ver_raw=$(command -v node >/dev/null 2>&1 && node -v 2>/dev/null || true)
if [[ -z "${node_ver_raw:-}" ]]; then echo "ERROR: node not found on PATH" >&2; exit 2; fi
node_ver_norm=${node_ver_raw#v}
node_major=$(echo "$node_ver_norm" | sed -E 's/^([0-9]+).*$/\1/')
if ! [[ "$node_major" =~ ^[0-9]+$ ]]; then echo "ERROR: unable to parse node version: $node_ver_raw" >&2; exit 3; fi

# Read simple engines.node from package.json if present (best-effort)
pkg_engine=""
if [ -f package.json ]; then
  pkg_engine=$(node -e "try{const j=require('./package.json');console.log(j.engines&&j.engines.node?j.engines.node:'')}catch(e){console.log('')}" 2>/dev/null || true)
fi

# Embedded best-effort engines check: handle patterns like '>=16', '^16.0.0', '16.x', '16'
if [ -n "${pkg_engine:-}" ]; then
  # extract leading numeric major
  req_major=$(echo "$pkg_engine" | sed -E 's/.*([0-9]+)(\.[0-9]+)?(\.[0-9]+)?.*/\1/' || true)
  if [[ "$req_major" =~ ^[0-9]+$ ]]; then
    if (( node_major < req_major )); then
      echo "ERROR: node $node_ver_raw does not meet package.json engines.node ($pkg_engine)" >&2
      echo "node=$node_ver_raw pkgmgr=unknown npm_prefix=" > "$OUT_LOG"
      exit 4
    fi
  else
    if (( node_major < NODE_MIN )); then
      echo "ERROR: node $node_ver_raw < required major $NODE_MIN (engines check limited)" >&2
      echo "node=$node_ver_raw pkgmgr=unknown npm_prefix=" > "$OUT_LOG"
      exit 5
    fi
  fi
else
  if (( node_major < NODE_MIN )); then
    echo "ERROR: node $node_ver_raw < required major $NODE_MIN" >&2
    echo "node=$node_ver_raw pkgmgr=unknown npm_prefix=" > "$OUT_LOG"
    exit 6
  fi
fi

# Ensure npm or yarn
pkgmgr=""
if command -v npm >/dev/null 2>&1; then pkgmgr=npm; elif command -v yarn >/dev/null 2>&1; then pkgmgr=yarn; else echo "ERROR: neither npm nor yarn found" >&2; echo "node=$node_ver_raw pkgmgr=none npm_prefix=" > "$OUT_LOG"; exit 7; fi

npm_prefix=""
npm_bin=""
if [ "$pkgmgr" = "npm" ]; then
  npm_prefix=$(npm config get prefix 2>/dev/null || true)
  if [ -n "$npm_prefix" ]; then
    npm_prefix=$(readlink -f "$npm_prefix" 2>/dev/null || echo "$npm_prefix")
    if [ -d "$npm_prefix/bin" ]; then npm_bin="$npm_prefix/bin"; fi
  fi
fi

# Record resolved versions
echo "node=$node_ver_raw pkgmgr=$pkgmgr npm_prefix=${npm_prefix:-}" > "$OUT_LOG"

# Only persist PATH if npm_bin exists and prefix looks system-owned under /usr or /usr/local
if [ -n "${npm_bin:-}" ]; then
  case "$npm_prefix" in
    /usr/*|/usr_local*|/usr/local*)
      tmpf=$(mktemp)
      cat > "$tmpf" <<'EOF'
# added by automated setup - expose npm global bin if not already present
if [ -n "NPM_GLOBAL_BIN" ]; then
  case ":$PATH:" in
    *":$NPM_GLOBAL_BIN:") :;;
    *) PATH="$NPM_GLOBAL_BIN":$PATH;;
  esac
fi
EOF
      # replace placeholder
      sed -i "s|NPM_GLOBAL_BIN|${npm_bin}|g" "$tmpf" || true
      # atomic move with sudo and set perms
      if sudo mv "$tmpf" "$PROFILE_FILE" && sudo chmod 644 "$PROFILE_FILE"; then
        : # success
      else
        echo "WARN: failed to write $PROFILE_FILE" >&2
      fi
      ;;
    *)
      echo "INFO: npm prefix ($npm_prefix) not under /usr or /usr/local; skipping global PATH persistence" >> "$OUT_LOG"
      ;;
  esac
fi

echo "OK: node=$node_ver_raw pkgmgr=$pkgmgr"
