# V5 integration status

The main Studio place uses ServerStorage.BlindOneV5Template for both monster roles.
The source upload and V4 template remain in ServerStorage as backups.

Joint repair: restored all 26 imported Motor6D connections from RootPart to the
mesh parts. MonsterAppearance preserves these joints and mounts RootPart to
TemplateRoot through V5SkeletonMount. Do not replace the imported connections
with WeldConstraints: the shared bone hierarchy must remain connected to the
meshes through skinning-enabled joints.

The 17-track playback runs on each client for AI and player monsters. User Play
testing confirmed the arms, hands, legs and limp work naturally after this repair.
No Play test was started by the agent.

The old Workspace.BlindOneV4ComparisonPreview display was archived to
ServerStorage at the user's request. The working V5 template is captured in
BlindOneV5Template.rbxmx and included by default.project.json. Its uploaded
asset IDs still require permission for the owning Roblox experience.
