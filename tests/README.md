# Isolated AI regression checks

Run `python tests/run_ai_audit.py` from this repository after placing the official Windows Luau CLI at `.tools/luau/luau.exe`.

The runner uses current production module/function source, with small doubles for Roblox vectors, players, remotes and collision callbacks. It checks target eligibility/commitment, hearing boundaries, hunt and distraction states, full-region patrol, bounded detours, distant-obstacle fallback progress, invalid throws and impact lifetime.

These are isolated logic checks. They do not start Studio Play or validate the real Roblox navmesh, physics, streaming or animation appearance. The user handles gameplay tests.

`python tests/run_ui_layout_checks.py` executes the current resize callbacks against GUI doubles for ten usable viewport sizes per screen. It verifies bounded menu/HUD geometry, calibration label separation, and key button sizes. Actual text rendering, inset behavior, rotation and touch interactions still need device/emulator tests.
