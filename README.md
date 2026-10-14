# wow-forever-mac-scripts

This repo is just collection of the various scripts, configs and etc I used in
setting up trinity core forever locally and getting the mac client to work with
it. The rest of the readme is ai written

## client/

- **`forever-patcher.c`** — the key part. Gets injected into the game binary
  with `DYLD_INSERT_LIBRARIES` and swaps a key in the client's region-group key
  store so it'll talk to my server instead of Blizzard's. It scans memory every
  100ms because the client rebuilds the store during login. The validation is
  strict on purpose — a looser version corrupted memory and crashed character
  select, so don't relax it.
  Build: `cc -shared -fPIC -o forever-patcher.dylib forever-patcher.c`
- **`PLAY.command`** — how I launch the game (injects the dylib).
- **`update-client.sh`** — run this after a client patch. Re-signs the binary
  and checks whether the hardcoded keys still match advocaite's current launcher.
- **`extract-maps.sh`** — pulls maps/vmaps/mmaps for the server.

Other stuff you need that isn't in here: a hosts entry pointing
`trinity.actual.battle.net` at 127.0.0.1, your own CA trusted in Keychain, and
`SET portal "trinity.actual.battle.net"` in the client's WTF/Config.wtf.

## server/

- **`Dockerfile` / `docker-compose.yml`** — the server containers (worldserver
  + bnetserver + MariaDB).
- **`update.sh`** — backs up the DBs, pulls the latest forever branch, rebuilds,
  restarts.
- **`env-dist-configs/`** — my configs. DB password is a placeholder.

No private keys in here — make your own.

Thanks to advocaite and the TrinityCore folks; the key patch idea comes from
advocaite's forever-launcher-linux.py.
