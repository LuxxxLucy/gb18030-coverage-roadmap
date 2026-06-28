#!/usr/bin/env bash
# Build and run helpers for coverage-roadmap.
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
  build)       cargo build --release && (cd app && npm install && npm run build) ;;
  run-web-app) (cd app && npm install && npm run dev) ;;
  roadmap)     cargo run --release -p cli -- roadmap "${2:-l1}" ;;
  curves)
    cargo run --release -p cli -- roadmap l1 > doc/curve_l1.csv
    cargo run --release -p cli -- roadmap-random l1 1 > doc/curve_l1_random.csv
    ;;
  test)        cargo test ;;
  *) echo "usage: ${0##*/} {build | run-web-app | roadmap [l1|full] | curves | test}"; exit 1 ;;
esac
