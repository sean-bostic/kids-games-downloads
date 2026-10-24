#!/bin/bash
# "Update Games" for the TV Mac: downloads the newest build of every game from the "games" release
# (put there by ../publish.sh on the MacBook) and swaps it in wherever the old copy lives.
# curl doesn't add the "downloaded from the internet" mark, so updated games open with no security prompt.
# Everything runs inside main() so bash has read the whole script before it replaces its own app at the end.
# Plain bash 3.2: this runs on an old Intel Mac.

BASE="https://github.com/sean-bostic/kids-games-downloads/releases/download/games"
SELF_APP="$(cd "$(dirname "$0")/../.." && pwd)"

dialog() { osascript -e "display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"Update Games\"" >/dev/null 2>&1; }
note() { osascript -e "display notification \"$1\" with title \"Update Games\"" >/dev/null 2>&1; }

# every existing copy of the app (kids may launch from Desktop or Downloads); the Desktop if there is none
copies() {
  local found=0
  for d in "$HOME/Desktop" "/Applications" "$HOME/Applications" "$HOME/Downloads"; do
    if [ -d "$d/$1.app" ]; then echo "$d/$1.app"; found=1; fi
  done
  [ $found = 1 ] || echo "$HOME/Desktop/$1.app"
}

# download + unzip one game, check it, then replace each copy
install() {
  local name="$1" asset="$2" out="$TMP/${asset%.zip}"
  mkdir -p "$out"
  curl -fsSL --retry 2 --max-time 300 "$BASE/$asset" -o "$TMP/$asset" || return 1
  ditto -x -k "$TMP/$asset" "$out" || return 1
  [ -x "$out/$name.app/Contents/MacOS/launch" ] || return 1
  xattr -dr com.apple.quarantine "$out/$name.app" 2>/dev/null
  local dest
  while IFS= read -r dest; do
    rm -rf "$dest" && ditto "$out/$name.app" "$dest" || return 1
  done < <(copies "$name")
}

main() {
  TMP="$(mktemp -d)"
  note "Downloading the newest games…"
  if ! curl -fsSL --retry 2 --max-time 30 "$BASE/games.txt" -o "$TMP/games.txt"; then
    dialog "Couldn't reach the internet, so nothing changed. The games still work. Try again when the Wi-Fi is on."
    exit 1
  fi
  local ok="" failed="" self_asset="" name asset
  while IFS='|' read -r name asset; do
    [ -z "$name" ] && continue
    if [ "$name" = "Update Games" ]; then self_asset="$asset"; continue; fi
    if install "$name" "$asset"; then ok="$ok\n  ✓ $name"; else failed="$failed\n  ✗ $name"; fi
  done < "$TMP/games.txt"

  # itself last, in place (main() is already fully read, so replacing this file is safe)
  if [ -n "$self_asset" ]; then
    mkdir -p "$TMP/self"
    if curl -fsSL --retry 2 --max-time 120 "$BASE/$self_asset" -o "$TMP/self.zip" && ditto -x -k "$TMP/self.zip" "$TMP/self" \
       && [ -x "$TMP/self/Update Games.app/Contents/MacOS/launch" ]; then
      xattr -dr com.apple.quarantine "$TMP/self/Update Games.app" 2>/dev/null
      rm -rf "$SELF_APP" && ditto "$TMP/self/Update Games.app" "$SELF_APP"
    fi
  fi
  rm -rf "$TMP"

  if [ -z "$failed" ]; then dialog "All the games are up to date!$ok"
  else dialog "Updated:$ok\n\nCouldn't update (the old version still works):$failed"; fi
}

main "$@"
exit
