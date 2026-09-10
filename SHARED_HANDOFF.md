# Shared Development Handoff - The Blind One

Last updated: 2026-09-10 on the PC
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

## Removed jumpscare experiment (2026-09-09)

- Replaced the red-flash placeholder with a full-screen kill sequence:
  - generated horror portrait support with zoom, jitter, chromatic split,
    static, vignette, red impact pulses, and blackout;
  - the moderation-safe portrait is palette-compressed into a Luau module and
    reconstructed with `EditableImage`, requiring no upload or asset ID;
  - the old live 3D monster fallback was removed completely;
  - a white-eyed drawn fallback remains only if `EditableImage` is unavailable;
  - Studio-only `J` preview key.
- The original v1 portrait was rejected by Roblox for violent content/gore and
  was removed. Replaced it with the non-graphic, white-eyed, sealed-mask image
  `assets/jumpscare/blind-one-jumpscare-safe-v2.png`.
- `assets/jumpscare/build_embedded_jumpscare.py` generates
  `EmbeddedJumpscareImage.luau` at 384x216 with a 64-color palette. Keep the safe
  PNG as the editable source and rerun the generator after future art changes.
- `Config.JumpscareSound` remains available for a future uploaded stinger.
- Catch events now forward the killer position to the client for reliable
  portrait selection.
- `git diff --check` passed and Rojo 7.7.0 built the project successfully.

### Final decision

The user rejected this experiment and requested complete removal. The client
overlay, `J` preview, image data, source art/generator, remote event, sound config,
and server trigger were removed. Monster catches now go directly to normal Roblox
death and respawn with no custom death screen or jumpscare.

## Analog-horror redesign concept (2026-09-10)

- The user rejected the previous antlered/bark-armored Blind One design and
  requested a simpler analog-horror direction without blood or gore.
- Generated a front/back approval sheet at
  `assets/blind-one-analog/concepts/TheBlindOne_AnalogConcept_V1.png`.
- Concept V1 uses a tall crooked humanoid silhouette, worn dark institutional
  cloth, an elongated pale mask, and two very small controlled white eye lights.
- No Blender geometry or game integration was changed. Do not start the Blender
  rebuild until the user explicitly approves a concept or requests revisions.

## Roblox-native analog prototype (2026-09-10)

- At the user's request, built a test version of Concept V1 entirely from
  Roblox-native Parts, materials, lights, and welds in
  `src/ServerScriptService/MonsterAppearance.luau`; Blender was not used.
- The old `BlindOneRig` / `BlindOneMesh` stored in Studio is now deliberately
  bypassed, so it cannot silently replace the test appearance again.
- Both the solo AI and a player-controlled Blind One share this appearance.
- The new model includes a tall thin silhouette, long robe with front/back
  panels and cloth folds, uneven shoulders, elongated dark hands and fingers,
  layered head wrapping, a two-piece pale mask, closed face seam, and two tiny
  cold-white glowing eyes. It contains no blood, gore, exposed ribs, antlers,
  teeth, spikes, or red wound lighting.
- The visual is marked `Articulated = true`, so the existing jointed limp/idle
  animator drives it instead of treating it as a rigid sliding shell.
- Rojo build succeeded and produced
  `the-blind-one-analog-native-test.rbxlx` in the PC temp directory. Roblox
  Studio was launched with that compiled place for user testing.
- This is still an approval prototype. Keep the Blender rebuild paused until
  the user has tested it and chooses whether Concept V1 is final.

### Stuck-AI fix

- The first user playtest showed the solo AI standing still. Studio's live log
  confirmed the map and monster scripts loaded without a Luau runtime error;
  the movement loop could receive no usable path waypoint and then idle.
- Reduced the collisionless monster's path-planning radius from 3 to 2.25 studs
  and added five-stud waypoint spacing.
- Added direct steering whenever Roblox pathfinding fails or returns a
  zero-length path, plus recovery when the final waypoint is exhausted. The AI
  now keeps patrolling/pursuing while it retries normal paths instead of being
  permanently stuck.
- Rojo build and `git diff --check` passed after the fix. The already-open
  Studio session remains connected to the correct PC Rojo server for retesting.
