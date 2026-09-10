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
- Created a non-destructive V2 concept revision at
  `assets/blind-one-analog/concepts/TheBlindOne_AnalogConcept_V2.png` after the
  user requested larger eyes. Only the front-view eye design was intentionally
  changed: the cold-white lights are wider, taller, and more readable while
  remaining narrow and uncanny. The back view and overall character design were
  preserved. Blender geometry and the Roblox-native prototype remain unchanged
  pending the user's approval of V2.

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

### Photo-mode inspection lighting

- Updated `PhotoMode.client.luau` so freezing the solo AI with `P` also enables
  local-only neutral inspection lighting: midday, bright white ambient light,
  no global shadows, no fog, no atmosphere haze, and no post-processing effects.
- Pressing `P` again restores every captured gameplay lighting, atmosphere, and
  post-effect value. Other clients and normal gameplay lighting are unaffected.
- Rojo build and `git diff --check` passed, and the open Studio session received
  the update through the correct Rojo server.

## Analog Blender model pass (2026-09-10)

- The user selected `TheBlindOne_AnalogConcept_V2.png` as the active modeling
  target and requested very close front/back visual parity.
- Built a new, non-destructive Blender model family under
  `assets/blind-one-analog/`; the rejected antler/rib/spike V7 source remains
  untouched in its original folder.
- Editable rigged source:
  `assets/blind-one-analog/blender/TheBlindOne_Analog_V1.blend`.
- Roblox-ready exports:
  `TheBlindOne_Analog_V1.glb` and `TheBlindOne_Analog_V1.fbx` in the same folder.
- The procedural/repeatable source builder is
  `assets/blind-one-analog/blender/build_blind_one_analog_v1.py`; its visible
  launcher is `launch_blind_one_analog_v1.ps1`.
- Rendered review angles are in `assets/blind-one-analog/previews/`: front,
  three-quarter, and back at 1024x1024.
- V1 reproduces the selected concept's tall thin silhouette, crooked body and
  head angle, long arms and narrow hands, ankle-length layered black robe,
  waist sash, wrapped limbs and hood, elongated cracked pale mask, and the
  enlarged controlled cold-white V2 eyes. It contains no blood, gore, antlers,
  exposed ribs, spikes, or teeth.
- The model has a named Roblox-style bone hierarchy and a subtle 36-frame
  unsettling idle action. Preview-only stage, camera, lights, and the V2
  reference image are excluded from GLB/FBX selection exports.
- Blender 4.5.13 completed the source save, GLB/FBX exports, and all three
  renders. Blender was left open with the corrected front render visible for
  the user.
- This is the first Blender approval pass. Do not replace the live Roblox model
  until the user approves this appearance or requests the next visual revision.

### Detailed V2 background rebuild

- Continued the model pass headlessly at the user's request so Blender would not
  take over the mouse or interrupt other PC use.
- Preserved every V1 source/export and created a separate detailed V2 family:
  `TheBlindOne_Analog_V2.blend`, `.glb`, and `.fbx` under
  `assets/blind-one-analog/blender/`.
- Added the reproducible V2 builder
  `build_blind_one_analog_v2.py` and a `launch_blind_one_analog_v2.ps1`
  wrapper. The shared launcher now supports explicit builder, background, and
  wait options while retaining its original V1 defaults.
- Rebuilt the rest silhouette around Concept V2: narrower asymmetrical body,
  forward/left slump, sloped shoulders, long connected sleeves and articulated
  hands, layered high-density robe panels, deep pleats, torn hem fibers, rear
  sash knot/tails, wrapped neck and hood, curved weathered mask, and larger
  cold-white eye cores with a controlled blue-white halo.
- Added new 1280x1280 approval renders for front, three-quarter, side, and back
  under `assets/blind-one-analog/previews/`.
- GLB structure validation passed: glTF 2.0, 32 nodes, 15 meshes, 8 materials,
  one skin, and one embedded 48-frame unsettling idle animation.
- V2 remains an approval asset and is not integrated into the live Roblox model
  yet. Wait for the user's visual approval before replacing the native prototype.

## Cinematic storm and survivor directive (2026-09-10)

- Upgraded the project and runtime map to Future lighting and bumped the generated
  map to `TheHollow_3` so Studio rebuilds it on the next playtest.
- Reworked normal gameplay into a cold, near-monochrome storm: denser layered
  atmosphere, shorter distance fog, softer high-quality shadows, stronger wet
  specular response, restrained bloom, and subtle cinematic depth of field.
- Added pooled client rain and rare cold lightning flashes in
  `Weather.client.luau`. The storm uses no uploaded assets and continuously
  follows the camera without allocating new parts during play.
- Added 34 collisionless glass rain puddles along the procedural routes. They
  catch moon and lantern highlights while leaving AI navigation unchanged.
- Replaced the single objective line with a top-center survivor directive card:
  Garamond `OBJECTIVE` title, analog-horror eyebrow, luminous divider/diamond,
  wrapped objective copy, and a short slide/fade reveal whenever it updates.
  The existing gate-power strip moved below it and the entire directive remains
  hidden from the player-controlled Blind One.
- Revised Studio Photo Mode to remove only darkness and fog: it uses clear
  daylight, bright ambient/exposure, zero legacy fog, and zero Atmosphere
  density/haze. It no longer disables post effects or changes Future lighting,
  shadows, diffuse/specular quality, rain, or wet surfaces. Dread darkness and
  storm lens edges are hidden while Photo Mode is active; the rest of the
  cinematic graphics remain on.
- Rojo build and `git diff --check` passed, producing
  `build/the-blind-one-atmosphere-test.rbxlx`. The active PC Rojo server remains
  the correct repo server on port 34872.

## Hollow Settlement rebuild and flashlight (2026-09-10)

- The first storm playtest was rejected: apart from rain, the old forest
  greybox still looked unchanged, normal gameplay was nearly pitch black, and
  the Blind One's grey silhouette outline revealed him at long range.
- Replaced the entire runtime map in `MapBuilder.server.luau` with
  `HollowSettlement_1`, a 440-stud abandoned wet town designed around the latest
  reference screenshots. The rebuild includes three connected asphalt streets,
  sidewalks and curbs, road markings, a crosswalk, reflective road sheen,
  storm drains, eight named multi-floor brick buildings, windows and lintels,
  lit rooms, locked doors, awnings, store signs, roof parapets and vents,
  drainpipes, a three-level fire escape, utility poles with sagging power lines,
  streetlights, abandoned cars, dumpsters, hydrants, a dead vending machine,
  soaked crates, town trees, and dense boundary vegetation.
- Repositioned and rebuilt all three restoration mechanisms, the survivor spawn,
  24 AI patrol nodes, throwable rocks, and the final sliding escape gate so the
  original objective loop remains functional in the new town. Objective copy
  now refers to the town perimeter instead of the forest road.
- Retuned normal gameplay lighting after diagnosing two sources of the black
  screen: negative underexposure and the HUD dread frame covering the entire
  viewport. Normal play now uses readable predawn overcast light, soft Future
  shadows, cool grey distance fog, restrained desaturation, wet specular response,
  subtle bloom/depth, and heavy clouds. Dread now adds at most a faint pulse and
  can no longer crush the scene to black.
- Removed the `DarkAura` Highlight from `MonsterAppearance.luau` completely.
  Survivors no longer receive an outline that reveals The Blind One. Blind One
  sound-sense silhouettes remain a separate role-only mechanic.
- Replaced the visible lantern behavior with a compact camera-aimed flashlight
  in `Lantern.client.luau`. It has a narrow bright shadow-casting hotspot, wide
  soft spill, near fill, cool neutral color, a dark metal first-person model,
  camera/hand sway, and follows the exact crosshair direction. `F` still toggles
  it; the HUD and first-person arm pose now say/use flashlight.
- Rain was made denser but thinner, shorter, greyer, and more transparent so it
  reads like rain rather than bright cyan debug lines.
- Rojo build and `git diff --check` passed, producing
  `build/the-blind-one-town-test.rbxlx`. GitHub had no incoming laptop commits,
  and the correct Rojo server remained live on port 34872.
