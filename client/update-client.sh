#!/bin/bash
# Run AFTER Battle.net has patched the game AND the server supports the new build.
# Re-thins + re-signs the binary for dylib injection, then checks the patcher's
# key constants against advocaite's launcher source of truth.
set -euo pipefail
cd "$(dirname "$0")"

APP="World of Warcraft/_classic_beta_/World of Warcraft Beta.app/Contents/MacOS/World of Warcraft"

echo "==> 1/3 Thin to arm64 + ad-hoc re-sign (needed for DYLD injection)"
lipo -thin arm64 "$APP" -o "$APP.arm64" && mv "$APP.arm64" "$APP"
codesign --force --sign - "$APP"
codesign -dv "$APP" 2>&1 | grep -E "architecture|Signature" || true
echo "    (want: arm64, Signature=adhoc)"

echo "==> 2/3 Compare patcher keys with forever-launcher source of truth"
rm -f /tmp/forever-launcher-linux.py
gh release download -R advocaite/foreverlauncher-releases -p "forever-launcher-linux.py" \
    -O /tmp/forever-launcher-linux.py --clobber \
    || { echo "    !! could not fetch launcher source — check keys at github.com/advocaite/foreverlauncher-releases/releases"; }
if [ -s /tmp/forever-launcher-linux.py ]; then
    # our keys live as C byte arrays — pull them out as hex for comparison
    c_key() {  # $1 = array name in forever-patcher.c
        sed -n "/$1\[\]/,/}/p" forever-patcher.c \
            | grep -oE "0x[0-9A-Fa-f]{2}" | sed 's/0x//' \
            | tr -d '\n' | awk '{print tolower($0)}'
    }
    OUR_BLIZZ=$(c_key SLOT8_ORIGINAL)
    OUR_TRINITY=$(c_key NEW_KEY)
    echo "    our Blizzard  key: ${OUR_BLIZZ:0:32}..."
    echo "    our Trinity   key: ${OUR_TRINITY:0:32}..."
    echo "    -- upstream launcher keys (hex found in forever-launcher-linux.py):"
    grep -oiE "[0-9a-f]{32,128}" /tmp/forever-launcher-linux.py | sort -u | head -8
    echo "    Also check the upstream file for how it names the region-group store"
    echo "    (grep -n 'region\|group\|8' /tmp/forever-launcher-linux.py)."
    echo "    If Blizzard's key differs from ours, update SLOT8_ORIGINAL in"
    echo "    forever-patcher.c and rebuild:  cc -shared -fPIC -o forever-patcher.dylib forever-patcher.c"
fi

echo "==> 3/3 Reminder checklist"
cat <<'EOF'
    [ ] server updated first (update.sh) and supports the new build
    [ ] login test: failure "server identity check failed regionGroup=8"
        = patcher not finding/patching the key store -> constants above
    [ ] new zones shipped? re-run extract-maps.sh
EOF
echo "Done. Launch with PLAY.command as always."
