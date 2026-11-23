"""Bake low-poly copies of the local Runners gameplay GLBs. Originals stay editable."""

import argparse
import ctypes as ct
from ctypes.util import find_library
import json
import os
from pathlib import Path
import struct
import tempfile

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FRACTION = 0.35
ORIGINAL_BADNIKS = {"beeton", "ganigani", "eggpawn"}
DTYPES = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load_simplifier():
    library = os.environ.get("MESHOPTIMIZER_LIBRARY") or find_library("meshoptimizer")
    if not library:
        blender = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation"
        library = next(iter(sorted(blender.glob("Blender */blender.shared/meshoptimizer.dll"),
                                   reverse=True)), None)
    if not library:
        raise OSError("Set MESHOPTIMIZER_LIBRARY to a shared library with meshopt_simplifyWithAttributes.")
    simplify = ct.CDLL(str(library)).meshopt_simplifyWithAttributes
    ptr, size = ct.c_void_p, ct.c_size_t
    simplify.argtypes = [ptr, ptr, size, ptr, size, size, ptr, size, ptr, size, ptr,
                         size, ct.c_float, ct.c_uint, ct.POINTER(ct.c_float)]
    simplify.restype = size
    return simplify


def read_glb(path):
    data = path.read_bytes()
    magic, version, length, json_size, kind = struct.unpack_from("<4sIII4s", data)
    if (magic, version, length, kind) != (b"glTF", 2, len(data), b"JSON"):
        raise ValueError(f"Invalid GLB header in {path}")
    document = json.loads(data[20:20 + json_size])
    length, kind = struct.unpack_from("<I4s", data, 20 + json_size)
    if kind != b"BIN\0" or len(document["buffers"]) != 1 or document.get("extensionsUsed"):
        raise ValueError("Expected a self-contained, uncompressed Runners GLB")
    return document, memoryview(data)[28 + json_size:28 + json_size + length]


def accessor_array(document, binary, index):
    accessor = document["accessors"][index]
    if "sparse" in accessor:
        raise ValueError("Sparse vertex data is unsupported")
    view = document["bufferViews"][accessor["bufferView"]]
    dtype = np.dtype(DTYPES[accessor["componentType"]])
    width = WIDTHS[accessor["type"]]
    return np.ndarray((accessor["count"], width), dtype, binary,
                      offset=view.get("byteOffset", 0) + accessor.get("byteOffset", 0),
                      strides=(view.get("byteStride", width * dtype.itemsize), dtype.itemsize))


def reduce_surface(simplify, indices, attributes, targets, fraction):
    triangles = len(indices) // 3
    # Keep small eye, mouth and accessory surfaces legible in close-up.
    target = max(80, round(triangles * fraction))
    if target >= triangles:
        return indices
    positions = np.ascontiguousarray(attributes["POSITION"], dtype=np.float32)
    features = [attributes["NORMAL"] * 0.2, attributes["TEXCOORD_0"] * 0.6]
    if "JOINTS_0" in attributes:
        joints = attributes["JOINTS_0"]
        weights = attributes["WEIGHTS_0"]
        if weights.dtype.kind != "f":
            weights = weights / np.iinfo(weights.dtype).max
        influences = np.zeros((len(positions), int(joints.max()) + 1), dtype=np.float32)
        np.add.at(influences, (np.arange(len(positions))[:, None], joints), weights)
        important = np.argsort(influences[indices].sum(axis=0))[-16:]
        features.append(influences[:, important] * 0.7)
    if targets:
        # Include displacement at each tail pose when judging edge collapse cost.
        extent = max(float(np.ptp(positions, axis=0).max()), 1e-6)
        features.extend(target["POSITION"] / extent for target in targets)
    values = np.ascontiguousarray(np.column_stack(features), dtype=np.float32)
    if values.shape[1] > 32:
        raise ValueError("Surface exceeds meshoptimizer's attribute limit")
    weights = np.ones(values.shape[1], dtype=np.float32)
    source = np.ascontiguousarray(indices, dtype=np.uint32)
    result = np.empty_like(source)
    poses = [positions, *(positions + pose["POSITION"] for pose in targets)]
    def dimensions(points, faces):
        triangles = points[faces.reshape(-1, 3)]
        edges = triangles[:, 1:] - triangles[:, :1]
        area = np.linalg.norm(np.cross(edges[:, 0], edges[:, 1]), axis=1).sum()
        return np.append(np.ptp(triangles, axis=(0, 1)), area)

    # Disconnected gloves, shoes and claws can disappear before the count target.
    # Reserve more faces if any pose loses its span or too much surface area.
    minimum = [dimensions(pose, source) * [0.92, 0.92, 0.92, 0.90] for pose in poses]
    for error in (0.08, 0.04, 0.02, 0.01, 0.005, 0.0025):
        count = simplify(result.ctypes.data, source.ctypes.data, len(source), positions.ctypes.data,
                         len(positions), positions.strides[0], values.ctypes.data, values.strides[0],
                         weights.ctypes.data, len(weights), None, target * 3, error, 0, None)
        if count and count % 3 == 0 and all(
                np.all(dimensions(pose, result[:count]) >= limit) for pose, limit in zip(poses, minimum)):
            return result[:count]
    return indices


def bake(path, simplify, fraction):
    doc, binary = read_glb(path)
    accessors, views, buffer = [], [], bytearray()
    copied_views, copied_accessors = {}, {}

    def store_view(payload, metadata):
        buffer.extend(bytes(-len(buffer) % 4))
        views.append({**metadata, "buffer": 0, "byteOffset": len(buffer), "byteLength": len(payload)})
        buffer.extend(payload)
        return len(views) - 1

    def copy_view(index):
        if index not in copied_views:
            view = doc["bufferViews"][index]
            start = view.get("byteOffset", 0)
            copied_views[index] = store_view(binary[start:start + view["byteLength"]], view)
        return copied_views[index]

    def copy_accessor(index):
        if index not in copied_accessors:
            accessor = doc["accessors"][index]
            copied_accessors[index] = len(accessors)
            accessors.append({**accessor, "bufferView": copy_view(accessor["bufferView"])})
        return copied_accessors[index]

    def store_array(index, values, target):
        old = doc["accessors"][index]
        values = np.asarray(values, dtype=DTYPES[old["componentType"]]).reshape(len(values), -1)
        accessor = {**old, "bufferView": store_view(values.tobytes(), {"target": target}),
                    "byteOffset": 0, "count": len(values)}
        if "min" in old:
            accessor["min"] = values.min(axis=0).tolist()
        if "max" in old:
            accessor["max"] = values.max(axis=0).tolist()
        accessors.append(accessor)
        return len(accessors) - 1

    before = after = 0
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            if primitive.get("mode", 4) != 4:
                raise ValueError("Expected indexed triangles")
            indices = accessor_array(doc, binary, primitive["indices"]).ravel()
            bindings = [primitive["attributes"], *primitive.get("targets", [])]
            arrays = [{key: accessor_array(doc, binary, idx) for key, idx in binding.items()}
                      for binding in bindings]
            reduced = reduce_surface(simplify, indices, arrays[0], arrays[1:], fraction)
            retained, compact = np.unique(reduced, return_inverse=True)
            before += len(indices) // 3
            after += len(reduced) // 3
            primitive["indices"] = store_array(primitive["indices"], compact, 34963)
            for binding, data in zip(bindings, arrays):
                for key, index in binding.items():
                    binding[key] = store_array(index, data[key][retained], 34962)

    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = copy_accessor(skin["inverseBindMatrices"])
    for animation in doc.get("animations", []):
        for sampler in animation["samplers"]:
            for key in ("input", "output"):
                sampler[key] = copy_accessor(sampler[key])
    for image in doc.get("images", []):
        if "bufferView" in image:
            image["bufferView"] = copy_view(image["bufferView"])

    doc.update(accessors=accessors, bufferViews=views, buffers=[{"byteLength": len(buffer)}])
    header = json.dumps(doc, separators=(",", ":"), allow_nan=False).encode()
    header += b" " * (-len(header) % 4)
    buffer.extend(bytes(-len(buffer) % 4))
    dest = path.with_suffix(".low.glb")
    temporary = tempfile.NamedTemporaryFile(dir=dest.parent, delete=False)
    try:
        with temporary as stream:
            stream.write(struct.pack("<4sIII4s", b"glTF", 2, 28 + len(header) + len(buffer),
                                     len(header), b"JSON"))
            stream.write(header)
            stream.write(struct.pack("<I4s", len(buffer), b"BIN\0"))
            stream.write(buffer)
        os.replace(temporary.name, dest)
    finally:
        Path(temporary.name).unlink(missing_ok=True)
    return before, after


def low_poly_sources(paths):
    for path in paths:
        model_id = path.stem.lower().removesuffix(" runners - original animations")
        if path.suffix.lower() == ".glb" and model_id in ORIGINAL_BADNIKS:
            print(f"{path.name}: using original Badnik mesh")
        else:
            yield path


def bake_generated(*paths):
    """Bake newly generated assets when the optional mesh toolchain is installed."""
    paths = list(low_poly_sources(paths))
    if not paths:
        return
    try:
        simplify = load_simplifier()
    except (OSError, AttributeError) as error:
        print(f"Low-poly bake skipped: {error}")
        return
    for path in paths:
        before, after = bake(path, simplify, DEFAULT_FRACTION)
        print(f"{path.name}: {before:,} -> {after:,} triangles")


def gameplay_sources():
    local = ROOT / "experiments/visual_lab/local"
    yield from sorted((local / "runners-decomp").glob("*/* Runners - original animations.glb"))
    yield from sorted((local / "runtime").glob("*_runners_poses.glb"))
    guests = Path(os.environ.get("EGGMOBILE_ART") or ROOT / "test-results/team-eggman-source-review")
    for filename in ("eggmobile.glb", "bomb.glb", "metal.glb", "metal_runners_poses.glb"):
        if (guests / filename).is_file():
            yield guests / filename


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="*", type=Path, help="Defaults to all available gameplay models")
    parser.add_argument("--fraction", type=float, default=DEFAULT_FRACTION, help="Target fraction per large surface")
    args = parser.parse_args()
    if not 0 < args.fraction <= 1:
        parser.error("--fraction must be greater than zero and at most one")
    sources = args.sources or list(gameplay_sources())
    if not sources:
        parser.error("No local Runners models found")
    sources = list(low_poly_sources(sources))
    if not sources:
        parser.exit()
    simplify = load_simplifier()
    for source in sources:
        if source.suffix.lower() != ".glb" or source.name.endswith(".low.glb"):
            parser.error(f"Expected an original .glb source, got {source}")
        before, after = bake(source, simplify, args.fraction)
        print(f"{source.name}: {before:,} -> {after:,} triangles", flush=True)
