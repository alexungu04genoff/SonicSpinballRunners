"""Bake Sonic's four Runners poses and a directional color map for the roll shader.

Run in background Blender with the extracted, animated Sonic GLB available locally.
"""
from math import cos, floor, pi, radians, sin, tau
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1] / "experiments/visual_lab/local"
SOURCE = ROOT / "runners-decomp/sonic/Sonic Runners - original animations.glb"
OUTPUT = ROOT / "runtime/sonic_runners_poses.glb"
TRICKS = {"sn_jump_trick": -40, "sn_jump_trick_02": -60, "sn_jump_trick_03": -43}


def bake_roll_map(mesh):
    """Sample the outermost original texel in each direction around the X roll axis."""
    mesh.calc_loop_triangles()
    triangles = mesh.loop_triangles
    coords = [vertex.co.copy() for vertex in mesh.vertices]
    tree = BVHTree.FromPolygons(coords, [tuple(t.vertices) for t in triangles], all_triangles=True)
    uv = mesh.uv_layers.active.data
    images = []
    for material in mesh.materials:
        texture = next(n.image for n in material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
        w, h = texture.size
        pixels = np.empty(w * h * 4, dtype=np.float32)
        texture.pixels.foreach_get(pixels)
        images.append(pixels.reshape(h, w, 4))

    w, h = 256, 96
    output = np.empty((h, w, 4), dtype=np.float32)
    for row in range(h):
        polar = pi * (row + 0.5) / h
        for col in range(w):
            angle = tau * ((col + 0.5) / w - 0.5)
            # Godot (+X, +Y, +Z) is Blender (+X, +Z, -Y).
            ray = Vector((cos(polar), -sin(polar) * sin(angle), sin(polar) * cos(angle)))
            point, _, hit, _ = tree.ray_cast(ray * 2, -ray, 4)
            if hit is None:
                raise ValueError("The centered curl has no surface along a roll-map direction.")
            tri = triangles[hit]
            a, b, c = (coords[i] for i in tri.vertices)
            ab, ac, ap = b - a, c - a, point - a
            normal = ab.cross(ac)
            s = ap.cross(ac).dot(normal) / normal.length_squared
            t = ab.cross(ap).dot(normal) / normal.length_squared
            uv0, uv1, uv2 = (uv[i].uv for i in tri.loops)
            u, v = uv0 * (1 - s - t) + uv1 * s + uv2 * t
            source = images[tri.material_index]
            th, tw = source.shape[:2]
            output[h - 1 - row, col] = source[floor(v * th) % th, floor(u * tw) % tw]
    output[:, :, 3] = 1
    texture = bpy.data.images.new("Sonic roll exposure", width=w, height=h, alpha=False)
    texture.pixels.foreach_set(output.ravel())
    texture.filepath_raw = str(OUTPUT.with_suffix(".png"))
    texture.file_format = "PNG"
    texture.save()


def bake():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 60
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    skin = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.find_armature() == rig)
    data = rig.animation_data
    for track in data.nla_tracks:
        track.mute = True
    def first_frame(action):
        data.action = action
        data.action_slot = next(slot for slot in action.slots if slot.target_id_type == "OBJECT")
        bpy.context.scene.frame_set(round(action.frame_range[0]))
        return skin.evaluated_get(bpy.context.evaluated_depsgraph_get())

    centers = {}
    for action in bpy.data.actions:
        evaluated = first_frame(action)
        points = np.array([evaluated.matrix_world @ v.co for v in evaluated.data.vertices])
        x, y, z = (points.min(axis=0) + points.max(axis=0)) / 2
        centers[action.name] = [float(x), float(z), float(-y)]
    posed = []
    curled_radius = None
    for name, yaw in {"sn_ball_loop": 0, **TRICKS}.items():
        evaluated = first_frame(bpy.data.actions[name])
        deps = bpy.context.evaluated_depsgraph_get()
        mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=deps)
        mesh.transform(Matrix.Rotation(radians(-yaw), 4, "Z") @ evaluated.matrix_world)
        coords = [v.co.copy() for v in mesh.vertices]
        low = Vector([min(p[i] for p in coords) for i in range(3)])
        high = Vector([max(p[i] for p in coords) for i in range(3)])
        center = (low + high) / 2
        if name == "sn_ball_loop":
            curled_radius = max((v - center).length for v in coords)
        # One source-to-game scale keeps Sonic's anatomy the same size when
        # his arms and legs unfold. Each pose is only recentered and turned.
        mesh.transform(Matrix.Scale(1 / curled_radius, 4) @ Matrix.Translation(-center))
        mesh["runners_source_radius"] = curled_radius
        mesh.name = name
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        posed.append(obj)
        if name == "sn_ball_loop":
            mesh["preview_centers"] = centers
            bake_roll_map(mesh)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in posed:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = posed[0]
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), use_selection=True, export_format="GLB",
                              export_animations=False, export_skins=False, export_cameras=False,
                              export_lights=False, export_extras=True)


if __name__ == "__main__":
    bake()
