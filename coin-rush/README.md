# Coin Rush (Roblox)

A small obby where you jump across platforms over lava, grab spinning coins, and race to the gold finish platform.

The whole game is one script: `src/CoinRush.server.luau`. When the server starts, it builds the map, coins, leaderboard and on-screen timer.

## Play it in 1 minute

1. Open **Roblox Studio** and pick the **Baseplate** template.
2. In **Explorer**, hover **ServerScriptService**, click **+**, and choose **Script**.
3. Delete the `print("Hello world!")` line, paste in everything from `src/CoinRush.server.luau`, and press **Play** (F5).

## What's in it

| Thing | What it does |
|---|---|
| Green platforms (stage 1) | Big platforms with small gaps |
| Blue checkpoint | If you fall after reaching it, you respawn here and your timer keeps running |
| Orange platforms (stage 2) | Smaller platforms with wider gaps |
| Gold finish | +1 Win, +25 coins and your time. You go back to the start after 4 seconds |
| Spinning coins | +1 coin each. They come back after 8 seconds |
| Bright green pads | Speed boost for 3 seconds |
| Lava | Sends you back to the start, or to the checkpoint once you've reached it |

The leaderboard shows **Coins**, **Wins** and **Best** time.

## Make it your own

Change the `CONFIG` table at the top of the script:

- `Seed`: any number gives a different course layout.
- `PlatformsPerStage`: a longer or shorter course.
- `FinishBonus`, `CoinValue`, `CoinRespawnSeconds`, `BoostSpeed`: rewards and difficulty.

Colors are in the `COLORS` table.

## Optional: Rojo

If you use [Rojo](https://rojo.space), `default.project.json` maps the script into ServerScriptService:

```sh
rojo build -o CoinRush.rbxlx   # a place file you can open in Studio
rojo serve                     # live-sync into Studio while you edit
```

Stats reset when you leave the game. Saving them between sessions needs DataStoreService and a published place.
