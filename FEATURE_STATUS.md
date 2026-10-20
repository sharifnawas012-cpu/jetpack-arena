# Feature status (honest)
Legend: DONE+TESTED = verified by headless automated run in the sandbox; DONE = implemented, not tested on devices; PARTIAL; NOT DONE.

| Feature | Status |
|---|---|
| Solo vs bots, 6 maps, all weapons, grenades, explosions, respawn, scoring | DONE+TESTED (headless, all maps) |
| Host/join over ENet, lobby, snapshots, client sees fighters/bullets | DONE+TESTED (2 processes, loopback) |
| Host-authoritative damage/deaths/scores/results | DONE |
| LAN auto-discovery (UDP broadcast) + manual IP | DONE, untested on real hotspots |
| Room code, version check, full-room reject, host-quit message | DONE |
| Teams (2 or custom up to 4), FFA, friendly fire, host settings | DONE |
| Unlimited ammo/jetpack/grenades, no-reload, gas zones, gas immunity | DONE |
| Touch controls (sticks, buttons), HUD, off-screen indicators | DONE, never run on a real touchscreen |
| Client movement prediction + interpolation | PARTIAL (simple blend, needs device tuning) |
| Bots | PARTIAL (basic: no pathfinding, rely on jetpack; may get stuck in tight spots) |
| 12 players over Wi-Fi performance | UNTESTED |
| Customizable button positions | PARTIAL (size/opacity only) |
| Smoke grenades | NOT DONE |
| Host migration | NOT DONE |
| Art/audio | Placeholder shapes + generated beeps |
| APK | NOT BUILT here (Android SDK not reachable from sandbox). Use the included GitHub workflow or docs/android_build.md; workflow and export preset are unverified. |


## Update 4 (verified by headless tests + real rendered screenshots in a virtual display)
- Larger animated cartoon soldiers (outline, shading, 4 helmet/hair styles, run/jump/jet/land/shoot/melee/death/spawn animations): DONE (look verified in screenshots; feel on phone untested)
- Weapon art: 9 distinct original silhouettes: DONE
- Bots: fight each other and the player (11 bot-vs-bot kills in 25 s test), seek health/weapons/power-ups, retreat when hurt, dodge rockets/grenades, use gas/smoke/frag, melee: DONE (still no real pathfinding)
- Melee, health packs, 3 power-ups, 4 grenade types, zoom, 8 maps: DONE
- NOT DONE: Capture the Flag, Co-op Survival, crouch, drop-weapon button, dual-wield, control layout editor, character selection screen
