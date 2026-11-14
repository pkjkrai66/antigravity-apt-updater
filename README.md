cat << 'EOF' > README.md
# antigravity-apt-updater

Zero-dependency installer and APT/`dpkg` auto-updater for **Google Antigravity App** and **Antigravity IDE** on Debian and Ubuntu.

Google Antigravity 2.x distributes Linux builds as portable `.tar.gz` archives rather than `.deb` packages in an APT repository. `antigravity-apt-updater` bridges that gap by hooking into `apt upgrade` (`DPkg::Post-Invoke`), verifying on-disk binary versions directly, atomically swapping `/opt` installations, configuring `chrome-sandbox` permissions, and provisioning system `.desktop` launchers.

## Features

- **Zero External Dependencies:** Uses only standard POSIX/GNU tools pre-installed on every Ubuntu/Debian system (`bash`, `curl`, `tar`, `od`, `dd`, `grep`, `sed`, `awk`). No `python3`, `node`, `asar`, or `jq` required.
- **Direct On-Disk Version Verification:**
  - **Antigravity App:** Parses the 16-byte binary header of `/opt/antigravity/resources/app.asar` via `od` and `dd` to read the root `package.json` `"version"` directly.
  - **Antigravity IDE:** Reads `"ideVersion"` directly from `/opt/antigravity-ide/resources/app/product.json`.
- **Fresh Install & Atomic Upgrade Support:** Installs afresh if `/opt/antigravity` or `/opt/antigravity-ide` is missing, or swaps directories safely (`*.bak`) when upstream publishes a newer version or build ID.
- **Running-Process Protection:** Skips updating an application if its binary is currently running (`pgrep`), preventing mid-session file corruption.
- **Automatic Sandbox & Desktop Integration:** Enforces `root:root` `4755` setuid permissions on `chrome-sandbox`, symlinks `/usr/local/bin/antigravity` and `/usr/local/bin/antigravity-ide`, extracts the 256×256 PNG icon from `app.asar`, and creates `.desktop` launchers in `/usr/share/applications/`.

## Repository Structure

```text
antigravity-apt-updater/
├── bin/
│   └── agy-ver                 # CLI helper to inspect installed versions & build IDs
├── sbin/
│   └── antigravity-apt-hook    # Main installer/updater invoked by APT/dpkg
├── install.sh                  # Installs hook, CLI, APT config, and runs initial sync
├── uninstall.sh                # Removes hook/config (with optional --purge-apps)
├── LICENSE
└── README.md
```

## Installation

```bash
git clone [https://github.com/YOUR_USERNAME/antigravity-apt-updater.git](https://github.com/YOUR_USERNAME/antigravity-apt-updater.git)
cd antigravity-apt-updater
sudo ./install.sh
```

### Installer Options

| Flag | Description |
| :--- | :--- |
| `--hook-mode upgrade` | *(Default)* Attaches to `DPkg::Post-Invoke` so updates run during `sudo apt upgrade`. |
| `--hook-mode update` | Attaches to `APT::Update::Post-Invoke` so updates run during `sudo apt update`. |
| `--no-sync` | Installs the hook, CLI, and APT configuration without downloading tarballs immediately. |

## Usage

### Automatic Updates via APT
Once installed, Antigravity App and Antigravity IDE update automatically alongside your regular system upgrades:

```bash
sudo apt update && sudo apt upgrade
```

### Manual Sync
If no `.deb` upgrades are pending and you want to check for a new Antigravity build immediately:

```bash
sudo /usr/local/sbin/antigravity-apt-hook
```

### Check Installed Versions
Run `agy-ver` as any user to inspect the on-disk versions extracted from `app.asar` and `product.json`:

```bash
agy-ver
```

Example output:
```text
Antigravity App : 2.32.0 (build: 2.32.0-6141816156848128)
Antigravity IDE : 2.7.0 (build: 2.7.0-4507555968450560)
```

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
EOF