#!/bin/bash
# Extract maps/vmaps/mmaps using REMOTE casc (empty input dir forces online mode,
# CascLib caches from Blizzard what the extractors need). Outputs go to the server data volume.
set -e
IMG=trinitycore-forever-tc-worldserver:latest
VOL=trinitycore-forever_tc-server-data

docker run --rm -v "$VOL":/data --entrypoint /bin/bash "$IMG" -c '
set -e
mkdir -p /work && cd /work
echo "=== mapextractor (remote casc) ==="
/trinity/bin/mapextractor -i /work -c 1 -r us -o /data
echo "=== vmap4extractor (remote casc) ==="
/trinity/bin/vmap4extractor -c 1 -r us -d /work
echo "=== vmap4assembler ==="
mkdir -p /data/vmaps
/trinity/bin/vmap4assembler Buildings /data/vmaps
echo "=== mmaps_generator ==="
mkdir -p /data/mmaps
/trinity/bin/mmaps_generator --input /data --output /data/mmaps
echo "=== cleanup temp ==="
rm -rf /work/Buildings
echo "=== extraction complete ==="
ls -la /data/
'
