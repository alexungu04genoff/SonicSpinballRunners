"""Prepare the authorized local Sonic Runners SMD for Godot; no add-ons required.

Blender 5.2 rejects the archive's FBX 6100 and no longer ships Collada import.
This deliberately narrow reader handles the supplied SMD v1 triangles and bind pose.
It reads data only, preserves authored skin weights, and never executes asset files.
"""
import bpy
import json
import math
import shlex
from collections import Counter
from pathlib import Path
from mathutils import Matrix, Vector, Euler, Quaternion

BASE = Path(__file__).resolve().parents[1]
SOURCE = next((BASE / 'local/source/sonic').rglob('chr_sonic.smd'))
OUT = BASE / 'local/runtime'
OUT.mkdir(parents=True, exist_ok=True)
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

world = {}
for idx, (_, parent) in nodes.items():
    world[idx] = world[parent] @ transforms[idx] if parent >= 0 else transforms[idx]
arm_data = bpy.data.armatures.new('SonicOriginalRig')
arm = bpy.data.objects.new('SonicRig',arm_data)
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
    tex.image=bpy.data.images.load(str(SOURCE.parent / ('chr_sonic_'+texture+'_dif.png')),check_existing=True)
    tex.interpolation='Linear'; tex.extension='REPEAT'
    m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    # Diffuse alpha is not transparency: eye/mouth overlays are opaque authored surfaces.
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
mesh=bpy.data.meshes.new('SonicWeightedMesh'); mesh.from_pydata(verts,[],faces); mesh.update()
obj=bpy.data.objects.new('Sonic',mesh); bpy.context.collection.objects.link(obj)
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

# Pose rotations use global source axes, converted into each bone's local basis.
def pose(rotations, gesture="idle"):
    for p in arm.pose.bones: p.matrix_basis=Matrix.Identity(4)
    for name,angles in rotations.items():
        p=arm.pose.bones[name]; r=p.bone.matrix_local.to_quaternion()
        q=Euler(tuple(math.radians(a) for a in angles),'XYZ').to_quaternion()
        p.rotation_mode='QUATERNION'; p.rotation_quaternion=r.inverted() @ q @ r
    if rotations:
        # Curl authored finger joints toward the palm in the original T-pose frame.
        # The trick keeps the leading index extended for a readable pointing gesture.
        for side,sign in [('L',-1),('R',1)]:
            for finger in ['Middle','Index','Ring','Pinky']:
                if gesture == 'trick' and side == 'L' and finger == 'Index': continue
                for joint,amount in [(1,35 if gesture=='idle' else 58),(2,50 if gesture=='idle' else 68)]:
                    p=arm.pose.bones[f'{finger}{joint}_{side}']
                    r=p.bone.matrix_local.to_quaternion()
                    q=Quaternion(Vector((0,0,sign)),math.radians(amount))
                    p.rotation_mode='QUATERNION'; p.rotation_quaternion=r.inverted() @ q @ r
    bpy.context.view_layer.update()

POSES={
'idle': {'UpperArm_L':(0,65,-10),'UpperArm_R':(0,-65,5),'ForeArm_L':(-10,8,-14),'ForeArm_R':(-15,-20,20),'Head':(0,-3,-5),'Thigh_L':(-3,-3,0),'Thigh_R':(3,3,0)},
'jump': {'UpperArm_L':(0,-10,-15),'UpperArm_R':(0,15,20),'ForeArm_L':(-15,35,0),'ForeArm_R':(-10,-40,0),'Thigh_L':(-40,-5,0),'Calf_L':(70,0,0),'Thigh_R':(-18,6,0),'Calf_R':(40,0,0),'Head':(-8,0,8)},
'trick': {'Spine':(0,-10,-12),'UpperArm_L':(0,-28,-15),'ForeArm_L':(-10,20,-15),'UpperArm_R':(0,-60,15),'ForeArm_R':(-35,-30,-35),'Thigh_L':(-78,-12,0),'Calf_L':(105,0,0),'Thigh_R':(12,15,0),'Calf_R':(15,0,0),'Head':(0,0,16)}
}
scene=bpy.context.scene; scene.render.fps=30
arm.animation_data_create()
for name,rotations in POSES.items():
    action=bpy.data.actions.new(name); arm.animation_data.action=action
    for frame,factor in [(1,1.0),(16,0.94),(31,1.0)]:
        pose({key:tuple(v*factor for v in angles) for key,angles in rotations.items()}, name)
        for p in arm.pose.bones: p.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=p.name)
    track=arm.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,1,action); strip.name=name
arm.animation_data.action=None
for tr in arm.animation_data.nla_tracks: tr.mute=True
pose({})
# Numeric deformation checks complement the rendered joint review.
rest=[(obj.matrix_world@v.co).copy() for v in obj.data.vertices]
deformation={}
for name,rotation in POSES.items():
    pose(rotation,name)
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    deformed=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
    deformation[name]={'moved_vertices':sum((a-b).length>0.001 for a,b in zip(rest,deformed)), 'max_displacement_m':max((a-b).length for a,b in zip(rest,deformed))}
pose(POSES['idle'])
report={'source':'chr_sonic.smd','blender':bpy.app.version_string,'bones':len(arm.data.bones),'vertices':len(verts),'triangles':len(faces),'materials':mat_names,'unweighted_vertices':sum(not w for w in weights),'max_weight_sum_error':max(abs(sum(w for _,w in links)-1) for links in weights),'source_frames':source_frames,'source_animation_clips':0,'authored_experimental_clips':list(POSES),'weight_link_histogram':dict(Counter(len(w) for w in weights)),'deformation':deformation,'bones_inspected':[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local)} for b in arm.data.bones]}
(BASE/'local/rig_report.json').write_text(json.dumps(report,indent=2))
print('RIG_REPORT',json.dumps({k:v for k,v in report.items() if k!='bones_inspected'}))
for image in bpy.data.images:
    if image.source=='FILE': image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'local/sonic_prepared.blend'))
# Export only rig and skin. Pose clips are local, in-place, and carry no root motion.
pose({})
for tr in arm.animation_data.nla_tracks: tr.mute=False
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'sonic.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_yup=True)

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
    pose(rotations,name); scene.render.filepath=str(BASE/'local'/('blender_'+name+'.png')); bpy.ops.render.render(write_still=True)
