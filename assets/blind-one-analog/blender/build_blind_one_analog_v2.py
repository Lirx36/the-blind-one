from __future__ import annotations

import importlib.util
import math
import random
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[1]
BLENDER_DIR = ROOT / "blender"
PREVIEW_DIR = ROOT / "previews"
V1_BUILDER = BLENDER_DIR / "build_blind_one_analog_v1.py"
CONCEPT = ROOT / "concepts" / "TheBlindOne_AnalogConcept_V2.png"
BLEND_PATH = BLENDER_DIR / "TheBlindOne_Analog_V2.blend"
GLB_PATH = BLENDER_DIR / "TheBlindOne_Analog_V2.glb"
FBX_PATH = BLENDER_DIR / "TheBlindOne_Analog_V2.fbx"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

spec = importlib.util.spec_from_file_location("blind_one_v1_base", V1_BUILDER)
base = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(base)


def progress(value: int, message: str) -> None:
    print(f"ANALOG V2 {value:03d}% | {message}", flush=True)


def slump_point(point: tuple[float, float, float] | Vector) -> Vector:
    value = Vector(point)
    factor = max(0.0, min(1.0, (value.z - 3.95) / 2.70))
    value.x -= 0.22 * factor
    value.y -= 0.27 * factor
    return value


def head_tilt_point(point: tuple[float, float, float] | Vector) -> Vector:
    value = slump_point(point)
    pivot = slump_point((-0.10, -0.10, 6.52))
    rotation = Matrix.Rotation(math.radians(8.0), 4, "X") @ Matrix.Rotation(math.radians(-13.0), 4, "Y")
    return pivot + rotation @ (value - pivot)


def warp_mesh(obj: bpy.types.Object, transform) -> None:
    world = obj.matrix_world.copy()
    world_inverse = world.inverted()
    for vertex in obj.data.vertices:
        vertex.co = world_inverse @ transform(world @ vertex.co)


def soft_ribbon(
    name: str,
    center: tuple[float, float],
    radius_x: float,
    radius_y: float,
    z: float,
    height: float,
    mat: bpy.types.Material,
    tilt: float = 0.0,
) -> bpy.types.Object:
    obj = base.ribbon_ring(name, center, radius_x, radius_y, z, height, mat, tilt=tilt, count=64)
    base.activate(obj)
    bevel = obj.modifiers.new("Soft crushed binding edge", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return base.smooth(obj)


def organic_shell(
    name: str,
    top_z: float,
    bottom_z: float,
    top_radius: tuple[float, float],
    bottom_radius: tuple[float, float],
    mat: bpy.types.Material,
    seed: int,
    rings: int = 22,
    sides: int = 56,
    fold_count: int = 11,
    ragged: float = 0.18,
    lean: float = 0.0,
) -> bpy.types.Object:
    """Dense asymmetrical cloth volume with silhouette and micro-wrinkles."""
    random.seed(seed)
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    hem = [random.uniform(0.0, ragged) for _ in range(sides)]
    phase = [random.uniform(-0.5, 0.5) for _ in range(sides)]
    for ring in range(rings):
        t = ring / (rings - 1)
        ease = t * t * (3.0 - 2.0 * t)
        rx = top_radius[0] + (bottom_radius[0] - top_radius[0]) * ease
        ry = top_radius[1] + (bottom_radius[1] - top_radius[1]) * ease
        center_x = lean * (t ** 1.35) + math.sin(t * math.pi * 1.3 + seed) * 0.018
        center_y = math.sin(t * math.pi * 1.7 + seed * 0.31) * 0.018
        z = top_z + (bottom_z - top_z) * t
        for side in range(sides):
            angle = math.tau * side / sides
            broad_fold = math.sin(angle * fold_count + t * 2.7 + phase[side]) * (0.030 + 0.035 * t)
            fine_fold = math.sin(angle * (fold_count * 2 + 1) - t * 7.0) * 0.011
            bias = 0.030 * math.sin(angle * 3.0 + seed) * math.sin(t * math.pi)
            local_z = z + (hem[side] if ring == rings - 1 else 0.0)
            vertices.append(
                (
                    center_x + math.cos(angle) * (rx + broad_fold + fine_fold + bias),
                    center_y + math.sin(angle) * (ry + broad_fold * 0.45 + fine_fold * 0.2),
                    local_z,
                )
            )
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
    base.activate(obj)
    solidify = obj.modifiers.new("Real cloth thickness", "SOLIDIFY")
    solidify.thickness = 0.030
    solidify.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bevel = obj.modifiers.new("Worn cloth edge", "BEVEL")
    bevel.width = 0.010
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return base.smooth(obj)


def ragged_panel(
    name: str,
    center_x: float,
    face_y: float,
    top_z: float,
    bottom_z: float,
    top_width: float,
    bottom_width: float,
    mat: bpy.types.Material,
    seed: int,
    rows: int = 20,
    columns: int = 9,
    warp: float = 0.035,
    lean: float = 0.0,
) -> bpy.types.Object:
    random.seed(seed)
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    hem = [random.uniform(0.0, 0.30) for _ in range(columns)]
    for row in range(rows):
        t = row / (rows - 1)
        ease = t * t * (3.0 - 2.0 * t)
        width = top_width + (bottom_width - top_width) * ease
        for column in range(columns):
            u = column / (columns - 1)
            x = center_x + lean * t + (u - 0.5) * width
            z = top_z + (bottom_z - top_z) * t
            if row == rows - 1:
                z += hem[column]
            pleat = math.sin(u * math.pi * 8.0 + seed) * warp * (0.45 + 0.75 * t)
            ripple = math.sin(t * math.pi * 4.4 + u * 4.0 + seed) * warp * 0.42
            vertices.append((x, face_y + pleat + ripple, z))
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
    base.activate(obj)
    solidify = obj.modifiers.new("Layered cloth thickness", "SOLIDIFY")
    solidify.thickness = 0.022
    solidify.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bevel = obj.modifiers.new("Frayed panel edge", "BEVEL")
    bevel.width = 0.008
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def make_mask(mask_mat: bpy.types.Material, seam_mat: bpy.types.Material) -> list[bpy.types.Object]:
    """Curved, subtly asymmetric mask matching the long V2 concept face."""
    rows = 15
    columns = 11
    top_z = 8.08
    bottom_z = 6.83
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    for row in range(rows):
        t = row / (rows - 1)
        z = top_z + (bottom_z - top_z) * t
        width = 0.385 * (1.0 - t) ** 0.58 + 0.075
        width *= 1.0 - 0.06 * math.sin(t * math.pi * 2.0)
        center_x = -0.015 * t + 0.012 * math.sin(t * math.pi)
        front_y = -0.525 - 0.155 * math.sin(t * math.pi * 0.92) - 0.030 * t
        for column in range(columns):
            u = column / (columns - 1) * 2.0 - 1.0
            edge_round = math.sqrt(max(0.0, 1.0 - u * u))
            x = center_x + u * width
            y = front_y - 0.050 * edge_round + 0.010 * math.sin(t * 9.0 + u * 4.0)
            vertices.append((x, y, z))
    for row in range(rows - 1):
        for column in range(columns - 1):
            a = row * columns + column
            b = a + 1
            c = a + columns + 1
            d = a + columns
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new("OrganicPaleMask_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mask = bpy.data.objects.new("OrganicElongatedPaleMask", mesh)
    bpy.context.collection.objects.link(mask)
    mask.data.materials.append(mask_mat)
    base.activate(mask)
    solidify = mask.modifiers.new("Mask shell thickness", "SOLIDIFY")
    solidify.thickness = 0.075
    solidify.offset = 0.3
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bevel = mask.modifiers.new("Hand worn mask rim", "BEVEL")
    bevel.width = 0.028
    bevel.segments = 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    base.smooth(mask)

    details = [mask]
    details.append(base.tube("MaskCenterSplit", [(0.00, -0.725, 7.99), (-0.018, -0.757, 7.67), (0.004, -0.760, 7.34), (-0.025, -0.722, 7.03), (-0.012, -0.660, 6.88)], 0.010, seam_mat, resolution=3))
    details.append(base.tube("MaskCrackL_Upper", [(-0.08, -0.747, 7.70), (-0.19, -0.742, 7.55), (-0.22, -0.715, 7.38), (-0.31, -0.680, 7.28)], 0.008, seam_mat, resolution=2))
    details.append(base.tube("MaskCrackL_Branch", [(-0.19, -0.742, 7.55), (-0.13, -0.752, 7.43), (-0.14, -0.740, 7.33)], 0.006, seam_mat, resolution=2))
    details.append(base.tube("MaskCrackR_Upper", [(0.06, -0.743, 7.88), (0.15, -0.744, 7.72), (0.12, -0.756, 7.55), (0.21, -0.727, 7.42)], 0.007, seam_mat, resolution=2))
    details.append(base.tube("MaskCrackR_Lower", [(0.02, -0.744, 7.28), (0.10, -0.742, 7.17), (0.06, -0.716, 7.03)], 0.006, seam_mat, resolution=2))
    return details


def build_hand(side: str, wrist: tuple[float, float, float], skin: bpy.types.Material) -> bpy.types.Object:
    sign = -1 if side == "Left" else 1
    wx, wy, wz = wrist
    items = [base.ellipsoid(side + "NarrowPalm", (wx, wy - 0.015, wz - 0.27), (0.145, 0.105, 0.31), skin, subdivisions=3, surface=0.009)]
    lengths = (0.56, 0.70, 0.75, 0.69, 0.57)
    spreads = (-0.14, -0.073, 0.0, 0.073, 0.14)
    for index, (spread, length) in enumerate(zip(spreads, lengths)):
        top = (wx + spread, wy - 0.045, wz - 0.48)
        middle = (wx + spread + sign * spread * 0.10, wy - 0.085, wz - 0.48 - length * 0.52)
        tip = (wx + spread + sign * spread * 0.24, wy - 0.115, wz - 0.48 - length)
        items.append(base.cone_between(side + f"Finger{index}_Proximal", top, middle, 0.030, 0.024, skin, vertices=12, bevel=0.009))
        items.append(base.cone_between(side + f"Finger{index}_Distal", middle, tip, 0.024, 0.013, skin, vertices=12, bevel=0.008))
        items.append(base.ellipsoid(side + f"Knuckle{index}", middle, (0.031, 0.028, 0.036), skin, subdivisions=2))
    thumb_top = (wx - sign * 0.14, wy - 0.03, wz - 0.20)
    thumb_mid = (wx - sign * 0.25, wy - 0.10, wz - 0.36)
    thumb_tip = (wx - sign * 0.28, wy - 0.13, wz - 0.52)
    items.append(base.cone_between(side + "ThumbProximal", thumb_top, thumb_mid, 0.034, 0.027, skin, vertices=12, bevel=0.009))
    items.append(base.cone_between(side + "ThumbDistal", thumb_mid, thumb_tip, 0.027, 0.014, skin, vertices=12, bevel=0.008))
    return base.join_segment(side + "Hand", items)


def build_model(materials: dict[str, bpy.types.Material]) -> dict[str, bpy.types.Object]:
    cloth = materials["cloth"]
    cloth_edge = materials["cloth_edge"]
    wrap = materials["wrap"]
    skin = materials["skin"]
    mask = materials["mask"]
    seam = materials["seam"]
    eye = materials["eye"]
    eye_halo = materials["eye_halo"]
    segments: dict[str, bpy.types.Object] = {}

    # Slender wrapped legs and narrow human-like feet.
    for side, x, forward, splay in (("Left", -0.35, -0.15, -0.035), ("Right", 0.39, -0.11, 0.045)):
        foot_items = [
            base.ellipsoid(side + "FootArch", (x, forward, 0.23), (0.205, 0.39, 0.125), skin, subdivisions=3, surface=0.010),
            base.ellipsoid(side + "Heel", (x, 0.09, 0.25), (0.19, 0.20, 0.15), skin, subdivisions=3),
        ]
        for index, scale in enumerate((0.066, 0.062, 0.057, 0.050, 0.044)):
            toe_x = x + (index - 2) * 0.072
            toe_y = forward - 0.31 + abs(index - 2) * 0.015
            foot_items.append(base.ellipsoid(side + f"Toe{index}", (toe_x, toe_y, 0.18), (scale, 0.14 - index * 0.008, 0.050), skin, subdivisions=2))
        for band_index, band_y in enumerate((-0.02, 0.10, 0.21)):
            foot_items.append(base.box(side + f"FootBand{band_index}", (x, band_y, 0.34 + band_index * 0.025), (0.225, 0.11, 0.050), wrap, rotation=(0.0, splay, splay * 0.6), bevel=0.024))
        segments[side + "Foot"] = base.join_segment(side + "Foot", foot_items)

        ankle = (x, 0.01, 0.50)
        knee = (x + (-0.025 if side == "Left" else 0.035), 0.015, 2.21)
        hip = (x * 0.77, 0.03, 4.27)
        lower_items = [base.cone_between(side + "ShinCore", ankle, knee, 0.16, 0.205, skin, vertices=20, bevel=0.020)]
        for index, z in enumerate((0.62, 0.78, 0.96, 1.15, 1.36, 1.58, 1.81, 2.03)):
            lower_items.append(soft_ribbon(side + f"ShinBinding{index}", (ankle[0], 0.01), 0.205 + 0.012 * math.sin(index), 0.175, z, 0.105, wrap, tilt=(index % 3 - 1) * 0.040))
        segments[side + "LowerLeg"] = base.join_segment(side + "LowerLeg", lower_items)
        segments[side + "UpperLeg"] = base.join_segment(side + "UpperLeg", [base.cone_between(side + "LeanThigh", knee, hip, 0.205, 0.255, skin, vertices=20, bevel=0.022)])

    # Ankle-length robe: asymmetrical volume, overlapping cloth panels, deep pleats and frayed hem.
    lower_items = [
        base.ellipsoid("HiddenNarrowPelvis", (0, 0.02, 4.37), (0.50, 0.31, 0.42), cloth_edge, subdivisions=3),
        organic_shell("AsymmetricRobeVolume", 5.02, 1.08, (0.56, 0.34), (0.72, 0.42), cloth, 109, fold_count=13, ragged=0.25, lean=-0.055),
        ragged_panel("FrontRobeOuterLeft", -0.27, -0.425, 4.96, 1.06, 0.66, 0.78, cloth, 113, lean=-0.045),
        ragged_panel("FrontRobeOuterRight", 0.28, -0.430, 4.92, 1.17, 0.64, 0.76, cloth, 127, lean=-0.015),
        ragged_panel("BackRobeOuterLeft", -0.28, 0.420, 4.93, 1.10, 0.67, 0.78, cloth, 131, lean=-0.040),
        ragged_panel("BackRobeOuterRight", 0.27, 0.425, 4.88, 1.02, 0.66, 0.77, cloth, 137, lean=-0.020),
    ]
    for index, x in enumerate((-0.66, -0.43, -0.20, 0.05, 0.29, 0.54, 0.70)):
        drift = -0.05 * (index / 6.0)
        lower_items.append(base.tube(f"FrontRaisedPleat{index}", [(x * 0.72, -0.468, 4.84), (x * 0.87 + drift, -0.493, 3.05), (x + drift, -0.455, 1.25 + 0.08 * (index % 2))], 0.015 + 0.004 * (index % 2), cloth_edge, resolution=3))
        lower_items.append(base.tube(f"BackRaisedPleat{index}", [(x * 0.72, 0.463, 4.84), (x * 0.88 + drift, 0.487, 3.03), (x + drift, 0.452, 1.23 + 0.07 * ((index + 1) % 2))], 0.014, cloth_edge, resolution=3))
    for index, x in enumerate((-0.70, -0.55, -0.37, -0.17, 0.13, 0.31, 0.50, 0.67)):
        length = 0.16 + 0.08 * (index % 4)
        lower_items.append(base.tube(f"FrontHemFiber{index}", [(x, -0.44, 1.22), (x + 0.015 * ((index % 3) - 1), -0.46, 1.22 - length)], 0.006, cloth_edge, resolution=1))
    # Three uneven sash wraps; the concept knot and tails live on the back.
    for index, z in enumerate((4.62, 4.50, 4.39)):
        lower_items.append(soft_ribbon(f"WeatheredWaistWrap{index}", (-0.02, 0.0), 0.70, 0.43, z, 0.125, wrap, tilt=(index - 1) * 0.045))
    lower_items.extend(
        [
            base.ellipsoid("BackSashKnot", (0.22, 0.49, 4.48), (0.19, 0.12, 0.15), wrap, subdivisions=2),
            ragged_panel("BackSashTailLong", 0.30, 0.505, 4.44, 2.72, 0.30, 0.20, wrap, 149, rows=12, columns=5, warp=0.025, lean=0.05),
            ragged_panel("BackSashTailShort", -0.03, 0.510, 4.40, 3.25, 0.26, 0.19, wrap, 151, rows=10, columns=5, warp=0.025, lean=-0.03),
        ]
    )
    segments["LowerTorso"] = base.join_segment("LowerTorso", lower_items)

    # Thin, slumped chest with a weathered shoulder cowl and hanging scarf layers.
    torso_items = [
        base.ellipsoid("GauntHiddenChest", (-0.03, 0.04, 5.73), (0.62, 0.31, 1.05), cloth_edge, subdivisions=3, surface=0.012),
        base.cone_between("WrappedSunkenNeck", (-0.04, -0.02, 6.34), (-0.10, -0.13, 7.18), 0.25, 0.29, cloth_edge, vertices=28, bevel=0.025),
        organic_shell("SlumpedUpperGarment", 6.46, 4.70, (0.69, 0.36), (0.55, 0.31), cloth, 157, rings=16, sides=48, fold_count=9, ragged=0.08, lean=-0.045),
        ragged_panel("LayeredChestCloth", -0.04, -0.385, 6.39, 4.82, 1.05, 0.96, cloth, 163, rows=16, columns=9, warp=0.026, lean=-0.045),
        ragged_panel("LayeredBackCloth", -0.03, 0.382, 6.35, 4.79, 1.10, 0.98, cloth, 167, rows=16, columns=9, warp=0.026, lean=-0.035),
    ]
    for index, z in enumerate((6.42, 6.29, 6.15)):
        torso_items.append(soft_ribbon(f"HeavyShoulderCowl{index}", (-0.07, -0.01), 0.80 + index * 0.050, 0.42 + index * 0.020, z, 0.135, cloth, tilt=(-0.12 + index * 0.045)))
    for index, z in enumerate((6.93, 6.81, 6.69, 6.56, 6.43)):
        torso_items.append(soft_ribbon(f"LooseNeckDrape{index}", (-0.08, -0.06), 0.34 + index * 0.075, 0.27 + index * 0.030, z, 0.105, cloth, tilt=(index % 2 - 0.5) * 0.060))
    torso_items.extend(
        [
            ragged_panel("LongScarfFallLeft", -0.40, -0.470, 6.37, 4.78, 0.34, 0.24, cloth, 173, rows=12, columns=5, warp=0.025, lean=-0.06),
            ragged_panel("LongScarfFallRight", 0.25, -0.475, 6.32, 5.05, 0.30, 0.23, cloth, 179, rows=11, columns=5, warp=0.022, lean=0.025),
        ]
    )
    segments["Torso"] = base.join_segment("Torso", torso_items)

    # Long sloped arms. Sleeves overlap the hands so posing never exposes gaps.
    arm_paths = {
        "Left": [(-0.73, 0.015, 6.35), (-0.96, -0.015, 5.03), (-1.04, -0.055, 3.49)],
        "Right": [(0.68, 0.015, 6.12), (0.98, 0.025, 4.83), (1.10, -0.045, 3.30)],
    }
    for side, points in arm_paths.items():
        sign = -1 if side == "Left" else 1
        upper_items = [base.cone_between(side + "NarrowUpperSleeve", points[0], points[1], 0.245, 0.190, cloth, vertices=24, bevel=0.030)]
        upper_items.append(ragged_panel(side + "UpperSleeveOuterLayer", sign * 0.84, -0.045, points[0][2], points[1][2] - 0.10, 0.36, 0.29, cloth, 181 + (0 if side == "Left" else 6), rows=10, columns=5, warp=0.020, lean=sign * 0.12))
        segments[side + "UpperArm"] = base.join_segment(side + "UpperArm", upper_items)
        lower_items = [base.cone_between(side + "NarrowLowerSleeve", points[1], (points[2][0], points[2][1], points[2][2] - 0.09), 0.195, 0.135, cloth, vertices=24, bevel=0.026)]
        for index in range(4):
            z = points[2][2] + 0.10 - index * 0.105
            lower_items.append(soft_ribbon(side + f"RaggedCuff{index}", (points[2][0], points[2][1]), 0.165 + 0.008 * (index % 2), 0.145, z, 0.075, wrap, tilt=(index - 1.5) * 0.025))
        for index in range(3):
            x = points[2][0] + sign * (index - 1) * 0.055
            lower_items.append(base.tube(side + f"CuffFiber{index}", [(x, -0.08, points[2][2] - 0.04), (x + sign * 0.015, -0.10, points[2][2] - 0.27 - index * 0.04)], 0.006, cloth_edge, resolution=1))
        segments[side + "LowerArm"] = base.join_segment(side + "LowerArm", lower_items)
        segments[side + "Hand"] = build_hand(side, (points[2][0], -0.055, points[2][2] - 0.10), skin)

    # Bound hood, black sockets, large V2 eyes, and the long mask.
    head_items = [
        base.ellipsoid("DeepHoodCore", (-0.03, 0.045, 7.73), (0.50, 0.43, 0.68), cloth_edge, subdivisions=4, surface=0.013),
        base.ellipsoid("BlackSocketBand", (-0.015, -0.420, 8.04), (0.43, 0.105, 0.155), seam, subdivisions=4),
    ]
    hood_bands = (
        (8.37, -0.085, 0.34),
        (8.29, 0.070, 0.40),
        (8.20, -0.055, 0.45),
        (8.10, 0.090, 0.48),
        (7.98, -0.075, 0.47),
        (7.86, 0.055, 0.45),
        (7.73, -0.045, 0.42),
        (7.61, 0.070, 0.38),
    )
    for index, (z, tilt, rx) in enumerate(hood_bands):
        head_items.append(soft_ribbon(f"CrossWrappedHoodBand{index}", (-0.03, 0.04), rx, rx * 0.82, z, 0.078 + 0.012 * (index % 2), wrap, tilt=tilt))
    # A rough rear hood flap makes the back silhouette match the concept.
    head_items.append(ragged_panel("RearHoodFlap", -0.03, 0.410, 8.12, 7.14, 0.72, 0.55, cloth, 193, rows=12, columns=7, warp=0.028, lean=-0.02))
    head_items.extend(make_mask(mask, seam))
    for side, x in (("Left", -0.185), ("Right", 0.177)):
        head_items.append(base.ellipsoid(side + "EyeHalo", (x, -0.548, 8.055), (0.185, 0.030, 0.074), eye_halo, subdivisions=4))
        head_items.append(base.ellipsoid(side + "ColdEyeCore", (x, -0.578, 8.058), (0.146, 0.021, 0.052), eye, subdivisions=4))
    for index, x in enumerate((-0.47, -0.32, 0.30, 0.45)):
        length = 0.46 + 0.15 * (index % 2)
        head_items.append(base.tube(f"HoodLooseFiber{index}", [(x, -0.24, 7.76), (x + 0.02 * ((index % 3) - 1), -0.28, 7.76 - length)], 0.007, cloth_edge, resolution=2))
    segments["Head"] = base.join_segment("Head", head_items)
    # Head sits low, left and forward instead of floating above a straight neck.
    for vertex in segments["Head"].data.vertices:
        vertex.co.x -= 0.105
        vertex.co.y -= 0.180
        vertex.co.z -= 0.075

    # Bake the iconic crooked posture into the rest mesh. This makes the silhouette
    # survive Roblox import even before an animation starts playing.
    def lower_slump(point: Vector) -> Vector:
        value = Vector(point)
        factor = max(0.0, min(1.0, (value.z - 1.05) / 3.95))
        value.x -= 0.10 * factor
        value.y -= 0.08 * factor
        return value

    warp_mesh(segments["LowerTorso"], lower_slump)
    for name in ("Torso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"):
        warp_mesh(segments[name], slump_point)
    warp_mesh(segments["Head"], head_tilt_point)
    return segments


def add_rig(segments: dict[str, bpy.types.Object]) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = "TheBlindOne_Analog_V2_Rig"
    rig.data.name = "TheBlindOne_Analog_V2_Armature"
    rig.data.edit_bones.remove(rig.data.edit_bones[0])
    specs = {
        "Root": ((0, 0, 0.22), (0, 0, 4.08), None),
        "LowerTorso": ((0, 0, 4.06), (0, 0, 5.02), "Root"),
        "Torso": ((0, 0, 4.96), (-0.03, 0, 6.67), "LowerTorso"),
        "Head": ((-0.03, 0, 6.63), (-0.03, 0, 8.46), "Torso"),
        "LeftUpperLeg": ((-0.27, 0, 4.22), (-0.375, 0, 2.21), "LowerTorso"),
        "LeftLowerLeg": ((-0.375, 0, 2.21), (-0.35, 0, 0.50), "LeftUpperLeg"),
        "LeftFoot": ((-0.35, 0, 0.50), (-0.35, -0.47, 0.22), "LeftLowerLeg"),
        "RightUpperLeg": ((0.30, 0, 4.22), (0.425, 0, 2.21), "LowerTorso"),
        "RightLowerLeg": ((0.425, 0, 2.21), (0.39, 0, 0.50), "RightUpperLeg"),
        "RightFoot": ((0.39, 0, 0.50), (0.39, -0.45, 0.22), "RightLowerLeg"),
        "LeftUpperArm": ((-0.70, 0, 6.34), (-0.96, 0, 5.03), "Torso"),
        "LeftLowerArm": ((-0.96, 0, 5.03), (-1.04, -0.04, 3.48), "LeftUpperArm"),
        "LeftHand": ((-1.04, -0.04, 3.50), (-1.04, -0.08, 2.18), "LeftLowerArm"),
        "RightUpperArm": ((0.66, 0, 6.12), (0.98, 0.02, 4.83), "Torso"),
        "RightLowerArm": ((0.98, 0.02, 4.83), (1.10, -0.04, 3.29), "RightUpperArm"),
        "RightHand": ((1.10, -0.04, 3.31), (1.10, -0.08, 1.97), "RightLowerArm"),
    }

    # Match the rest bones to the baked crooked mesh so joints remain connected.
    for bone_name, (head, tail, parent) in list(specs.items()):
        if bone_name in {"Torso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"}:
            specs[bone_name] = (tuple(slump_point(head)), tuple(slump_point(tail)), parent)
    bones: dict[str, bpy.types.EditBone] = {}
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
    rig["Revision"] = "V2_Detailed"

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

    def set_key(frame: int, rotations: dict[str, tuple[float, float, float]], locations=None) -> None:
        bpy.context.scene.frame_set(frame)
        for bone_name, rotation in rotations.items():
            bone = rig.pose.bones[bone_name]
            bone.rotation_euler = tuple(math.radians(value) for value in rotation)
            bone.keyframe_insert("rotation_euler", frame=frame)
        for bone_name, location in (locations or {}).items():
            bone = rig.pose.bones[bone_name]
            bone.location = location
            bone.keyframe_insert("location", frame=frame)

    base_pose = {
        "Root": (0, 0, -1.5),
        "LowerTorso": (1.5, 2.5, 0),
        "Torso": (8.0, -3.0, 1.5),
        "Head": (0.0, 0.0, 0.0),
        "LeftUpperArm": (2.0, -1.0, -1.0),
        "LeftLowerArm": (-2.5, 0.0, -1.0),
        "RightUpperArm": (-1.0, 1.0, 2.0),
        "RightLowerArm": (3.5, 0.0, 1.0),
        "LeftUpperLeg": (-1.0, 0.0, -1.0),
        "RightUpperLeg": (3.0, 0.0, 2.0),
        "RightLowerLeg": (6.0, 0.0, 0.0),
    }
    set_key(1, base_pose, {"Root": (-0.055, 0, -0.02)})
    set_key(16, {**base_pose, "Torso": (9.2, -2.2, 2.3), "Head": (-0.8, -1.2, -0.6), "LeftUpperArm": (3.0, -1.0, -0.5)}, {"Root": (-0.035, 0, -0.055)})
    set_key(25, {**base_pose, "Head": (0.7, 1.4, 0.5)}, {"Root": (-0.045, 0, -0.040)})
    set_key(32, {**base_pose, "Torso": (7.2, -3.8, 0.8), "Head": (-0.5, -0.8, -0.4), "RightUpperArm": (0.5, 1.0, 2.5)}, {"Root": (-0.070, 0, -0.065)})
    set_key(48, base_pose, {"Root": (-0.055, 0, -0.02)})
    bpy.ops.object.mode_set(mode="OBJECT")
    if rig.animation_data and rig.animation_data.action:
        rig.animation_data.action.name = "Analog_V2_Unsettling_Idle"
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 48
    bpy.context.scene.frame_set(1)
    return rig


def configure_scene() -> None:
    base.configure_scene()
    scene = bpy.context.scene
    scene.name = "TheBlindOne_Analog_V2_Detailed"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 1280
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene["DesignTarget"] = "TheBlindOne_AnalogConcept_V2.png"
    scene["Revision"] = "Detailed V2 approval model"


def add_stage() -> bpy.types.Object:
    camera = base.add_stage()
    world = bpy.context.scene.world
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.16, 0.16, 0.17, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.60
    # Brighter, softer neutral review light keeps the black cloth readable.
    for light in bpy.data.lights:
        if light.name == "SoftFrontKey":
            light.energy = 1250
            light.size = 5.8
        elif light.name == "SoftFrontFill":
            light.energy = 760
        elif light.name == "BackSilhouetteRim":
            light.energy = 340
            light_obj = bpy.data.objects.get(light.name)
            if light_obj:
                light_obj.location = (0.2, 2.4, 8.0)
        elif light.name == "LowClothFill":
            light.energy = 430
    return camera


def export_model(segments: dict[str, bpy.types.Object], rig: bpy.types.Object) -> None:
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
    bpy.ops.export_scene.fbx(
        filepath=str(FBX_PATH),
        use_selection=True,
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_actions=True,
        axis_forward="-Z",
        axis_up="Y",
    )


def render_previews(camera: bpy.types.Object) -> None:
    scene = bpy.context.scene
    scene.frame_set(1)
    views = {
        "TheBlindOne_Analog_V2_front.png": ((0, -18.6, 4.38), (0, 0, 4.20), 68),
        "TheBlindOne_Analog_V2_three_quarter.png": ((7.0, -17.2, 4.65), (0, 0, 4.23), 70),
        "TheBlindOne_Analog_V2_side.png": ((18.2, 0, 4.48), (0, 0, 4.22), 69),
        "TheBlindOne_Analog_V2_back.png": ((0, 18.6, 4.38), (0, 0, 4.20), 68),
    }
    for filename, (location, target, lens) in views.items():
        backdrop = bpy.data.objects.get("PreviewBackdrop_NOT_EXPORTED")
        if backdrop:
            backdrop.location.y = -3.8 if "back" in filename else 3.8
        base.point_camera(camera, location, target, lens)
        scene.render.filepath = str(PREVIEW_DIR / filename)
        bpy.ops.render.render(write_still=True)
        print("Rendered", filename, flush=True)
    backdrop = bpy.data.objects.get("PreviewBackdrop_NOT_EXPORTED")
    if backdrop:
        backdrop.location.y = 3.8
    front = views["TheBlindOne_Analog_V2_front.png"]
    base.point_camera(camera, front[0], front[1], front[2])
    scene.render.filepath = str(PREVIEW_DIR / "TheBlindOne_Analog_V2_front.png")


def main() -> None:
    progress(2, "clearing scene")
    base.clear_scene()
    configure_scene()
    progress(7, "building layered procedural materials")
    materials = {
        "cloth": base.textured_material("V2_WornInstitutionalCloth", (0.010, 0.011, 0.012), (0.060, 0.063, 0.066), 0.965, 9.0, 0.32, (1.0, 1.0, 0.22)),
        "cloth_edge": base.textured_material("V2_DeepClothEdges", (0.004, 0.004, 0.005), (0.027, 0.029, 0.031), 0.98, 13.0, 0.25, (1.0, 1.0, 0.30)),
        "wrap": base.textured_material("V2_AgedBindings", (0.014, 0.014, 0.015), (0.078, 0.073, 0.066), 0.95, 15.0, 0.33, (1.0, 1.0, 0.16)),
        "skin": base.textured_material("V2_CharcoalHandsFeet", (0.020, 0.021, 0.021), (0.095, 0.090, 0.082), 0.93, 7.0, 0.24, (1.0, 1.0, 0.55)),
        "mask": base.textured_material("V2_AgedIvoryMask", (0.31, 0.30, 0.27), (0.72, 0.69, 0.61), 0.86, 6.0, 0.24, (1.0, 0.8, 0.45)),
        "seam": base.flat_material("V2_MaskCracksAndVoid", (0.002, 0.002, 0.002), 0.99),
        "eye_halo": base.emission_material("V2_ColdEyeHalo", (0.20, 0.38, 0.58), 2.2),
        "eye": base.emission_material("V2_ColdWhiteEyeCore", (0.84, 0.93, 1.0), 8.0),
    }
    progress(12, "building detailed body, cloth, mask and hands")
    segments = build_model(materials)
    progress(68, "building Roblox-compatible articulated rig")
    rig = add_rig(segments)
    progress(76, "adding concept reference and review stage")
    base.add_reference_image()
    camera = add_stage()
    progress(81, "saving editable V2 source")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    progress(85, "exporting Roblox GLB and FBX")
    export_model(segments, rig)
    progress(90, "rendering four approval views")
    render_previews(camera)
    progress(99, "saving final V2 source")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    progress(100, "DETAILED ANALOG V2 COMPLETE")


if __name__ == "__main__":
    main()
