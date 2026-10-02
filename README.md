# RConnect

Two-player online co-op for **Fallout Equestria: REMAINS** — see each other, chat, and fight through the wasteland together, including splitting up across separate rooms of the same map.

English (this page) · [简体中文](README.zh-CN.md)

> Current local candidate: **0.2.12-dev (M40)**, deployed 2026-10-03. Smooths enemy and teammate movement under uneven update timing, and restores faint native zebra/alicorn camouflage on the joining side. All 389 automated checks passed; see the [validation record](knowledge/experiments/2026-10-03-m40-presentation.md). Retains M39 combat, shared drops, following, XP-point and checkpoint features. Game v1.02, two players on one machine; stable reconnection, 3+ players, real-network play and other versions remain unverified.
>
> For local co-op, save and close both games, then use **[Start-Coop.bat](Start-Coop.bat)**. It keeps only the processes it starts responsive in the background and preserves each character's saves. This may use more power. The 80-enemy stress test sustained roughly 16–17 FPS for 56 seconds; large encounters remain limited by rendering load.

## Features

- One player **hosts**, the other **joins** (3+ untested). The joining side needs no matching save: the host's world is mirrored to them (world injection — missing enemies spawn, extras are removed, state synced at 5 Hz).
- Players see each other as translucent ghost ponies with floating name tags, walk/run/jump pose animations and **held-weapon display**; remote health shows in the co-op panel.
- Enemy and teammate movement plays continuously between updates. Native zebra/alicorn camouflage keeps its faint outline and its original targeting restrictions.
- In-panel **chat** between both sides.
- Shared ground items: one copy, first collector owns it; container drops can be collected on either side.
- Shared XP-point rewards and checkpoint unlocks; each player saves their own character.
- Optional **Follow teammate** switch in F10, off by default; follows departures from a shared ordinary room.
- Player firing/projectile visuals, alicorn lightning and shield state; native turret, mine and griffon perception of the joining player.
- **Shared exploration** (M31): two-way fog-of-war sharing with an independent toggle on each side; whatever you already received stays when you turn it off.
- **Separate rooms** (M36): each player advances combat in the room they occupy; when you meet up, the host settles the fight with the joining side's reported damage. Empty rooms pause and keep their progress (enemy damage, deaths, broken walls, doors/containers, drops) until someone returns.
- **SATS crash fix** (M37): mirrored enemies provide valid targeting visuals and respect invisibility and targeting restrictions. Native target selection and firing remain available; retired room targets are invalidated.
- **Combat and animation fixes** (M38): restored ghoul collision bounds and resistance data, native player damage calculation for incoming hits, bloodwing flight/rest poses, and immediate door/container updates with confirmation. Weapon aim advances between snapshots.
- Enemy state broadcast by the host every 200 ms with client-side smoothing; story and challenge areas are entered together, host leads map transitions.
- Optional auto-reconnect (test configuration).
- Works alongside RealisticVision (remote vision respects your local vision settings; shared exploration integrates with it).

## Requirements

- Fallout Equestria: REMAINS (1.02) on **both** machines.
- The one-time **ModLoader** game patch on **both** machines — see
  [ModLoader Releases](https://github.com/Eclipse-NotFound/ModLoader/releases) → `Remains-GamePatch`.

## Install

1. Download a published RConnect package from [Releases](../../releases). The local candidate noted above has not been published by this update.
2. Copy the zip's `mods` folder into your game root (next to `pfe.swf`).
3. Restart the game — a translucent RConnect panel appears at the top-right of the main menu.

## Connecting

| Side | `mods/RConnect/release/config.txt` |
|---|---|
| Host | keep defaults (`hostIp` = `127.0.0.1`) |
| Join | set `hostIp` to the host's LAN IP (e.g. `192.168.1.10`) |

Both players then start the game. The host opens the room from the panel; the joiner connects. Port `23456` (configurable) must be allowed through the host's firewall.

> Both sides must update the mod and fully restart the game when versions change. In-game shield damage shows as a blue `S -number`, regular numbers are HP damage.

## Disable / uninstall

Set the mod's switches to `0` in `mods/loader-manifest.txt`, or delete `mods/RConnect`. Closing the game keeps vanilla saves — co-op room progress is per-session.

## Development notes

Sources in `src/`, build/tooling in `tools/`; milestone records (`knowledge/experiments/m*.md`, Chinese) document each feature's verification. The old per-mod patch flow described in the Chinese README is superseded by the shared ModLoader game patch.

## Related mods

[ModLoader](https://github.com/Eclipse-NotFound/ModLoader) ·
[Sandevistan](https://github.com/Eclipse-NotFound/Sandevistan) ·
[MoreSkillsAndWeapons](https://github.com/Eclipse-NotFound/MoreSkillsAndWeapons) ·
[TDFC](https://github.com/Eclipse-NotFound/TDFC) ·
[RealisticVision](https://github.com/Eclipse-NotFound/RealisticVision) ·
[RandomRooms](https://github.com/Eclipse-NotFound/RandomRooms)

> Fan mod project; not affiliated with the game's authors.
