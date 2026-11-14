cat << 'EOF' > install.sh
#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Please run as root: sudo ./install.sh [--hook-mode upgrade|update] [--no-sync]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_MODE="upgrade"
RUN_NOW=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hook-mode)
            HOOK_MODE="${2:-upgrade}"
            shift 2
            ;;
        --no-sync)
            RUN_NOW=0
            shift
            ;;
        -h|--help)
            echo "Usage: sudo ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --hook-mode <upgrade|update>  Run on 'apt upgrade' (DPkg::Post-Invoke, default)"
            echo "                                or 'apt update' (APT::Update::Post-Invoke)"
            echo "  --no-sync                     Install hook and CLI only without downloading apps now"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

case "$HOOK_MODE" in
    upgrade)
        APT_DIRECTIVE='DPkg::Post-Invoke'
        ;;
    update)
        APT_DIRECTIVE='APT::Update::Post-Invoke'
        ;;
    *)
        echo "Invalid --hook-mode '$HOOK_MODE'. Use 'upgrade' or 'update'."
        exit 1
        ;;
esac

echo "[1/3] Installing hook and version CLI..."
install -Dm755 "$SCRIPT_DIR/sbin/antigravity-apt-hook" /usr/local/sbin/antigravity-apt-hook
install -Dm755 "$SCRIPT_DIR/bin/agy-ver" /usr/local/bin/agy-ver

echo "[2/3] Configuring APT hook ($APT_DIRECTIVE)..."
cat > /etc/apt/apt.conf.d/99-antigravity-updater << EOF
${APT_DIRECTIVE} { "if [ -x /usr/local/sbin/antigravity-apt-hook ]; then /usr/local/sbin/antigravity-apt-hook; fi"; };
EOF
chmod 644 /etc/apt/apt.conf.d/99-antigravity-updater

if [[ "$RUN_NOW" -eq 1 ]]; then
    echo "[3/3] Running initial install/update sync..."
    /usr/local/sbin/antigravity-apt-hook
else
    echo "[3/3] Skipping initial sync (--no-sync)."
fi

echo ""
echo "Installation complete. Run 'agy-ver' anytime to check installed versions."
EOF
chmod +x install.sh