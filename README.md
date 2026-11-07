<p align="center"><img src="ui/assets/app_icon.png" width="120" alt="Yomi icon"></p>

<h1 align="center">Yomi</h1>

<p align="center">
  Shows the visual novel you're reading on your Discord profile, and keeps a diary of everything you read.<br>
  A Windows tray app that reads the VN's window title, so most engines work with <b>no setup</b>.
</p>

<p align="center"><sub>Yomi (読み) is a fork of <a href="https://github.com/lennmoe/shiori">Shiori</a> by len, under the MIT license.</sub></p>

## What's new compared to Shiori

| | |
|---|---|
| **Reading goals** | Hours this year, hours this month and VNs finished this year, with progress bars and an "on track" hint above the reading calendar. Set them in *Settings → Reading goals*. |
| **Characters read** | Turn on *Settings → Characters read*, run a text hooker (Textractor with its *Copy to Clipboard* extension, LunaTranslator…) and each line counts. Every VN page shows the total, today's count and your speed per hour. Only the count is saved, never the text. |
| **Notes** | Jot down thoughts, lines you liked or where you stopped, on each VN's page (Ctrl+Enter to add). Kept with the VN, included in backups and exports. |
| **Export your history** | *Settings → Your data*: CSV with one line per VN, CSV with one line per VN per day (for pivot tables and charts), or JSON with everything including notes. Never includes your settings or VNDB token. |
| **Safer updates** | Updates are only offered when GitHub provides a SHA-256 checksum, the file comes from this repository's own releases, and its size and checksum match. Anything else is refused. |
| **Fewer crash points** | Removed the avoidable panics in the presence and update code. |
| **Brings your Shiori library** | On first start, Yomi copies your Shiori data (time read, statuses, covers, settings). Shiori itself is left untouched. Shared `.shiorimascot` files still open. |

Everything else from Shiori is still here: chapter and route detection, per-VN Discord privacy, VNDB covers, list sync and wishlist, reading calendar and streaks, screenshots, Steam / Locale Emulator / NTLEA launching, themes, desktop mascots and 10 languages.

## Get started

1. **Download** `yomi_setup.exe` (or the portable `yomi.exe`) from the [latest release](../../releases/latest). No admin rights needed.
2. **Open Discord** (the desktop app), with *Settings → Activity Privacy → Share your detected activities* on.
3. **Start a VN.** It shows up on your profile.

## Setting up your own copy

These steps take about five minutes and are needed once.

1. **Point the app at your repository.** In the project folder run:
   ```
   npm run set-repo -- your-github-name/yomi
   ```
   This sets the update source, the bug-report links and the icon Discord shows. Until you do it, update checks are simply switched off.
2. **(Recommended) Make your own Discord application.** At [discord.com/developers/applications](https://discord.com/developers/applications) create an application named "Yomi", copy its *Application ID*, and put it in `src-tauri/src/config.rs` (`discord_client_id`). Until then Yomi uses Shiori's Discord application, which works but belongs to someone else. Users can also change it in *Settings → Advanced*.
3. **(Optional) Your Discord server.** Put an invite link in `DISCORD_INVITE` in `ui/js/links.js` to show "Join the Discord" buttons. They're hidden while it's empty.
4. **Push to GitHub.** The *Build* workflow in `.github/workflows/build.yml` runs the tests and builds `yomi.exe` and the installer on every push. Download them from the run's *Artifacts*.

### Publishing a release

1. Change the version in `src-tauri/Cargo.toml`, `src-tauri/tauri.conf.json` and `package.json` (all three the same, e.g. `1.0.1`).
2. Commit, then tag and push:
   ```
   git tag v1.0.1
   git push origin v1.0.1
   ```
3. The workflow builds and publishes the release with `yomi.exe` and `yomi_setup.exe`. Installed copies offer the update on their next start.

The workflow refuses to publish if the tag and the version don't match, or if step 1 above wasn't done.

## Where your data is

`%APPDATA%\app.yomi.desktop\`: `config.yaml` (settings), `games\<title>.yaml` (one file per VN: time read, notes, characters), `mascots\`, `backgrounds\` and `cache\`. Screenshots go to `Pictures\Yomi\<VN title>\` unless you pick another folder.

## For developers

Rust with [Tauri](https://tauri.app), and plain HTML, CSS and JavaScript modules with no build step. Needs [Rust](https://rustup.rs), the MSVC build tools and Node.js 20, on Windows 10 or 11.

```
npm install
npm run dev        # run it
npm run build      # yomi.exe and the installer, in src-tauri\target\release
cd src-tauri && cargo test
```

| Added in Yomi | |
|---|---|
| `src-tauri/src/branding.rs` | repository name and Discord icon, in one place |
| `src-tauri/src/chars.rs` | characters-read tracking from the clipboard |
| `src-tauri/src/export.rs` | CSV and JSON export |
| `config.rs` (`add_chars`, `add_note`, `remove_note`) | storing characters and notes, merging them with duplicates |
| `ui/js/pages/game.js`, `library.js`, `settings.js` | notes, characters, goals and export screens |
| `tools/set-repo.mjs` | `npm run set-repo` |

See the [Shiori README](https://github.com/lennmoe/shiori#readme) for a map of the rest of the code.

## Credits

- **[Shiori](https://github.com/lennmoe/shiori)** by len: the app this is built on (MIT).
- **[VNDB](https://vndb.org)**: visual novel data, covers, characters, lengths and list sync. Covers belong to their publishers.
- **AI cutouts**: the optional mascot cutout downloads [anime-seg](https://github.com/SkyTNT/anime-segmentation) by SkyTNT (Apache-2.0) and [ONNX Runtime](https://github.com/microsoft/onnxruntime) by Microsoft (MIT), only after you agree.
- **Flags**: from [osu-resources](https://github.com/ppy/osu-resources) by ppy, under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/).
- **Yearly recap**: the "Wrapped" page is hosted by Shiori's author at wrapped.maia.moe.
