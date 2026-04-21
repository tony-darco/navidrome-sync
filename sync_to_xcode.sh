#!/bin/bash
# Copies all iOS source files from navidrome-sync to the Xcode project.
set -e

SRC="/Users/tdarco/Documents/Projects/navidrome-sync/navidrome-ios"
DST="/Users/tdarco/Documents/Projects/navidrome/navidrome-ios/navidrome-ios"

# Use rsync to mirror the entire directory, preserving structure.
# --delete removes files in DST that no longer exist in SRC.
rsync -av --delete \
  --exclude='*navidrome-iosTests/*'\
  --include='*.swift' \
  --include='*.plist' \
  --include='*.json' \
  --include='*/' \
  --exclude='*' \
  "$SRC/" "$DST/"

echo "Done – synced all files from navidrome-sync to Xcode project."
