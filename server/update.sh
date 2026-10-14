#!/bin/bash
# WoW Forever server updater — pulls advocaite/TrinityCore `forever` branch,
# rebases our local commit, rebuilds the images, and restarts the stack.
# DB migrations apply automatically when worldserver boots.
#
# Usage: ./update.sh [--no-backup]
# Run it while logged OUT of the game (worldserver + bnetserver restart).

set -euo pipefail
cd "$(dirname "$0")"

BACKUP_DIR=~/games/forever-backups
STAMP=$(date +%Y-%m-%d_%H%M)

echo "==> 1/5 Backing up databases to $BACKUP_DIR (skip with --no-backup)"
if [[ "${1:-}" != "--no-backup" ]]; then
    mkdir -p "$BACKUP_DIR"
    for db in auth characters hotfixes world; do
        docker exec tc-database mariadb-dump -uroot -pCHANGE_ME_DB_PASSWORD --single-transaction "$db" \
            | gzip > "$BACKUP_DIR/${db}_${STAMP}.sql.gz"
    done
    echo "    backups: ${BACKUP_DIR}/*_${STAMP}.sql.gz"
else
    echo "    skipped"
fi

echo "==> 2/5 Fetching upstream forever branch"
git fetch --depth 100 origin forever

LOCAL_AHEAD=$(git rev-list --count origin/forever..HEAD)
BEHIND=$(git rev-list --count HEAD..origin/forever)
echo "    local commits: $LOCAL_AHEAD, upstream new commits: $BEHIND"

if [[ "$BEHIND" -eq 0 ]]; then
    echo "==> Already up to date, nothing to do."
    exit 0
fi

echo "==> 3/5 Rebasing local commit(s) onto origin/forever"
if ! git rebase origin/forever; then
    echo
    echo "!!! REBASE CONFLICT — our local patch needs manual merging."
    echo "    Fix conflicts in the marked files, then:"
    echo "      git rebase --continue && docker compose build && docker compose up -d"
    echo "    Or abort and stay on the old version: git rebase --abort"
    exit 1
fi

echo "==> 4/5 Rebuilding worldserver + bnetserver images (this takes a while)"
docker compose build

echo "==> 5/5 Restarting stack"
docker compose up -d

echo
echo "Done. Watching worldserver boot for DB updates (Ctrl-C when bored)..."
sleep 5
docker compose logs -f tc-worldserver 2>/dev/null | grep --line-buffered -m3 -E "database is up-to-date|Halting|ERROR"
echo "Tip: verify with: docker compose logs tc-worldserver | grep -A2 'Updating'"
