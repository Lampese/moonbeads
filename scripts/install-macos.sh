#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if ! command -v moon >/dev/null 2>&1; then
  echo "moon CLI not found. Install MoonBit first."
  echo "https://www.moonbitlang.com/download"
  exit 1
fi

moon update

moon install

moon build --target native --release cmd/moonbead

BIN_DIR="$ROOT_DIR/_build/native/release/build/cmd/moonbead"
if [ -f "$BIN_DIR/moonbead.exe" ]; then
  SRC="$BIN_DIR/moonbead.exe"
elif [ -f "$BIN_DIR/moonbead" ]; then
  SRC="$BIN_DIR/moonbead"
else
  echo "build completed but binary not found at $BIN_DIR"
  exit 1
fi

if [ -w "/opt/homebrew/bin" ]; then
  DEST_DIR="/opt/homebrew/bin"
elif [ -w "/usr/local/bin" ]; then
  DEST_DIR="/usr/local/bin"
else
  DEST_DIR="$HOME/.local/bin"
fi

mkdir -p "$DEST_DIR"
install -m 0755 "$SRC" "$DEST_DIR/moonbead"

echo "installed: $DEST_DIR/moonbead"
case ":$PATH:" in
  *":$DEST_DIR:"*) ;;
  *)
    echo "warning: $DEST_DIR is not in PATH"
    echo "add to PATH: export PATH=\"$DEST_DIR:\$PATH\""
    ;;
esac
