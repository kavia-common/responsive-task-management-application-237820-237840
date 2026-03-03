#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/responsive-task-management-application-237820-237840/backend"
cd "$WORKSPACE"
# create minimal jest sanity test (idempotent)
mkdir -p __tests__
if [ ! -f __tests__/sanity.test.js ]; then
  cat >__tests__/sanity.test.js <<'JS'
test('sanity',()=>{expect(1+1).toBe(2)})
JS
fi
# create minimal ESLint config if absent
if [ ! -f .eslintrc.json ]; then
  cat >.eslintrc.json <<'JSON'
{ "env": { "browser": true, "es2021": true }, "extends": "eslint:recommended", "parserOptions": { "ecmaVersion": 2021 }, "rules": {} }
JSON
fi
# create minimal Prettier config if absent
if [ ! -f .prettierrc ]; then
  echo '{"singleQuote":true}' > .prettierrc
fi
# Ensure local jest exists and run tests in CI mode with NODE_ENV=test
if [ -x ./node_modules/.bin/jest ]; then
  export NODE_ENV=test
  # run local jest in CI mode, single thread to be CI-friendly
  ./node_modules/.bin/jest --colors --runInBand --ci
else
  echo "ERROR: local jest binary not found; ensure install step succeeded" >&2
  exit 40
fi
