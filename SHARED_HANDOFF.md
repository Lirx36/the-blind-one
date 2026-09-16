# Shared Development Handoff - The Blind One

Last updated: 2026-09-12 on the PC
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

### 2026-09-12 fresh-place MCP restoration

- Restored the complete Hollow Labyrinth directly into the single connected
  Roblox Studio place `The Blind One` (`placeId 121524238363010`) using Studio
  MCP. No additional Roblox places/worlds were created and Rojo was not used.
- Injected all 24 source scripts: five shared modules, seven server scripts,
  and twelve client scripts. Removed only the fresh template's Baseplate and
  SpawnLocation; the runtime map builder owns the playable environment.
- Fixed an ambiguous Luau statement in `BlindOneController.client.luau` that
  prevented the Blind One client controller from compiling.
- Made Photo Mode tolerate experiences where Roblox's default `PlayerModule`
  is unavailable instead of waiting forever. Free flight now enters, moves,
  and exits correctly in the fresh place.
- Nerfed the survivor flashlight to stop washing out nearby walls: focused
  beam brightness/range/angle are now 3.2/66/42, spill is 0.7/42/76, and the
  near fill is 0.1/5.
- MCP playtest passed with a clean console. Verified map version
  `HollowLabyrinth_2`, 2,716 generated descendants, 317 wall parts, 361
  navigation cells, 81 roof sections, 84 loops, three mechanisms, a valid
  spawn, a live monster humanoid, and survivor jumping disabled.

### 2026-09-11 MCP migration checkpoint

- Replaced the oversized city with a connected 19x19 Hollow Labyrinth. It has
  84 loops, five landmark rooms, three gate mechanisms, a northern exit, and
  maze-aware AI navigation/collision safeguards.
- Added a complete solid roof and ceiling lights across all 361 maze cells.
  Indoor rain and lightning are suppressed by a roof check.
- Photo Mode now freezes the solo AI and provides a free-flying camera:
  `WASD` and mouse to move/look, `Space` or `E` up, `Q` or `Ctrl` down,
  `Shift` for fast movement, and `P` to enter/return.
- Survivors cannot jump. The lock is enforced on both the server and client;
  The Blind One retains its normal movement settings.
- Refined Blind One hearing visualization: near noisy survivors use a blue
  silhouette, distant noisy survivors use a small marker, and the global
  harsh color grade no longer changes the original sense-dot colors.
- Survivor distance fog uses legacy Lighting fog plus a local rolling mist
  bank. Photo Mode removes fog/darkness while keeping cinematic effects.
- Current standalone MCP-ready place:
  `backups/maze-2026-09-11/TheBlindOne-Labyrinth-v2.rbxlx`.
- Previous city backup remains at:
  `backups/city-2026-09-11/TheBlindOne-City.rbxlx`.
- Runtime checks passed for map construction (2,716 instances), all 361 roof
  cells, 84-loop graph validation, fog values 12/92, indoor rain suppression,
  and a forced jump attempt with zero vertical movement.

Do not delete the local repository until this checkpoint is confirmed on
GitHub. The standalone place can be opened without Rojo, while `src/` retains
all readable scripts for MCP restoration and future maintenance.

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

### Settlement V2 scale, façade, and held-flashlight correction

- The user approved the town direction but reported that V1 felt small, the
  building façades were much flatter than the reference game, and the first
  flashlight floated as a huge glowing object instead of sitting in the hand.
- Expanded the generated world from 440x440 to 760x760 studs. V2 now has a
  full-length main street, long cross street, north and south district roads,
  and two parallel avenues, all with their own sidewalks and faded markings.
- Added eleven outer-district buildings, bringing the town to multiple distinct
  blocks: power station, water works, telephone exchange, grocery, cinema, fire
  station, two residence blocks, foundry, bus depot, and church. Added more
  streetlights, utility poles/wires, cars, reflective puddles, and boundary
  vegetation throughout the expanded area.
- Spread survivor spawn, final perimeter gate, all three mechanisms, patrol
  nodes, and throwable rocks across the expanded town so the extra scale is
  part of the actual objective route instead of empty scenery.
- Upgraded every generated façade with window sills, vertical/horizontal metal
  mullions, deeper framing, nine-strip rain awnings, and additional roof detail.
  Added two proper glass storefronts with lit interiors, shelves, framed panels,
  and physical `OPEN ALL NIGHT` posters to approach the reference's layered
  background-building look without relying on uploaded marketplace assets.
- Rebuilt the flashlight around the last proven lantern hand-tracking logic.
  The pivot now follows the actual right hand, falls back to a safe camera-hand
  position only for unusual avatars, lowers with the hand when looking down,
  and uses direct movement bob/roll without sideways lag. The correctly scaled
  model has a rubber grip, metal barrel, tail cap, expanded head, bezel, glass
  lens, switch, and six grip ribs. The lens is no longer Neon, preventing the
  giant white bloom disc seen in V1.
- The narrow shadow-casting hotspot and softer spill now originate from the held
  lens and aim along the full camera look vector, so illumination follows the
  crosshair vertically and horizontally.
- GitHub had no incoming laptop changes. Rojo build and `git diff --check`
  passed, producing `build/the-blind-one-town-v2-test.rbxlx`; the correct Rojo
  server remained live on port 34872.

### Flashlight beam-direction hotfix

- V2 testing showed the beam illuminating the left wall while the player looked
  forward. Root cause: the SpotLights were children of the cylindrical lens;
  the 90-degree rotation needed to orient the cylinder also rotated its Roblox
  `Front` face—and therefore both SpotLights—sideways.
- Added a tiny invisible, unrotated `BeamEmitter` at the physical lens and moved
  the focused and spill SpotLights to it. The visible lens keeps its correct
  cylindrical orientation, while illumination now follows the flashlight
  model's true forward axis and camera crosshair.
- The user also noted that V2's fog was effectively invisible against the dark
  horizon. Bumped the map to `HollowSettlement_3`, pulled legacy fog from
  24-158 studs, brightened it to a cold grey, and increased Atmosphere density
  and haze. Nearby flashlight space stays readable while streets and buildings
  now dissolve into a visible grey fog wall like the reference.

## Blindness, global hearing, and rolling fog (2026-09-11)

- Checked both handoff reports, fetched GitHub with no incoming changes, and
  confirmed the correct Rojo server remained connected on port 34872 before
  editing.
- Fixed the player-controlled Blind One being able to see the town normally.
  The generated map is now hidden locally for that role while its collision and
  raycast geometry remain intact, so only the existing close-range surface
  echoes and noise silhouettes reveal useful information. The old local color
  filter, which had actually brightened the world, is now a severe dark
  monochrome grade.
- Removed the distance gate from survivor sound sensing. Any living survivor
  whose noise reaches `MonsterHearingFloor` now creates an echo anywhere in the
  map; silence is the only way to disappear. The through-wall BillboardGui cap
  was raised to 100,000 studs so rendering cannot reintroduce a practical range.
- Reduced the survivor echo icon from 68x108 to 40x64 pixels and reduced its
  outline thickness, keeping faraway signals informative rather than huge.
- Added `Fog.client.luau`: twelve pooled, camera-relative ground fog banks use a
  built-in Roblox smoke texture to create actual drifting street-level fog for
  survivors instead of relying on a uniform grey Atmosphere wash. Fog clears
  immediately for Blind One POV and Photo Mode.
- Bumped the generated map to `HollowSettlement_4` and reduced the broad
  Atmosphere density/haze so the new rolling banks provide depth without making
  every building a flat grey silhouette.
- Rojo build and `git diff --check` passed, producing
  `build/the-blind-one-hearing-fog-test.rbxlx`.

## Blind One V4 Roblox comparison preview (2026-09-12)

- Preserved `assets/blind-one-analog/v4/TheBlindOne_V4_Detail.blend`
  byte-for-byte. Its SHA-256 is
  `8CB9C6F007408BA9615681B041582B06F5D4FFD059B00A24267D210AAC044A63`.
- Created separate optimized outputs:
  `TheBlindOne_V4_RobloxPreview.blend`, `.glb`, and `.json`. The static
  comparison contains 26 mesh pieces and 252,316 triangles total; no piece is
  above 16,920 triangles.
- Inserted the comparison through Roblox Studio MCP into the existing main
  place only (`placeId: 121524238363010`) at
  `Workspace.BlindOneV4ComparisonPreview`, positioned at `(350, 0, 0)` with a
  labeled review pedestal and neutral review lights. The camera and Studio
  selection point to the preview. No playtest was started.
- This is a static appearance comparison made with session-scoped DataModel
  mesh content because this Studio build reports that `CreateAssetAsync` is not
  available yet. It is not the live rig, does not replace the current monster,
  and has no collisions. Rigging and the final persistent asset import remain
  gated on the user's visual approval.
- User verdict: the Blender execution looks really good, but the character
  design itself does not yet hit the intended direction. Preserve V4 and its
  exports as a finished concept/reference. Do not rig, replace the live monster,
  or delete this version unless the user later changes direction.

### V4 gameplay promotion update (2026-09-13)

- The user later selected the existing V4 Studio character as the gameplay
  Blind One.
- The main place now contains `ServerStorage.BlindOneV4Template`, a clean copy
  of all 26 V4 mesh pieces aligned to the monster root. Both the solo AI and the
  player-controlled Blind One receive this appearance through
  `ServerScriptService.MonsterAppearance`.
- The original comparison model and review pedestal remain untouched at
  `Workspace.BlindOneV4ComparisonPreview`.
- The previous native appearance remains as a runtime fallback and is backed up
  at `ServerStorage.MonsterAppearanceLegacyNativeBackup`.
- No playtest was started; the user remains the gameplay tester.

### V4 root-alignment correction (2026-09-13)

- The persistent GLB import used a feet-level scene pivot, which placed the
  visual 3.9 studs above `HumanoidRootPart`. Lowered every gameplay template
  mesh by 3.9 studs and recorded that offset in the import manifest.
- Photo Mode intentionally freezes the AI Blind One while active; normal AI
  movement resumes after leaving Photo Mode. No playtest was started.

### Blind One navigation recovery and V4 limp (2026-09-13)

- Maze navigation now follows the exact `MazeLayout` passage graph instead of
  allowing navmesh paths to shave wall corners. Clear next-cell paths skip the
  current cell centre, obstacle hits slide or sidestep, and stalled routes are
  abandoned and recomputed instead of repeatedly pushing into one wall.
- Fixed the V4 animator ignoring the AI's server-provided visual speed and then
  resetting the AI visual motor during the same frame. The imported shell now
  performs a smooth asymmetric limp with body drop and lurch.
- Added independent runtime joints for both sleeves, the long robe and the
  lower exposed mesh group. They counter-swing and drag during the limp rather
  than remaining frozen while the entire character glides.
- No playtest was started; the user remains the gameplay tester.

### Charcoal survivor fog pass (2026-09-13)

- Shifted the maze distance fog from cold grey `(92,100,103)` to near-black
  charcoal `(22,27,29)` without changing its 12-92 stud depth range.
- Darkened the moving ground banks to charcoal/black and heavily reduced their
  self-emission, while allowing nearby lamps to catch their edges slightly.
- Blind One and Photo Mode fog exceptions remain unchanged. No playtest was
  started; the user remains the gameplay tester.

### V4 Play-client visibility hotfix (2026-09-13)

- A Play-session report confirmed that the V4 Blind One was absent in Photo
  Mode. Inspection found local `MeshContent` on all V4 pieces but blank
  `MeshId` values, so the MCP-created Edit-mode preview cannot replicate as a
  persistent mesh asset to Play clients.
- `MonsterAppearance` now checks the template for at least one persistent mesh
  ID before cloning it. Until the GLB is imported and published through
  Studio, both AI and player-controlled Blind Ones use the existing visible
  native appearance instead of an invisible V4 shell.
- The V4 preview, template, Blender source, and GLB remain preserved. No
  playtest was started; the user remains the gameplay tester.

### V4 persistent Studio import completed (2026-09-13)

- The user imported `TheBlindOne_V4_RobloxPreview.glb` through Studio with
  **Upload to Roblox** enabled. All 26 MeshParts now have persistent Roblox
  mesh IDs and pass `MonsterAppearance`'s Play-client safety guard.
- Rebuilt `ServerStorage.BlindOneV4Template` from that upload, using the dark
  V4 cloth/binding/skin palette, stained ivory mask, black eye void and cold
  Neon eyes with a restrained local glow. The grey Import Preview colors are
  no longer used by the gameplay template.
- Preserved the raw uploaded hierarchy at
  `ServerStorage.BlindOneV4ImportedSource` and recorded all asset IDs and colors
  in `assets/blind-one-analog/v4/RobloxImportedManifest.json`.
- No playtest was started; the user remains the gameplay tester.

## 2026-09-13 — V5 confirmed and preview archived
User confirmed the repaired V5 limp and limb movement work naturally. Restored 26 imported Motor6D skinning connections and preserved them in MonsterAppearance. Archived the obsolete V4 display from Workspace to ServerStorage. Captured V5 as assets/blind-one-analog/v5-rig-review/BlindOneV5Template.rbxmx and included it in default.project.json. Main and lobby Rojo builds passed; user owns Play testing. Both AI and player roles use shared V5 playback.

### Physical lobby elevators (2026-09-13)

- Added persistent, furnished elevator cabins behind all four private modules and
  the larger public freight opening. The private modules reuse their existing
  metal panels as sliding doors; the public elevator has a new ribbed,
  red-striped freight-door pair.
- Joining or hosting opens the matching doors, disables that opening's blocker,
  and places all queue members into numbered standing slots inside the cabin.
  Leaving returns the player outside, while an empty cabin closes again.
- Starting/departing closes the doors before teleporting. A failed teleport (or
  Studio's non-teleport test path) reopens them so players are not trapped.
- Corrected the persistent model-name mismatch: printed Private 01/02 are on
  the right and Private 03/04 are on the left even though their old model names
  used the opposite numbering. No Play test was started; the user remains the
  gameplay tester.
- Queue members now see a fixed, slightly offset exterior camera framing the
  open elevator and their avatar inside, matching the supplied reference's POV.
  The existing right-side match terminal UI was preserved without redesign.
- Added a separate bottom-centre occupancy strip with circular Roblox headshot
  portraits, empty-slot circles, live capacity, and the public countdown/status.
- Removed the old private elevator's solid fake backing so its sliding panels
  reveal a real cabin. Cabin materials remain bunker-authentic: concrete,
  steel, diamond plate, cold overhead lighting, and restrained queue accents.
- A second legacy `PrivateElevatorFrame_*` slab was discovered in front of the
  new private doors and hidden. Each private opening now uses a purpose-built
  split bunker lift door with diamond-plate panels, recessed steel sections,
  structural ribs, bolts, luminous safety edges, descent stencil, dark
  diamond-plate jambs matching the public lift, and a real animated centre opening.
- Queue cameras now sit squarely on each doorway's centre axis and aim lower at
  the occupants instead of using the earlier side angle. Slot 01 is centred, so
  a solo host is visibly framed inside the cabin. Each cabin light and door
  safety glow uses the exact matching pad/sign color (pink, orange, cyan,
  green, or public red) without a white tint.
- Queue placement now happens immediately as the doors begin opening, then is
  reaffirmed after the animation. An invisible full-height occupant barrier
  closes the open doorway, letting queued players move within the cabin without
  walking back into the lobby; Leave still moves them safely outside.
- Lowered the private top jamb and shortened/re-centred the public freight door
  panels, ribs, and glow strips so neither door clips its overhead sign.
- Public entry now uses a 0.25-second hold-E / gamepad-X ProximityPrompt instead
  of automatic pad touch. Its straight-on camera was moved much farther back to
  frame the entire freight lift.
- Public Bot/Player selection is now one vote per queued player. The live UI
  shows both totals and highlights only the local player's vote. A strict
  majority decides the mode; ties choose Bot or Player randomly at departure.
  When Player wins, the main place's existing `RoleService` randomly selects
  one party member as the Blind One.
- Lobby player speed is now 34 studs/second. Private queue placement was made
  deterministic by zeroing root velocity, setting the root directly, and
  reaffirming placement several times while the door opens. The solo slot was
  brought forward and given a matching-color overhead light so the occupant is
  clearly visible from the fixed camera. No Play test was started; the user
  remains the gameplay tester.
- Private cabins were expanded again to a 28 x 16-stud footprint with deeper side
  walls, ceiling, back wall, rails, floor guides, and status panel, giving
  occupants room to walk and jump. All private and public sliding panels now
  disappear behind dedicated diamond-plate wall pockets when opening, matching
  a real elevator's concealed door travel instead of exposing intersecting
  panels. No Play test was started.
- Private Slot 01 now sits 5.8 studs behind the doorway rather than against the
  occupant barrier, and additional rows use 5-stud spacing. Queue placement now
  explicitly unanchors the root and performs only one quick 0.15-second
  correction, eliminating the previous movement hold. Private cameras were
  pulled back to 40 studs and aimed higher to include the complete overhead
  module header in the same way as the public freight view.
- Added a permanent invisible `LobbySafetySpawn` on the bunker floor and assign
  it as every lobby player's `RespawnLocation`. The menu holding point now uses
  the same safe floor position, eliminating the default-origin void spawn race.
- Repaired a live-Studio-only missing `)` after the 0.15-second placement
  correction. That syntax error had prevented `LobbyServiceV2` from starting,
  which temporarily bypassed both the menu/loading state and server spawn flow;
  the repository source already contained the correct closure.
- The original solid `EastWall` and `WestWall` were discovered crossing the
  private cabins and blocking the camera/avatar line of sight. They are now
  replaced visually and physically by three concrete sections per side, leaving
  real 12-stud openings at both private elevator doors. The wide camera and
  deeper safe occupant slots therefore work without hiding or trapping avatars.
- Two separate invisible side `ContainmentCollider` parts were also crossing
  the same private doorways. They now use matching segmented collision sections,
  leaving the openings genuinely clear. Queue-specific legacy doorway colliders
  disable both collision and queries while their elevator is occupied.
- The public freight elevator now receives the same true-room treatment: its
  old full-width `ForwardWall` and invisible containment wall are segmented
  around a real 50-stud opening. The cabin is enlarged to a 44 x 34-stud
  footprint with extended floor/ceiling/side walls, two rows of freight lights,
  full-depth floor guides, side handrails, diamond-plate wall panels, rear
  structural dividers, and a relocated status panel.
- The obsolete Toolbox `PublicFreightElevator` model that became visible in
  the centre of the new cabin is archived to `ServerStorage` as
  `LegacyPublicFreightElevator`. Public camera distance is reduced from 73 to
  roughly 52 studs, and private camera distance from roughly 46 to 38 studs;
  both retain their higher header-safe aim to reduce dead space without
  cropping the overhead labels.
- Added permanent dark diamond-plate header seals between every door top and
  overhead sign, plus full private upper bulkheads that meet the bunker ceiling.
  Matching-color underside accents keep the structures readable. The public
  freight opening receives a 50-stud-wide lintel that overlaps its doors, sign,
  existing top structure, and cabin ceiling so no background slit remains.
- Corrected all four `WallPipes_*` clusters: the front-wall assets are rotated
  90 degrees, seated flush on the inner East/West wall faces, and assigned one
  clean invisible collision proxy each. Private header seals and upper
  bulkheads are also deepened to overlap the original wall by 0.2 studs,
  eliminating the remaining side-view seam behind each sign.
- Queue entry now force-confirms the entrance panels at their exact open CFrame
  immediately after the normal 0.8-second tween, preventing a camera transition
  from ever leaving the public or private doors visually closed. Rear-wall
  vertical dividers were replaced with horizontal bunker braces so the far end
  cannot be mistaken for a second elevator-door set.


## 2026-09-15 — Bot/rock audit and hunt tuning

- Bot hunt speed is now 17.5 studs/s; investigate remains 14 and wander 9. Player-controlled Blind One remains 19.
- Fixed `humanBlindOne()` treating any loading/non-match survivor as the human monster. Only an active player with Role=BlindOne now replaces the bot. Returning from human mode clears old AI targets/routes.
- Escaped survivors are excluded from hearing targets and catch/dread processing. Loading/escaped players no longer generate movement noise or receive movement speed changes from NoiseService. Movement noise target is capped at the advertised 100.
- Maze fallback no longer rejects its entire route because of furniture in a distant room. It keeps the route; every actual move is still collision-swept, with the existing MonsterDetour local recovery on obstruction.
- Anonymous noise (including rocks) selects investigate rather than inheriting hunt grace from a previous survivor. Reaching a waypoint now clears VisualMoveSpeed for that stopped frame.
- V5 playback rescans bones once per second to handle streamed/late descendants and ignores removed bones. No bind poses, meshes, or animation tracks changed.
- Rocks reject invalid/zero/non-finite directions before consuming inventory. Pickup/throw require a living active survivor; pickup requires a rock still in Workspace. Noncolliding triggers no longer count as impacts. Removed/picked-up rocks cannot produce the delayed fallback sound.
- Rock behavior: first solid impact emits loudness 95 at its location, audible to the bot within the 300-stud cap. It must beat the current target's distance-adjusted score and commitment margin. Continued survivor noise can reclaim attention. Investigate speed 14; six seconds at the heard spot, then patrol if no stronger sound takes over. Missed collision callback has a 4-second, loudness-57 fallback. Human monster receives an anonymous silhouette while the decoy is active, ending 3.2 seconds after impact; human movement is never forced.
- Validation: all 41 main/lobby Luau sources compiled with official Luau CLI; 34 isolated assertions passed using actual extracted AI functions/modules and engine doubles (`tests/run_ai_audit.py`). Main and lobby Rojo builds and `git diff --check` passed. All five edited Studio scripts read back equal to local source; only one active MonsterService exists.
- Applied only to the existing MAIN Studio Edit datamodel. No Play session started, no Roblox publish, no Git push. User performs gameplay tests. Engine doubles do not validate Roblox navmesh/collider geometry, replication, or visual quality; these remain user test items.
- Preserved the other model's existing DeathJumpscare, DeathMenu, LabyrinthAmbience and SilentMovement changes.

## 2026-09-15 — Responsive UI and touch controls

- Added shared `ResponsiveUI` safe-area/resize helpers to both main and lobby projects. UI follows usable ScreenGui bounds and PreferredInput, including window resizing and rotation. Fullscreen effects retain their own coverage.
- HUD reflows the objective, generator progress, noise/stamina and inventory for compact screens. Short landscape hides the decorative heading; keyboard controls panel is hidden on touch/small windows. Photo-mode helper stays Studio/keyboard-only.
- Added touch RUN/CROUCH toggles and LIGHT toggle, plus explicit THROW and PICK UP buttons. Roblox's built-in movement joystick/camera remain in use. Movement uses the same stamina/noise rules as keyboard controls; focus loss, death and blocking menus clear toggles.
- Generator calibration has a compact layout with separated progress, track and action button. Death terminal and elevator queue use bounded scrolling viewports rather than shrinking controls by screen height. Narrow elevator menus reflow capacity/access/voting and use 44+ pixel controls. Lobby title/loading/role banners also fit smaller screens.
- Validation: 43 Luau files compiled; main and lobby Rojo builds passed; 60 isolated resize-callback scenarios passed (`tests/run_ui_layout_checks.py`). This checks layout math with GUI doubles, not actual rendered text/Roblox touch interactions. All 14 deployed script/module copies were read back against local fingerprints.
- Applied to BOTH existing Studio Edit places. No Play session started and no Roblox publish or Git push. User should test phone portrait/landscape, tablet and laptop layouts, touch movement/stamina, light, equip/throw/pickup, calibration, death recovery, and elevator menu scrolling. Real phone testing needs both edited places published first.
- Pre-edit local script copies are under `.tools/responsive-before` (ignored). Existing AI and other model changes preserved.

## 2026-09-15 — User correction: scale menus, no scrolling

- Supersedes the scrolling approach above: user explicitly wants device-sized menus without scrolling. Death terminal and elevator panel now scale uniformly to fit both available width and height. Removed the ScrollPanel helper and all lobby roster scrolling; larger parties use two roster columns so all ten slots fit.
- Restored OBJECTIVE heading and decorative rule on short phone screens. The short banner uses a smaller 19px heading above the mission text; it is no longer hidden by the landscape breakpoint.
- 60 layout scenarios passed with assertions for visible heading, text separation and scaled menu bounds. Changed scripts compile; main/lobby builds pass. Five Studio source copies read back identical to local edits. No Play, publishing or Git push performed. User tests the visual size and readability.

## 2026-09-15 — Raised phone objective and elevator dings

- Phone HUD uses DeviceSafeInsets and places its objective banner 2px below that safe top edge, instead of the extra core-topbar inset plus 16px. Generator progress follows the banner upward. Desktop retains its previous top spacing; heading remains visible. Reveal tween completion reapplies the latest responsive position after rotation.
- Added shared ElevatorChime to both projects using Roblox-owned electronicpingshort audio asset 12221990 (Creator Store: https://create.roblox.com/store/asset/12221990). Moderate volume 0.55; departure pitch 0.85, arrival 1.05; sounds are cleaned up after six seconds.
- Lobby BeginDeparture emits one positional ding after the door-close tween. Actual non-instant closed-to-open transitions also ding, without duplicates from repeated SetOpen calls. Destination ArrivalCinematic emits its arrival ding when Reveal starts opening the doors; existing reveal guard prevents repeats.
- 60 UI layout cases and isolated ding transition/duplicate checks pass; changed scripts compile and both Rojo builds pass. All updated Studio sources read back correctly. No Play started, no audio audition performed, no Roblox publishing or Git push. User tests phone position and sound volume/loading/timing; both places need publishing for live teleport testing.

## 2026-09-15 — Phone lobby banner and near-field flashlight

- The hub-only `THE DESCENT LOBBY` banner now scales uniformly from its 650x76 desktop proportions, with a 0.68 floor for readability. Touch layouts move it into the unused top-center device area instead of leaving it below the tall Core UI inset; tablet and laptop sizes interpolate back to the original dimensions.
- After the first hand-mounted near-light attempt still missed close geometry on PC, the near emitter was separated from the held model and placed 0.18 studs ahead of the camera every frame. It uses a 14-stud, 110-degree near cone plus a restrained 7-stud fill; the original long hotspot/spill remains hand-mounted.
- Desktop HUD now uses no Core UI inset and an 8px top offset, returning the centered objective to the top of the screen. Touch HUD still uses DeviceSafeInsets and its existing 2px safe-top offset.
- The changed Luau files compile and `git diff --check` passes. No Play session, publish, Git commit, or push was performed; user performs visual testing.

## 2026-09-15 — Full-screen casualty blackout

- Fixed the death terminal leaving the Core UI top strip uncovered. `DeathMenu` now restores `ScreenInsets.None` after the responsive helper attaches, so its black backdrop covers the complete viewport while the centered terminal retains responsive scaling.
- The updated source compiles, passes `git diff --check`, and was copied exactly into the existing MAIN Studio Edit place. No Play session, publish, Git commit, or push was performed.

## 2026-09-15 - Player Blind One nearby navigation vision
- Replaced hidden-map / 35 cyan SurfaceEcho dots with visible real geometry. Client black fog begins at 20 studs and ends at 35; local ambient and 35-stud fill light make nearby paths readable. Removed per-frame surface raycast pool.
- Actual survivor bodies remain hidden to the player monster; existing noise-driven sound silhouettes remain. Bot AI and survivor lighting unchanged.
- Role exit restores original fog, ambient, exposure, post-effect enabled states and any temporarily detached Atmosphere. Repeated-frame and repeated-round fixture passed; Luau compile and main Rojo build passed.
- Main Studio BlindOneController synced and source readback verified. No Play test or publishing performed. User should publish main place and test player monster on alt account; visual brightness/range still needs user's device check.

## 2026-09-16 - Player monster jump lock and hunter HUD
- Disabled Blind One jumping through existing shared JumpPolicy on server and client, including automatic mobile jump; survivor restriction retained.
- Reduced player monster vision to 30 studs, black fade starts at 17; fill-light range matches.
- Reused survivor objective banner for persistent red "You are the blind one" title, hunter directive, and sound/catch tip. Same Garamond font, reveal animation, divider, and responsive layout. Survivor progress/inventory remain role-specific.
- All source Luau compilation, both Rojo builds, 60 layout cases, 34 AI checks and isolated jump-policy checks passed. Updated layout test mock for existing lobby GuiService inset usage.
- Five changed scripts synced to main Studio and readback verified. User handles Play and publishing.
