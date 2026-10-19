# Jetpack Arena

Original offline 2D jetpack shooter for Android (Godot 4.3, GDScript). Solo vs bots, or up to 12 fighters
(humans + bots) over a phone hotspot / local Wi-Fi. No internet, accounts, ads or servers.

## Get an APK (free, pick one)
**A. GitHub Actions (no installs):** create a free GitHub account, upload this folder as a new repo, open
*Actions -> Build Android APK -> Run workflow*. Download `JetpackArena-apk` (contains `JetpackArena.apk`).
**B. On your PC:** see `docs/android_build.md`.

Install: copy the APK to each phone, open it, allow "Install unknown apps" for your file manager/browser.
Everyone must install the **same version**.

## Play together (hotspot)
1. Host phone: turn on Hotspot. Others join that Wi-Fi (internet not needed).
2. Host: *Host Match* -> set options -> *Create Lobby*. The lobby shows the host IP.
3. Others: *Join Match* -> tap the host in the list, or type the IP -> *Join*.
4. Host taps *Start Match*.

## Test on PC
Open the folder in Godot 4.3 and press F5. Controls: A/D move, W or Shift jetpack, Space jump, mouse aim,
left click shoot, G grenade, Q/E swap, Tab scoreboard. Automated tests: `tests/smoke_solo.tscn`, `tests/net_test.tscn`.

## Tuning
Weapons: `config/weapons.json`. Maps: `scripts/cfg.gd` (`_build_maps`, mirrored half-layouts). Defaults: `default_settings()`.

## Troubleshooting
See `docs/networking_troubleshooting.md`. Status of every feature: `FEATURE_STATUS.md`.
