# Networking troubleshooting
- Uses UDP port 47770 (game, ENet) and 47771 (host discovery broadcast).
- Host not listed? Broadcasts are blocked on some hotspots/routers/phones. Type the IP shown in the host lobby.
- Cannot connect: both devices on the same network? Router "AP/client isolation" must be off (hotspots usually fine; public/guest Wi-Fi blocks it). Turn off VPNs and "Private DNS" experiments.
- Mobile data on while on Wi-Fi without internet: Android may route traffic oddly; try turning mobile data off on joiners.
- "Version mismatch": install the same APK everywhere.
- Host leaves: clients see a message and return to the main menu (no host migration).
- Lag: lower Settings -> frame cap to 30, use fewer bots, stay close to the hotspot.
## Real-device test checklist
Host+join with 2, 4, 8, 12 phones; shoot, explosions, respawn, kill limit, host quit, client quit mid-match, wrong room code, no-internet hotspot.
