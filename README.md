# Kids games downloads

The newest build of every game lives in the [**games** release](https://github.com/sean-bostic/kids-games-downloads/releases/tag/games).

## On the TV Mac

- **First time:** download `Update-Games.zip` from the release, unzip it, drag **Update Games** to the Desktop, and open it once with right-click → Open (or System Settings → Privacy & Security → Open Anyway).
- **After that:** double-click **Update Games**. It downloads the newest version of every game and replaces the old copies wherever they are (Desktop, Applications or Downloads). New games land on the Desktop. Updated games open with no security prompt.
- Google Chrome must be installed: the games use it to open full screen with sound.

## On the MacBook

```
./publish.sh            # rebuild every game, copy it to the Desktop, upload it
./publish.sh marble     # just one (claw, marble, vehicles, reading)
```

### The lab: try it on the phones first

```
./lab.sh dogfight new      # once: dogfight-lab beside the game (a studio game is found in ~/code/dad-hour-studios/<game>/), a git worktree on its own branch
./lab.sh dogfight serve    # http://<this Mac>:8800/ on home Wi-Fi (hide-elf: 8801, others 8810)
./lab.sh dogfight ship     # the lab's committed work goes everywhere: main, GitHub, Desktop, TV, web
```

Work happens in the lab and gets played there; `ship` merges it into main (tests first), publishes it everywhere, checks the TV zip and the Desktop app match, and leaves the lab level with main for the next round.

To add a game, add a line to `GAMES` in `publish.sh`. `updater/update.sh` is the Update Games app's script. It runs on an old Intel Mac, so it uses plain bash 3.2.

## Credits

Turbo Vehicle Simulator uses the "Airplane" model by Poly by Google (CC-BY 3.0). The other models are CC0 (Kenney, Quaternius).
