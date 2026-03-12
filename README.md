# 🧹 Mac Cleanup

A simple, safe, interactive shell script to free up disk space on macOS — no apps, no installs, just run it.

## What it cleans

| Category | What gets removed |
|---|---|
| **App & System Caches** | Chrome, Firefox, Spotify, JetBrains, Yarn, pip, Telegram, Slack, etc. |
| **Homebrew** | Old downloads and stale formula cache |
| **Xcode** | DerivedData, device support files, simulator caches |
| **Docker** | Stopped containers, dangling images, unused volumes |
| **Telegram** | Locally cached media files (re-downloads if you open them again) |
| **Orphaned node_modules** | `node_modules` folders with no `package.json` nearby |
| **Trash** | Everything in `~/.Trash` |
| **Log files** | Old `.log` files in `~/Library/Logs` |
| **Large file scan** | Lists videos, ISOs, DMGs, archives over 500 MB for manual review |

> Nothing in iCloud, OneDrive, or your Documents/Pictures/Music is touched.
> The large file scan is **display only** — you decide what to delete.

## Usage

### 1. Download

```bash
git clone https://github.com/17-jd/mac-cleanup.git
cd mac-cleanup
chmod +x cleanup.sh
```

### 2. Run (interactive — asks before each step)

```bash
./cleanup.sh
```

### 3. Scan only — see what *would* be deleted, nothing touched

```bash
./cleanup.sh --scan
```

### 4. Auto-confirm everything (no prompts)

```bash
./cleanup.sh --yes
```

## Example output

```
╔══════════════════════════════════════════════════╗
║          🧹  Mac Cleanup Tool  🧹                ║
╚══════════════════════════════════════════════════╝

  Disk: Used 167Gi / 228Gi  |  Free 61Gi
  Mode: Interactive cleanup

────────────────────────────────────────────────────
▶ App & System Caches  ~/Library/Caches
  2.4G  Yarn
  2.4G  JetBrains
  1.0G  ms-playwright
  671M  Homebrew
  Delete all listed caches? [y/N]: y
  ✔ Caches cleared

...

  ✔ Cleanup complete!

  Free space before : 5 GB
  Free space after  : 61 GB
    ≈ 56 GB freed 🎉
```

## Safety

- Asks for confirmation before deleting anything (unless `--yes` is passed)
- Never touches your personal files (Documents, Pictures, Music, Desktop files)
- Never touches cloud-synced folders (OneDrive, iCloud Drive)
- Large files are only **listed**, never auto-deleted
- All deleted data is cache/temp — apps rebuild it automatically

## Requirements

- macOS 12 or later
- Bash (pre-installed on all Macs)
- Optional: Homebrew, Docker (only used if installed)

## License

MIT
