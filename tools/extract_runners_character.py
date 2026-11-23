"""Export a local Runners character or field model and its controller clips to GLB.

Usage: python tools/extract_runners_character.py amy (requires NumPy and PyYAML).
The checkout and output live under experiments/visual_lab/local/runners-decomp.
"""
import argparse
import json
import re
import struct
import subprocess
from pathlib import Path

import numpy as np
import yaml
from optimize_runners_models import bake_generated


LOCAL = Path(__file__).resolve().parents[1] / "experiments/visual_lab/local/runners-decomp"
SOURCE = LOCAL / "RunnersAssetBundleDecomp"
GUID = re.compile(r"guid: ([0-9a-f]{32})")
REFLECTION = np.diag([-1, 1, 1, 1])


def documents(path):
    parts = re.split(r"^--- !u!(\d+) &(\d+)\s*\n", path.read_text(encoding="utf-8"), flags=re.M)
    for kind, file_id, raw in zip(parts[1::3], parts[2::3], parts[3::3]):
        yield kind, file_id, next(iter(yaml.load(raw, Loader=yaml.CBaseLoader).values()))


def vector(mapping, axes):
    return np.array([float(mapping[axis]) for axis in axes])


class Buffer:
    def __init__(self):
        self.data = bytearray()
        self.views = []
        self.accessors = []

    def view(self, data):
        self.data.extend(b"\0" * (-len(self.data) % 4))
        self.views.append(dict(buffer=0, byteOffset=len(self.data), byteLength=len(data)))
        self.data.extend(data)
        return len(self.views) - 1

    def accessor(self, data, shape, dtype="<f4", bounds=False):
        data = np.ascontiguousarray(data, dtype=dtype)
        item = dict(bufferView=self.view(data.tobytes()), type=shape, count=len(data),
                    componentType={"<u2": 5123, "<f4": 5126}[dtype])
        if bounds:
            values = data.reshape(len(data), -1)
            item.update(min=values.min(axis=0).tolist(), max=values.max(axis=0).tolist())
        self.accessors.append(item)
        return len(self.accessors) - 1

    def write(self, path, scene):
        scene.update(buffers=[dict(byteLength=len(self.data))], bufferViews=self.views, accessors=self.accessors)
        header = json.dumps(scene, separators=(",", ":")).encode()
        header += b" " * (-len(header) % 4)
        self.data.extend(b"\0" * (-len(self.data) % 4))
        path.write_bytes(struct.pack("<4sIIII", b"glTF", 2, 28 + len(header) + len(self.data),
                                     len(header), 0x4E4F534A) + header +
                         struct.pack("<II", len(self.data), 0x004E4942) + self.data)


def hierarchy(scene_path, actor_root=None):
    rows = list(documents(scene_path))
    names = {i: d["m_Name"] for kind, i, d in rows if kind == "1"}
    transforms = {i: d for kind, i, d in rows if kind == "4"}
    def name(row):
        return names[row["m_GameObject"]["fileID"]]
    animator = next(d for kind, _, d in rows if kind == "95" and (actor_root is None or name(d) == actor_root))
    root = next(i for i, t in transforms.items() if t["m_GameObject"] == animator["m_GameObject"])
    nodes, paths, indices = [], {}, {}
    def visit(file_id, path):
        t = transforms[file_id]
        index = len(nodes)
        indices[file_id] = paths[path] = index
        node = dict(name=name(t), translation=(vector(t["m_LocalPosition"], "xyz") * [-1, 1, 1]).tolist(),
                    rotation=(vector(t["m_LocalRotation"], "xyzw") * [1, -1, -1, 1]).tolist(),
                    scale=vector(t["m_LocalScale"], "xyz").tolist())
        nodes.append(node)
        for child in t["m_Children"] or []:
            child_id = child["fileID"]
            child_path = (path + "/" + name(transforms[child_id])).lstrip("/")
            node.setdefault("children", []).append(visit(child_id, child_path))
        return index
    visit(root, "")
    objects = {transforms[i]["m_GameObject"]["fileID"]: index for i, index in indices.items()}
    components = {(d["m_GameObject"]["fileID"], kind): d for kind, _, d in rows if "m_GameObject" in d}
    return animator, nodes, paths, indices, objects, components


def geometry(mesh, buf):
    vertices = mesh["m_VertexData"]
    raw = bytes.fromhex(vertices["_typelessdata"])
    def channel(index):
        ch = vertices["m_Channels"][index]
        stream = vertices["m_Streams"][int(ch["stream"])]
        if ch["format"] != "0":
            raise ValueError("Expected float vertex data")
        return np.ndarray((int(vertices["m_VertexCount"]), int(ch["dimension"])), dtype="<f4",
                          buffer=raw, offset=int(stream["offset"]) + int(ch["offset"]),
                          strides=(int(stream["stride"]), 4)).copy()
    positions, normals, uv = channel(0), channel(1), channel(3)
    positions[:, 0] *= -1
    normals[:, 0] *= -1
    uv[:, 1] = 1 - uv[:, 1]
    triangles = np.frombuffer(bytes.fromhex(mesh["m_IndexBuffer"]), dtype="<u2").reshape(-1, 3)
    a, b, c = positions[triangles].transpose(1, 0, 2)
    if (np.cross(b - a, c - a) * normals[triangles].mean(axis=1)).sum() < 0:
        triangles = triangles[:, [0, 2, 1]]
    attributes = dict(POSITION=buf.accessor(positions, "VEC3", bounds=True), NORMAL=buf.accessor(normals, "VEC3"),
                      TEXCOORD_0=buf.accessor(uv, "VEC2"))
    primitives = []
    for index, sub in enumerate(mesh["m_SubMeshes"]):
        start, count = int(sub["firstByte"]) // 6, int(sub["indexCount"]) // 3
        indices = buf.accessor(triangles[start:start + count].flatten(), "SCALAR", "<u2")
        primitives.append(dict(attributes=attributes, indices=indices, material=index))
    return primitives


def mesh_data(mesh, buf):
    primitives = geometry(mesh, buf)
    attributes = primitives[0]["attributes"]
    skin = mesh["m_Skin"]
    weights = np.array([[float(row[f"weight[{i}]"]) for i in range(4)] for row in skin])
    if not np.allclose(weights.sum(axis=1), 1, atol=2e-5):
        raise ValueError("Invalid skin weights")
    joints = [[int(row[f"boneIndex[{i}]"]) for i in range(4)] for row in skin]
    attributes.update(JOINTS_0=buf.accessor(joints, "VEC4", "<u2"), WEIGHTS_0=buf.accessor(weights, "VEC4"))
    bind = np.array([[[float(m[f"e{i}{j}"]) for j in range(4)] for i in range(4)] for m in mesh["m_BindPose"]])
    inverse_bind = buf.accessor((REFLECTION @ bind @ REFLECTION).transpose(0, 2, 1), "MAT4")
    return primitives, inverse_bind


def sample(keys, times, axes):
    # Sample Unity's Hermite curves with the authored endpoint tangents.
    ts = np.array([float(k["time"]) for k in keys])
    values = np.array([vector(k["value"], axes) for k in keys])
    if len(ts) == 1:
        return np.repeat(values, len(times), axis=0)
    left = (np.searchsorted(ts, times, side="right") - 1).clip(0, len(ts) - 2)
    span = (ts[left + 1] - ts[left])[:, None]
    u = ((times[:, None] - ts[left, None]) / span).clip(0, 1)
    outgoing = np.array([vector(k["outSlope"], axes) for k in keys])
    incoming = np.array([vector(k["inSlope"], axes) for k in keys])
    return ((2*u**3 - 3*u**2 + 1)*values[left] + (u**3 - 2*u**2 + u)*span*outgoing[left]
            + (-2*u**3 + 3*u**2)*values[left + 1] + (u**3 - u**2)*span*incoming[left + 1])


def animation(path, paths, buf):
    clip = next(documents(path))[2]
    # One Blaze pose retains numeric IDs in the decompilation. Its remaining
    # position and rotation tracks follow the first trick's joint order.
    if path.stem == "bl_jump_trick_02":
        reference = next(documents(path.with_name("bl_jump_trick.anim")))[2]
        tracks = [c["path"] for c in clip["m_PositionCurves"]]
        missing = [c["path"] for c in reference["m_PositionCurves"] if c["path"] not in tracks]
        numeric = [key for key in tracks if key.isdecimal()]
        if len(numeric) != len(missing) or tracks != [c["path"] for c in clip["m_RotationCurves"]]:
            raise ValueError("Unexpected Blaze trick track layout")
        paths = {**paths, **{key: paths[name] for key, name in zip(numeric, missing)}}
    end = float(clip["m_AnimationClipSettings"]["m_StopTime"])
    times = np.linspace(0, end, round(end * float(clip["m_SampleRate"])) + 1)
    timeline = buf.accessor(times, "SCALAR", bounds=True)
    samplers, channels = [], []
    for field, target, axes, sign in [("Position", "translation", "xyz", [-1, 1, 1]),
                                      ("Rotation", "rotation", "xyzw", [1, -1, -1, 1]),
                                      ("Scale", "scale", "xyz", [1, 1, 1])]:
        for curve in clip[f"m_{field}Curves"] or []:
            values = sample(curve["curve"]["m_Curve"], times, axes) * sign
            if target == "rotation":
                values /= np.linalg.norm(values, axis=1, keepdims=True)
                for i in range(1, len(values)):
                    if values[i] @ values[i - 1] < 0:
                        values[i] *= -1
            if not np.isfinite(values).all():
                raise ValueError(f"Invalid samples in {path.name}")
            output = buf.accessor(values, "VEC" + str(len(axes)))
            channels.append(dict(sampler=len(samplers), target=dict(node=paths[curve["path"]], path=target)))
            samplers.append(dict(input=timeline, output=output, interpolation="LINEAR"))
    return dict(name=clip["m_Name"], samplers=samplers, channels=channels)


def export(character):
    listing = subprocess.check_output(["git", "-C", str(SOURCE), "grep", "-I", "-e", "^guid: ", "--", "*.meta"], text=True)
    assets = {guid: SOURCE / name[:-5] for name, guid in (line.split(":guid: ", 1) for line in listing.splitlines())}
    title = character.capitalize()
    actor_root = {"beeton": "enm_beeton", "ganigani": "enm_ganigani", "eggpawn": "enm_eggpawn",
                  "flicky": "ani_flicky"}.get(character)
    scene = "CommonEnemyResource.unity" if actor_root else f"CharacterModel{title}.unity"
    animator, nodes, paths, indices, objects, components = hierarchy(SOURCE / scene, actor_root)
    buf = Buffer()
    materials, images, image_paths, material_ids = [], [], [], {}
    def material(guid):
        if guid in material_ids:
            return material_ids[guid]
        mat = assets[guid]
        diffuse = mat.read_text(encoding="utf-8").split("name: _DifTex", 1)[1]
        texture = assets[GUID.search(diffuse).group(1)]
        if texture not in image_paths:
            image_paths.append(texture)
            images.append(dict(name=texture.stem, mimeType="image/png", bufferView=buf.view(texture.read_bytes())))
        material_ids[guid] = len(materials)
        # The Flicky has an inverted outline shell that must only draw its front faces.
        materials.append(dict(name=mat.stem, doubleSided=character != "flicky", pbrMetallicRoughness=dict(
            baseColorTexture=dict(index=image_paths.index(texture)), metallicFactor=0, roughnessFactor=0.93)))
        return material_ids[guid]

    meshes, skins, roots = [], [], [0]
    # Keep the original body renderer selection for characters and Badniks.
    skinned_body = next((go for go, kind in components if kind == "137" and go in objects
                         and (actor_root or nodes[objects[go]]["name"] == "Mesh_Body")), None)
    for go, index in objects.items():
        if go == skinned_body:
            renderer = components[(go, "137")]
            mesh = next(documents(assets[renderer["m_Mesh"]["guid"]]))[2]
            joints = [indices[bone["fileID"]] for bone in renderer["m_Bones"]]
            if len(mesh["m_BindPose"]) != len(joints):
                raise ValueError("Joint and inverse bind matrix counts differ")
            primitives, binds = mesh_data(mesh, buf)
            roots.append(len(nodes))
            nodes.append(dict(name=title + " mesh", skin=len(skins), mesh=len(meshes)))
            skins.append(dict(joints=joints, inverseBindMatrices=binds))
            mesh_name = title
        elif character == "flicky" and (go, "33") in components:
            renderer = components[(go, "23")]
            mesh = next(documents(assets[components[(go, "33")]["m_Mesh"]["guid"]]))[2]
            primitives = geometry(mesh, buf)
            nodes[index]["mesh"] = len(meshes)
            mesh_name = nodes[index]["name"]
        else:
            continue
        for primitive, slot in zip(primitives, renderer["m_Materials"], strict=True):
            primitive["material"] = material(slot["guid"])
        meshes.append(dict(name=mesh_name, primitives=primitives))
    if not meshes:
        raise ValueError(f"No renderable mesh found for {title}")
    controller = assets[animator["m_Controller"]["guid"]].read_text(encoding="utf-8")
    clips = sorted({assets[g] for g in GUID.findall(controller) if g in assets and assets[g].suffix == ".anim"})
    animations = [animation(path, paths, buf) for path in clips]
    output = LOCAL / character / f"{title} Runners - original animations.glb"
    output.parent.mkdir(exist_ok=True)
    result = dict(asset=dict(version="2.0"), scene=0, scenes=[dict(nodes=roots)], nodes=nodes, meshes=meshes,
                  animations=animations, materials=materials, images=images, textures=[dict(source=i) for i in range(len(images))])
    if skins:
        result["skins"] = skins
    buf.write(output, result)
    print(f"{title}: {len(meshes)} meshes and {len(clips)} animations -> {output}")
    bake_generated(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("character", choices=["amy", "big", "blaze", "cream", "rouge", "sonic", "knuckles", "shadow", "tails", "beeton", "ganigani", "eggpawn", "flicky"])
    export(parser.parse_args().character)
