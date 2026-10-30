#!/bin/bash
# Publishes the kids' games for the TV Mac. Run on the MacBook:
#   ./publish.sh            rebuild and upload every game
#   ./publish.sh marble     just one (folder names: claw marble vehicles reading skifree jumping-bean shabin dance)
# Each game is rebuilt with its own tools/build-app.sh, copied to the Desktop, zipped, and uploaded to the
# "games" release. On the TV Mac, double-clicking "Update Games" downloads whatever is there.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
JUNK="$(dirname "$HERE")"
REPO="sean-bostic/kids-games-downloads"
TAG="games"
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# folder | app name. To add a game: add a line here and run ./publish.sh <folder>.
GAMES=(
  "claw|Claw Machine"
  "marble|Marble Rush"
  "vehicles|Turbo Vehicle Simulator"
  "reading|Reading Rainbow"
  "skifree|SkiFree"
  "jumping-bean|Jumping Bean Jamboree"
  "shabin|The Shabin"
  "dance|Dance Party"
)
asset() { echo "${1// /-}.zip"; }   # "Marble Rush" -> Marble-Rush.zip (no spaces in download links)

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# the list the updater reads, always every game
{ for g in "${GAMES[@]}"; do n="${g#*|}"; echo "$n|$(asset "$n")"; done; echo "Update Games|$(asset "Update Games")"; } > "$OUT/games.txt"

# ---- the games ----
uploads=("$OUT/games.txt")
for g in "${GAMES[@]}"; do
  dir="${g%%|*}" name="${g#*|}"
  if [ $# -gt 0 ] && [[ " $* " != *" $dir "* ]]; then continue; fi
  echo "== $name"
  (cd "$JUNK/$dir" && ./tools/build-app.sh)
  rm -rf "$HOME/Desktop/$name.app" && ditto "$JUNK/$dir/$name.app" "$HOME/Desktop/$name.app"
  ditto -c -k --sequesterRsrc --keepParent "$JUNK/$dir/$name.app" "$OUT/$(asset "$name")"
  uploads+=("$OUT/$(asset "$name")")
done

# ---- the updater app itself (tiny, so it always goes up) ----
APP="$OUT/Update Games.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/updater/update.sh" "$APP/Contents/MacOS/launch" && chmod +x "$APP/Contents/MacOS/launch"
ICON="$OUT/icon"
mkdir -p "$ICON/AppIcon.iconset"
"$CHROME_BIN" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
  --window-size=1024,1024 --screenshot="$ICON/icon.png" "file://$HERE/updater/icon.html" >/dev/null 2>&1
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON/icon.png" --out "$ICON/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$ICON/icon.png" --out "$ICON/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICON/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Update Games</string>
  <key>CFBundleDisplayName</key><string>Update Games</string>
  <key>CFBundleIdentifier</key><string>local.family.updategames</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>launch</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
</dict>
</plist>
PLIST
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$(asset "Update Games")"
uploads+=("$OUT/$(asset "Update Games")")

# ---- upload ----
gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 || gh release create "$TAG" --repo "$REPO" --title "Latest games" \
  --notes "The newest build of every game. On the TV Mac, double-click Update Games to get them. First time only: download Update-Games.zip, unzip it, right-click → Open (or System Settings → Privacy & Security → Open Anyway)."
gh release upload "$TAG" --repo "$REPO" --clobber "${uploads[@]}"
echo "Published: https://github.com/$REPO/releases/tag/$TAG"
