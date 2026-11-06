#!/bin/bash
# Publishes the kids' games to the web (and so to the iPhone). Run on the MacBook:
#   ./publish-web.sh vehicles     https://sean-bostic.github.io/play/vehicles/
# Each game's built page (its game/ folder, from npm run build) is copied to <folder>/ in the public repo
# sean-bostic/play, which GitHub Pages serves. Only the built page goes there, never the source. Each script
# tag gets ?v=<the game's commit> (replacing any the build put there) so phones fetch the new version, and the page gets a noindex tag.
# A game with its own web build (npm run build:web, writing web/site/: the Shabin's leaves out the truck radio's
# song) goes up from that instead. Builds from the folder as it is, like publish.sh: commit first.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
JUNK="$(dirname "$HERE")"
REPO="sean-bostic/play"
SITE="https://sean-bostic.github.io/play"
WEB_GAMES=(vehicles claw marble basement hide-elf shabin dance shark dogfight backyard) # only the games that work on the web; add a folder here once it does

[ $# -gt 0 ] || { echo "Usage: ./publish-web.sh <folder…>   (on the web: ${WEB_GAMES[*]})"; exit 1; }
# (a web game's lab, <folder>-lab: its own page at play/<folder>-lab/, for trying it away from home: ./lab.sh <folder> web)
for dir in "$@"; do [[ " ${WEB_GAMES[*]} " == *" ${dir%-lab} "* && ( "$dir" == "${dir%-lab}" || -d "$JUNK/$dir" ) ]] || { echo "$dir isn't on the web list (${WEB_GAMES[*]}, or one's lab)"; exit 1; }; done

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
git clone -q --depth 1 "https://github.com/$REPO.git" "$OUT/play"

for dir in "$@"; do
  echo "== $dir"
  built=game
  if grep -q '"build:web"' "$JUNK/$dir/package.json"; then (cd "$JUNK/$dir" && npm run build:web >/dev/null); built=web/site
  else (cd "$JUNK/$dir" && npm run build >/dev/null); fi
  sha="$(git -C "$JUNK/$dir" rev-parse --short HEAD)"
  [ -z "$(git -C "$JUNK/$dir" status --porcelain -- src game)" ] || echo "   (uncommitted changes in $dir: they go out too)"
  rm -rf "$OUT/play/$dir" && cp -R "$JUNK/$dir/$built" "$OUT/play/$dir"
  sed -i '' -e "s|<script src=\"\([^\"?]*\)\.js\(?[^\"]*\)\{0,1\}\"></script>|<script src=\"\1.js?v=$sha\"></script>|g" \
    "$OUT/play/$dir/index.html"
  grep -q 'name="robots"' "$OUT/play/$dir/index.html" || sed -i '' -e 's|<meta charset="utf-8">|<meta charset="utf-8">\
<meta name="robots" content="noindex">|' "$OUT/play/$dir/index.html"
  echo "$dir $sha" >> "$OUT/versions"
done

cd "$OUT/play"
git add -A
if git diff --cached --quiet; then echo "Nothing changed on the web."; exit 0; fi
git commit -q -m "$(tr '\n' ' ' < "$OUT/versions")"
git push -q

# wait for Pages to serve the new version (usually under a minute)
while read -r dir sha; do
  for i in $(seq 1 30); do
    curl -s "$SITE/$dir/?check=$i" | grep -q "v=$sha" && { echo "Live: $SITE/$dir/ ($sha)"; continue 2; }
    sleep 10
  done
  echo "Not live after 5 minutes: $SITE/$dir/ (check github.com/$REPO/actions)"; exit 1
done < "$OUT/versions"
