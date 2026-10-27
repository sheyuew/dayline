#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/cache
cat Store.swift test.swift > .build/tests.swift
swift -module-cache-path .build/cache .build/tests.swift
