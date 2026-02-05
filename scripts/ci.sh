#!/usr/bin/env bash
set -euo pipefail

swift --version
swift build -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
