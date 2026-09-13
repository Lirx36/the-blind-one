from pathlib import Path
import bpy, traceback, json
from mathutils import Vector
out=Path(__file__).resolve().parents[1]/'v4'
try:
    bpy.ops.wm.open_mainfile(filepath=str(out/'TheBlindOne_V4_Detail.blend'))
    scene=bpy.context.scene
    camera=scene.camera
    camera.location=(3,-18,8.4)
    camera.rotation_euler=(Vector((-.1,0,8.25))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=3.8
    scene.cycles.samples=48
    scene.render.resolution_x=900
    scene.render.resolution_y=1200
    scene.render.filepath=str(out/'TheBlindOne_V4_closeup.png')
    bpy.ops.render.render(write_still=True)
    (out/'review_status.json').write_text(json.dumps({'status':'awaiting user appearance approval','rigged':False,'game_integrated':False,'source':'preserved V3'},indent=2))
except Exception:
    (out/'closeup_error.txt').write_text(traceback.format_exc())
    raise
