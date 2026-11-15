#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat << 'HELP'
Usage: sudo ./install.sh [OPTIONS]

Zero-dependency installer and APT auto-updater for Google Antigravity & IDE.

Options:
  --hook-mode <upgrade|update>  Run on 'apt upgrade' (DPkg::Post-Invoke, default)
                                or 'apt update' (APT::Update::Post-Invoke)
  --no-sync                     Install hook and CLI without downloading apps now
  --force                       Force re-download during initial sync
  --systemd-timer               Also install and activate daily systemd updater timer
  -h, --help                    Show this help message
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
    echo "Please run as root: sudo ./install.sh [OPTIONS]" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_MODE="upgrade"
RUN_NOW=1
FORCE_SYNC=0
ENABLE_SYSTEMD_TIMER=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hook-mode)
            if [[ $# -lt 2 ]]; then
                echo "Error: --hook-mode requires an argument ('upgrade' or 'update')." >&2
                exit 1
            fi
            HOOK_MODE="$2"
            shift 2
            ;;
        --no-sync)
            RUN_NOW=0
            shift
            ;;
        --force)
            FORCE_SYNC=1
            shift
            ;;
        --systemd-timer)
            ENABLE_SYSTEMD_TIMER=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

# Architecture sanity check
ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
    echo "Warning: Current machine architecture is '$ARCH'. Upstream Antigravity builds are currently x86_64 only." >&2
fi

case "$HOOK_MODE" in
    upgrade)
        APT_DIRECTIVE='DPkg::Post-Invoke'
        ;;
    update)
        APT_DIRECTIVE='APT::Update::Post-Invoke'
        ;;
    *)
        echo "Invalid --hook-mode '$HOOK_MODE'. Use 'upgrade' or 'update'." >&2
        exit 1
        ;;
esac

echo "[1/4] Installing hook and version CLI..."
chmod +x "$SCRIPT_DIR/sbin/antigravity-apt-hook" "$SCRIPT_DIR/bin/agy-ver"
install -Dm755 "$SCRIPT_DIR/sbin/antigravity-apt-hook" /usr/local/sbin/antigravity-apt-hook
install -Dm755 "$SCRIPT_DIR/bin/agy-ver" /usr/local/bin/agy-ver

echo "[2/4] Configuring APT hook ($APT_DIRECTIVE)..."
cat > /etc/apt/apt.conf.d/99-antigravity-updater << EOF
${APT_DIRECTIVE} { "if [ -x /usr/local/sbin/antigravity-apt-hook ]; then /usr/local/sbin/antigravity-apt-hook; fi"; };
EOF
chmod 644 /etc/apt/apt.conf.d/99-antigravity-updater

if [[ "$ENABLE_SYSTEMD_TIMER" -eq 1 ]]; then
    echo "[3/4] Enabling systemd daily timer..."
    if command -v systemctl >/dev/null 2>&1; then
        install -Dm644 "$SCRIPT_DIR/systemd/antigravity-updater.service" /etc/systemd/system/antigravity-updater.service
        install -Dm644 "$SCRIPT_DIR/systemd/antigravity-updater.timer" /etc/systemd/system/antigravity-updater.timer
        systemctl daemon-reload
        systemctl enable --now antigravity-updater.timer
    else
        echo "systemctl not found; skipping systemd timer setup."
    fi
else
    echo "[3/4] Skipping systemd timer setup (use --systemd-timer to enable)."
fi

if [[ "$RUN_NOW" -eq 1 ]]; then
    echo "[4/4] Running initial sync..."
    if [[ "$FORCE_SYNC" -eq 1 ]]; then
        /usr/local/sbin/antigravity-apt-hook --force
    else
        /usr/local/sbin/antigravity-apt-hook
    fi
else
    echo "[4/4] Skipping initial sync (--no-sync)."
fi

echo ""
echo "Installation complete. Run 'agy-ver' anytime to check installed versions."
