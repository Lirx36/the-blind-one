"""Create a non-destructive, Roblox-sized V4 comparison export.

Run by opening TheBlindOne_V4_Detail.blend in Blender background mode and
passing this script with --python. The source file is never overwritten.
"""

from __future__ import annotations

from collections import defaultdict
from pathlib import Path
import hashlib
import json
import re

import bpy


ROOT = Path(__file__).resolve().parents[1]
V4_DIR = ROOT / "v4"
SOURCE = V4_DIR / "TheBlindOne_V4_Detail.blend"
OUTPUT_BLEND = V4_DIR / "TheBlindOne_V4_RobloxPreview.blend"
OUTPUT_GLB = V4_DIR / "TheBlindOne_V4_RobloxPreview.glb"
OUTPUT_REPORT = V4_DIR / "TheBlindOne_V4_RobloxPreview.json"

MAX_TRIANGLES = 18_000
CHUNK_TARGET = 14_000


def log(message: str) -> None:
    print("V4_ROBLOX | " + message, flush=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


SOURCE_HASH = sha256(SOURCE)


def select_only(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def safe_name(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_]+", "_", value).strip("_")
    return value[:48] or "Part"


def make_material(name: str, color: tuple[float, float, float, float], roughness: float,
                  emission: tuple[float, float, float, float] | None = None,
                  emission_strength: float = 0.0) -> bpy.types.Material:
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = 0.0
    if emission is not None:
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = emission
        strength_input = shader.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = emission_strength
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    material.diffuse_color = color
    return material


EXPORT_MATERIALS = {
    "cloth": make_material("Roblox_V4_CharcoalCloth", (0.018, 0.020, 0.022, 1.0), 0.96),
    "fold": make_material("Roblox_V4_DeepFolds", (0.006, 0.006, 0.007, 1.0), 0.98),
    "binding": make_material("Roblox_V4_WeatheredBindings", (0.035, 0.030, 0.026, 1.0), 0.94),
    "skin": make_material("Roblox_V4_LeatherySkin", (0.022, 0.021, 0.020, 1.0), 0.98),
    "mask": make_material("Roblox_V4_StainedIvoryMask", (0.39, 0.35, 0.28, 1.0), 0.91),
    "void": make_material("Roblox_V4_EyeSocket", (0.001, 0.001, 0.001, 1.0), 1.0),
    "eyes": make_material(
        "Roblox_V4_PinprickEyes",
        (0.62, 0.72, 0.80, 1.0),
        0.45,
        (0.68, 0.82, 0.96, 1.0),
        2.0,
    ),
    "stitch": make_material("Roblox_V4_WornStitching", (0.055, 0.045, 0.034, 1.0), 0.96),
    "crack": make_material("Roblox_V4_MaskCrevices", (0.055, 0.041, 0.025, 1.0), 0.98),
}


def material_category(obj: bpy.types.Object) -> str:
    names = " ".join(slot.material.name.lower() for slot in obj.material_slots if slot.material)
    object_name = obj.name.lower()
    combined = names + " " + object_name
    if "pinprick" in combined or "eye glow" in combined:
        return "eyes"
    if "socket" in combined or "void" in combined:
        return "void"
    if "fissure" in combined or "crevice" in combined or "crack" in combined:
        return "crack"
    if "stitch" in combined or "thread" in combined or "fibre" in combined:
        return "stitch"
    if "ivory" in combined or "faceplate" in combined or "mask" in combined:
        return "mask"
    if "skin" in combined or "finger" in combined or "palm" in combined or "foot" in combined or "toe" in combined:
        return "skin"
    if "binding" in combined or "sash" in combined or "wrap" in combined:
        return "binding"
    if "fold" in combined:
        return "fold"
    return "cloth"


def replace_material(obj: bpy.types.Object, category: str) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(EXPORT_MATERIALS[category])
    for polygon in obj.data.polygons:
        polygon.material_index = 0


def apply_modifiers(obj: bpy.types.Object) -> list[str]:
    removed = []
    for modifier in list(obj.modifiers):
        if modifier.type in {"SUBSURF", "MULTIRES"}:
            removed.append(modifier.name)
            obj.modifiers.remove(modifier)
            continue
        select_only(obj)
        try:
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        except RuntimeError as error:
            log(f"modifier skipped on {obj.name}: {modifier.name} ({error})")
    return removed


def convert_curve(obj: bpy.types.Object) -> bpy.types.Object:
    obj.data.resolution_u = min(obj.data.resolution_u, 2)
    obj.data.bevel_resolution = 0
    select_only(obj)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def decimate_to_budget(obj: bpy.types.Object) -> tuple[int, int]:
    before = triangle_count(obj)
    if before <= MAX_TRIANGLES:
        return before, before
    ratio = max(0.02, (MAX_TRIANGLES * 0.94) / before)
    modifier = obj.modifiers.new("Roblox triangle budget", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    modifier.use_collapse_triangulate = True
    select_only(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    after = triangle_count(obj)
    return before, after


def join_objects(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    active = objects[0]
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    active.name = name
    active.data.name = name + "_Mesh"
    return active


log("isolating the visible V4 character")
characters = [
    obj for obj in list(bpy.context.scene.objects)
    if obj.get("CharacterAsset", False) and not obj.hide_render
]
character_set = set(characters)
for obj in list(bpy.context.scene.objects):
    if obj not in character_set:
        bpy.data.objects.remove(obj, do_unlink=True)

processed: list[bpy.types.Object] = []
removed_subdivision: dict[str, list[str]] = {}
decimation: dict[str, dict[str, int]] = {}

log(f"optimizing {len(characters)} source objects")
for index, original in enumerate(characters, start=1):
    if original.name not in bpy.context.scene.objects:
        continue
    obj = original
    if obj.type == "CURVE":
        obj = convert_curve(obj)
    if obj.type != "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    removed = apply_modifiers(obj)
    if removed:
        removed_subdivision[obj.name] = removed
    category = material_category(obj)
    replace_material(obj, category)
    obj["RobloxMaterialCategory"] = category
    obj["V4PreviewOnly"] = True
    before, after = decimate_to_budget(obj)
    if before != after:
        decimation[obj.name] = {"before": before, "after": after}
    processed.append(obj)
    if index % 150 == 0:
        log(f"processed {index}/{len(characters)}")

log("combining small details into importer-friendly chunks")
by_category: dict[str, list[bpy.types.Object]] = defaultdict(list)
final_objects: list[bpy.types.Object] = []
for obj in processed:
    tris = triangle_count(obj)
    if tris >= CHUNK_TARGET // 2:
        final_objects.append(obj)
    else:
        by_category[obj["RobloxMaterialCategory"]].append(obj)

for category, objects in sorted(by_category.items()):
    chunks: list[list[bpy.types.Object]] = []
    current: list[bpy.types.Object] = []
    current_triangles = 0
    for obj in sorted(objects, key=triangle_count, reverse=True):
        tris = triangle_count(obj)
        if current and current_triangles + tris > CHUNK_TARGET:
            chunks.append(current)
            current = []
            current_triangles = 0
        current.append(obj)
        current_triangles += tris
    if current:
        chunks.append(current)
    for number, chunk in enumerate(chunks, start=1):
        joined = join_objects(chunk, f"V4_{safe_name(category)}_{number:02d}")
        replace_material(joined, category)
        joined["RobloxMaterialCategory"] = category
        joined["V4PreviewOnly"] = True
        final_objects.append(joined)

root = bpy.data.objects.new("BlindOneV4Preview", None)
bpy.context.collection.objects.link(root)
root["PreviewOnly"] = True
root["SourceSHA256"] = SOURCE_HASH
root["Rigged"] = False
root["ReplacesCurrentMonster"] = False
for obj in final_objects:
    obj.parent = root
    obj["Source"] = "TheBlindOne_V4_Detail.blend"

for obj in final_objects:
    count = triangle_count(obj)
    if count > MAX_TRIANGLES:
        raise RuntimeError(f"{obj.name} still exceeds Roblox budget: {count}")

bpy.context.scene["Status"] = "Optimized static Roblox comparison preview; current monster untouched"
bpy.context.scene["SourceSHA256"] = SOURCE_HASH
bpy.context.scene["Rigged"] = False
bpy.context.scene["PreviewOnly"] = True

log("saving a separate editable preview blend")
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND), copy=True)

log("exporting GLB")
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for obj in final_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_extras=True,
    export_animations=False,
    export_skins=False,
    export_cameras=False,
    export_lights=False,
)

report = {
    "status": "static Roblox comparison preview",
    "source": SOURCE.name,
    "source_sha256": SOURCE_HASH,
    "source_unchanged": sha256(SOURCE) == SOURCE_HASH,
    "replaces_current_monster": False,
    "rigged": False,
    "source_objects": len(characters),
    "export_objects": len(final_objects),
    "total_triangles": sum(triangle_count(obj) for obj in final_objects),
    "max_triangles_per_mesh": max((triangle_count(obj) for obj in final_objects), default=0),
    "mesh_triangles": {
        obj.name: triangle_count(obj)
        for obj in sorted(final_objects, key=lambda item: item.name)
    },
    "removed_subdivision_modifiers": removed_subdivision,
    "decimated_meshes": decimation,
    "materials": sorted(material.name for material in EXPORT_MATERIALS.values()),
    "notes": [
        "This is a visual comparison asset, not the live gameplay rig.",
        "The original V4 Blender file is preserved byte-for-byte.",
        "Procedural Blender shading was replaced with Roblox-export-safe PBR colors; geometric seams, folds and cracks remain.",
        "Rigging and animation transfer happen only after the appearance is approved.",
    ],
}
OUTPUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
log("REPORT=" + json.dumps(report))
