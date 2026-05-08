#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

exec /Applications/Xcode.app/Contents/Developer/usr/bin/xed Package.swift
