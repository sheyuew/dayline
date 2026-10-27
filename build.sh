#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/cache .build/Dayline.app/Contents/MacOS
swiftc -module-cache-path .build/cache Store.swift main.swift -o .build/Dayline.app/Contents/MacOS/Dayline
cp Info.plist .build/Dayline.app/Contents/Info.plist
codesign --force --sign - .build/Dayline.app
codesign --verify .build/Dayline.app
printf 'Built: .build/Dayline.app\n'
