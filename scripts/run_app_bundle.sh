#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/build_app_bundle.sh"
open -n "$ROOT_DIR/Build/WorkspaceManager.app"
