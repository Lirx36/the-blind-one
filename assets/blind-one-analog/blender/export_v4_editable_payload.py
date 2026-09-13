"""Serialize the optimized V4 preview for a local Studio EditableMesh bridge.

This temporary payload is intentionally split one JSON file per mesh so Studio
can fetch and build each MeshPart without a giant script or clipboard transfer.
"""

from __future__ import annotations

from pathlib import Path
import json
import shutil

import bpy


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "v4" / "roblox-payload"

COLORS = {
    "cloth": [25, 28, 31],
    "fold": [9, 9, 11],
    "binding": [45, 39, 33],
    "skin": [31, 30, 29],
    "mask": [143, 132, 108],
    "void": [2, 2, 2],
    "eyes": [174, 213, 248],
    "stitch": [57, 48, 37],
    "crack": [44, 34, 23],
}


def round_float(value: float) -> float:
    return round(float(value), 5)


def to_roblox(vector) -> list[float]:
    return [round_float(vector.x), round_float(vector.z), round_float(-vector.y)]


if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True)

objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.get("V4PreviewOnly", False)]
objects.sort(key=lambda item: item.name)
manifest = {
    "version": 1,
    "name": "BlindOneV4ComparisonPreview",
    "source": "TheBlindOne_V4_Detail.blend",
    "rigged": False,
    "previewOnly": True,
    "currentMonsterUntouched": True,
    "colors": COLORS,
    "objects": [],
}

for index, obj in enumerate(objects, start=1):
    mesh = obj.data
    mesh.calc_loop_triangles()
    world_positions = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    minimum = [min(point[axis] for point in world_positions) for axis in range(3)]
    maximum = [max(point[axis] for point in world_positions) for axis in range(3)]
    center = [(minimum[axis] + maximum[axis]) * 0.5 for axis in range(3)]

    # MeshPart geometry is centered locally; CFrame restores the original
    # position so all separately baked pieces line up perfectly.
    local_positions = []
    for point in world_positions:
        local_positions.extend(to_roblox(point - type(point)(center)))

    triangles = []
    for triangle in mesh.loop_triangles:
        triangles.extend(int(vertex_index) for vertex_index in triangle.vertices)

    file_name = f"mesh-{index:02d}.json"
    category = str(obj.get("RobloxMaterialCategory", "cloth"))
    payload = {
        "n": obj.name,
        "c": category,
        "p": to_roblox(type(world_positions[0])(center)),
        "v": local_positions,
        "t": triangles,
    }
    (OUT / file_name).write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    manifest["objects"].append({
        "file": file_name,
        "name": obj.name,
        "category": category,
        "vertices": len(mesh.vertices),
        "triangles": len(mesh.loop_triangles),
    })
    print(
        f"V4_PAYLOAD | {index:02d}/{len(objects)} {obj.name}: "
        f"{len(mesh.vertices)} vertices, {len(mesh.loop_triangles)} triangles",
        flush=True,
    )

(OUT / "manifest.json").write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")
print("V4_PAYLOAD_REPORT=" + json.dumps({
    "objects": len(objects),
    "vertices": sum(item["vertices"] for item in manifest["objects"]),
    "triangles": sum(item["triangles"] for item in manifest["objects"]),
    "output": str(OUT),
}), flush=True)
