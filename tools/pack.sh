#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${1:?Usage: pack.sh <game_name> [output_dir]}"
OUTPUT_DIR="${2:-$REPO_ROOT/dist}"
GAME_DIR="$REPO_ROOT/games/$GAME"

if [ ! -d "$GAME_DIR" ]; then
    echo "Error: game '$GAME' not found at $GAME_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$GAME_DIR/"* "$TMPDIR/"
rm -rf "$TMPDIR/.vscode"

if [ -d "$REPO_ROOT/vendor" ]; then
    mkdir -p "$TMPDIR/vendor"
    for lib in "$REPO_ROOT/vendor"/*/; do
        lib_name=$(basename "$lib")
        [ "$lib_name" = ".gitkeep" ] && continue
        cp -r "$lib" "$TMPDIR/vendor/$lib_name"
        rm -rf "$TMPDIR/vendor/$lib_name/.git"
    done
fi

if [ -d "$REPO_ROOT/shared" ]; then
    cp -r "$REPO_ROOT/shared" "$TMPDIR/shared"
fi

LOVE_FILE="$OUTPUT_DIR/${GAME}.love"
(cd "$TMPDIR" && zip -9 -r "$LOVE_FILE" .)

echo "Packed: $LOVE_FILE"
