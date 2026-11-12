#!/bin/bash
# The lab: a private test bed for a game, played on the phones over home Wi-Fi before it goes out. Run on the MacBook:
#   ./lab.sh dogfight new      make the lab once: ../dogfight-lab, a git worktree on its own branch (lab)
#   ./lab.sh dogfight serve    serve the lab's build (its game/ folder: npm run build there) at http://<this Mac>:<port>/
#                              on home Wi-Fi, keeping the Mac awake. Ctrl-C stops it.
#   ./lab.sh dogfight web      the lab on the web too, for away from home (cell): its own page, play/dogfight-lab/, kept
#                              apart from the real game (its own saved settings, rooms and invite link). Lab work only:
#                              commit it first. The real game's page isn't touched.
#   ./lab.sh dogfight app      the lab as an app in Desktop/Games too ("Dogfight Lab.app", kept apart from the real game
#                              like the lab page), and up to the TV Mac (the mini: Update Games) if publish.sh's LABS
#                              lists it. Needs the game's tools/build-app.sh to know 'lab' (dogfight's does).
#   ./lab.sh dogfight ship     the lab's COMMITTED work goes everywhere: main catches up with the lab (tested), then
#                              GitHub (the backup repo), the Desktop app, the TV Mac (publish.sh) and the web if the
#                              game's on it (publish-web.sh). Afterwards the lab and main are the same again.
# Built files (game/, web/site/, the .app) that conflict in a merge are just rebuilt; any other conflict stops it.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
JUNK="$(dirname "$HERE")"
die() { echo "lab: $*" >&2; exit 1; }

[ $# -eq 2 ] || die "usage: ./lab.sh <game folder> new|serve|web|app|ship"
dir="$1" cmd="$2" MAIN="$JUNK/$1" LAB="$JUNK/$1-lab"
[ -d "$MAIN/.git" ] || [ -f "$MAIN/.git" ] || die "no game at $MAIN"
case "$dir" in dogfight) PORT=8800 ;; hide-elf) PORT=8801 ;; drainage) PORT=8802 ;; *) PORT=8810 ;; esac # (the phones remember these)
built='^(game/|web/site/|[^/]+\.app/)'

case "$cmd" in
new)
  [ -e "$LAB" ] && die "$LAB is already there"
  git -C "$MAIN" worktree add -q -b lab "$LAB" main
  [ -e "$MAIN/node_modules" ] && ln -s "$(cd "$MAIN/node_modules" && pwd -P)" "$LAB/node_modules"
  (cd "$LAB" && npm run build >/dev/null)
  echo "Made $LAB (branch lab). Serve it: ./lab.sh $dir serve"
  ;;
serve)
  [ -d "$LAB/game" ] || die "no lab yet: ./lab.sh $dir new"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1 && die "something's already serving on :$PORT (the lab, probably: it serves the newest build by itself)"
  ip="$(ipconfig getifaddr en0 2>/dev/null || echo localhost)"
  echo "The $dir lab: http://$ip:$PORT/  (home Wi-Fi; Ctrl-C stops it)"
  exec caffeinate -is python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$LAB/game"
  ;;
ship)
  [ -d "$LAB" ] || die "no lab at $LAB"
  branch="$(git -C "$LAB" branch --show-current)"
  [ "$(git -C "$MAIN" branch --show-current)" = main ] || die "$MAIN isn't on main"
  [ -z "$(git -C "$LAB" status --porcelain | grep -vE "^.. $built" || true)" ] || die "the lab has uncommitted changes: commit them (or throw them away) first"
  [ -z "$(git -C "$MAIN" status --porcelain | grep -vE "^.. $built" || true)" ] || die "$MAIN has uncommitted changes"
  git -C "$MAIN" checkout -q -- . && git -C "$LAB" checkout -q -- . # (just stale built files: they're rebuilt below)

  echo "== the lab catches up with main"
  if ! git -C "$LAB" merge -q --no-edit main; then
    other="$(git -C "$LAB" diff --name-only --diff-filter=U | grep -vE "$built" || true)"
    [ -z "$other" ] || { git -C "$LAB" merge --abort; die "merge conflicts to sort out by hand in the lab: $other"; }
    git -C "$LAB" diff --name-only --diff-filter=U | xargs git -C "$LAB" checkout --theirs --
    (cd "$LAB" && npm run build >/dev/null) && git -C "$LAB" add -A && git -C "$LAB" commit -q --no-edit
  fi
  echo "== tests and build (in the lab)"
  (cd "$LAB" && npm run build >/dev/null && { ! grep -q '"test"' package.json || npm test >/dev/null; }) || die "the tests failed: nothing shipped"
  [ -z "$(git -C "$LAB" status --porcelain -- game)" ] || { git -C "$LAB" add game && git -C "$LAB" commit -q -m "Rebuilt"; }

  echo "== main = the lab ($branch)"
  git -C "$MAIN" merge -q --ff-only "$branch"
  git -C "$MAIN" push -q

  echo "== the Desktop app and the TV Mac"
  (cd "$HERE" && ./publish.sh "$dir")
  app="$(grep -E "^  \"$dir\|" "$HERE/publish.sh" | grep -v ' Lab"' | sed -E 's/.*\|(.*)".*/\1/')"
  if [ -n "$(git -C "$MAIN" status --porcelain)" ]; then git -C "$MAIN" add -A && git -C "$MAIN" commit -q -m "$app.app: rebuilt" && git -C "$MAIN" push -q; fi
  check="$(mktemp -d)"; trap 'rm -rf "$check"' EXIT
  gh release download games -R sean-bostic/kids-games-downloads -p "${app// /-}.zip" -D "$check" && ditto -x -k "$check/${app// /-}.zip" "$check/x"
  for f in "$MAIN/$app.app/Contents/Resources/game/"*.js; do cmp -s "$f" "$check/x/$app.app/Contents/Resources/game/$(basename "$f")" || die "the TV's zip doesn't match $(basename "$f")"; done
  for f in "$MAIN/$app.app/Contents/Resources/game/"*.js; do cmp -s "$f" "$HOME/Desktop/Games/$app.app/Contents/Resources/game/$(basename "$f")" || die "the Desktop app doesn't match $(basename "$f")"; done
  echo "   TV zip and Desktop app match"

  git -C "$LAB" merge -q --ff-only main # (the lab's the same as main again, the .app commit too)

  if grep -qE "^WEB_GAMES=\(([^)]* )?$dir[ )]" "$HERE/publish-web.sh"; then echo "== the web"; (cd "$HERE" && ./publish-web.sh "$dir"); fi
  echo "Shipped the $dir lab ($(git -C "$MAIN" rev-parse --short HEAD)). On the mini: click Update Games."
  ;;
app)
  [ -d "$LAB" ] || die "no lab at $LAB"
  grep -q 'build-app.sh lab' "$LAB/tools/build-app.sh" 2>/dev/null || die "$dir's tools/build-app.sh can't build a lab app yet (see dogfight's)"
  mkdir -p "$HOME/Desktop/Games" && (cd "$LAB" && tools/build-app.sh lab "$HOME/Desktop/Games" | tail -1)
  name="$(grep -E "^  \"$dir\|" "$HERE/publish.sh" | grep ' Lab"' | sed -E 's/.*\|(.*)".*/\1/' || true)"
  if [ -n "$name" ]; then # (the TV Mac: zipped up to the games release, checked, and Update Games brings it down)
    zips="$(mktemp -d)"; trap 'rm -rf "$zips"' EXIT
    ditto -c -k --sequesterRsrc --keepParent "$HOME/Desktop/Games/$name.app" "$zips/${name// /-}.zip"
    gh release upload games -R sean-bostic/kids-games-downloads --clobber "$zips/${name// /-}.zip"
    gh release download games -R sean-bostic/kids-games-downloads -p "${name// /-}.zip" -D "$zips/check" && ditto -x -k "$zips/check/${name// /-}.zip" "$zips/x"
    for f in "$HOME/Desktop/Games/$name.app/Contents/Resources/"*/*.js; do cmp -s "$f" "$zips/x/$name.app/${f#"$HOME/Desktop/Games/$name.app/"}" || die "the TV's zip doesn't match $(basename "$f")"; done
    echo "On the TV Mac: $name (click Update Games on the mini)"
  fi
  ;;
web)
  [ -d "$LAB" ] || die "no lab at $LAB"
  grep -qE "^WEB_GAMES=\(([^)]* )?$dir[ )]" "$HERE/publish-web.sh" || die "$dir isn't on the web"
  [ -f "$LAB/src/lab.js" ] || die "$dir has no src/lab.js yet: add one like ../dogfight/src/lab.js first (its own saved settings, rooms and invite link), or the lab page would mix with the real game's"
  (cd "$HERE" && ./publish-web.sh "$dir-lab")
  ;;
*) die "new, serve, web or ship?" ;;
esac
