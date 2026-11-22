"""Sample the packed Runners GLB skin in the same Y-up space as Godot."""
import json
import struct

import numpy as np


def clip_bounds(path):
    source = path.read_bytes()
    size = struct.unpack_from("<I", source, 12)[0]
    doc = json.loads(source[20:20 + size])
    binary = memoryview(source)[28 + size:]

    def read(index):
        acc = doc["accessors"][index]
        view = doc["bufferViews"][acc["bufferView"]]
        dtype = np.dtype({5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}[acc["componentType"]])
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc["type"]]
        stride = view.get("byteStride", width * dtype.itemsize)
        return np.ndarray((acc["count"], width), dtype=dtype, buffer=binary,
                          offset=view.get("byteOffset", 0) + acc.get("byteOffset", 0),
                          strides=(stride, dtype.itemsize))

    nodes = doc["nodes"]
    skin = doc["skins"][0]
    binds = read(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    positions, weights, joints = [], [], []
    for primitive in doc["meshes"][0]["primitives"]:
        att = primitive["attributes"]
        used = np.unique(read(primitive["indices"]))
        positions.append(read(att["POSITION"])[used])
        weights.append(read(att["WEIGHTS_0"])[used])
        joints.append(read(att["JOINTS_0"])[used])
    positions = np.concatenate(positions)
    points = np.column_stack((positions, np.ones(len(positions))))
    joints, weights = np.concatenate(joints), np.concatenate(weights)
    tracks = {}
    fronts = {}
    for clip in doc["animations"]:
        samplers = clip["samplers"]
        end = max(float(read(s["input"])[-1, 0]) for s in samplers)
        times = np.linspace(0, end, round(end * 60) + 1)
        poses = {}
        for prop, default in [("translation", [0, 0, 0]), ("rotation", [0, 0, 0, 1]), ("scale", [1, 1, 1])]:
            rest = np.array([n.get(prop, default) for n in nodes], dtype=float)
            poses[prop] = np.repeat(rest[None], len(times), axis=0)
        for channel in clip["channels"]:
            sampler = samplers[channel["sampler"]]
            target = channel["target"]
            keys, values = read(sampler["input"])[:, 0], read(sampler["output"])
            poses[target["path"]][:, target["node"]] = np.stack(
                [np.interp(times, keys, component) for component in values.T], axis=-1)
        q = poses["rotation"]
        x, y, z, w = np.moveaxis(q / np.linalg.norm(q, axis=-1, keepdims=True), -1, 0)
        transforms = np.zeros((*q.shape[:2], 4, 4))
        transforms[..., 3, 3] = 1
        for row, vals in enumerate([(1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)),
                                    (2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)),
                                    (2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y))]):
            transforms[..., row, :3] = np.stack(vals, axis=-1) * poses["scale"]
        transforms[..., :3, 3] = poses["translation"]

        def visit(index):
            for child in nodes[index].get("children", []):
                transforms[:, child] = transforms[:, index] @ transforms[:, child]
                visit(child)

        for root in doc["scenes"][doc["scene"]]["nodes"]:
            visit(root)
        name = clip["name"]
        centers = []
        # Ground headings repeat every quarter turn for an axis-aligned box.
        # Flight also uses these samples when steering 30 degrees either way.
        yaw_tracks = {}
        if name.endswith("_boost_loop") or name in ("tl_jump_bunk_loop", "ru_jump_bunk_loop"):
            for yaw in range(15, 90, 15):
                angle = np.deg2rad(yaw)
                yaw_tracks[yaw] = (np.array([[np.cos(angle), np.sin(angle)],
                                              [-np.sin(angle), np.cos(angle)]]), [])
        for frame, matrices in enumerate(transforms[:, skin["joints"]] @ binds):
            xyz = np.einsum("vjab,vb,vj->va", matrices[joints], points, weights)[:, :3]
            high = xyz.max(axis=0)
            center = (xyz.min(axis=0) + high) / 2
            centers.extend(center.tolist())
            for rotation, track in yaw_tracks.values():
                flat = xyz[:, [0, 2]] @ rotation.T
                cx, cz = ((flat.min(axis=0) + flat.max(axis=0)) / 2) @ rotation
                track.extend((float(cx), float(center[1]), float(cz)))
            if frame == 0:
                fronts[clip["name"]] = float(high[2] - center[2])
        tracks[name] = centers
        for yaw, (_, track) in yaw_tracks.items():
            tracks[f"{name}@{yaw}"] = track
    return tracks, fronts
