#!/usr/bin/env bash
# Build dist/WowfahLedger-<version>.zip and copy it to the website's downloads folder.
set -euo pipefail
cd "$(dirname "$0")/.."
luajit tests/run.lua
V=$(grep -E '^## Version:' WowfahLedger/WowfahLedger.toc | sed 's/.*: *//')
mkdir -p dist
rm -f "dist/WowfahLedger-$V.zip"
zip -q -r "dist/WowfahLedger-$V.zip" WowfahLedger -x '*.DS_Store'
WEB=../web/static/downloads
if [ -d ../web/static ]; then
  mkdir -p "$WEB"
  cp "dist/WowfahLedger-$V.zip" "$WEB/WowfahLedger-$V.zip"
  cp "dist/WowfahLedger-$V.zip" "$WEB/WowfahLedger.zip"
  echo "$V" > "$WEB/version.txt"
fi
echo "built dist/WowfahLedger-$V.zip ($(du -h "dist/WowfahLedger-$V.zip" | cut -f1))"
