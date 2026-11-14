cat << 'EOF' > uninstall.sh
#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Please run as root: sudo ./uninstall.sh [--purge-apps]"
    exit 1
fi

PURGE_APPS=0
if [[ "${1:-}" == "--purge-apps" ]]; then
    PURGE_APPS=1
elif [[ -n "${1:-}" ]]; then
    echo "Usage: sudo ./uninstall.sh [--purge-apps]"
    echo "  --purge-apps   Also remove /opt/antigravity, /opt/antigravity-ide, launchers, and icons"
    exit 1
fi

echo "[1/2] Removing APT hook, state files, and CLI helper..."
rm -f /etc/apt/apt.conf.d/99-antigravity-updater
rm -f /usr/local/sbin/antigravity-apt-hook
rm -f /usr/local/bin/agy-ver
rm -rf /var/lib/antigravity-updater

if [[ "$PURGE_APPS" -eq 1 ]]; then
    echo "[2/2] Removing Antigravity App & IDE installations..."
    rm -rf /opt/antigravity /opt/antigravity.bak
    rm -rf /opt/antigravity-ide /opt/antigravity-ide.bak
    rm -f /usr/local/bin/antigravity /usr/local/bin/antigravity-ide
    rm -f /usr/share/applications/antigravity.desktop /usr/share/applications/antigravity-ide.desktop
    rm -f /usr/share/icons/hicolor/256x256/apps/antigravity.png
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    update-desktop-database /usr/share/applications 2>/dev/null || true
else
    echo "[2/2] Keeping /opt/antigravity and /opt/antigravity-ide intact (use --purge-apps to remove)."
fi

echo "Uninstall complete."
EOF
chmod +x uninstall.sh