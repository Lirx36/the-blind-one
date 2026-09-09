# Shared Development Handoff - The Blind One

Last updated: 2026-09-09 on the PC
Repository: https://github.com/Lirx36/the-blind-one
Branch: `main`

This file is the shared source of truth for work performed from the PC and the
laptop. Before starting work on either computer:

1. Pull the latest `main` branch.
2. Read this file and `PC_HANDOFF_REPORT.md`.
3. Check `git status` before editing.
4. Update this file with completed work, validation results, and next steps.
5. Commit and push the code and this handoff together.

## Current state

The PC pulled the laptop checkpoint and continued with the first two gameplay
priorities from `PC_HANDOFF_REPORT.md`.

### Completed on the PC

- Updated pickup behavior in
  `src/StarterPlayer/StarterPlayerScripts/ThrowController.client.luau`:
  - The pickup target is now selected by a center-camera raycast instead of
    choosing the nearest rock.
  - The outline and `E  ·  PICK UP` prompt appear only when the survivor
    is looking directly at an unobstructed rock within pickup range.
  - The prompt is suppressed when the player already carries
    `Config.MaxThrowables` rocks.
  - Pickup requests now send the rock, camera position, and camera look vector,
    matching the server-side validation added on the laptop.

- Updated `src/StarterPlayer/StarterPlayerScripts/Hud.client.luau`:
  - Removed the rock count from the noise-meter label.
  - Added a separate hotbar-style rock inventory slot beside the noise/stamina
    panel.
  - The slot displays key `1`, a rock icon, and the current `xN` count.
  - Empty inventory is visually dimmed.
  - The slot is hidden from The Blind One.

### Validation on the PC

- Pulled `main`; it was up to date before the PC edits.
- `git diff --check` passed.
- Rojo 7.7.0 built `default.project.json` successfully.
- Rojo serve was started on port 34872.
- The generated place opened in Roblox Studio and the user entered the playtest.

## Next requested work

The user plans to begin the Blender/model pass on 2026-09-10. Start by
inspecting `assets/blind-one-v7/` and the current in-game model integration.
The working estimate is 2-5 hours of agent work because a v7 base already
exists.

Model-pass goals:

1. Improve The Blind One's silhouette, anatomy, and horror readability.
2. Fix overly black front/back surfaces without making lantern light flattering.
3. Replace the oversized plain-white eyes with convincing controlled glow.
4. Keep geometry, materials, textures, bones, and export settings compatible
   with Roblox.
5. Create a proper smooth limp animation instead of sliding.
6. Export versioned FBX/GLB assets without overwriting the only working source.
7. Integrate and test the updated model for both the bot and player-controlled
   Blind One.

## Gameplay backlog after the model pass

1. Pressing `1` equips a rock into the left hand.
2. Give the equipped rock physical follow/sway similar to the lantern.
3. Hide the real rolling rock from Blind One POV while its anonymous survivor
   decoy is visible.
4. Show noisy survivors through walls while their noise is high, then fade them
   when it falls.
5. Prevent Blind One body parts/textures from blocking first-person view.
6. Lower lantern brightness on The Blind One.
7. Confirm the AI bot uses the newest model and appearance path.

## Notes for the next agent

- Do not assume local tool installations transfer between computers.
- Check whether Rojo is already running before making or testing changes.
- Preserve the user's unrelated local edits if the working tree is dirty.
- Do not promise exact parity with generated PNG concepts; Roblox lighting and
  material limits still apply.

## PC jumpscare pass (2026-09-09)

- Replaced the red-flash placeholder with a full-screen kill sequence:
  - generated horror portrait support with zoom, jitter, chromatic split,
    static, vignette, red impact pulses, and blackout;
  - live 3D clone of the killer when no uploaded portrait ID is configured;
  - white-eyed fallback if neither image nor killer model is available;
  - Studio-only `J` preview key.
- The original v1 portrait was rejected by Roblox for violent content/gore and
  was removed. Replaced it with the non-graphic, white-eyed, sealed-mask image
  `assets/jumpscare/blind-one-jumpscare-safe-v2.png`.
- Added `Config.JumpscareImage` and `Config.JumpscareSound`. The image uses the
  experience-local URL `rbxgameasset://Images/blind-one-jumpscare-safe-v2`, so a
  numeric ID is not required. It preloads safely and falls back to 3D if missing.
- Catch events now forward the killer position to the client for reliable
  portrait selection.
- `git diff --check` passed and Rojo 7.7.0 built the project successfully.

### Immediate next step

Stop the playtest, ensure the place is published/connected to the intended
experience, then use Studio's `File > Import` on
`assets/jumpscare/blind-one-jumpscare-safe-v2.png`. The pictured warning rows are
unrelated Toolbox model inventory entries. Restart the playtest and press `J`.
Temporarily set `Config.StudioSafeMode = false` only when testing a real AI kill,
then restore it to `true`.
