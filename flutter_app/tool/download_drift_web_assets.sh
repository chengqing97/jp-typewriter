#!/usr/bin/env bash
set -euo pipefail

# Keep this in sync with the resolved drift version in pubspec.lock.
DRIFT_VERSION="2.35.4"
WEB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/web"
BASE_URL="https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VERSION}"

mkdir -p "${WEB_DIR}"

curl --fail --location --retry 3 "${BASE_URL}/sqlite3.wasm" \
  --output "${WEB_DIR}/sqlite3.wasm"
curl --fail --location --retry 3 "${BASE_URL}/drift_worker.js" \
  --output "${WEB_DIR}/drift_worker.js"

echo "Installed Drift ${DRIFT_VERSION} web runtime assets in ${WEB_DIR}"
