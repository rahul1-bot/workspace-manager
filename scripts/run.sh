#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="${1:-debug}"
case "$MODE" in
  debug|release) ;;
  *)
    echo "Usage: $(basename "$0") [debug|release]" >&2
    exit 2
    ;;
esac

CONFIG="$MODE" "$ROOT_DIR/scripts/build_app_bundle.sh"
open "$ROOT_DIR/Build/WorkspaceManager.app"

