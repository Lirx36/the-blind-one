# PC Handoff Report - The Blind One

Date: 2026-09-09
Repo: https://github.com/Lirx36/the-blind-one.git
Branch: main
Laptop repo path: C:\Users\jesvi\Documents\Codex\2026-09-08\i-m-going-to-stop-here\work\the-blind-one

## What the game is

The Blind One is a Roblox horror prototype built with Rojo. Survivors explore a dark forest / hollow map, manage noise and stamina, use a lantern, collect and throw rocks/balls, and avoid The Blind One. The Blind One is meant to track noise, not normal vision. A player can also become The Blind One, with special limited vision and noise-based outlines.

## Current user vibe / target

The user wants the game to feel scary, readable, and smooth. The Blind One model currently does not meet the visual quality target in-game compared with the generated PNG concepts. Blender rendering / a higher-quality model pass is planned for later on the PC, but game mechanics should continue now.

Big preferences:

- The Blind One looks scarier without lantern lighting, so avoid lighting that washes him out.
- Survivors should not feel like they are blind too; the map was too dark.
- The Blind One should be blind, but still playable.
- Rock / ball mechanics need to feel physical and game-like, not debuggy.
- UI should be cool and readable, not giant debug boxes.

## Latest laptop changes included in this handoff

These changes were made locally on the laptop and are being pushed so the PC can pull them.

### 1. Survivor visibility / map lighting tweak

File: src/ServerScriptService/MapBuilder.server.luau

The map version was bumped from `TheHollow_1` to `TheHollow_2` so Roblox rebuilds the generated map after the lighting changes.

Lighting was made less pitch-black:

- Brightness increased from `0.62` to `0.9`.
- Ambient and outdoor ambient were raised.
- Fog starts farther out and ends farther out.
- Color correction is less dark and less saturated.
- Atmosphere density and haze were reduced.

Intent: the user said survivors could not see anything and it felt like they were The Blind One. This should make the forest readable while keeping the horror mood.

### 2. Rock / ball pickup limit

File: src/ReplicatedStorage/Config.luau

Added:

```luau
MaxThrowables = 4
```

Intent: the user asked for a max of 4 balls.

### 3. Removed infinite test balls

File: src/ServerScriptService/ThrowableService.server.luau

The previous special tester infinite-ball logic was removed. Held balls are now clamped between `0` and `Config.MaxThrowables`.

Intent: the latest request changed direction: max pickup should be 4, and the count should behave like an inventory count.

### 4. Rock / ball texture/material pass

Files:

- src/ServerScriptService/MapBuilder.server.luau
- src/ServerScriptService/ThrowableService.server.luau

Throwable rocks now use `Enum.Material.Rock` instead of Slate, with darker earthy colors and slight randomized size for spawned map rocks.

Intent: user asked to update the rock texture because the ball looked plain.

### 5. Pickup validation now requires looking at the rock

File: src/ServerScriptService/ThrowableService.server.luau

Pickup remote now accepts camera origin and camera look vector and validates:

- Player is not The Blind One.
- Player is within pickup distance.
- Camera origin is close to the player head.
- Camera is pointing tightly at the rock.
- A raycast from the camera actually hits the rock.
- Player is below `MaxThrowables`.

Intent: user complained they could pick up balls without looking at them. Server-side validation now enforces actual look direction, not just distance.

Important next check: the client must send camera origin/look into `Remotes.Pickup:FireServer(...)`. The current diff did not show a content change in `ThrowController.client.luau`, so inspect that file on PC before testing. If it still only sends the rock instance, pickup will fail or not behave as intended.

## Current unfinished / important requests

The user asked for these game fixes before the handoff:

1. Rock pickup should require looking at the rock.
2. Max balls should be 4.
3. Rock texture should look better.
4. Survivors need better visibility.
5. Balls count should move outside the noise meter and look more like an inventory UI.
6. Pressing `1` should equip the rock into the left hand.
7. Equipped rock should stick out and work similarly to lantern physics.
8. Previous session balls lying on the floor should be cleared after server restart.
9. Blind One POV should not show the real rolling ball near the anonymous fake survivor model.
10. Blind One should see noisy survivors through walls while their noise meter is high, then lose them when noise fades.
11. Blind One body textures/parts should not block the player's own view.
12. Blind One needs an actual smooth limp animation, not sliding.
13. Bot should use the updated model, not the old one.
14. Lantern brightness should be lower / less flattering on The Blind One.
15. Add ball outline plus `E - Pick up` text only when the pickup is valid.
16. Add a bottom-left controls UI with actions like `F - Lantern`, styled nicely.

Some of these may already be partially implemented in the current repo. Read the relevant files before editing.

## Files most likely involved next

- `src/StarterPlayer/StarterPlayerScripts/ThrowController.client.luau`
  - Pickup UI.
  - Camera look validation sent to server.
  - Ball outline and `E - Pick up`.
  - Inventory/equip behavior for key `1`.

- `src/ServerScriptService/ThrowableService.server.luau`
  - Server pickup validation.
  - Max ball count.
  - Clearing old session balls.
  - Rock throw behavior.

- `src/StarterPlayer/StarterPlayerScripts/Hud.client.luau`
  - Move ball count outside noise meter.
  - Add controls UI bottom-left.

- `src/StarterPlayer/StarterPlayerScripts/Lantern.client.luau`
  - Use as reference for left-hand held rock behavior.
  - Lantern brightness tuning.

- `src/StarterPlayer/StarterPlayerScripts/BlindOneController.client.luau`
  - Blind One vision.
  - Seeing noisy survivors through walls.
  - Fake survivor visual for thrown rocks.
  - Hide real rolling ball in Blind One POV.

- `src/StarterPlayer/StarterPlayerScripts/BlindOneVisualAnimator.client.luau`
  - Limp animation / visual animation.

- `src/ServerScriptService/MonsterService.server.luau`
  - Bot tracking logic and model use.

- `src/ServerScriptService/MonsterAppearance.luau`
  - Bot appearance / model replacement.

- `assets/blind-one-v7/`
  - Latest higher quality local Blender source/export assets.
  - Contains `.blend`, `.fbx`, `.glb`, previews, and build script.

## Current asset/model state

The in-game model is still visually disappointing to the user. They specifically disliked:

- Too-black front/back surfaces depending on lighting.
- Eyes too large and just white instead of convincingly glowing.
- In-game model looking much worse than PNG concepts.
- Lack of a proper limp animation.

There is a planned PC Blender pass. The user has a stronger PC with i9-12900K, RTX 3070, 32 GB DDR5, SSD/HDD. They may use the PC for Blender rendering and asset refinement later. Do not promise perfect PNG parity; explain Roblox material/lighting limits honestly.

## Rojo / launch notes

User had trouble with Rojo saying `make sure rojo serve is running`. Before making game changes from now on, the user asked: check whether the server is running before changes.

Useful expected workflow:

1. Check the project status / running Rojo server.
2. If needed, start Rojo serve from the repo.
3. Open / launch Roblox Studio play test.
4. Test the specific mechanic.

The current repo is Rojo-based with `default.project.json`.

## Git notes for PC Codex

On the PC:

1. Open the Codex project named `The Blind One`.
2. Pull latest from GitHub.
3. Run `git status` first.
4. Read this report.
5. Inspect the files above before editing.

Do not assume all laptop in-progress behavior is done. The commit containing this report is intended as a checkpoint so the PC has the latest source state.

## Suggested next implementation order

1. Fix `ThrowController.client.luau` so pickup only displays and fires when the player is looking at a valid nearby rock. Send camera origin/look to the server pickup remote.
2. Move ball count out of the noise meter and build a small inventory-style ball UI in `Hud.client.luau`.
3. Add key `1` equip behavior for the rock, using `Lantern.client.luau` as the feel/physics reference.
4. Hide the physical rolling ball from Blind One POV when a fake anonymous survivor is shown.
5. Make noisy survivor outlines visible through walls for Blind One while noise is active.
6. Tune lantern brightness lower.
7. Confirm the bot is using latest intended Blind One model.
8. Smooth/rework limp animation.

## Message to user when PC takes over

Tell the user that the PC has the latest GitHub checkpoint, then start with the rock pickup / inventory fixes unless they ask to switch to Blender.
