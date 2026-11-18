#!/bin/bash
# wowfah Ledger for Mac: installs or updates the addon, and finds your saved ledger file.
# It only copies the WowfahLedger folder into World of Warcraft/_forever_/Interface/AddOns.
# Nothing is downloaded and nothing else on your Mac is changed. Open this file in TextEdit to read it.
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/WowfahLedger"
WOW=""
FL="_forever_"

try() {   # sets WOW when the folder given (or the one above it) contains _forever_
  [ -n "$WOW" ] && return
  local p="${1%/}"
  [ -z "$p" ] && return
  local up; up="$(dirname "$p")"
  for name in _forever_ forever; do
    [ -n "$WOW" ] && break
    if [ -d "$p/$name" ] && { [ "$name" = "_forever_" ] || [ -d "$p/$name/Interface" ]; }; then WOW="$p"; FL="$name"
    elif [ -d "$up/$name" ] && { [ "$name" = "_forever_" ] || [ -d "$up/$name/Interface" ]; }; then WOW="$up"; FL="$name"; fi
  done
}

echo
echo "  wowfah Ledger"
echo "  ============="
echo
[ -n "$WOWFAH_WOW_DIR" ] && try "$WOWFAH_WOW_DIR"
try "/Applications/World of Warcraft"
try "$HOME/Applications/World of Warcraft"
try "/Users/Shared/World of Warcraft"
for v in /Volumes/*; do
  try "$v/World of Warcraft"; try "$v/Games/World of Warcraft"; try "$v/Applications/World of Warcraft"
done
if [ -z "$WOW" ] && command -v mdfind >/dev/null 2>&1; then
  while IFS= read -r hit; do try "$hit"; done < <(mdfind -name "_forever_" 2>/dev/null | grep '/_forever_$' | head -5)
fi
if [ -z "$WOW" ]; then
  echo "  World of Warcraft was not found automatically."
  echo
  echo "  1. Open the Battle.net app and select World of Warcraft."
  echo "  2. Click the cog next to Play, then Reveal in Finder."
  echo "  3. Drag the World of Warcraft folder onto this window and press Return."
  echo
  read -r -p "  Folder: " ASK
  ASK="${ASK//\\ / }"; ASK="${ASK%\'}"; ASK="${ASK#\'}"; ASK="${ASK%\"}"; ASK="${ASK#\"}"; ASK="${ASK% }"
  try "$ASK"
  if [ -z "$WOW" ]; then
    echo; echo "  That folder has no _forever_ folder inside it, so WoW Forever is not installed there."
    echo "  Nothing was changed. You can also install by hand: https://wowfah.com/addon"; echo
    exit 1
  fi
fi

echo "  Game found: $WOW/$FL"
echo
echo "  1  Install or update the addon"
echo "  2  Find my ledger file and open the upload page"
echo "  3  Close"
echo
read -r -p "  Choose 1, 2 or 3 and press Return [1]: " PICK
case "${PICK:-1}" in
  2)
    FILES=()
    while IFS= read -r f; do FILES+=("$f"); done < <(find "$WOW/$FL/WTF/Account" -name "WowfahLedger.lua" -path "*SavedVariables*" 2>/dev/null)
    if [ ${#FILES[@]} -eq 0 ]; then
      echo; echo "  No ledger file yet. The game writes it when you log out or type /sync"
      echo "  with the addon turned on. Do that, then choose 2 again."
    else
      NEWEST="$(ls -t "${FILES[@]}" | head -1)"
      echo; echo "  Your ledger file:"; echo "  $NEWEST"
      [ ${#FILES[@]} -gt 1 ] && echo "  You have more than one game account. Each has its own file in WTF/Account."
      echo; echo "  Finder is opening with the file selected, and the upload page is opening in your browser."
      echo "  Drag the file onto the page."
      [ -z "$WOWFAH_NO_OPEN" ] && { open -R "$NEWEST"; open "https://wowfah.com/ledger/upload"; }
    fi ;;
  3) ;;
  *)
    if [ ! -f "$SRC/WowfahLedger.toc" ]; then
      echo; echo "  The WowfahLedger folder is not next to this file. Unzip the whole download first."
      echo "  Nothing was changed. You can also install by hand: https://wowfah.com/addon"; echo
      exit 1
    fi
    DEST="$WOW/$FL/Interface/AddOns"
    if mkdir -p "$DEST" && rm -rf "$DEST/WowfahLedger" && cp -R "$SRC" "$DEST/WowfahLedger" && [ -f "$DEST/WowfahLedger/WowfahLedger.toc" ]; then
      echo; echo "  Installed to $DEST/WowfahLedger"; echo
      echo "  Next:"
      echo "    1. Start the game, or type /reload if it is already running."
      echo "    2. On the character screen click AddOns and make sure wowfah Ledger is ticked."
      echo "       If it is greyed out, tick Load out of date AddOns."
      echo "    3. In game, type /wowfah"
      echo; echo "  Keep this folder. Run this file again and choose 2 when you want to upload your ledger."
    else
      echo; echo "  The files could not be copied to:"; echo "  $DEST"
      echo "  Close the game and try again, or install by hand: https://wowfah.com/addon"
    fi ;;
esac
echo
