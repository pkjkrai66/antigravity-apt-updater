#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat << 'HELP'
Usage: sudo ./uninstall.sh [OPTIONS]

Removes antigravity-apt-updater hooks, state files, and CLI helpers.

Options:
  --purge-apps  Also remove /opt/antigravity, /opt/antigravity-ide, launchers, and icons
  -h, --help    Show this help message
HELP
}

# Allow non-root users to view help
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        show_help
        exit 0
    fi
done

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Please run as root: sudo ./uninstall.sh [--purge-apps]" >&2
    exit 1
fi

PURGE_APPS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge-apps)
            PURGE_APPS=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

echo "[1/3] Disabling systemd units (if enabled)..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now antigravity-updater.timer 2>/dev/null || true
    rm -f /etc/systemd/system/antigravity-updater.service /etc/systemd/system/antigravity-updater.timer
    systemctl daemon-reload 2>/dev/null || true
fi

echo "[2/3] Removing APT hook, state files, lock files, and CLI helper..."
rm -f /etc/apt/apt.conf.d/99-antigravity-updater
rm -f /usr/local/sbin/antigravity-apt-hook
rm -f /usr/local/bin/agy-ver
rm -rf /var/lib/antigravity-updater
rm -f /run/lock/antigravity-updater.lock /var/lock/antigravity-updater.lock

if [[ "$PURGE_APPS" -eq 1 ]]; then
    echo "[3/3] Purging Antigravity App & IDE installations and desktop integration..."
    
    # Safe validation before recursive deletion of /opt directories
    if [[ -d "/opt/antigravity" ]]; then
        if [[ -f "/opt/antigravity/chrome-sandbox" || -f "/opt/antigravity/resources/app.asar" || -f "/opt/antigravity/antigravity" ]]; then
            rm -rf /opt/antigravity /opt/antigravity.bak
        else
            echo "Warning: /opt/antigravity did not match expected Antigravity structure; skipping deletion." >&2
        fi
    fi

    if [[ -d "/opt/antigravity-ide" ]]; then
        if [[ -f "/opt/antigravity-ide/chrome-sandbox" || -f "/opt/antigravity-ide/resources/app/product.json" || -f "/opt/antigravity-ide/antigravity-ide" ]]; then
            rm -rf /opt/antigravity-ide /opt/antigravity-ide.bak
        else
            echo "Warning: /opt/antigravity-ide did not match expected Antigravity IDE structure; skipping deletion." >&2
        fi
    fi

    rm -f /usr/local/bin/antigravity /usr/local/bin/antigravity-ide
    rm -f /usr/share/applications/antigravity.desktop /usr/share/applications/antigravity-ide.desktop
    rm -f /usr/share/icons/hicolor/256x256/apps/antigravity.png /usr/share/icons/hicolor/256x256/apps/antigravity-ide.png
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    update-desktop-database /usr/share/applications 2>/dev/null || true
else
    echo "[3/3] Keeping /opt/antigravity and /opt/antigravity-ide intact (use --purge-apps to remove)."
fi

echo "Uninstall complete."
