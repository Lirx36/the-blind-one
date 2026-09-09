THE BLIND ONE JUMPSCARE IMAGE

The game no longer requires this image to be uploaded to Roblox.

Source image:
  blind-one-jumpscare-safe-v2.png

Generated runtime data:
  ../../src/StarterPlayer/StarterPlayerScripts/EmbeddedJumpscareImage.luau

The generator downsizes the source to 384x216 and compresses it to a 64-color
palette stored directly in Luau. JumpscareEffect reconstructs it as an
EditableImage when the client starts. This bypasses Asset Manager and cloud
moderation for local development; the old 3D monster fallback is never shown.

After changing the source PNG, regenerate the Luau data with:
  build_embedded_jumpscare.py

If EditableImage is unavailable on a device, the effect uses a simple drawn
white-eyed face so the screen never becomes blank.
