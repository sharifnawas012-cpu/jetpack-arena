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
