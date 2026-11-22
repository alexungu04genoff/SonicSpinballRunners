"""Run with Blender in background mode to bake a single local Sonic Runners pose."""
from collections import Counter, defaultdict
from math import cos, radians, sin
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree


ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "experiments/visual_lab/local/runtime"
SOURCE = LOCAL / "sonic.glb"
OUTPUT = LOCAL / "sonic_sa1_combo.glb"


def verify_hip_clearance(body, rig):
    """Reject a posed leg that cuts through the torso beyond its hip socket."""
    mesh = body.data
    mesh.calc_loop_triangles()
    to_rig = rig.matrix_world.inverted() @ body.matrix_world
    coords = [to_rig @ v.co for v in mesh.vertices]
    groups = []
    for group in body.vertex_groups:
        name = group.name
        if name in {"Hips", "Spine", "Spine1", "Tail"}:
            groups.append("body")
        elif name.startswith(("Thigh_", "Calf_", "Knee_", "Foot_", "Toe_", "Socks_")):
            groups.append(name)
        else:
            groups.append("other")

    parts = defaultdict(list)
    for tri in mesh.loop_triangles:
        weight = Counter()
        for i in tri.vertices:
            for assignment in mesh.vertices[i].groups:
                weight[groups[assignment.group]] += assignment.weight
        name = weight.most_common(1)[0][0]
        if name != "other":
            parts[name].append(list(tri.vertices))
    torso = BVHTree.FromPolygons(coords, parts["body"], all_triangles=True)
    for side in ("L", "R"):
        hip = rig.pose.bones["Thigh_" + side].head
        knee = rig.pose.bones["Calf_" + side].head
        axis = (knee - hip).normalized()
        # The source thigh joins inside the pelvis. Test the portion past
        # the socket plus every triangle of the knee, shin, cuff and shoe.
        socket = hip.lerp(knee, 0.20)
        faces = []
        for tri in parts["Thigh_" + side]:
            clipped = []
            for start, end in zip(tri[-1:] + tri[:-1], tri):
                a, b = (coords[i] - socket for i in (start, end))
                da, db = a.dot(axis), b.dot(axis)
                if (da > 0) != (db > 0):
                    clipped.append(len(coords))
                    coords.append(coords[start].lerp(coords[end], da / (da - db)))
                if db > 0:
                    clipped.append(end)
            if len(clipped) >= 3:
                faces.append(clipped)
        for name in ("Calf_", "Knee_", "Foot_", "Toe_", "Socks_"):
            faces.extend(parts[name + side])
        if torso.overlap(BVHTree.FromPolygons(coords, faces)):
            raise ValueError(f"{side} leg intersects the torso outside the hip socket")


def bake():
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.find_armature() == rig)
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()

    def orient(name, rotation):
        bone = rig.pose.bones[name]
        basis = rotation @ bone.bone.matrix_local.to_quaternion()
        bone.matrix = Matrix.LocRotScale(bone.head.copy(), basis, Vector((1, 1, 1)))
        bpy.context.view_layer.update()

    def face(name, forward, top):
        # The source faces -Y with +Z up. Set the two visible axes explicitly
        # so turning the head or kicking a shoe up doesn't expose its back.
        front = Vector(forward).normalized()
        right = Vector(top).cross(front).normalized()
        up = front.cross(right).normalized()
        orient(name, Matrix((right, -front, up)).transposed().to_quaternion())

    def aim(name, downstream, direction):
        start = rig.data.bones[name].head_local
        rest = (rig.data.bones[downstream].head_local - start).normalized()
        target = Vector(direction).normalized()
        orient(name, rest.rotation_difference(target))

    def glove(side, pointing, thumb):
        sign = 1 if side == "L" else -1
        across = Vector(pointing).normalized() * sign
        normal = across.cross(-Vector(thumb)).normalized()
        back = normal.cross(across)
        orient("Hand_" + side, Matrix((across, back, normal)).transposed().to_quaternion())
        for finger, curls in {"Middle": (66, 75), "Ring": (82, 86), "Pinky": (88, 85),
                              "Index": (3, 16)}.items():
            for joint, angle in enumerate(curls, 1):
                bone = rig.pose.bones[f"{finger}{joint}_{side}"]
                rest = bone.bone.matrix_local.to_quaternion()
                curl = Quaternion(Vector((0, 1, 0)), radians(angle * sign))
                bone.rotation_quaternion = rest.inverted() @ curl @ rest
        bpy.context.view_layer.update()

    def leg(side, thigh_direction, shin_direction, ankle_flex):
        # Keep hip, knee and ankle in one bend plane. The shoe points in
        # the knee's direction and flexes around the same lateral axis.
        thigh = Vector(thigh_direction).normalized()
        shin = Vector(shin_direction).normalized()
        forward = (thigh - shin * thigh.dot(shin)).normalized()
        side_axis = (-shin).cross(forward).normalized()

        def align_segment(name, child, direction):
            joint = rig.data.bones[name]
            rest = (rig.data.bones[child].head_local - joint.head_local).normalized()
            rest_axis = (-rest).cross(Vector((0, -1, 0))).normalized()
            source = Matrix((rest_axis, (-rest).cross(rest_axis), -rest)).transposed()
            target = Matrix((side_axis, (-direction).cross(side_axis), -direction)).transposed()
            rotation = (target @ source.transposed()).to_quaternion()
            orient(name, rotation)
            return rotation

        thigh_rotation = align_segment("Thigh_" + side, "Calf_" + side, thigh)
        shin_rotation = align_segment("Calf_" + side, "Foot_" + side, shin)
        orient("Knee_" + side, thigh_rotation.slerp(shin_rotation, 0.5))
        angle = radians(ankle_flex)
        face("Foot_" + side, forward * cos(angle) + shin * sin(angle), -shin)

    # Compose the tucked SA1 silhouette in the play camera's image plane.
    # The face looks down over the upright sneaker. The two pointing gloves
    # frame it on opposite diagonals; both red uppers remain visible.
    face("Hips", (-0.86, -0.48, -0.16), (-0.31, 0.12, 0.94))
    face("Spine", (-0.44, -0.84, -0.32), (-0.91, 0.04, 0.42))
    face("Head", (-0.50, -0.79, -0.37), (-0.79, 0.07, 0.63))
    aim("UpperArm_L", "ForeArm_L", (0.72, -0.42, 0.65))
    aim("ForeArm_L", "Hand_L", (0.9, -0.33, 0.52))
    glove("L", (0.96, -0.36, -0.31), (0.03, -0.2, 1))
    aim("UpperArm_R", "ForeArm_R", (0.38, -0.80, -0.72))
    aim("ForeArm_R", "Hand_R", (0.27, -0.72, -0.85))
    glove("R", (-0.65, -0.48, -0.91), (0.05, -0.38, 1))
    # The far thigh drops behind the pelvis before the shin folds outward.
    # The near knee leads the kick in front of the opposite hip.
    leg("R", (-0.489, 0.600, -0.634), (-0.953, -0.186, 0.240), -16)
    leg("L", (0.168, -0.096, -0.981), (0.857, 0.087, -0.509), -21)
    for side in ("L", "R"):
        rig.pose.bones["Hand_" + side].scale *= 1.18
    bpy.context.view_layer.update()

    # The Runners eyes have textured irises. Direct the gaze toward the
    # viewer over the raised shoe, using the existing left and right textures.
    mesh = body.data
    uv_layer = mesh.uv_layers.active.data
    for polygon in mesh.polygons:
        if mesh.materials[polygon.material_index].name.startswith("chr_sonic_eye"):
            for index in polygon.loop_indices:
                uv = uv_layer[index].uv
                uv.x = 0.50 + (uv.x - 0.61) * 0.85
                uv.y = 1.50 + (uv.y - 1.62) * 0.90
    export_pose(body, rig)


def export_pose(body, rig):
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = body.evaluated_get(depsgraph)
    verify_hip_clearance(evaluated, rig)
    mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
    mesh.transform(evaluated.matrix_world)
    coords = [vertex.co for vertex in mesh.vertices]
    lo = Vector(tuple(min(p[i] for p in coords) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in coords) for i in range(3)))
    # Unit height and a centered pivot let gameplay size the pose in Ball radii.
    mesh.transform(Matrix.Scale(1 / (hi.z - lo.z), 4) @ Matrix.Translation(-(lo + hi) / 2))
    posed = bpy.data.objects.new("SonicAdventureComboPose", mesh)
    bpy.context.collection.objects.link(posed)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    posed.select_set(True)
    bpy.context.view_layer.objects.active = posed
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), use_selection=True, export_format="GLB",
                              export_animations=False, export_skins=False, export_cameras=False,
                              export_lights=False)
    print(f"Static combo pose: {OUTPUT}")


if __name__ == "__main__":
    if "--from-rig" in sys.argv:
        rig = bpy.context.view_layer.objects.active
        if not rig or rig.type != "ARMATURE":
            raise ValueError("Select the Sonic armature in the saved Blender scene.")
        skin = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.find_armature() == rig)
        export_pose(skin, rig)
    else:
        bake()
