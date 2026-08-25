#!/usr/bin/env bash
# Symlinks this repo's pi/ folder to ~/.pi (Linux/macOS) and sets up the
# toilet-pi supervisor as a systemd --user service.
#
# Usage:
#   ./install.sh              install/update everything
#   ./install.sh --uninstall  remove the toilet-pi supervisor service and exit
#                             (does not touch the ~/.pi symlink or toilet-pi.json)
set -euo pipefail

TOILET_PI_SERVICE_NAME="toilet-pi-supervisor.service"
TOILET_PI_UNIT_PATH="$HOME/.config/systemd/user/$TOILET_PI_SERVICE_NAME"

if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$TOILET_PI_UNIT_PATH" ]; then
    systemctl --user disable --now "$TOILET_PI_SERVICE_NAME" 2>/dev/null || true
    rm -f "$TOILET_PI_UNIT_PATH"
    systemctl --user daemon-reload
    echo "Removed $TOILET_PI_SERVICE_NAME."
  else
    echo "$TOILET_PI_SERVICE_NAME not found. Nothing to do."
  fi
  exit 0
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/pi"
DEST="$HOME/.pi"

if [ ! -d "$SRC" ]; then
  echo "Error: $SRC not found." >&2
  exit 1
fi

if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
  echo "Error: $DEST already exists and is not a symlink." >&2
  echo "Back it up or remove it, then re-run this script." >&2
  exit 1
fi

SKIP_SYMLINK=0
if [ -L "$DEST" ]; then
  CURRENT_TARGET="$(readlink "$DEST")"
  if [ "$CURRENT_TARGET" = "$SRC" ]; then
    echo "$DEST already links to $SRC. Nothing to do."
    SKIP_SYMLINK=1
  else
    echo "Removing existing symlink $DEST -> $CURRENT_TARGET"
    rm "$DEST"
  fi
fi

if [ "$SKIP_SYMLINK" -eq 0 ]; then
  ln -s "$SRC" "$DEST"
  echo "Linked $DEST -> $SRC"
fi

if [ ! -f "$SRC/agent/auth.json" ]; then
  echo
  echo "Note: $SRC/agent/auth.json does not exist yet (it's gitignored)."
  echo "Run 'pi' and use /login for built-in providers, and/or export"
  echo "YUNWU_API_KEY in your shell profile for the yunwu provider in models.json."
fi

# toilet-pi supervisor (systemd --user service) ------------------------------
# toilet-pi (https://github.com/mrexodia/toilet-pi) is loaded as a pi package
# via pi/agent/settings.json's "packages" list; pi itself clones/updates the
# checkout on startup. This step just wires the supervisor process (the thing
# that makes this machine controllable from the toilet-pi web UI) into
# systemd so it survives logoff, reboot, sleep/wake, and crashes.
# See docs/toilet-pi.md.
TOILET_PI_DIR="$HOME/.pi/agent/git/github.com/mrexodia/toilet-pi"

echo
if [ ! -f "$TOILET_PI_DIR/package.json" ]; then
  echo "Note: toilet-pi checkout not found at $TOILET_PI_DIR yet."
  echo "Start 'pi' once so it installs the package from settings.json (or run"
  echo "'pi install https://github.com/mrexodia/toilet-pi' yourself), then re-run"
  echo "install.sh to set up the supervisor service. See docs/toilet-pi.md."
elif ! command -v systemctl >/dev/null 2>&1; then
  echo "Note: systemctl not found — skipping supervisor service setup."
  echo "Run 'npm run supervisor' from $TOILET_PI_DIR manually, or adapt this"
  echo "step for your init system. See docs/toilet-pi.md."
else
  NPM_PATH="$(command -v npm || echo npm)"
  if [ "$NPM_PATH" = "npm" ]; then
    echo "Warning: npm not found on PATH — the supervisor service will fail to start until it is."
  fi

  mkdir -p "$(dirname "$TOILET_PI_UNIT_PATH")"
  cat > "$TOILET_PI_UNIT_PATH" <<EOF
[Unit]
Description=toilet-pi supervisor (remote control for pi sessions)
After=network-online.target graphical-session.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=%h/.pi/agent/git/github.com/mrexodia/toilet-pi
ExecStart=$NPM_PATH run supervisor
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now "$TOILET_PI_SERVICE_NAME"

  echo "Installed and started systemd --user service: $TOILET_PI_SERVICE_NAME"
  echo "Restarts on failure every 5s with unlimited retries (StartLimitIntervalSec=0)."
  echo "Check status with: systemctl --user status $TOILET_PI_SERVICE_NAME"
  echo
  echo "Tip: run 'loginctl enable-linger $USER' (as root, or via sudo) if you want"
  echo "this to keep running even when you're not logged in interactively."

  TOILET_PI_CONFIG_PATH="$HOME/.pi/agent/toilet-pi.json"
  if [ ! -f "$TOILET_PI_CONFIG_PATH" ]; then
    echo
    echo "Note: $TOILET_PI_CONFIG_PATH does not exist yet (it's gitignored)."
    echo "Run 'pi' and use '/toilet-pi setup <machine-url>' to connect this machine."
    echo "See docs/toilet-pi.md."
  fi
fi
