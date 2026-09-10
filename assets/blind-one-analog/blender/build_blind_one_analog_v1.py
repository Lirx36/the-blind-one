from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
BLENDER_DIR = ROOT / "blender"
PREVIEW_DIR = ROOT / "previews"
CONCEPT = ROOT / "concepts" / "TheBlindOne_AnalogConcept_V2.png"
BLEND_PATH = BLENDER_DIR / "TheBlindOne_Analog_V1.blend"
GLB_PATH = BLENDER_DIR / "TheBlindOne_Analog_V1.glb"
FBX_PATH = BLENDER_DIR / "TheBlindOne_Analog_V1.fbx"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)


def progress(value: int, message: str) -> None:
    bpy.context.window_manager.progress_update(value)
    print(f"ANALOG BUILD {value:03d}% | {message}")
    try:
        bpy.ops.wm.redraw_timer(type="DRAW_WIN_SWAP", iterations=1)
    except Exception:
        pass


def clear_scene() -> None:
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def textured_material(
    name: str,
    dark: tuple[float, float, float],
    light: tuple[float, float, float],
    roughness: float = 0.88,
    noise_scale: float = 7.0,
    bump_strength: float = 0.28,
    stretch: tuple[float, float, float] = (1.0, 1.0, 1.0),
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*dark, 1.0)
    mat.use_backface_culling = False
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.18
    texcoord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = stretch
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "4D"
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 8.0
    noise.inputs["Roughness"].default_value = 0.78
    noise.inputs["Distortion"].default_value = 0.25
    noise.inputs["W"].default_value = 0.41
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1.0)
    ramp.color_ramp.elements[0].position = 0.23
    ramp.color_ramp.elements[1].color = (*light, 1.0)
    ramp.color_ramp.elements[1].position = 0.77
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = bump_strength
    bump.inputs["Distance"].default_value = 0.11

    links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def flat_material(name: str, color: tuple[float, float, float], roughness: float = 0.8) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def emission_material(name: str, color: tuple[float, float, float], strength: float) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1.0)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.08
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def smooth(obj: bpy.types.Object) -> bpy.types.Object:
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def ellipsoid(name, location, scale, mat, subdivisions=3, surface=0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if surface:
        texture = bpy.data.textures.new(name + "_surface", type="CLOUDS")
        texture.noise_scale = 0.19
        modifier = obj.modifiers.new("Subtle worn surface", "DISPLACE")
        modifier.texture = texture
        modifier.strength = surface
        modifier.mid_level = 0.52
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    return smooth(obj)


def cone_between(name, start, end, radius_start, radius_end, mat, vertices=16, bevel=0.025):
    a = Vector(start)
    b = Vector(end)
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_start,
        radius2=radius_end,
        depth=direction.length,
        location=(a + b) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft worn edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    return smooth(obj)


def box(name, location, scale, mat, rotation=(0.0, 0.0, 0.0), bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft worn edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    return smooth(obj)


def tube(name, points, radius, mat, cyclic=False, resolution=2):
    curve = bpy.data.curves.new(name + "_curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    return smooth(obj)


def ribbon_ring(name, center, radius_x, radius_y, z, height, mat, tilt=0.0, count=48):
    cx, cy = center
    vertices = []
    faces = []
    for index in range(count):
        angle = math.tau * index / count
        wave = math.sin(angle * 3.0 + tilt * 9.0) * 0.018
        lean = math.cos(angle) * tilt
        for side in (-1, 1):
            vertices.append((
                cx + math.cos(angle) * radius_x,
                cy + math.sin(angle) * radius_y,
                z + wave + lean + side * height * 0.5,
            ))
    for index in range(count):
        nxt = (index + 1) % count
        a = index * 2
        b = nxt * 2
        faces.append((a, b, b + 1, a + 1))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    solidify = obj.modifiers.new("Bandage thickness", "SOLIDIFY")
    solidify.thickness = 0.022
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    return obj


def cloth_panel(
    name,
    center_x,
    face_y,
    top_z,
    bottom_z,
    top_width,
    bottom_width,
    mat,
    seed,
    rows=12,
    columns=5,
    warp=0.05,
):
    random.seed(seed)
    vertices = []
    faces = []
    bottom_damage = [random.uniform(0.0, 0.18) for _ in range(columns)]
    for row in range(rows):
        t = row / (rows - 1)
        eased = t * t * (3.0 - 2.0 * t)
        width = top_width + (bottom_width - top_width) * eased
        for column in range(columns):
            u = column / (columns - 1)
            x = center_x + (u - 0.5) * width
            z = top_z + (bottom_z - top_z) * t
            if row == rows - 1:
                z += bottom_damage[column]
            y = face_y + math.sin(t * math.pi * 2.2 + u * 5.5 + seed) * warp
            y += math.sin(u * math.pi * 4.0) * warp * 0.45
            vertices.append((x, y, z))
    for row in range(rows - 1):
        for column in range(columns - 1):
            a = row * columns + column
            b = a + 1
            c = a + columns + 1
            d = a + columns
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    activate(obj)
    solidify = obj.modifiers.new("Cloth thickness", "SOLIDIFY")
    solidify.thickness = 0.035
    solidify.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bevel = obj.modifiers.new("Frayed soft edge", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def cloth_shell(
    name,
    top_z,
    bottom_z,
    top_radius,
    bottom_radius,
    mat,
    seed,
    rings=14,
    sides=40,
    fold_count=10,
    ragged=0.12,
):
    """Rounded irregular garment shell; prevents a boxy Roblox silhouette."""
    random.seed(seed)
    vertices = []
    faces = []
    hem_damage = [random.uniform(0.0, ragged) for _ in range(sides)]
    for ring in range(rings):
        t = ring / (rings - 1)
        eased = t * t * (3.0 - 2.0 * t)
        radius_x = top_radius[0] + (bottom_radius[0] - top_radius[0]) * eased
        radius_y = top_radius[1] + (bottom_radius[1] - top_radius[1]) * eased
        z = top_z + (bottom_z - top_z) * t
        for side in range(sides):
            angle = math.tau * side / sides
            fold = math.sin(angle * fold_count + t * 2.3 + seed) * 0.038
            drift = math.sin(t * math.pi * 1.7 + angle * 2.0) * 0.018
            local_z = z + (hem_damage[side] if ring == rings - 1 else 0.0)
            vertices.append((
                math.cos(angle) * (radius_x + fold + drift),
                math.sin(angle) * (radius_y + fold * 0.45),
                local_z,
            ))
    for ring in range(rings - 1):
        for side in range(sides):
            nxt = (side + 1) % sides
            a = ring * sides + side
            b = ring * sides + nxt
            c = (ring + 1) * sides + nxt
            d = (ring + 1) * sides + side
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    activate(obj)
    solidify = obj.modifiers.new("Garment thickness", "SOLIDIFY")
    solidify.thickness = 0.045
    solidify.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bevel = obj.modifiers.new("Soft garment edge", "BEVEL")
    bevel.width = 0.014
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return smooth(obj)


def join_segment(name, items):
    valid = [item for item in items if item and item.name in bpy.context.view_layer.objects]
    bpy.ops.object.select_all(action="DESELECT")
    for item in valid:
        item.select_set(True)
    target = valid[0]
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    target.name = name
    target["RobloxBodySegment"] = name
    return target


def build_mask(mask_mat, seam_mat):
    rings = [
        (8.02, 0.35, -0.37, -0.57),
        (7.61, 0.29, -0.36, -0.66),
        (7.16, 0.19, -0.33, -0.68),
        (6.84, 0.11, -0.30, -0.62),
    ]
    vertices = []
    for z, half_width, back_y, front_y in rings:
        vertices.extend([
            (-half_width, back_y, z),
            (half_width, back_y, z),
            (half_width, front_y, z),
            (-half_width, front_y, z),
        ])
    faces = []
    for ring in range(len(rings) - 1):
        a = ring * 4
        b = (ring + 1) * 4
        faces.extend([
            (a, a + 1, b + 1, b),
            (a + 1, a + 2, b + 2, b + 1),
            (a + 2, a + 3, b + 3, b + 2),
            (a + 3, a, b, b + 3),
        ])
    faces.extend([(0, 3, 2, 1), (12, 13, 14, 15)])
    mesh = bpy.data.meshes.new("PaleMask_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mask = bpy.data.objects.new("ElongatedPaleMask", mesh)
    bpy.context.collection.objects.link(mask)
    mask.data.materials.append(mask_mat)
    bevel = mask.modifiers.new("Rounded mask edges", "BEVEL")
    bevel.width = 0.045
    bevel.segments = 3
    activate(mask)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    smooth(mask)

    details = [mask]
    details.append(tube("MaskCenterSeam", [(0, -0.724, 7.92), (0.008, -0.744, 7.57), (-0.01, -0.742, 7.20), (0, -0.635, 6.91)], 0.012, seam_mat))
    details.append(tube("MaskCrackLeft", [(-0.08, -0.73, 7.48), (-0.18, -0.722, 7.37), (-0.22, -0.69, 7.23)], 0.009, seam_mat))
    details.append(tube("MaskCrackRight", [(0.04, -0.736, 7.72), (0.14, -0.72, 7.62), (0.18, -0.69, 7.47)], 0.008, seam_mat))
    return details


def build_model(materials):
    cloth = materials["cloth"]
    cloth_edge = materials["cloth_edge"]
    wrap = materials["wrap"]
    skin = materials["skin"]
    mask = materials["mask"]
    seam = materials["seam"]
    eye = materials["eye"]
    segments = {}

    # Wrapped feet and shins remain visible beneath the ankle-length robe.
    for side, x, forward, twist in (("Left", -0.42, -0.15, -0.055), ("Right", 0.47, -0.11, 0.07)):
        foot = [
            ellipsoid(side + "FootBase", (x, forward, 0.25), (0.235, 0.42, 0.14), skin, surface=0.012),
            box(side + "FootWrap", (x, 0.00, 0.40), (0.26, 0.25, 0.08), wrap, rotation=(0, twist, twist), bevel=0.025),
        ]
        for toe in range(4):
            toe_x = x + (toe - 1.5) * 0.11
            foot.append(ellipsoid(side + f"Toe{toe}", (toe_x, forward - 0.32, 0.20), (0.060, 0.15, 0.055), skin, subdivisions=2))
        segments[side + "Foot"] = join_segment(side + "Foot", foot)

        shin_top = (x + (0.025 if side == "Right" else -0.015), 0.02, 2.38)
        shin_bottom = (x, 0.0, 0.54)
        lower = [cone_between(side + "Shin", shin_bottom, shin_top, 0.21, 0.25, skin, vertices=16)]
        for index, z in enumerate((0.72, 0.90, 1.08, 1.28, 1.51, 1.75, 2.00, 2.21)):
            band = ribbon_ring(side + f"ShinBand{index}", (x, 0.0), 0.255, 0.22, z, 0.14, wrap, tilt=(index % 3 - 1) * 0.035)
            lower.append(band)
        segments[side + "LowerLeg"] = join_segment(side + "LowerLeg", lower)

        thigh_top = (x * 0.82, 0.02, 4.34)
        thigh = cone_between(side + "Thigh", shin_top, thigh_top, 0.25, 0.31, skin, vertices=16)
        segments[side + "UpperLeg"] = join_segment(side + "UpperLeg", [thigh])

    # Central hidden body plus layered front/back cloth matching the concept.
    lower_items = [
        ellipsoid("NarrowPelvis", (0, 0.02, 4.46), (0.58, 0.36, 0.46), cloth_edge, surface=0.018),
        cloth_shell("RoundedRobeBody", 5.10, 1.20, (0.66, 0.39), (0.79, 0.46), cloth, 9, fold_count=11, ragged=0.19),
        cloth_panel("FrontRobeLeft", -0.30, -0.465, 4.98, 1.26, 0.56, 0.67, cloth, 17, warp=0.035),
        cloth_panel("FrontRobeRight", 0.31, -0.465, 4.94, 1.20, 0.56, 0.66, cloth, 23, warp=0.04),
        cloth_panel("BackRobeLeft", -0.29, 0.455, 4.96, 1.25, 0.57, 0.67, cloth, 37, warp=0.035),
        cloth_panel("BackRobeRight", 0.30, 0.455, 4.91, 1.19, 0.57, 0.66, cloth, 41, warp=0.04),
    ]
    # Long raised folds keep the robe readable in flat Roblox lighting.
    for index, x in enumerate((-0.66, -0.34, 0.0, 0.32, 0.64)):
        lower_items.append(tube(
            f"FrontRobeFold{index}",
            [(x * 0.72, -0.515, 4.86), (x * 0.91, -0.535, 3.12), (x, -0.505, 1.38)],
            0.022,
            cloth_edge,
        ))
        lower_items.append(tube(
            f"BackRobeFold{index}",
            [(x * 0.72, 0.505, 4.86), (x * 0.90, 0.525, 3.08), (x, 0.495, 1.36)],
            0.020,
            cloth_edge,
        ))
    # Uneven frayed cords at the hem.
    for index, x in enumerate((-0.72, -0.49, -0.27, 0.18, 0.43, 0.70)):
        length = 0.17 + (index % 3) * 0.09
        lower_items.append(tube(f"HemThread{index}", [(x, -0.49, 1.34), (x + 0.02, -0.50, 1.34 - length)], 0.009, cloth_edge))

    # Thick waist sash and hanging knot ends.
    for index, z in enumerate((4.67, 4.55, 4.43)):
        lower_items.append(ribbon_ring(f"WaistSash{index}", (0, 0.0), 0.78, 0.51, z, 0.16, wrap, tilt=(index - 1) * 0.045))
    lower_items.extend([
        ellipsoid("SashKnot", (0.46, -0.52, 4.48), (0.20, 0.12, 0.16), wrap, subdivisions=2),
        cloth_panel("SashTailLong", 0.49, -0.54, 4.45, 2.70, 0.28, 0.20, wrap, 51, rows=8, columns=3, warp=0.025),
        cloth_panel("SashTailShort", 0.22, -0.535, 4.39, 3.20, 0.24, 0.18, wrap, 53, rows=7, columns=3, warp=0.025),
    ])
    segments["LowerTorso"] = join_segment("LowerTorso", lower_items)

    # Gaunt shoulders under a simple draped institutional/funeral garment.
    torso_items = [
        ellipsoid("GauntTorsoCore", (0, 0.02, 5.77), (0.75, 0.38, 1.13), cloth_edge, surface=0.020),
        cloth_shell("RoundedUpperGarment", 6.55, 4.70, (0.78, 0.41), (0.62, 0.35), cloth, 57, rings=10, fold_count=8, ragged=0.05),
        cloth_panel("ChestDrape", 0, -0.43, 6.48, 4.92, 1.12, 1.03, cloth, 61, rows=9, columns=6, warp=0.026),
        cloth_panel("BackDrape", 0, 0.42, 6.44, 4.90, 1.16, 1.05, cloth, 67, rows=9, columns=6, warp=0.026),
        ribbon_ring("ShoulderMantle", (0, 0), 0.89, 0.45, 6.49, 0.28, cloth, tilt=-0.025),
        ribbon_ring("NeckWrapLower", (0, 0), 0.60, 0.39, 6.61, 0.17, cloth, tilt=0.025),
        ribbon_ring("NeckWrapMiddle", (0, 0), 0.55, 0.37, 6.73, 0.16, cloth, tilt=-0.018),
        ribbon_ring("NeckWrapUpper", (0, 0), 0.50, 0.35, 6.84, 0.15, cloth_edge, tilt=0.012),
    ]
    # Layered scarf loops and two loose hanging ends.
    for index, z in enumerate((6.72, 6.57, 6.42, 6.28)):
        torso_items.append(ribbon_ring(f"NeckScarf{index}", (-0.04, 0), 0.79 + index * 0.06, 0.55 + index * 0.025, z, 0.17, cloth, tilt=(index - 1.5) * 0.035))
    torso_items.extend([
        cloth_panel("ScarfEndLeft", -0.42, -0.54, 6.42, 4.95, 0.37, 0.27, cloth, 79, rows=8, columns=3, warp=0.025),
        cloth_panel("ScarfEndRight", 0.24, -0.545, 6.39, 5.26, 0.33, 0.25, cloth, 83, rows=7, columns=3, warp=0.025),
    ])
    segments["Torso"] = join_segment("Torso", torso_items)

    # Long, almost human arms: cloth sleeves ending in dark bare hands.
    arm_paths = {
        "Left": [(-0.86, 0.01, 6.44), (-1.10, -0.02, 4.95), (-1.17, -0.08, 3.43)],
        "Right": [(0.87, 0.01, 6.35), (1.13, 0.04, 4.86), (1.26, -0.04, 3.34)],
    }
    for side, points in arm_paths.items():
        sign = -1 if side == "Left" else 1
        upper = [cone_between(side + "UpperSleeve", points[0], points[1], 0.31, 0.24, cloth, vertices=18, bevel=0.035)]
        upper.append(cloth_panel(side + "SleeveTatter", sign * 1.00, -0.03, 6.44, 4.83, 0.46, 0.32, cloth, 91 + (0 if sign < 0 else 2), rows=7, columns=3, warp=0.025))
        segments[side + "UpperArm"] = join_segment(side + "UpperArm", upper)

        lower = [cone_between(side + "LowerSleeve", points[1], points[2], 0.24, 0.17, cloth, vertices=18, bevel=0.03)]
        for index in range(3):
            elbow_z = points[1][2] - 0.08 - index * 0.13
            band = ribbon_ring(side + f"ElbowWrap{index}", (points[1][0], points[1][1]), 0.275, 0.23, elbow_z, 0.11, wrap, tilt=(index - 1) * 0.025)
            lower.append(band)
        segments[side + "LowerArm"] = join_segment(side + "LowerArm", lower)

        hand_center = (points[2][0] + sign * 0.015, -0.06, 3.02 if side == "Left" else 2.92)
        hand_items = [ellipsoid(side + "Palm", hand_center, (0.18, 0.135, 0.32), skin, surface=0.012)]
        finger_lengths = (0.63, 0.72, 0.75, 0.66)
        for finger, length in enumerate(finger_lengths):
            x = hand_center[0] + (finger - 1.5) * 0.105
            top = (x, -0.07, hand_center[2] - 0.27)
            mid = (x + sign * (finger - 1.5) * 0.010, -0.10, hand_center[2] - 0.27 - length * 0.57)
            tip = (x + sign * (finger - 1.5) * 0.018, -0.12, hand_center[2] - 0.27 - length)
            hand_items.append(cone_between(side + f"FingerA{finger}", top, mid, 0.039, 0.031, skin, vertices=12, bevel=0.012))
            hand_items.append(cone_between(side + f"FingerB{finger}", mid, tip, 0.031, 0.018, skin, vertices=12, bevel=0.010))
        thumb_top = (hand_center[0] - sign * 0.17, -0.08, hand_center[2] - 0.06)
        thumb_tip = (hand_center[0] - sign * 0.29, -0.16, hand_center[2] - 0.37)
        hand_items.append(cone_between(side + "Thumb", thumb_top, thumb_tip, 0.043, 0.020, skin, vertices=12, bevel=0.011))
        segments[side + "Hand"] = join_segment(side + "Hand", hand_items)

    # Wrapped hood, pale elongated mask, and the enlarged V2 eye shape.
    head_items = [
        ellipsoid("HoodCore", (0, 0.01, 7.76), (0.54, 0.46, 0.68), cloth_edge, subdivisions=4, surface=0.015),
        ellipsoid("BlackEyeBand", (0, -0.425, 8.07), (0.44, 0.115, 0.16), seam, subdivisions=3),
    ]
    hood_bands = (
        (8.39, -0.035, 0.43),
        (8.29, 0.025, 0.50),
        (8.16, -0.018, 0.55),
        (7.99, 0.042, 0.54),
        (7.83, -0.032, 0.51),
        (7.69, 0.015, 0.47),
    )
    for index, (z, tilt, radius_x) in enumerate(hood_bands):
        head_items.append(ribbon_ring(f"HoodBinding{index}", (0, 0.01), radius_x, radius_x * 0.83, z, 0.145, wrap, tilt=tilt))
    head_items.extend(build_mask(mask, seam))
    for side, x in (("Left", -0.19), ("Right", 0.19)):
        head_items.append(ellipsoid(side + "EyeGlow", (x, -0.535, 8.075), (0.125, 0.026, 0.046), eye, subdivisions=3))
    # Loose wet-looking threads from the hood, without wounds or gore.
    for index, x in enumerate((-0.48, -0.31, 0.36, 0.52)):
        end = 7.17 - (index % 2) * 0.23
        head_items.append(tube(f"HoodThread{index}", [(x, -0.28, 7.67), (x + 0.02, -0.31, end)], 0.010, cloth_edge))
    segments["Head"] = join_segment("Head", head_items)
    return segments


def add_rig(segments):
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = "TheBlindOne_Analog_V1_Rig"
    rig.data.name = "TheBlindOne_Analog_V1_Armature"
    rig.data.edit_bones.remove(rig.data.edit_bones[0])
    specs = {
        "Root": ((0, 0, 0.22), (0, 0, 4.18), None),
        "LowerTorso": ((0, 0, 4.12), (0, 0, 5.08), "Root"),
        "Torso": ((0, 0, 5.00), (0, 0, 6.76), "LowerTorso"),
        "Head": ((0, 0, 6.70), (0, 0, 8.47), "Torso"),
        "LeftUpperLeg": ((-0.34, 0, 4.30), (-0.43, 0, 2.34), "LowerTorso"),
        "LeftLowerLeg": ((-0.43, 0, 2.34), (-0.42, 0, 0.54), "LeftUpperLeg"),
        "LeftFoot": ((-0.42, 0, 0.54), (-0.42, -0.47, 0.24), "LeftLowerLeg"),
        "RightUpperLeg": ((0.37, 0, 4.30), (0.49, 0.02, 2.34), "LowerTorso"),
        "RightLowerLeg": ((0.49, 0.02, 2.34), (0.47, 0, 0.54), "RightUpperLeg"),
        "RightFoot": ((0.47, 0, 0.54), (0.47, -0.45, 0.24), "RightLowerLeg"),
        "LeftUpperArm": ((-0.83, 0, 6.43), (-1.10, 0, 4.94), "Torso"),
        "LeftLowerArm": ((-1.10, 0, 4.94), (-1.18, -0.05, 3.42), "LeftUpperArm"),
        "LeftHand": ((-1.18, -0.05, 3.42), (-1.18, -0.08, 2.24), "LeftLowerArm"),
        "RightUpperArm": ((0.83, 0, 6.35), (1.13, 0.03, 4.85), "Torso"),
        "RightLowerArm": ((1.13, 0.03, 4.85), (1.26, -0.04, 3.33), "RightUpperArm"),
        "RightHand": ((1.26, -0.04, 3.33), (1.27, -0.08, 2.16), "RightLowerArm"),
    }
    bones = {}
    for name, (head, tail, parent) in specs.items():
        bone = rig.data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = bones[parent]
        bones[name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    rig["ConceptReference"] = "TheBlindOne_AnalogConcept_V2.png"
    rig["RobloxReady"] = True
    rig["NoBloodOrGore"] = True

    for name, obj in segments.items():
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = name
        obj.matrix_world = world

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"

    def key(frame, rotations, locations=None):
        bpy.context.scene.frame_set(frame)
        for bone_name, rotation in rotations.items():
            bone = rig.pose.bones[bone_name]
            bone.rotation_euler = tuple(math.radians(value) for value in rotation)
            bone.keyframe_insert("rotation_euler", frame=frame)
        for bone_name, location in (locations or {}).items():
            bone = rig.pose.bones[bone_name]
            bone.location = location
            bone.keyframe_insert("location", frame=frame)

    # Crooked V2 turnaround pose plus a subtle breathing/limp-ready idle loop.
    pose = {
        "Root": (0, 0, -3),
        "LowerTorso": (0, 0, 2),
        "Torso": (-7, 0, 7),
        "Head": (-5, 0, -14),
        "LeftUpperArm": (2, 0, -3),
        "LeftLowerArm": (-2, 0, -1),
        "RightUpperArm": (-1, 0, 5),
        "RightLowerArm": (3, 0, 1),
        "LeftUpperLeg": (-1, 0, -1),
        "RightUpperLeg": (4, 0, 3),
        "RightLowerLeg": (8, 0, 0),
    }
    key(1, pose, {"Root": (-0.09, 0, -0.02)})
    key(18, {**pose, "Torso": (-9, 0, 9), "Head": (-3, 0, -17), "RightUpperArm": (1, 0, 6)}, {"Root": (-0.06, 0, -0.07)})
    key(36, pose, {"Root": (-0.09, 0, -0.02)})
    bpy.ops.object.mode_set(mode="OBJECT")
    if rig.animation_data and rig.animation_data.action:
        rig.animation_data.action.name = "Analog_Unsettling_Idle"
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 36
    bpy.context.scene.frame_set(1)
    return rig


def add_reference_image():
    if not CONCEPT.exists():
        return None
    image = bpy.data.images.load(str(CONCEPT), check_existing=True)
    bpy.ops.object.empty_add(type="IMAGE", location=(4.9, 1.9, 4.6), rotation=(math.radians(90), 0, 0))
    reference = bpy.context.object
    reference.name = "REFERENCE_Concept_V2_Toggle_In_Viewport"
    reference.data = image
    reference.empty_display_size = 5.6
    reference.color[3] = 0.32
    reference.show_in_front = False
    reference.hide_render = True
    reference["Usage"] = "Viewport comparison only - never exported"
    return reference


def add_stage():
    floor_mat = flat_material("NeutralFloor", (0.19, 0.19, 0.18), 0.96)
    backdrop_mat = flat_material("NeutralBackdrop", (0.31, 0.31, 0.30), 0.94)
    bpy.ops.mesh.primitive_plane_add(size=36, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = "PreviewFloor_NOT_EXPORTED"
    floor.data.materials.append(floor_mat)
    floor["PreviewOnly"] = True
    bpy.ops.mesh.primitive_plane_add(size=28, location=(0, 3.8, 7.0), rotation=(math.radians(90), 0, 0))
    backdrop = bpy.context.object
    backdrop.name = "PreviewBackdrop_NOT_EXPORTED"
    backdrop.data.materials.append(backdrop_mat)
    backdrop["PreviewOnly"] = True

    world = bpy.context.scene.world or bpy.data.worlds.new("AnalogNeutralWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.105, 0.105, 0.11, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42

    def area(name, location, color, energy, size, target=(0, 0, 4.4)):
        data = bpy.data.lights.new(name, "AREA")
        data.color = color
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = location
        light.rotation_euler = ((Vector(target) - light.location).to_track_quat("-Z", "Y")).to_euler()
        light["PreviewOnly"] = True
        return light

    area("SoftFrontKey", (-3.2, -8.0, 8.7), (0.78, 0.82, 0.86), 930, 5.2)
    area("SoftFrontFill", (4.5, -6.0, 5.0), (0.48, 0.55, 0.62), 560, 4.2)
    area("BackSilhouetteRim", (0.2, 4.2, 8.2), (0.58, 0.62, 0.68), 720, 3.8)
    area("LowClothFill", (-1.5, -4.5, 2.0), (0.38, 0.41, 0.44), 280, 3.0)

    camera_data = bpy.data.cameras.new("AnalogPreviewCamera")
    camera = bpy.data.objects.new("AnalogPreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.data.lens = 66
    camera["PreviewOnly"] = True
    bpy.context.scene.camera = camera
    return camera


def point_camera(camera, location, target=(0, 0, 4.25), lens=66):
    camera.location = location
    camera.data.lens = lens
    camera.rotation_euler = ((Vector(target) - camera.location).to_track_quat("-Z", "Y")).to_euler()


def configure_scene():
    scene = bpy.context.scene
    scene.name = "TheBlindOne_Analog_V1"
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.render.use_file_extension = True
    scene.render.resolution_percentage = 100
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene["DesignTarget"] = "TheBlindOne_AnalogConcept_V2.png"
    scene["DesignRule"] = "No blood, gore, exposed ribs, antlers, spikes, or teeth"

    scene.use_nodes = True
    nodes = scene.node_tree.nodes
    links = scene.node_tree.links
    nodes.clear()
    layers = nodes.new("CompositorNodeRLayers")
    glare = nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.quality = "HIGH"
    glare.threshold = 2.0
    glare.size = 6
    composite = nodes.new("CompositorNodeComposite")
    links.new(layers.outputs["Image"], glare.inputs["Image"])
    links.new(glare.outputs["Image"], composite.inputs["Image"])


def export_model(segments, rig):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(segments.values()) + [rig]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_apply=False,
        export_yup=True,
    )
    try:
        bpy.ops.export_scene.fbx(
            filepath=str(FBX_PATH),
            use_selection=True,
            add_leaf_bones=False,
            bake_anim=True,
            bake_anim_use_all_actions=True,
            axis_forward="-Z",
            axis_up="Y",
        )
    except Exception as exc:
        print("FBX export skipped:", exc)


def render_previews(camera):
    scene = bpy.context.scene
    scene.frame_set(1)
    views = {
        "TheBlindOne_Analog_V1_front.png": ((0, -18.2, 4.45), (0, 0, 4.25), 66),
        "TheBlindOne_Analog_V1_three_quarter.png": ((7.3, -16.5, 4.75), (0, 0, 4.28), 69),
        "TheBlindOne_Analog_V1_back.png": ((0, 18.2, 4.45), (0, 0, 4.25), 66),
    }
    for filename, (location, target, lens) in views.items():
        backdrop = bpy.data.objects.get("PreviewBackdrop_NOT_EXPORTED")
        if backdrop:
            backdrop.location.y = -3.8 if "back" in filename else 3.8
        point_camera(camera, location, target, lens)
        scene.render.filepath = str(PREVIEW_DIR / filename)
        bpy.ops.render.render(write_still=True)
        print("Rendered", filename)
    # Leave the front result in Blender for immediate visual review.
    backdrop = bpy.data.objects.get("PreviewBackdrop_NOT_EXPORTED")
    if backdrop:
        backdrop.location.y = 3.8
    point_camera(camera, views["TheBlindOne_Analog_V1_front.png"][0], views["TheBlindOne_Analog_V1_front.png"][1], 66)
    scene.render.filepath = str(PREVIEW_DIR / "TheBlindOne_Analog_V1_front.png")
    bpy.ops.render.render(write_still=False)


def main():
    bpy.context.window_manager.progress_begin(0, 100)
    try:
        progress(2, "clearing old scene")
        clear_scene()
        configure_scene()
        progress(8, "creating layered cloth and surface materials")
        materials = {
            "cloth": textured_material("WornBlackInstitutionalCloth", (0.008, 0.009, 0.010), (0.040, 0.043, 0.045), 0.96, 8.5, 0.34, (1.1, 1.1, 0.24)),
            "cloth_edge": textured_material("DarkClothEdges", (0.004, 0.004, 0.005), (0.021, 0.023, 0.025), 0.98, 11.0, 0.24, (1.0, 1.0, 0.32)),
            "wrap": textured_material("AgedBlackBindings", (0.012, 0.012, 0.013), (0.065, 0.061, 0.057), 0.94, 13.0, 0.32, (1.0, 1.0, 0.18)),
            "skin": textured_material("AshDarkHandsAndFeet", (0.018, 0.019, 0.019), (0.080, 0.077, 0.071), 0.92, 6.0, 0.22, (1.0, 1.0, 0.65)),
            "mask": textured_material("AgedPaleMask", (0.30, 0.29, 0.26), (0.67, 0.65, 0.58), 0.84, 5.2, 0.21, (1.0, 0.8, 0.5)),
            "seam": flat_material("MaskSeamsAndEyeVoid", (0.002, 0.002, 0.002), 0.99),
            "eye": emission_material("ColdWhiteUncannyEyes_V2", (0.82, 0.91, 1.0), 5.0),
        }
        progress(14, "building wrapped legs and feet")
        segments = build_model(materials)
        progress(64, "building Roblox-compatible bone hierarchy")
        rig = add_rig(segments)
        progress(74, "adding V2 reference and neutral preview stage")
        add_reference_image()
        camera = add_stage()
        progress(80, "saving editable Blender source")
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
        progress(83, "exporting Roblox GLB and FBX")
        export_model(segments, rig)
        progress(88, "rendering front, three-quarter, and back previews")
        render_previews(camera)
        progress(99, "saving final first-pass source")
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
        progress(100, "THE BLIND ONE ANALOG V1 COMPLETE")
    finally:
        bpy.context.window_manager.progress_end()


if __name__ == "__main__":
    main()
