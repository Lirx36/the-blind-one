import bpy
import json
from collections import Counter

character = [obj for obj in bpy.context.scene.objects if obj.get("CharacterAsset", False) and not obj.hide_render]
type_counts = Counter(obj.type for obj in character)
base_vertices = sum(len(obj.data.vertices) for obj in character if obj.type == "MESH")
base_polygons = sum(len(obj.data.polygons) for obj in character if obj.type == "MESH")

depsgraph = bpy.context.evaluated_depsgraph_get()
evaluated_polygons = 0
largest = []
for obj in character:
    if obj.type != "MESH":
        continue
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    count = len(mesh.polygons)
    evaluated_polygons += count
    largest.append((count, obj.name))
    evaluated.to_mesh_clear()

print("V4_ROBLOX_SUMMARY=" + json.dumps({
    "object_count": len(character),
    "types": dict(type_counts),
    "base_vertices": base_vertices,
    "base_polygons": base_polygons,
    "evaluated_mesh_polygons": evaluated_polygons,
    "largest_evaluated_meshes": sorted(largest, reverse=True)[:20],
    "actions": [action.name for action in bpy.data.actions],
    "armatures": [obj.name for obj in bpy.data.objects if obj.type == "ARMATURE"],
}))
