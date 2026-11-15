# antigravity-apt-updater

Zero-dependency installer and APT/`dpkg` auto-updater for **Google Antigravity App** and **Antigravity IDE** on Debian and Ubuntu.

Google Antigravity 2.x distributes Linux builds as portable `.tar.gz` archives rather than `.deb` packages in an APT repository. `antigravity-apt-updater` bridges that gap by hooking into `apt upgrade` (`DPkg::Post-Invoke`) or systemd timers, verifying on-disk binary versions directly, verifying archive integrity, atomically swapping `/opt` installations with automatic rollback, configuring `chrome-sandbox` permissions, and provisioning system `.desktop` launchers and icons.

## Features

- **Zero External Dependencies:** Uses only standard POSIX/GNU tools pre-installed on every Ubuntu/Debian system (`bash`, `curl`, `tar`, `od`, `dd`, `grep`, `sed`, `awk`, `flock`). No `python3`, `node`, `asar`, or `jq` required.
- **Direct On-Disk Version Verification:**
  - **Antigravity App:** Parses the 16-byte binary header of `/opt/antigravity/resources/app.asar` via `od` and `dd` to read the root `package.json` `"version"` directly.
  - **Antigravity IDE:** Reads `"ideVersion"` directly from `/opt/antigravity-ide/resources/app/product.json`.
- **Semantic Versioning & Fresh Install Support:** Installs afresh if missing, uses `sort -V` semantic version checks to prevent accidental downgrades, and upgrades safely when upstream publishes a newer version or build ID.
- **Download Integrity Verification:** Validates minimum size (>10MB), verifies gzip magic bytes (`0x1f 0x8b`), and performs a full `tar -tzf` archive integrity test before touching `/opt`.
- **Atomic Swap with Rollback & Health Check:** Moves existing directory to `.bak`, unpacks the new version, verifies binary executability and `chrome-sandbox` permissions (`4755`), and rolls back immediately if any health check fails.
- **Accurate Running-Process Protection:** Direct `/proc/[0-9]*/exe` inspection ensures updates are skipped only when the binary is actively executing, avoiding TOCTOU race conditions and false positives from text searches.
- **Concurrency Protection & Logging:** Uses advisory file locks (`flock`) to serialize simultaneous APT or manual runs, and logs detailed actions to `/var/log/antigravity-updater.log`.
- **System Desktop & Icon Integration:** Enforces `root:root` `4755` setuid permissions on `chrome-sandbox`, extracts the 256×256 PNG icon from `app.asar`, installs system-wide `.desktop` entries in `/usr/share/applications/`, and updates the GTK icon cache.
- **Flexible Triggers:** Supports `apt upgrade` (`DPkg::Post-Invoke`), `apt update` (`APT::Update::Post-Invoke`), manual sync, and optional daily systemd timers (`antigravity-updater.timer`).

## Repository Structure

```text
antigravity-apt-updater/
├── bin/
│   └── agy-ver                     # CLI helper to inspect installed versions & build IDs
├── sbin/
│   └── antigravity-apt-hook        # Main installer/updater invoked by APT/dpkg/systemd
├── systemd/
│   ├── antigravity-updater.service # Systemd service unit for scheduled execution
│   └── antigravity-updater.timer   # Systemd timer unit for daily updates
├── install.sh                      # Installs hook, CLI, APT config, and runs initial sync
├── uninstall.sh                    # Removes hook/config (with optional --purge-apps)
├── LICENSE
└── README.md
```

## Installation

```bash
git clone https://github.com/pkjkrai66/antigravity-apt-updater.git
cd antigravity-apt-updater
sudo ./install.sh
```

> **Note on APT Hook Configuration:** Running `sudo ./install.sh` automatically creates `/etc/apt/apt.conf.d/99-antigravity-updater` with the following directive (removed automatically by `sudo ./uninstall.sh`):
> ```text
> DPkg::Post-Invoke { "if [ -x /usr/local/sbin/antigravity-apt-hook ]; then /usr/local/sbin/antigravity-apt-hook; fi"; };
> ```
> *(If `--hook-mode update` is passed, `DPkg::Post-Invoke` is replaced with `APT::Update::Post-Invoke`.)*

### Installer Options

| Flag | Description |
| :--- | :--- |
| `--hook-mode upgrade` | *(Default)* Attaches to `DPkg::Post-Invoke` so updates run during `sudo apt upgrade`. |
| `--hook-mode update` | Attaches to `APT::Update::Post-Invoke` so updates run during `sudo apt update`. |
| `--no-sync` | Installs the hook, CLI, and APT configuration without downloading apps immediately. |
| `--force` | Force re-download during the initial sync even if local versions match upstream. |
| `--systemd-timer` | Also installs and activates a daily systemd timer (`antigravity-updater.timer`). |

## Usage

### Automatic Updates via APT
Once installed, Antigravity App and Antigravity IDE update automatically alongside your regular system upgrades:

```bash
sudo apt update && sudo apt upgrade
```

### Manual Sync & Options
You can run the hook manually anytime:

```bash
# Standard check and update
sudo /usr/local/sbin/antigravity-apt-hook

# Dry run / check without downloading or modifying files
sudo /usr/local/sbin/antigravity-apt-hook --dry-run

# Force re-download and reinstall (e.g. to repair a broken install)
sudo /usr/local/sbin/antigravity-apt-hook --force
```

### Check Installed Versions (`agy-ver`)
Run `agy-ver` as any user to inspect the on-disk versions extracted from `app.asar` and `product.json`:

```bash
agy-ver
```

Example human-readable output:
```text
Antigravity App : 2.32.0 (build: 2.32.0-6141816156848128)
Antigravity IDE : 2.7.0 (build: 2.7.0-4507555968450560)
```

JSON output for scripting and CI pipelines:
```bash
agy-ver --json
```

Example JSON output:
```json
{
  "antigravity_app": {
    "installed": true,
    "version": "2.32.0",
    "build": "2.32.0-6141816156848128"
  },
  "antigravity_ide": {
    "installed": true,
    "version": "2.7.0",
    "build": "2.7.0-4507555968450560"
  }
}
```

**Exit Codes:**
- `0`: Both Antigravity App and IDE are installed
- `1`: Only one application is installed
- `2`: Neither application is installed

## Architecture & Troubleshooting

### How Version Detection Works
- **Antigravity App (`/opt/antigravity`):** Electron's `app.asar` begins with a 16-byte little-endian header where bytes `4–7` store `header_size` and bytes `12–15` store `json_size`. `antigravity-apt-hook` and `agy-ver` read those integers with `od -An -t u4 -N 16`, slice the JSON index with `dd`, locate the root `package.json` byte offset, and extract `"version"` directly—avoiding full archive extraction or Node/Python runtimes.
- **Antigravity IDE (`/opt/antigravity-ide`):** Reads `"ideVersion"` directly from `/opt/antigravity-ide/resources/app/product.json` and compares it alongside the CDN build ID cached in `/var/lib/antigravity-updater/antigravity-ide.build`.

### Common Scenarios
- **Update Skipped (`app is running`):** If Antigravity App or Antigravity IDE is open during `sudo apt upgrade`, the hook logs a skip message instead of overwriting active binaries. Close the application and run `sudo /usr/local/sbin/antigravity-apt-hook` to apply the pending update.
- **Chromium SUID Sandbox Errors (`FATAL:setuid_sandbox_host.cc`):** Both binaries require `chrome-sandbox` to be owned by `root:root` with mode `4755` (`-rwsr-xr-x`). The hook enforces this on every install/update; to verify manually, run:
  ```bash
  ls -l /opt/antigravity/chrome-sandbox /opt/antigravity-ide/chrome-sandbox
  ```
- **Desktop Launcher Icon Missing or Stale:** User-local `.desktop` files in `~/.local/share/applications/` override system-wide entries in `/usr/share/applications/`. If an older user-local `.desktop` points to an unpacked `resources/app/...` icon path, remove it or update its `Icon=` key to `/usr/share/icons/hicolor/256x256/apps/antigravity.png` or `antigravity-ide`.
- **Logs:** Review `/var/log/antigravity-updater.log` to inspect history, download statuses, and update events.

## Uninstallation

Remove the APT hook, state tracking files, and `agy-ver` CLI while keeping `/opt/antigravity` and `/opt/antigravity-ide`:

```bash
sudo ./uninstall.sh
```

Remove everything including `/opt/antigravity`, `/opt/antigravity-ide`, `/usr/local/bin` symlinks, `.desktop` files, and icons:

```bash
sudo ./uninstall.sh --purge-apps
```

## License

MIT
