from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
PREVIEWS = ROOT / "previews"
PREVIEWS.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass


def material(name, dark, light=None, roughness=0.78, metallic=0.0, bump=0.0, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if light is None:
        bsdf.inputs["Base Color"].default_value = (*dark, 1)
    else:
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 7.2
        noise.inputs["Detail"].default_value = 7.0
        noise.inputs["Roughness"].default_value = 0.72
        noise.inputs["Distortion"].default_value = 0.24
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*dark, 1)
        ramp.color_ramp.elements[1].color = (*light, 1)
        ramp.color_ramp.elements[0].position = 0.27
        ramp.color_ramp.elements[1].position = 0.78
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        if bump:
            bump_node = nodes.new("ShaderNodeBump")
            bump_node.inputs["Strength"].default_value = bump
            bump_node.inputs["Distance"].default_value = 0.13
            links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
            links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def cracked_bark_material():
    mat = bpy.data.materials.new("Layered charred bark")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.94
    bsdf.inputs["Specular IOR Level"].default_value = 0.18

    texcoord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.1, 1.1, 0.46)
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "4D"
    noise.inputs["Scale"].default_value = 5.6
    noise.inputs["Detail"].default_value = 9.5
    noise.inputs["Roughness"].default_value = 0.83
    noise.inputs["Distortion"].default_value = 1.9
    noise.inputs["W"].default_value = 0.37
    voronoi = nodes.new("ShaderNodeTexVoronoi")
    voronoi.distance = "EUCLIDEAN"
    voronoi.feature = "DISTANCE_TO_EDGE"
    voronoi.inputs["Scale"].default_value = 13.0
    crack_ramp = nodes.new("ShaderNodeValToRGB")
    crack_ramp.color_ramp.elements[0].position = 0.018
    crack_ramp.color_ramp.elements[0].color = (0.001, 0.0005, 0.0004, 1)
    crack_ramp.color_ramp.elements[1].position = 0.095
    crack_ramp.color_ramp.elements[1].color = (0.040, 0.024, 0.016, 1)
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 0.72
    mix.inputs[2].default_value = (0.18, 0.07, 0.026, 1)
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.72
    bump.inputs["Distance"].default_value = 0.18

    links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    links.new(mapping.outputs["Vector"], voronoi.inputs["Vector"])
    links.new(voronoi.outputs["Distance"], crack_ramp.inputs["Fac"])
    links.new(crack_ramp.outputs["Color"], mix.inputs[1])
    links.new(noise.outputs["Fac"], mix.inputs["Fac"])
    links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(voronoi.outputs["Distance"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    return mat


def active(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def smooth(obj):
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True


def ellipsoid(name, location, scale, mat, rough=0.025, subdivisions=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    active(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rough:
        texture = bpy.data.textures.new(name + "_surface", type="CLOUDS")
        texture.noise_scale = 0.23
        modifier = obj.modifiers.new("Cracked organic surface", "DISPLACE")
        modifier.texture = texture
        modifier.strength = rough
        modifier.mid_level = 0.53
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def cone_between(name, start, end, r_start, r_end, mat, vertices=12, bevel=0.035):
    a, b = Vector(start), Vector(end)
    direction = b - a
    length = direction.length
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=r_start,
        radius2=r_end,
        depth=length,
        location=(a + b) / 2,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction.normalized())
    active(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Worn edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def tube(name, points, radius, mat, cyclic=False, resolution=2):
    curve_data = bpy.data.curves.new(name + "_curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = resolution
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 2
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, co in zip(spline.bezier_points, points):
        point.co = co
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    active(obj)
    bpy.ops.object.convert(target="MESH")
    smooth(obj)
    return obj


def box(name, location, scale, mat, rotation=(0, 0, 0), bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    active(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Worn edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def shard(name, center, width, height, depth, mat, lean=0.0):
    x, y, z = center
    front, back = y - depth / 2, y + depth / 2
    top_z, bottom_z = z + height / 2, z - height / 2
    half = width / 2
    tip_x = x + lean
    verts = [
        (x - half, front, top_z), (x + half, front, top_z), (tip_x, front, bottom_z),
        (x - half, back, top_z), (x + half, back, top_z), (tip_x, back, bottom_z),
    ]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def join_segment(name, items):
    items = [item for item in items if item and item.name in bpy.context.view_layer.objects]
    bpy.ops.object.select_all(action="DESELECT")
    for item in items:
        item.select_set(True)
    target = items[0]
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    target.name = name
    return target


def wrap_ring(name, z, radius_x, radius_y, mat, wobble=0.0, count=36):
    points = []
    for index in range(count):
        angle = math.tau * index / count
        points.append((
            math.cos(angle) * radius_x,
            math.sin(angle) * radius_y,
            z + math.sin(angle * 3 + wobble) * 0.035,
        ))
    return tube(name, points, 0.045, mat, cyclic=True)


def band_ring(name, z, radius_x, radius_y, height, mat, tilt=0.0, count=48):
    verts = []
    faces = []
    for index in range(count):
        angle = math.tau * index / count
        wave = math.sin(angle * 3.0 + tilt * 8.0) * 0.025
        dz = math.cos(angle) * tilt
        for layer in (-1, 1):
            verts.append((
                math.cos(angle) * radius_x,
                math.sin(angle) * radius_y,
                z + dz + wave + layer * height * 0.5,
            ))
    for index in range(count):
        nxt = (index + 1) % count
        a = index * 2
        b = nxt * 2
        faces.append((a, b, b + 1, a + 1))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def bark_plates(prefix, center, spread, count, mat, seed):
    random.seed(seed)
    cx, cy, cz = center
    sx, sy, sz = spread
    items = []
    for index in range(count):
        x = cx + random.uniform(-sx, sx)
        z = cz + random.uniform(-sz, sz)
        side = random.choice((-1, 1))
        y = cy - sy * random.uniform(0.82, 1.04)
        width = random.uniform(0.10, 0.25)
        height = random.uniform(0.28, 0.72)
        items.append(shard(
            f"{prefix}_plate_{index}", (x, y, z), width, height, 0.035,
            mat, random.uniform(-0.10, 0.10) + side * 0.02,
        ))
    return items


def build_model():
    bark = cracked_bark_material()
    bark_edge = material("Splintered bark plates", (0.006, 0.004, 0.003), (0.055, 0.026, 0.014), roughness=0.96, bump=0.62)
    cloth = material("Black rotten cloth", (0.006, 0.005, 0.006), (0.028, 0.019, 0.016), roughness=1.0, bump=0.26)
    wrap = material("Ancient bindings", (0.022, 0.014, 0.011), (0.075, 0.045, 0.028), roughness=0.98, bump=0.42)
    bone = material("Old bone", (0.10, 0.078, 0.050), (0.39, 0.30, 0.19), roughness=0.9, bump=0.40)
    dark_bone = material("Antler", (0.009, 0.006, 0.004), (0.075, 0.036, 0.018), roughness=0.95, bump=0.52)
    wound = material("Dried wound", (0.018, 0.0, 0.0), (0.17, 0.004, 0.002), roughness=0.72, bump=0.18)
    eye = material("Blind white glow", (0.9, 0.96, 1.0), roughness=0.12, emission=(0.88, 0.96, 1.0), emission_strength=8.5)

    segments = {}

    # Feet and legs: slim, rooted, and deliberately uneven on the injured right side.
    left_foot = [box("LeftFootBase", (-0.52, -0.20, 0.34), (0.32, 0.64, 0.27), bark, rotation=(0.03, 0.02, 0.01), bevel=0.045)]
    left_foot += [box("LeftFootWrap", (-0.52, -0.05, 0.55), (0.37, 0.43, 0.075), wrap, rotation=(0, 0, 0.04), bevel=0.025)]
    segments["LeftFoot"] = join_segment("LeftFoot", left_foot)

    right_foot = [box("RightFootBase", (0.58, -0.11, 0.39), (0.30, 0.57, 0.26), bark, rotation=(-0.02, 0.06, -0.04), bevel=0.045)]
    right_foot += [box("RightFootWrap", (0.58, 0.0, 0.58), (0.35, 0.40, 0.075), wrap, rotation=(0, 0.08, -0.08), bevel=0.025)]
    segments["RightFoot"] = join_segment("RightFoot", right_foot)

    segments["LeftLowerLeg"] = join_segment("LeftLowerLeg", [
        cone_between("LeftShin", (-0.54, 0, 0.62), (-0.52, 0.02, 2.38), 0.28, 0.24, bark, vertices=10),
        wrap_ring("LeftShinWrapA", 0.94, 0.30, 0.27, wrap, 0.2),
        wrap_ring("LeftShinWrapB", 1.05, 0.30, 0.27, wrap, 1.1),
    ])
    segments["RightLowerLeg"] = join_segment("RightLowerLeg", [
        cone_between("RightShin", (0.58, 0.02, 0.66), (0.66, 0.07, 2.28), 0.28, 0.23, bark, vertices=10),
        wrap_ring("RightShinWrapA", 1.62, 0.30, 0.27, wrap, 0.7),
        wrap_ring("RightShinWrapB", 1.73, 0.30, 0.27, wrap, 1.8),
    ])
    segments["LeftUpperLeg"] = join_segment("LeftUpperLeg", [
        cone_between("LeftThigh", (-0.52, 0.02, 2.32), (-0.48, 0.04, 4.28), 0.31, 0.27, bark, vertices=10),
        shard("LeftLegTatter", (-0.78, 0.0, 3.56), 0.48, 1.45, 0.11, cloth, -0.12),
    ])
    segments["RightUpperLeg"] = join_segment("RightUpperLeg", [
        cone_between("RightThigh", (0.65, 0.07, 2.24), (0.49, 0.04, 4.26), 0.31, 0.27, bark, vertices=10),
        shard("RightLegTatter", (0.81, 0.02, 3.48), 0.46, 1.6, 0.11, cloth, 0.10),
    ])

    # Narrow pelvis and broad, layered upper body.
    lower_items = [
        ellipsoid("Pelvis", (0, 0.02, 4.52), (0.67, 0.46, 0.50), bark, rough=0.025),
        wrap_ring("WaistWrapA", 4.64, 0.71, 0.49, wrap, 0.3),
        wrap_ring("WaistWrapB", 4.53, 0.73, 0.50, wrap, 1.4),
    ]
    for index, (x, h, lean) in enumerate([(-0.58, 1.45, -0.12), (-0.25, 1.82, 0.05), (0.08, 1.7, -0.04), (0.42, 1.35, 0.13)]):
        lower_items.append(shard(f"WaistTatter{index}", (x, -0.02, 3.75), 0.48, h, 0.13, cloth, lean))
    segments["LowerTorso"] = join_segment("LowerTorso", lower_items)

    torso_items = [
        ellipsoid("GauntTorso", (0, 0.04, 5.95), (1.08, 0.50, 1.28), bark, rough=0.035),
        tube("SternumWound", [(0, -0.535, 6.72), (0.01, -0.575, 6.08), (-0.02, -0.535, 5.33)], 0.045, wound),
    ]
    for index in range(6):
        z = 6.62 - index * 0.23
        width = 0.48 + index * 0.070
        for side in (-1, 1):
            torso_items.append(tube(
                f"Rib_{side}_{index}",
                [(side * 0.08, -0.545, z), (side * width * 0.70, -0.61, z - 0.04), (side * width, -0.50, z - 0.14)],
                0.045 if index < 3 else 0.038,
                bone,
            ))
    # Ragged shoulder mantle and six bone spikes.
    for side in (-1, 1):
        torso_items.append(shard(f"ShoulderMantle{side}", (side * 1.00, 0.02, 6.38), 0.74, 1.22, 0.22, cloth, side * 0.16))
        for idx, x in enumerate((0.88, 1.24)):
            base = (side * x, 0.0, 6.73 - idx * 0.06)
            tip = (side * (x + 0.05 + idx * 0.02), 0.0, 7.50 - idx * 0.22)
            torso_items.append(cone_between(f"ShoulderSpike{side}_{idx}", base, tip, 0.16, 0.008, bone, vertices=8, bevel=0.006))
    # Back spine plates make the rear view as deliberate as the front.
    for index in range(7):
        z = 6.72 - index * 0.25
        torso_items.append(shard(f"SpinePlate{index}", (0, 0.67, z), 0.26, 0.38, 0.18, dark_bone, 0))
    torso_items.extend(bark_plates("Chest", (0, -0.02, 5.95), (0.92, 0.53, 1.05), 22, bark_edge, 81))
    segments["Torso"] = join_segment("Torso", torso_items)

    # Long arms, with asymmetrical bends and cloth bindings at the elbows/wrists.
    arm_specs = {
        "Left": [(-1.03, 0.03, 6.55), (-1.30, 0.02, 5.10), (-1.44, -0.01, 3.58)],
        "Right": [(1.03, 0.03, 6.48), (1.33, 0.07, 5.02), (1.53, 0.02, 3.48)],
    }
    for side_name, points in arm_specs.items():
        sign = -1 if side_name == "Left" else 1
        upper_name = side_name + "UpperArm"
        lower_name = side_name + "LowerArm"
        hand_name = side_name + "Hand"
        upper = [cone_between(upper_name + "Body", points[0], points[1], 0.29, 0.23, bark, vertices=10)]
        upper.append(shard(upper_name + "Tatter", (sign * 1.25, 0.04, 5.62), 0.34, 1.35, 0.10, cloth, sign * 0.08))
        upper.extend(bark_plates(upper_name, (sign * 1.20, -0.01, 5.76), (0.18, 0.28, 0.58), 7, bark_edge, 20 + (1 if sign > 0 else 2)))
        segments[upper_name] = join_segment(upper_name, upper)
        lower = [cone_between(lower_name + "Body", points[1], points[2], 0.25, 0.20, bark, vertices=10)]
        elbow_z = points[1][2] - 0.08
        lower.extend([
            wrap_ring(lower_name + "WrapA", elbow_z, 0.28, 0.26, wrap, sign * 0.4),
            wrap_ring(lower_name + "WrapB", elbow_z - 0.12, 0.28, 0.26, wrap, sign * 1.2),
        ])
        # Wrap rings were created around world X=0; move them to the arm.
        for item in lower[1:]:
            item.location.x = points[1][0]
        segments[lower_name] = join_segment(lower_name, lower)

        hand_center = (points[2][0] + sign * 0.03, -0.01, 3.15 if side_name == "Left" else 3.03)
        hand = [ellipsoid(hand_name + "Palm", hand_center, (0.25, 0.19, 0.41), bark, rough=0.012)]
        for finger in range(4):
            x = hand_center[0] + ((finger - 1.5) * 0.115)
            top = (x, -0.02, hand_center[2] - 0.28)
            knuckle = (x + (finger - 1.5) * 0.018, -0.08, hand_center[2] - 0.68 - abs(finger - 1.5) * 0.04)
            tip = (knuckle[0] + (finger - 1.5) * 0.035, -0.16, knuckle[2] - 0.47 - (0.10 if finger in (1, 2) else 0))
            hand.append(cone_between(hand_name + f"Finger{finger}", top, knuckle, 0.070, 0.050, bone, vertices=8, bevel=0.010))
            hand.append(cone_between(hand_name + f"Claw{finger}", knuckle, tip, 0.050, 0.005, bone, vertices=8, bevel=0.004))
        segments[hand_name] = join_segment(hand_name, hand)

    # Hooded, bandaged head with small embedded eyes and vertical tooth seam.
    head_items = [
        ellipsoid("CrackedCowl", (0, 0.0, 7.91), (0.66, 0.54, 0.72), bark, rough=0.040, subdivisions=4),
        cone_between("LongFaceMask", (0, -0.03, 7.88), (0, -0.02, 6.92), 0.52, 0.16, bark, vertices=12, bevel=0.020),
    ]
    for index, z in enumerate((8.25, 8.12, 7.99, 7.86, 7.73)):
        head_items.append(band_ring(f"HeadBinding{index}", z, 0.69 - index * 0.015, 0.565, 0.155, wrap, (-0.03 + index * 0.014), count=48))
    for x in (-0.255, 0.255):
        head_items.append(ellipsoid("EyeCore", (x, -0.568, 8.015), (0.105, 0.024, 0.032), eye, rough=0, subdivisions=3))
    head_items.append(tube("MouthSeam", [(0, -0.525, 7.64), (0.01, -0.55, 7.32), (-0.02, -0.42, 7.02)], 0.035, wound))
    for index in range(5):
        z = 7.57 - index * 0.12
        side = -1 if index % 2 == 0 else 1
        head_items.append(cone_between(f"MouthTooth{index}", (side * 0.025, -0.555, z), (-side * 0.075, -0.575, z - 0.05), 0.035, 0.007, bone, vertices=7, bevel=0.004))
    # Bone stitches over the bandage.
    for x in (-0.31, 0, 0.31):
        head_items.append(cone_between("BandageStitch", (x, -0.590, 7.84), (x, -0.592, 8.23), 0.018, 0.018, bone, vertices=7, bevel=0.004))

    # Branched antlers with knuckles instead of smooth cartoon forks.
    for side in (-1, 1):
        paths = [
            [(side * 0.40, 0.05, 8.55), (side * 0.55, 0.05, 9.10), (side * 0.84, 0.03, 9.55), (side * 0.91, 0.02, 10.34)],
            [(side * 0.68, 0.04, 9.35), (side * 1.10, 0.02, 9.63), (side * 1.22, 0.0, 10.08)],
            [(side * 0.86, 0.03, 9.67), (side * 0.58, 0.01, 10.05), (side * 0.55, 0.0, 10.48)],
            [(side * 0.58, 0.04, 9.12), (side * 0.28, 0.02, 9.45), (side * 0.24, 0.0, 9.78)],
        ]
        for path_index, path in enumerate(paths):
            for index in range(len(path) - 1):
                start_radius = max(0.045, 0.115 - (index + path_index * 0.35) * 0.020)
                head_items.append(cone_between(
                    f"Antler{side}_{path_index}_{index}", path[index], path[index + 1],
                    start_radius, max(0.014, start_radius - 0.030), dark_bone, vertices=7, bevel=0.005,
                ))
    head_items.extend(bark_plates("Face", (0, -0.02, 7.55), (0.50, 0.54, 0.68), 16, bark_edge, 119))
    segments["Head"] = join_segment("Head", head_items)

    return segments


def add_rig(segments):
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = "TheBlindOne_V7_Rig"
    armature = rig.data
    armature.name = "TheBlindOne_V7_Armature"
    armature.edit_bones.remove(armature.edit_bones[0])

    specs = {
        "Root": ((0, 0, 0.2), (0, 0, 4.15), None),
        "LowerTorso": ((0, 0, 4.12), (0, 0, 5.03), "Root"),
        "Torso": ((0, 0, 4.95), (0, 0, 6.82), "LowerTorso"),
        "Head": ((0, 0, 6.78), (0, 0, 8.55), "Torso"),
        "LeftUpperLeg": ((-0.48, 0, 4.2), (-0.52, 0, 2.25), "LowerTorso"),
        "LeftLowerLeg": ((-0.52, 0, 2.25), (-0.54, 0, 0.65), "LeftUpperLeg"),
        "LeftFoot": ((-0.54, 0, 0.65), (-0.54, -0.60, 0.30), "LeftLowerLeg"),
        "RightUpperLeg": ((0.49, 0, 4.18), (0.65, 0.06, 2.18), "LowerTorso"),
        "RightLowerLeg": ((0.65, 0.06, 2.18), (0.58, 0.02, 0.68), "RightUpperLeg"),
        "RightFoot": ((0.58, 0.02, 0.68), (0.58, -0.56, 0.34), "RightLowerLeg"),
        "LeftUpperArm": ((-1.15, 0, 6.55), (-1.47, 0, 5.20), "Torso"),
        "LeftLowerArm": ((-1.47, 0, 5.20), (-1.62, 0, 3.83), "LeftUpperArm"),
        "LeftHand": ((-1.62, 0, 3.83), (-1.65, 0, 2.72), "LeftLowerArm"),
        "RightUpperArm": ((1.15, 0, 6.48), (1.50, 0.07, 5.10), "Torso"),
        "RightLowerArm": ((1.50, 0.07, 5.10), (1.73, 0.02, 3.68), "RightUpperArm"),
        "RightHand": ((1.73, 0.02, 3.68), (1.78, 0, 2.52), "RightLowerArm"),
    }
    edit_bones = {}
    for name, (head, tail, parent) in specs.items():
        bone = armature.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = edit_bones[parent]
        edit_bones[name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True

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
            bone.rotation_euler = rotation
            bone.keyframe_insert("rotation_euler", frame=frame)
        for bone_name, location in (locations or {}).items():
            bone = rig.pose.bones[bone_name]
            bone.location = location
            bone.keyframe_insert("location", frame=frame)

    neutral = {
        "Root": (0, 0, math.radians(2)),
        "Torso": (math.radians(-5), 0, math.radians(3)),
        "Head": (math.radians(3), 0, math.radians(-2)),
        "RightUpperLeg": (math.radians(10), 0, math.radians(6)),
        "RightLowerLeg": (math.radians(22), 0, 0),
        "LeftUpperLeg": (math.radians(-4), 0, math.radians(-2)),
        "LeftLowerLeg": (0, 0, 0),
        "LeftUpperArm": (math.radians(-5), 0, math.radians(-3)),
        "RightUpperArm": (math.radians(6), 0, math.radians(5)),
    }
    key(1, neutral)
    key(9, {
        **neutral,
        "Root": (math.radians(-3), 0, math.radians(8)),
        "Torso": (math.radians(-10), math.radians(2), math.radians(9)),
        "Head": (math.radians(6), 0, math.radians(-6)),
        "LeftUpperLeg": (math.radians(27), 0, math.radians(-2)),
        "LeftLowerLeg": (math.radians(18), 0, 0),
        "RightUpperLeg": (math.radians(15), 0, math.radians(9)),
        "RightLowerLeg": (math.radians(36), 0, 0),
        "LeftUpperArm": (math.radians(-13), 0, math.radians(-5)),
        "RightUpperArm": (math.radians(10), 0, math.radians(8)),
    }, {"Root": (-0.10, 0, -0.19)})
    key(17, {
        **neutral,
        "Root": (math.radians(1), 0, math.radians(-1)),
        "Torso": (math.radians(-6), math.radians(-2), math.radians(1)),
        "LeftUpperLeg": (math.radians(-25), 0, 0),
        "LeftLowerLeg": (math.radians(28), 0, 0),
        "RightUpperLeg": (math.radians(8), 0, math.radians(7)),
        "RightLowerLeg": (math.radians(29), 0, 0),
        "LeftUpperArm": (math.radians(10), 0, math.radians(-3)),
        "RightUpperArm": (math.radians(-4), 0, math.radians(7)),
    }, {"Root": (0.04, 0, -0.03)})
    key(25, neutral, {"Root": (0, 0, 0)})
    bpy.ops.object.mode_set(mode="OBJECT")

    action = rig.animation_data.action if rig.animation_data else None
    if action:
        action.name = "Injured_Limp_Cycle"
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 25
    return rig


def add_stage():
    ground_mat = material("Ground", (0.006, 0.004, 0.003), (0.025, 0.014, 0.008), roughness=1.0, bump=0.35)
    bpy.ops.mesh.primitive_plane_add(size=45, location=(0, 0, 0))
    ground = bpy.context.object
    ground.name = "Preview_Ground"
    ground.data.materials.append(ground_mat)

    world = bpy.context.scene.world or bpy.data.worlds.new("BlindWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.001, 0.001, 0.0015, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.035

    def area(name, location, color, energy, size):
        data = bpy.data.lights.new(name, "AREA")
        data.color = color
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = ((Vector((0, 0, 5.2)) - obj.location).to_track_quat("-Z", "Y")).to_euler()
        return obj

    area("Cold_Front", (0, -10, 7), (0.24, 0.31, 0.37), 430, 5.5)
    area("Amber_Rim_Left", (-6, 2.5, 7.5), (1.0, 0.16, 0.028), 560, 4.2)
    area("Amber_Rim_Right", (6, 1.5, 6.5), (1.0, 0.11, 0.020), 390, 3.8)
    area("Top_Rim", (0, 2, 13), (0.32, 0.14, 0.06), 340, 3.0)

    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.lens = 63
    bpy.context.scene.camera = camera
    return camera


def look(camera, location, target=(0, 0, 5.25), lens=63):
    camera.location = location
    camera.data.lens = lens
    camera.rotation_euler = ((Vector(target) - camera.location).to_track_quat("-Z", "Y")).to_euler()


def configure_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 760
    scene.render.resolution_y = 1040
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_percentage = 100
    scene.render.use_file_extension = True
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.engine = "BLENDER_EEVEE_NEXT"

    scene.use_nodes = True
    nodes = scene.node_tree.nodes
    links = scene.node_tree.links
    nodes.clear()
    render_layers = nodes.new("CompositorNodeRLayers")
    glare = nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.quality = "HIGH"
    glare.threshold = 1.2
    glare.size = 6
    composite = nodes.new("CompositorNodeComposite")
    links.new(render_layers.outputs["Image"], glare.inputs["Image"])
    links.new(glare.outputs["Image"], composite.inputs["Image"])


def export_model(segments, rig):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(segments.values()) + [rig]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(ROOT / "TheBlindOne_V7.glb"),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_apply=False,
        export_yup=True,
    )
    try:
        bpy.ops.export_scene.fbx(
            filepath=str(ROOT / "TheBlindOne_V7.fbx"),
            use_selection=True,
            add_leaf_bones=False,
            bake_anim=True,
            axis_forward="-Z",
            axis_up="Y",
        )
    except Exception as exc:
        print("FBX export skipped:", exc)


def render_previews(camera):
    scene = bpy.context.scene
    scene.frame_set(1)
    views = {
        "TheBlindOne_V7_front.png": ((0, -18.7, 5.45), (0, 0, 5.25), 63),
        "TheBlindOne_V7_three_quarter.png": ((8.7, -16.7, 5.9), (0, 0, 5.25), 66),
        "TheBlindOne_V7_back.png": ((0, 18.7, 5.45), (0, 0, 5.25), 63),
    }
    for filename, (location, target, lens) in views.items():
        look(camera, location, target, lens)
        scene.render.filepath = str(PREVIEWS / filename)
        bpy.ops.render.render(write_still=True)
        print("Rendered", filename)


clear_scene()
configure_render()
segments = build_model()
rig = add_rig(segments)
camera = add_stage()
export_model(segments, rig)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "TheBlindOne_V7.blend"))
render_previews(camera)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "TheBlindOne_V7.blend"))
print("THE BLIND ONE V7 COMPLETE")
