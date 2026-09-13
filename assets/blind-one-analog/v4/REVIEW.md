# V4 detail pass — preserved concept

The user's requested V3 checkpoint is preserved at
`../v3/preserved-2026-09-12/`, including the Blender file, builder and three renders.
The original and preserved Blender file both have SHA-256
`157B6EE2FD7B3041B85F541D83EBBE24991ABF0164C001BCAA427AAC4E11EC83`.

V4 is a separate derivative. Its builder loads only that preserved checkpoint
and writes to this folder. It adds procedural weave, worn surfaces, skin relief,
secondary folds, sewn seams, hem fibres and mask fissures. Renders are actual
Cycles views of the editable mesh, with 96 samples and 1200 x 1600 resolution.

Files: `TheBlindOne_V4_Detail.blend`, front/back/detail PNGs.
Builder: `../blender/detail_blind_one_v4.py`.

The original remains an unrigged Blender appearance study. Its current SHA-256
is `8CB9C6F007408BA9615681B041582B06F5D4FFD059B00A24267D210AAC044A63`.

A separate, non-destructive Roblox comparison derivative is now available:

- `TheBlindOne_V4_RobloxPreview.blend`
- `TheBlindOne_V4_RobloxPreview.glb`
- `TheBlindOne_V4_RobloxPreview.json`

The comparison export has 26 mesh pieces and 252,316 triangles total. No piece
exceeds 16,920 triangles. Procedural Blender materials were replaced with
portable PBR-safe material colors, while geometric folds, seams, fibres and
mask cracks were retained. The source file is unchanged byte-for-byte.

The preview is visible in the main Roblox Studio place as
`Workspace.BlindOneV4ComparisonPreview`, offset to X=350 so it cannot replace or
interfere with the current monster. It is static, non-colliding and clearly
marked preview-only. Its mesh content is DataModel-session content created
through Studio MCP, because direct mesh-asset publishing is unavailable in the
current Studio API build.

The user approved the quality of the Blender work on 2026-09-12. On 2026-09-13,
the user selected the existing V4 Studio character as the gameplay Blind One.
The original `Workspace.BlindOneV4ComparisonPreview` remains untouched, and a
clean 26-piece copy is preserved at `ServerStorage.BlindOneV4Template`.

Play-client inspection then confirmed that these MCP-created pieces have local
`MeshContent` but blank `MeshId` values. They can render in Studio Edit mode but
cannot persist to a Play client. `MonsterAppearance` therefore rejects that
template until it contains real Roblox mesh asset IDs and automatically uses
the visible native Blind One instead. The native appearance is also backed up
at `ServerStorage.MonsterAppearanceLegacyNativeBackup`. Import and publish
`TheBlindOne_V4_RobloxPreview.glb` through Studio before enabling V4 at runtime.

The user completed that Studio import later on 2026-09-13 with **Upload to
Roblox** enabled. All 26 pieces now have persistent asset IDs. The live template
at `ServerStorage.BlindOneV4Template` uses those uploaded meshes, restores the
intended dark cloth, weathered bindings, stained mask and cold glowing eyes,
and is accepted by the runtime guard. The untouched imported hierarchy is kept
at `ServerStorage.BlindOneV4ImportedSource`; its IDs and palette are recorded in
`RobloxImportedManifest.json`.
