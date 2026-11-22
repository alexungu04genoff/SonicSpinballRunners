"""Bake original Runners poses and a directional color map for the roll shader.

Pass a supported character ID after "--" to bake that character's poses.
"""
import json
from math import cos, floor, pi, radians, sin, tau
from pathlib import Path
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, str(Path(__file__).resolve().parent))
from runners_clip_bounds import clip_bounds

ROOT = Path(__file__).resolve().parents[1] / "experiments/visual_lab/local"
CHARACTER = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "sonic"
PREFIX, CURL, ANGLES = {
    "sonic": ("sn", "sn_ball_loop", (-40, -60, -43)),
    "tails": ("tl", "tl_jump_ball_loop", (-35, -40, -38)),
    "knuckles": ("kn", "kn_jump_ball_loop", (-45, -65, -40)),
    "shadow": ("sh", "sh_jump_ball_loop", (-40, -40, -20)),
    "rouge": ("ru", "ru_jump_ball_loop", (-40, -45, -25)),
    "amy": ("am", "am_jump_ball_loop", (-40, -45, -25)),
    "blaze": ("bl", "bl_jump_ball_loop", (-40, -45, -25)),
}[CHARACTER]
SOURCE = ROOT / "runners-decomp" / CHARACTER / f"{CHARACTER.title()} Runners - original animations.glb"
OUTPUT = ROOT / "runtime" / f"{CHARACTER}_runners_poses.glb"
TRICKS = dict(zip([f"{PREFIX}_jump_trick{n}" for n in ("", "_02", "_03")], ANGLES))


def split_tails(mesh, tail_vertices):
    """Keep both meshes in the same curl-centered space and preserve their UVs."""
    for face in mesh.polygons:
        flags = [i in tail_vertices for i in face.vertices]
        if any(flags) != all(flags):
            raise ValueError("A tail shares a face with the body. Check the skin weights.")
    tails = mesh.copy()
    indices = tails.attributes.new("source_vertex", "INT", "POINT")
    indices.data.foreach_set("value", np.arange(len(tails.vertices), dtype=np.int32))
    for part, keep_tails in ((mesh, False), (tails, True)):
        edit = bmesh.new()
        edit.from_mesh(part)
        remove = [v for v in edit.verts if (v.index in tail_vertices) != keep_tails]
        bmesh.ops.delete(edit, geom=remove, context="VERTS")
        edit.to_mesh(part)
        edit.free()
        if not part.polygons:
            raise ValueError("The curl must contain both a body and detached tail meshes.")
    tails.name = "tl_roll_tails"
    return tails


def bake_tail_motion(obj, skin, action, center, radius):
    """Sample the original deformed tail islands in heading space across one body revolution."""
    indices = obj.data.attributes["source_vertex"]
    original = [item.value for item in indices.data]
    obj.data.attributes.remove(indices)
    obj.shape_key_add(name="Basis")
    start, end = map(round, action.frame_range)
    for step in range(1, end - start):
        bpy.context.scene.frame_set(start + step)
        sample = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
        key = obj.shape_key_add(name=f"roll_{step:02d}")
        for dest, src in zip(key.data, original):
            dest.co = (sample.matrix_world @ sample.data.vertices[src].co - center) / radius
    bpy.context.scene.frame_set(start)


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
                # Some characters leave small gaps between limbs in their curl.
                # Use the nearest visible texel so the exposure map remains solid.
                point, _, hit, _ = tree.find_nearest(ray)
            if hit is None:
                raise ValueError("The centered curl has no usable surface for the roll map.")
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
    texture = bpy.data.images.new("Roll exposure", width=w, height=h, alpha=False)
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
    if "--save-blend" in sys.argv:
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_suffix(".blend")))
    data = rig.animation_data
    for track in data.nla_tracks:
        track.mute = True
    def first_frame(action):
        data.action = action
        data.action_slot = next(slot for slot in action.slots if slot.target_id_type == "OBJECT")
        bpy.context.scene.frame_set(round(action.frame_range[0]))
        return skin.evaluated_get(bpy.context.evaluated_depsgraph_get())

    center_tracks, fronts = clip_bounds(SOURCE)
    centers = {clip: track[:3] for clip, track in center_tracks.items() if "@" not in clip}
    posed = []
    curled_radius = None
    for name, yaw in {CURL: 0, **TRICKS}.items():
        evaluated = first_frame(bpy.data.actions[name])
        deps = bpy.context.evaluated_depsgraph_get()
        mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=deps)
        mesh.transform(Matrix.Rotation(radians(-yaw), 4, "Z") @ evaluated.matrix_world)
        coords = [v.co.copy() for v in mesh.vertices]
        body = coords
        tail_vertices = set()
        if name == CURL and CHARACTER == "tails":
            tails = {g.index for g in skin.vertex_groups if g.name.startswith("Tail")}
            tail_vertices = {v.index for v in mesh.vertices
                             if sum(g.weight for g in v.groups if g.group in tails) >= 0.5}
            if not tail_vertices:
                raise ValueError("The original tail joints have no vertices in the curl.")
            body = [p for i, p in enumerate(coords) if i not in tail_vertices]
        low = Vector([min(p[i] for p in body) for i in range(3)])
        high = Vector([max(p[i] for p in body) for i in range(3)])
        center = (low + high) / 2
        if name == CURL:
            curled_radius = max((v - center).length for v in body)
        # A single character scale preserves proportions when a trick unfolds.
        mesh.transform(Matrix.Scale(1 / curled_radius, 4) @ Matrix.Translation(-center))
        if tail_vertices:
            tails_mesh = split_tails(mesh, tail_vertices)
            tails_object = bpy.data.objects.new(tails_mesh.name, tails_mesh)
            bpy.context.collection.objects.link(tails_object)
            bake_tail_motion(tails_object, skin, bpy.data.actions[CURL], center, curled_radius)
            posed.append(tails_object)
        mesh["runners_source_radius"] = curled_radius
        mesh.name = name
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        posed.append(obj)
        if name == CURL:
            mesh["preview_centers"] = centers
            mesh["pose_center_tracks"] = center_tracks
            if CHARACTER in ["knuckles", "blaze"]:
                attack_name = f"{PREFIX}_jump_bunk_loop"
                mesh["slam_front"] = fronts[attack_name]
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
