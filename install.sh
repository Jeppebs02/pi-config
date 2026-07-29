#!/usr/bin/env bash
# Symlinks this repo's pi/ folder to ~/.pi (Linux/macOS).
set -euo pipefail

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

if [ -L "$DEST" ]; then
  CURRENT_TARGET="$(readlink "$DEST")"
  if [ "$CURRENT_TARGET" = "$SRC" ]; then
    echo "$DEST already links to $SRC. Nothing to do."
    exit 0
  fi
  echo "Removing existing symlink $DEST -> $CURRENT_TARGET"
  rm "$DEST"
fi

ln -s "$SRC" "$DEST"
echo "Linked $DEST -> $SRC"

if [ ! -f "$SRC/agent/auth.json" ]; then
  echo
  echo "Note: $SRC/agent/auth.json does not exist yet (it's gitignored)."
  echo "Run 'pi' and use /login for built-in providers, and/or export"
  echo "YUNWU_API_KEY in your shell profile for the yunwu provider in models.json."
fi
