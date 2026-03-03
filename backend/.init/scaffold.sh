#!/usr/bin/env bash
set -euo pipefail
# Scaffold script for project: ensures package.json has build/start/test scripts per step
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/responsive-task-management-application-237820-237840/backend"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE"
# Record env versions
{ printf "node:%s\n" "$(node -v 2>/dev/null || echo 'missing')"; printf "npm:%s\n" "$(npm -v 2>/dev/null || echo 'missing')"; printf "yarn:%s\n" "$(yarn -v 2>/dev/null || echo 'missing')"; } > /tmp/env-versions.log
# Quick Node >=16 check (accept v16+). If package.json has engines, do a simple parse for major.
node -e "try{const v=process.versions.node.split('.')[0]|0; if(v<16) {console.error('ERROR: node>=16 required, found',process.versions.node); process.exit(2);} }catch(e){console.error('ERROR: node not available'); process.exit(3);}"
# Ensure npm or yarn present
if ! command -v npm >/dev/null 2>&1 && ! command -v yarn >/dev/null 2>&1; then
  echo "ERROR: neither npm nor yarn found" >&2
  exit 4
fi
# Helper: write file only if not exists
_write_if_missing(){ local path="$1"; shift; if [ -e "$path" ]; then return 0; fi; mkdir -p "$(dirname "$path")"; cat >"$path" <<'EOF'
$*
EOF
}
# Primary logic
if [ ! -f package.json ]; then
  # empty dir check
  if [ "$(ls -A . | wc -l)" -eq 0 ]; then
    # prefer preinstalled create-react-app
    if command -v create-react-app >/dev/null 2>&1; then
      create-react-app . --use-npm --silent || { echo "ERROR: create-react-app failed" >&2; exit 10; }
    elif command -v npx >/dev/null 2>&1; then
      npx create-react-app@latest . --use-npm --silent || { echo "ERROR: npx create-react-app failed" >&2; exit 11; }
    else
      echo "ERROR: create-react-app not available (neither create-react-app nor npx)" >&2
      exit 12
    fi
  else
    # non-empty directory: create minimal package.json and small prepare-build.js without overwriting existing files
    if [ ! -f package.json ]; then
      cat >package.json <<'JSON'
{
  "name": "workspace-app",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "prebuild": "node ./scripts/prepare-build.js",
    "build": "node ./scripts/prepare-build.js",
    "start": "serve -s build -l 3000",
    "test": "jest --colors --runInBand --ci"
  },
  "devDependencies": {
    "serve": "^14.0.0",
    "jest": "^29.0.0"
  }
}
JSON
    fi
    mkdir -p public scripts build
    if [ ! -f public/index.html ]; then
      cat >public/index.html <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>App</title></head><body><div id="root">Hello</div></body></html>
HTML
    fi
    if [ ! -f scripts/prepare-build.js ]; then
      cat >scripts/prepare-build.js <<'JS'
const fs=require('fs'),path=require('path');const src='public',dest='build';function copyDir(s,d){if(!fs.existsSync(d))fs.mkdirSync(d,{recursive:true});fs.readdirSync(s).forEach(f=>{const sp=path.join(s,f),dp=path.join(d,f);if(fs.statSync(sp).isDirectory())copyDir(sp,dp);else fs.copyFileSync(sp,dp)});}try{copyDir(src,dest);console.log('OK: copied public -> build')}catch(e){console.error(e);process.exit(1)}
JS
    fi
  fi
else
  # package.json exists: merge scripts without clobbering other fields; do not overwrite file except update scripts
  node - <<'NODE'
const fs=require('fs');const p='package.json';let j=JSON.parse(fs.readFileSync(p));j.scripts=j.scripts||{};j.scripts.start=j.scripts.start||'serve -s build -l 3000';j.scripts.build=j.scripts.build||'echo "No build configured" && exit 1';j.scripts.test=j.scripts.test||'jest --colors --runInBand --ci';// avoid '*' pins: ensure devDependencies use conservative caret if absent
j.devDependencies=j.devDependencies||{}; if(!j.devDependencies.serve) j.devDependencies.serve='^14.0.0'; if(!j.devDependencies.jest) j.devDependencies.jest='^29.0.0';fs.writeFileSync(p,JSON.stringify(j,null,2));
NODE
fi
# Final validation: ensure scripts exist in package.json
node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync('package.json')); if(!j.scripts||!j.scripts.build||!j.scripts.start||!j.scripts.test){console.error('ERROR: package.json missing required scripts'); process.exit(20);} console.log('OK: package.json scripts present');"
exit 0
