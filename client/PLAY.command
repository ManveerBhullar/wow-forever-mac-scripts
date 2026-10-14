#!/bin/bash
# WoW Forever beta — native macOS client → home TrinityCore server
# Launches the game with the key-store patcher injected (mac replacement
# for the Windows Forever Launcher). Use THIS to start the game, always.
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/World of Warcraft/_classic_beta_" || exit 1
exec env DYLD_INSERT_LIBRARIES="$DIR/forever-patcher.dylib" \
  "./World of Warcraft Beta.app/Contents/MacOS/World of Warcraft" -config WTF/Config.wtf
