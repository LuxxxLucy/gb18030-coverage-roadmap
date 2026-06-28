#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Fetch the CJK fonts into the gitignored vendor font dir (idempotent).
./fonts.sh

FONTS=vendor/dual-typst/assets/fonts

# HTML only, emitted as index.html so GitHub Pages serves it at the site root.
# color-scheme=light + the envision style force light mode on dark-OS visitors.
typst compile --root . --font-path "$FONTS" \
    --features html --input target=html --input color-scheme=light \
    main.typ index.html

echo "Built: $(pwd)/index.html"
