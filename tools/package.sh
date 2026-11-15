#!/usr/bin/env bash
# Build dist/wowfah-ledger-<version>.zip (the addon plus the installers) and copy it to the website.
set -euo pipefail
cd "$(dirname "$0")/.."
luajit tests/run.lua
bash -n "installer/Mac - wowfah Ledger.command"
V=$(grep -E '^## Version:' WowfahLedger/WowfahLedger.toc | sed 's/.*: *//')
STAGE=$(mktemp -d)
TOP="$STAGE/wowfah-ledger"
mkdir -p "$TOP" dist
cp -R WowfahLedger "$TOP/"
cp "installer/Windows - wowfah Ledger.bat" "installer/Mac - wowfah Ledger.command" "installer/READ ME FIRST.txt" "$TOP/"
chmod +x "$TOP/Mac - wowfah Ledger.command"
# Windows needs CRLF line endings in the batch file and the read-me
file "$TOP/Windows - wowfah Ledger.bat" | grep -q CRLF || { echo "batch file lost its CRLF line endings"; exit 1; }
perl -pi -e 's/\r?\n/\r\n/' "$TOP/READ ME FIRST.txt"
find "$TOP" -name '.DS_Store' -delete
rm -f "dist/wowfah-ledger-$V.zip"
(cd "$STAGE" && zip -q -r -X out.zip wowfah-ledger)
mv "$STAGE/out.zip" "dist/wowfah-ledger-$V.zip"
rm -rf "$STAGE"
WEB=../web/static/downloads
if [ -d ../web/static ]; then
  mkdir -p "$WEB"
  rm -f "$WEB"/WowfahLedger-*.zip "$WEB"/wowfah-ledger-*.zip
  cp "dist/wowfah-ledger-$V.zip" "$WEB/wowfah-ledger-$V.zip"
  cp "dist/wowfah-ledger-$V.zip" "$WEB/WowfahLedger.zip"      # the stable address the site links to
  echo "$V" > "$WEB/version.txt"
fi
echo "built dist/wowfah-ledger-$V.zip ($(du -h "dist/wowfah-ledger-$V.zip" | cut -f1))"
