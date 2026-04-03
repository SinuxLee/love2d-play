#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Updating all git submodules..."
git -C "$REPO_ROOT" submodule update --init --recursive --remote

echo "All submodules updated."
git -C "$REPO_ROOT" submodule status
