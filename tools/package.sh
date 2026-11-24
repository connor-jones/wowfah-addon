#!/usr/bin/env bash
# Build two zips from the same files:
#   dist/WowfahLedger-<version>.zip      only the addon folder, for CurseForge, Wago and GitHub
#   dist/wowfah-ledger-<version>.zip     the addon plus the installers, for wowfah.com
# and copy the second one to the website next door, if it is there.
set -euo pipefail
cd "$(dirname "$0")/.."
luajit tests/run.lua
bash -n "installer/Mac - wowfah Ledger.command"
V=$(grep -E '^## Version:' WowfahLedger.toc | sed 's/.*: *//')
# the version the addon reports in uploads must be the one in the .toc
grep -q "^ns.VERSION = \"$V\"" Core.lua || { echo "Core.lua does not say version $V"; exit 1; }
STAGE=$(mktemp -d)
ADDON="$STAGE/clean/WowfahLedger"
mkdir -p "$ADDON" dist
# the addon is every tracked or new file except the development folders and dotfiles
git ls-files -co --exclude-standard | grep -v -E '^(tests|tools|installer|dist|\.github)/|^\.|^README\.md$' | while IFS= read -r f; do
  mkdir -p "$ADDON/$(dirname "$f")"
  cp "$f" "$ADDON/$f"
done
# every file the .toc names must be in the package
grep -v -E '^\s*(#|$)' WowfahLedger.toc | tr -d '\r' | tr '\\' '/' | while IFS= read -r f; do
  [ -f "$ADDON/$f" ] || { echo "the .toc names $f, which is not in the package"; exit 1; }
done
find "$STAGE" -name '.DS_Store' -delete
rm -f "dist/WowfahLedger-$V.zip" "dist/wowfah-ledger-$V.zip"
(cd "$STAGE/clean" && zip -q -r -X ../clean.zip WowfahLedger)
mv "$STAGE/clean.zip" "dist/WowfahLedger-$V.zip"

TOP="$STAGE/full/wowfah-ledger"
mkdir -p "$TOP"
cp -R "$ADDON" "$TOP/"
cp "installer/Windows - wowfah Ledger.bat" "installer/Mac - wowfah Ledger.command" "installer/READ ME FIRST.txt" "$TOP/"
chmod +x "$TOP/Mac - wowfah Ledger.command"
# Windows needs CRLF line endings in the batch file and the read-me
file "$TOP/Windows - wowfah Ledger.bat" | grep -q CRLF || { echo "batch file lost its CRLF line endings"; exit 1; }
perl -pi -e 's/\r?\n/\r\n/' "$TOP/READ ME FIRST.txt"
(cd "$STAGE/full" && zip -q -r -X ../full.zip wowfah-ledger)
mv "$STAGE/full.zip" "dist/wowfah-ledger-$V.zip"
rm -rf "$STAGE"
WEB=../web/static/downloads
# WOWFAH_NO_PUBLISH=1 builds the zips without putting them on the website: for a version still being tested in game
if [ -d ../web/static ] && [ -z "${WOWFAH_NO_PUBLISH:-}" ]; then
  mkdir -p "$WEB"
  rm -f "$WEB"/WowfahLedger-*.zip "$WEB"/wowfah-ledger-*.zip
  cp "dist/wowfah-ledger-$V.zip" "$WEB/wowfah-ledger-$V.zip"
  cp "dist/wowfah-ledger-$V.zip" "$WEB/WowfahLedger.zip"      # the stable address the site links to
  echo "$V" > "$WEB/version.txt"
fi
echo "built dist/WowfahLedger-$V.zip ($(du -h "dist/WowfahLedger-$V.zip" | cut -f1)) and dist/wowfah-ledger-$V.zip ($(du -h "dist/wowfah-ledger-$V.zip" | cut -f1))"
