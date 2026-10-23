"""Prepare an authorized local Sonic Runners character SMD for Godot.

Blender 5.2 rejects the archive's FBX 6100 and no longer ships Collada import.
This deliberately narrow reader handles the supplied SMD v1 triangles and bind pose.
It reads data only, preserves authored skin weights, and never executes asset files.
"""
import argparse
import shutil
import sys
from datetime import datetime
import bpy
import json
import math
import shlex
import struct
from collections import Counter
from pathlib import Path
from mathutils import Matrix, Vector, Euler, Quaternion

BASE = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--character', choices=('sonic', 'tails'), default='sonic')
parser.add_argument('--skip-renders', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
CHARACTER = args.character
SOURCE = next((BASE / 'local/source' / CHARACTER).rglob(f'chr_{CHARACTER}.smd'))
OUT = BASE / 'local/runtime'
OUT.mkdir(parents=True, exist_ok=True)
# Keep prior prepared results recoverable; source files are never modified.
backup = BASE / 'local/backups' / (CHARACTER + '_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
for previous in [OUT / f'{CHARACTER}.glb', BASE / 'local' / f'{CHARACTER}_prepared.blend']:
    if previous.exists():
        backup.mkdir(parents=True, exist_ok=True)
        shutil.copy2(previous, backup / previous.name)
bpy.ops.wm.read_factory_settings(use_empty=True)
lines = SOURCE.read_text().splitlines()
nodes, transforms, triangles = {}, {}, []
i = lines.index('nodes') + 1
while lines[i] != 'end':
    p = shlex.split(lines[i]); nodes[int(p[0])] = (p[1], int(p[2])); i += 1
i = lines.index('skeleton') + 1
source_frames = []
while lines[i] != 'end':
    p = lines[i].split()
    if p[0] == 'time': source_frames.append(int(p[1]))
    else:
        vals = [float(v) for v in p[1:]]
        transforms[int(p[0])] = Matrix.Translation(Vector(vals[:3])) @ Euler(vals[3:], 'XYZ').to_matrix().to_4x4()
    i += 1
i = lines.index('triangles') + 1
while lines[i] != 'end':
    mat = lines[i]; tri = []
    for row in lines[i+1:i+4]:
        p = row.split(); count = int(p[9]) if len(p)>9 else 0
        weights = [(int(p[10+2*j]), float(p[11+2*j])) for j in range(count)] or [(int(p[0]), 1.0)]
        tri.append((tuple(map(float,p[1:4])), tuple(map(float,p[4:7])), tuple(map(float,p[7:9])), weights))
    triangles.append((mat,tri)); i += 4

if source_frames != [0]:
    raise ValueError('This bind-pose reader requires exactly one source frame (time 0).')
world = {}
def bone_world(idx):
    if idx not in world:
        parent = nodes[idx][1]
        world[idx] = bone_world(parent) @ transforms[idx] if parent >= 0 else transforms[idx]
    return world[idx]
for idx in nodes:
    bone_world(idx)
if any(idx == 0 and weight > 0 for _, tri in triangles for _, _, _, links in tri for idx, weight in links):
    raise ValueError('The implicit omitted root unexpectedly owns skin weights.')
arm_data = bpy.data.armatures.new(CHARACTER.title() + 'OriginalRig')
arm = bpy.data.objects.new(CHARACTER.title() + 'Rig',arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for idx,(name,parent) in nodes.items():
    if idx == 0: continue
    b = arm_data.edit_bones.new(name)
    b.head = world[idx].translation
    b.tail = b.head + world[idx].to_3x3() @ Vector((0,0.045,0))
    b.matrix = world[idx]
    b.length = 0.045
    if parent > 0: b.parent = arm_data.edit_bones[nodes[parent][0]]
bpy.ops.object.mode_set(mode='OBJECT')
materials = {}
for name in sorted(set(t[0] for t in triangles)):
    m = bpy.data.materials.new(name); m.use_nodes=True
    bsdf=m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=0.7
    bsdf.inputs['Specular IOR Level'].default_value=0.22
    texture = 'eye' if 'eye' in name else 'mouth' if 'mouth' in name else 'body'
    tex=m.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(SOURCE.parent / (f'chr_{CHARACTER}_'+texture+'_dif.png')),check_existing=True)
    tex.interpolation='Linear'; tex.extension='REPEAT'
    m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    # Both supplied DAE files bind only diffuse images. Tails' `_a` auxiliary maps
    # are opaque grayscale, not cutout opacity; do not erase the eye/mouth surfaces.
    materials[name]=m
verts=[]; normals=[]; uvs=[]; weights=[]; faces=[]; mats=[]; unique={}
for mat,tri in triangles:
    face=[]
    for co,no,uv,w in tri:
        key=(co,no,uv,tuple(w))
        if key not in unique:
            unique[key]=len(verts); verts.append(co); normals.append(no); uvs.append(uv); weights.append(w)
        face.append(unique[key])
    faces.append(face); mats.append(mat)
mesh=bpy.data.meshes.new(CHARACTER.title() + 'WeightedMesh'); mesh.from_pydata(verts,[],faces); mesh.update()
obj=bpy.data.objects.new(CHARACTER.title(),mesh); bpy.context.collection.objects.link(obj)
for m in materials.values(): mesh.materials.append(m)
mat_names=list(materials)
uv_layer=mesh.uv_layers.new(name='UVMap')
for poly,mat in zip(mesh.polygons,mats):
    poly.material_index=mat_names.index(mat); poly.use_smooth=True
    for li in poly.loop_indices: uv_layer.data[li].uv=uvs[mesh.loops[li].vertex_index]
mesh.normals_split_custom_set_from_vertices(normals)
for idx,(name,parent) in nodes.items():
    if idx: obj.vertex_groups.new(name=name)
for vi,links in enumerate(weights):
    for idx,w in links:
        if idx and w>0: obj.vertex_groups[nodes[idx][0]].add([vi],w,'REPLACE')
mod=obj.modifiers.new('Original skin binding','ARMATURE'); mod.object=arm; obj.parent=arm
# Geometry already faces Blender -Y (Godot +Z). Normalize height to 1.0 m.
lo=min(v[2] for v in verts); hi=max(v[2] for v in verts)
scale=1/(hi-lo)
arm.scale=(scale,)*3; arm.location.z=-lo*scale
bpy.context.view_layer.update()

# Pose rotations use source rest-frame axes, converted into each bone's local basis.
# Animated parents carry those axes with them; fingers keep their authored open rest pose.
def pose(rotations, tail_phase=None):
    for p in arm.pose.bones: p.matrix_basis=Matrix.Identity(4)
    for name,angles in rotations.items():
        p=arm.pose.bones[name]; r=p.bone.matrix_local.to_quaternion()
        q=Euler(tuple(math.radians(a) for a in angles),'XYZ').to_quaternion()
        p.rotation_mode='QUATERNION'; p.rotation_quaternion=r.inverted() @ q @ r
    if CHARACTER == 'tails' and (tail_phase is not None or rotations):
        # The two supplied tail chains are almost straight in their rest pose.
        # Derive the blade alignment from actual joint positions, then rotate
        # each complete chain around its own attachment. Child bones stay at rest.
        for side, blade in [('L', Vector((1, 0, 0))), ('R', Vector((-1, 0, 0)))]:
            root = arm.pose.bones['Tail1_' + side]
            child = arm.data.bones['Tail2_' + side]
            direction = (child.head_local - root.bone.head_local).normalized()
            # Relaxed tails trail beside the legs rather than point through the
            # table. Flight spreads the same original geometry into a rotor.
            target = blade if tail_phase is not None else Vector((blade.x * 0.55, 0.22, -0.62)).normalized()
            spread = direction.rotation_difference(target)
            turn = Quaternion(Vector((0, 1, 0)), tail_phase or 0.0)
            rest = root.bone.matrix_local.to_quaternion()
            root.rotation_mode = 'QUATERNION'
            root.rotation_quaternion = rest.inverted() @ turn @ spread @ rest
    bpy.context.view_layer.update()

POSES={
'idle': {'UpperArm_L':(0,65,-10),'UpperArm_R':(0,-65,5),'ForeArm_L':(-10,8,-14),'ForeArm_R':(-15,-20,20),'Head':(0,-3,-5),'Thigh_L':(-3,-3,0),'Thigh_R':(3,3,0)},
'jump': {'UpperArm_L':(0,-10,-15),'UpperArm_R':(0,15,20),'ForeArm_L':(-15,35,0),'ForeArm_R':(-10,-40,0),'Thigh_L':(-40,-5,0),'Calf_L':(70,0,0),'Thigh_R':(-18,6,0),'Calf_R':(40,0,0),'Head':(-8,0,8)},
'trick': {'Spine':(0,-10,-12),'UpperArm_L':(0,-28,-15),'ForeArm_L':(-10,20,-15),'UpperArm_R':(0,-60,15),'ForeArm_R':(-35,-30,-35),'Thigh_L':(-78,-12,0),'Calf_L':(105,0,0),'Thigh_R':(12,15,0),'Calf_R':(15,0,0),'Head':(0,0,16)}
}
if CHARACTER == 'sonic':
    POSES['homing'] = {'UpperArm_L':(0,48,-18),'UpperArm_R':(0,-48,18),'ForeArm_L':(-8,12,-8),'ForeArm_R':(-8,-12,8),'Thigh_L':(-24,-3,0),'Calf_L':(40,0,0),'Thigh_R':(-24,3,0),'Calf_R':(40,0,0),'Head':(-6,0,0)}
    POSES['impact'] = {'Spine':(6,0,0),'UpperArm_L':(0,-8,-12),'UpperArm_R':(0,8,12),'ForeArm_L':(-12,28,0),'ForeArm_R':(-12,-28,0),'Thigh_L':(-42,-6,0),'Calf_L':(64,0,0),'Thigh_R':(-42,6,0),'Calf_R':(64,0,0),'Head':(10,0,0)}
else:
    # The shared arm/leg names and measured rest bases match Sonic, but retain a
    # milder flight silhouette and leave all fingers/hair/tail child joints alone.
    POSES['fly'] = {'UpperArm_L':(0,32,-8),'UpperArm_R':(0,-32,8),'ForeArm_L':(-6,16,-6),'ForeArm_R':(-6,-16,6),'Thigh_L':(-15,-3,0),'Calf_L':(22,0,0),'Thigh_R':(-15,3,0),'Calf_R':(22,0,0),'Head':(-5,0,0)}
scene=bpy.context.scene; scene.render.fps=30
arm.animation_data_create()
for name,rotations in POSES.items():
    action=bpy.data.actions.new(name); arm.animation_data.action=action
    # Evaluate the action switch before setting its first pose. Otherwise Blender
    # can replace that first sample with the preceding clip's cached pose.
    bpy.context.view_layer.update()
    previous_quaternions = {}
    samples = [(frame, 1.0) for frame in range(31)] if name == 'fly' else [(0,1.0),(15,0.94),(30,1.0)]
    for frame,factor in samples:
        phase = frame / 30 * math.tau * 2 if name == 'fly' else None
        pose({key:tuple(v*factor for v in angles) for key,angles in rotations.items()}, phase)
        for p in arm.pose.bones:
            # Preserve the quaternion hemisphere through full revolutions.
            if p.name in previous_quaternions and p.rotation_quaternion.dot(previous_quaternions[p.name]) < 0:
                p.rotation_quaternion.negate()
            previous_quaternions[p.name] = p.rotation_quaternion.copy()
            p.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=p.name)
    track=arm.animation_data.nla_tracks.new(); track.name=name; track.mute=True
    strip=track.strips.new(name,0,action); strip.name=name
arm.animation_data.action=None
for tr in arm.animation_data.nla_tracks: tr.mute=True
pose({})
# Numeric deformation checks complement the rendered joint review.
rest=[(obj.matrix_world@v.co).copy() for v in obj.data.vertices]
deformation={}
for name,rotation in POSES.items():
    pose(rotation, 0.0 if name == 'fly' else None)
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    deformed=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
    deformation[name]={'moved_vertices':sum((a-b).length>0.001 for a,b in zip(rest,deformed)), 'max_displacement_m':max((a-b).length for a,b in zip(rest,deformed))}
pose({})
identity_mesh = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
identity_error = max((obj.matrix_world @ a.co - identity_mesh.matrix_world @ b.co).length for a, b in zip(obj.data.vertices, identity_mesh.data.vertices))
rest_matrix_error = max(abs(arm.data.bones[name].matrix_local[r][c] - world[idx][r][c]) for idx, (name, _) in nodes.items() if idx for r in range(4) for c in range(4))
# glTF's axis conversion maps Blender (x,y,z) to Godot (x,z,-y).
# After the table's -90-degree X alignment, Godot Z becomes board-normal Y.
depth_bounds = {}
for name, rotations in [('rest', {})] + list(POSES.items()):
    depths = []
    for phase in ([math.tau * i / 24 for i in range(24)] if name == 'fly' else [None]):
        pose(rotations, phase)
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        depths.extend(-(evaluated.matrix_world @ v.co).y for v in evaluated.data.vertices)
    depth_bounds[name] = [min(depths), max(depths)]
tail_audit = {}
if CHARACTER == 'tails':
    for side in ['L', 'R']:
        chain = [f'Tail{i}_{side}' for i in range(1, 5)]
        ids = {idx for idx, (name, _) in nodes.items() if name in chain}
        attached = [links for links in weights if any(idx in ids and weight > 0 for idx, weight in links)]
        tail_audit[side] = {
            'chain': chain,
            'weighted_vertices': len(attached),
            'vertices_blended_with_body': sum(any(idx not in ids and weight > 0 for idx, weight in links) for links in attached),
            'rest_root_position': list(arm.data.bones[chain[0]].head_local),
            'rest_direction': list((arm.data.bones[chain[1]].head_local - arm.data.bones[chain[0]].head_local).normalized()),
            'animated_bone': chain[0],
            'child_rotation_deltas': 'identity',
            'rotor_axis_blender': [0, 1, 0],
            'revolutions_per_second': 2,
            'relaxed_direction_blender': [(-1 if side == 'R' else 1) * 0.55, 0.22, -0.62],
        }
pose(POSES['idle'])
report={'source':SOURCE.name,'blender':bpy.app.version_string,'bones':len(arm.data.bones),'vertices':len(verts),'triangles':len(faces),'materials':mat_names,'unweighted_vertices':sum(not w for w in weights),'max_weight_sum_error':max(abs(sum(w for _,w in links)-1) for links in weights),'source_frames':source_frames,'source_animation_clips':0,'authored_experimental_clips':list(POSES),'weight_link_histogram':dict(Counter(len(w) for w in weights)),'deformation':deformation,'identity_skin_error_m':identity_error,'rest_matrix_max_element_error':rest_matrix_error,'godot_depth_bounds_m':depth_bounds,'tail_audit':tail_audit,'bones_inspected':[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local)} for b in arm.data.bones]}
(BASE/'local'/f'{CHARACTER}_rig_report.json').write_text(json.dumps(report,indent=2))
if CHARACTER == 'sonic':
    (BASE/'local/rig_report.json').write_text(json.dumps(report,indent=2))
print('RIG_REPORT',json.dumps({k:v for k,v in report.items() if k!='bones_inspected'}))
for image in bpy.data.images:
    if image.source=='FILE': image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'local'/f'{CHARACTER}_prepared.blend'))
# Export only rig and skin. Pose clips are local, in-place, and carry no root motion.
pose({})
for tr in arm.animation_data.nla_tracks: tr.mute=False
# Force dependency evaluation outside the clip range before glTF samples frame 0.
scene.frame_set(-1)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/f'{CHARACTER}.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_yup=True)


# Check the exported samples, not just Blender poses. This catches a stale first
# NLA sample and verifies that authored in-place clips cannot introduce motion.
glb = (OUT / f'{CHARACTER}.glb').read_bytes()
json_size = struct.unpack_from('<I', glb, 12)[0]
gltf = json.loads(glb[20:20 + json_size])
binary_start = 20 + json_size + 8

def exported_values(accessor_id):
    accessor = gltf['accessors'][accessor_id]
    view = gltf['bufferViews'][accessor['bufferView']]
    count = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
    offset = binary_start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    return [struct.unpack_from('<' + 'f' * count, glb, offset + i * view.get('byteStride', 4 * count)) for i in range(accessor['count'])]

export_validation = {}
for animation in gltf['animations']:
    loop_error = 0.0
    translation_delta = 0.0
    for channel in animation['channels']:
        sampler = animation['samplers'][channel['sampler']]
        values = exported_values(sampler['output'])
        if channel['target']['path'] == 'rotation':
            first, last = values[0], values[-1]
            norm = math.sqrt(sum(v * v for v in first) * sum(v * v for v in last))
            dot = abs(sum(a * b for a, b in zip(first, last)) / norm)
            loop_error = max(loop_error, math.degrees(2 * math.acos(min(1.0, dot))))
        elif channel['target']['path'] == 'translation':
            translation_delta = max(translation_delta, max((Vector(value) - Vector(values[0])).length for value in values))
    if loop_error > 0.1 or translation_delta > 0.00001:
        raise ValueError(f"Invalid exported clip {animation['name']}: loop={loop_error}, translation={translation_delta}")
    export_validation[animation['name']] = {'loop_error_degrees': loop_error, 'max_translation_delta_m': translation_delta}
report['export_validation'] = export_validation
(BASE / 'local' / f'{CHARACTER}_rig_report.json').write_text(json.dumps(report, indent=2))
if CHARACTER == 'sonic':
    (BASE / 'local/rig_report.json').write_text(json.dumps(report, indent=2))
print('EXPORT_VALIDATION', json.dumps(export_validation))

if args.skip_renders:
    print('Skipped studio renders (--skip-renders).')
    raise SystemExit(0)
# A local studio render makes weights/material defects visible before Godot integration.
for tr in arm.animation_data.nla_tracks: tr.mute=True
arm.animation_data.action=None
scene.render.engine='CYCLES'; scene.cycles.samples=32
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio sky'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(0.35,0.55,0.8,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=0.5
scene.view_settings.view_transform='Standard'
def area(name,at,power,size):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    light=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(light); light.location=at; light.rotation_euler=(Vector((0,0,0.5))-light.location).to_track_quat('-Z','Y').to_euler()
area('Key',(2,-3,4),180,3); area('Rim',(-2,1,2),100,2)
cam_data=bpy.data.cameras.new('Preview'); cam=bpy.data.objects.new('Preview',cam_data); bpy.context.collection.objects.link(cam)
cam.location=(1.25,-2.5,1.25); cam.rotation_euler=(Vector((0,0,0.52))-cam.location).to_track_quat('-Z','Y').to_euler(); cam_data.type='ORTHO'; cam_data.ortho_scale=1.35; scene.camera=cam
scene.render.image_settings.file_format='PNG'
for name,rotations in POSES.items():
    pose(rotations, 0.0 if name == 'fly' else None); scene.render.filepath=str(BASE/'local'/f'{CHARACTER}_blender_{name}.png'); bpy.ops.render.render(write_still=True)

if CHARACTER == 'tails':
    for suffix, phase in [('quarter', math.pi / 2), ('diagonal', math.pi / 4)]:
        pose(POSES['fly'], phase)
        scene.render.filepath = str(BASE / 'local' / f'tails_blender_fly_{suffix}.png')
        bpy.ops.render.render(write_still=True)

# Table-space check: normalized head +Z becomes up-table +Y and front -Y
# becomes board-normal +Z. This is the Blender equivalent of Godot RX=-90°.
arm.rotation_euler.x = -math.pi / 2
arm.location = Vector((0, 0, 0.40)) + Matrix.Rotation(-math.pi / 2, 4, 'X') @ Vector((0, 0, -lo * scale - 0.5))
cam.location = (0.8, -1.6, 2.4)
cam.rotation_euler = (Vector((0, 0, 0.40)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam_data.ortho_scale = 1.5
for name in (['fly', 'jump'] if CHARACTER == 'tails' else ['homing', 'impact']):
    pose(POSES[name], math.pi / 4 if name == 'fly' else None)
    scene.render.filepath = str(BASE / 'local' / f'{CHARACTER}_blender_table_{name}.png')
    bpy.ops.render.render(write_still=True)
