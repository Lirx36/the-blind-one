# The Blind One

A co-op horror prototype for Roblox. The monster **cannot see**. It hunts entirely by
sound — your footsteps, sprinting, thrown rocks, doors. Light is free; noise kills.

Working title, rename freely.

## The hook

- Every player has a **noise meter** (0–100). Walking is loud, crouching is near-silent,
  sprinting is a scream. Stand still and you vanish from the monster's world.
- The monster builds a mental map from **noise events**. It investigates the last thing it
  heard, searches, then loses interest and wanders.
- **Throw a rock** to make a loud noise somewhere else and pull it off you.
- A **flashlight** helps *you* and costs you nothing — the genre expectation that light
  draws danger is inverted here.
- Objective: find the **key**, reach the **exit**. Get caught → jumpscare → respawn.

## What's in here

```
src/
  ReplicatedStorage/
    Config.luau                       all tuning numbers
    Remotes.luau                      remote-event registry (require from either side)
  ServerScriptService/
    NoiseService.server.luau          per-player noise meter + positional noise events
    MonsterService.server.luau        the blind AI (wander / investigate / hunt)
    ThrowableService.server.luau      pick up (E) and throw (click) rocks
    GameService.server.luau           key -> exit flow, catch + respawn
    MapBuilder.server.luau            builds a dark maze-building on Play (delete later)
  StarterPlayer/StarterPlayerScripts/
    MoveController.client.luau         walk / crouch / sprint + stamina
    Flashlight.client.luau            camera-follow flashlight (toggle F)
    ThrowController.client.luau       rock pickup / throw input
    Hud.client.luau                   noise + stamina bars, objective, dread overlay
    JumpscareEffect.client.luau       screen slam + shake on death (swap in your assets)
default.project.json                  Rojo mapping
```

## Run it

Same as any Rojo project:

1. `rokit install` (installs Rojo 7.7.0 from `rokit.toml`)
2. `rojo serve` — from a terminal you leave open:
   `& "$env:USERPROFILE\.rokit\bin\rojo.exe" serve`
3. Roblox Studio → Rojo plugin → **Connect** (in edit mode, not a playtest)
4. Press **F5**. The map builds itself; the monster spawns after ~1.5 s at the far end.

Test solo — you vs the monster is the whole loop right now.

## Controls

| Action | Input |
| --- | --- |
| Move | WASD |
| Sprint (hold) | Left Shift — loud, drains stamina |
| Crouch (toggle) | C — slow, near-silent |
| Flashlight | F |
| Pick up rock | E (near one) |
| Throw rock | Left click — makes a loud noise where it lands |

## Tuning (`src/ReplicatedStorage/Config.luau`)

- **Monster too hard / easy:** `MonsterHuntSpeed` (vs `SprintSpeed` 20), `MonsterCatchDistance`,
  `MonsterHearingFloor` (raise = deafer), `MonsterInvestigateTime`.
- **Walking too loud / quiet:** `NoiseWalk`, `NoiseCrouch`, `NoiseCarry` (how far sound travels).
- **Sprint window:** `StaminaMax`, `StaminaDrainPerSec`, `StaminaRegenPerSec`.

## Known rough edges (next passes)

- Monster is a placeholder shape (dark slab + glowing eyes). Custom rig / animation later.
- No sound yet — `JumpscareEffect` and a monster breathing loop need real asset ids.
- Single objective, single monster, no multiplayer downing/revive yet.
- Exit door spams the objective text if you bump it without the key (needs a debounce).
- Monster locomotion is replan-every-0.35 s + straight-line fallback; fine in open rooms,
  can stutter in tight doorways.
