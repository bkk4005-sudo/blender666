import bpy, math, json, sys, random
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from motions import CLIPS,FPS,sample,rotation
random.seed(19)
bpy.ops.wm.read_factory_settings(use_empty=True)
S=bpy.context.scene; S.render.fps=FPS; S.unit_settings.system='NONE'
for folder in ['exports/animations','previews','textures']: (ROOT/folder).mkdir(parents=True,exist_ok=True)

def material(name,col,metal=0,rough=.5,detail=False):
    m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if detail:
        n=m.node_tree.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value=145; n.inputs['Detail'].default_value=2
        b=m.node_tree.nodes.new('ShaderNodeBump'); b.inputs['Strength'].default_value=.14; b.inputs['Distance'].default_value=.008
        m.node_tree.links.new(n.outputs['Fac'],b.inputs['Height']); m.node_tree.links.new(b.outputs[0],p.inputs['Normal'])
    return m
M=[material('01 / Tempered silver steel',(.28,.34,.40),.88,.27,True),material('02 / Honed edges',(.62,.69,.72),.93,.21),material('03 / Recessed fuller',(.045,.07,.09),.82,.34),material('04 / Aged brass',(.37,.235,.075),.8,.31,True),material('05 / Oxblood leather',(.065,.017,.014),0,.72,True),material('06 / Blackened iron',(.055,.07,.083),.8,.4,True),material('07 / Pale engraving',(.53,.40,.19),.83,.29),material('08 / Training armor',(.10,.14,.17),.65,.42),material('09 / Cloth joints',(.026,.033,.038),0,.86)]

class Geo:
    def __init__(self): self.v=[]; self.f=[]; self.mi=[]
    def add(self,v,f,m=0):
        n=len(self.v); self.v.extend(v); self.f.extend(tuple(n+i for i in face) for face in f); self.mi.extend([m]*len(f))
    def box(self,p,s,m=0,T=None):
        x,y,z=p; a,b,c=[v/2 for v in s]
        v=[(x+u,y+w,z+t) for u,w,t in [(-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),(-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c)]]
        if T is not None: v=[tuple(T@Vector(q)) for q in v]
        self.add(v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m)
    def cyl(self,p,r,h,m=0,n=16,rt=None,T=None):
        rt=r if rt is None else rt; x,y,z=p
        v=[(x+rr*math.cos(i*math.tau/n),y+rr*math.sin(i*math.tau/n),zz) for rr,zz in [(r,z-h/2),(rt,z+h/2)] for i in range(n)]
        if T is not None: v=[tuple(T@Vector(q)) for q in v]
        self.add(v,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],m)
    def obj(self,name,col,bevel=0):
        me=bpy.data.meshes.new(name); me.from_pydata(self.v,[],self.f); me.update()
        for m in M: me.materials.append(m)
        for p,mi in zip(me.polygons,self.mi): p.material_index=mi
        o=bpy.data.objects.new(name,me); col.objects.link(o)
        if bevel:
            mod=o.modifiers.new('Forged softened edges','BEVEL'); mod.width=bevel; mod.segments=2
        return o

def collection(name):
    c=bpy.data.collections.new(name); S.collection.children.link(c); return c
weapon_col=collection('01 / ASHEN OATH / original greatsword')
rig_col=collection('02 / Standard R15 skeleton and original display mannequin')
stage_col=collection('03 / Preview studio / do not export')

# Broad tapered blade, distinct cutting bevels, real recessed central fuller.
g=Geo()
stations=[(.36,.28),(.59,.32),(.85,.33),(2.5,.28),(3.1,.215),(3.55,.015)]
# Each cross-section runs around both faces with a sunk fuller near the spine.
profile=[(-1,0),(-.79,-.055),(-.25,-.075),(-.13,-.043),(.13,-.043),(.25,-.075),(.79,-.055),(1,0),(.79,.055),(.25,.075),(.13,.043),(-.13,.043),(-.25,.075),(-.79,.055)]
v=[(xx*w,yy*(.3 if z>3.5 else 1),z) for z,w in stations for xx,yy in profile]; n=len(profile)
g.add(v,[tuple(reversed(range(n))),tuple(range((len(stations)-1)*n,len(stations)*n))],0)
for j in range(len(stations)-1):
    for i in range(n):
        mat=1 if i in [0,6,7,13] else 2 if i in [2,3,4,9,10,11] else 0
        g.add([v[j*n+i],v[j*n+(i+1)%n],v[(j+1)*n+(i+1)%n],v[(j+1)*n+i]],[(0,1,2,3)],mat)
# Swept crossguard with descending quillons, engraved collar.
for side in [-1,1]:
    points=[(side*x,z) for x,z in [(0,.35),(.22,.36),(.46,.30),(.68,.17),(.76,.20),(.65,.40),(.29,.50),(0,.49)]]
    vv=[(x,y,z) for y in [-.095,.095] for x,z in points]
    g.add(vv,[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)],5)
    for k in range(3): g.box((side*(.28+k*.12),-.102,.39-k*.036),(.065,.018,.046),3)
g.box((0,0,.43),(.26,.25,.24),3)
g.cyl((0,0,-.20),.105,1.05,4,16)
for i in range(19):
    z=-.69+i*.053
    g.cyl((0,0,z),.111,.026,4 if i%3 else 5,16)
    # Offset seam adds an actual spiral rhythm to the leather wrapping.
    a=i*.85; g.box((.108*math.cos(a),.108*math.sin(a),z),(.02,.025,.035),3)
for z in [-.77,.28]: g.cyl((0,0,z),.13,.12,3,12)
g.cyl((0,0,-.93),.155,.22,5,10,rt=.20)
g.cyl((0,0,-1.09),.08,.14,3,10,rt=.155)
g.cyl((0,0,-.79),.20,.09,3,10,rt=.13)
# Inlaid geometric script is original; not a copied game insignia.
for side in [-1,1]:
    for i in range(8):
        z=.85+i*.21; y=side*.046
        g.add([(-.035,y,z),(0,y,z+.075),(.035,y,z),(0,y,z-.075)],[(0,1,2),(0,2,3)],6)
weapon=g.obj('AshenOath_Greatsword',weapon_col,.008)
weapon['design']='Original two-handed greatsword / Ashen Oath. Geometry and motions are original.'
weapon['right_grip_local']=[0,0,0]; weapon['left_grip_local']=[0,0,-.53]
weapon['blade_base_local']=[0,0,.56]; weapon['blade_tip_local']=[0,0,3.55]
weapon['length_blender_units']=4.71
# UV layout includes all geometry and will support texture baking.
bpy.context.view_layer.objects.active=weapon; weapon.select_set(True)
bpy.ops.object.modifier_apply(modifier=weapon.modifiers[0].name)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015); bpy.ops.object.mode_set(mode='OBJECT')
weapon.select_set(False)
prop=bpy.data.objects.new('Sword motion / paired PROP actions',None); weapon_col.objects.link(prop); weapon.parent=prop

# Official skeleton only, with a new mannequin authored here. No supplied character art.
ref=next((ROOT/'reference'/'R15').rglob('Rig_and_Attachments_Template.blend'))
with bpy.data.libraries.load(str(ref),link=False) as (source,target): target.objects=['Armature']
rig=target.objects[0]; rig_col.objects.link(rig); rig.name='R15_AshenOath'; rig.show_in_front=True
bpy.context.view_layer.objects.active=rig; rig.select_set(True)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
rig.data.transform(Matrix.Translation((0,0,3.13)))
rig.select_set(False)
REST={b.name:b.matrix_local.copy() for b in rig.data.bones}
HEAD={b.name:b.head_local.copy() for b in rig.data.bones}
TAIL={b.name:b.tail_local.copy() for b in rig.data.bones}
PARENT={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
ORDER=[b.name for b in rig.data.bones]
LOCAL={n:(REST[PARENT[n]].inverted()@REST[n] if PARENT[n] else REST[n]) for n in ORDER}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
prop.rotation_mode='QUATERNION'

# Fifteen separately skinned display meshes, including closed gauntlets.
for name in ORDER:
    if name in ['Root','HumanoidRootNode']: continue
    geo=Geo(); T=REST[name]; length=(TAIL[name]-HEAD[name]).length
    if name=='LowerTorso':
        geo.box((0,.1,0),(.72,.42,.43),8,T); geo.box((0,.02,0),(.80,.16,.48),3,T)
    elif name=='UpperTorso':
        geo.box((0,length*.47,0),(.94,length*.88,.49),7,T)
        geo.box((0,length*.47,.26),(.085,length*.76,.04),3,T)
        for side in [-1,1]: geo.box((side*.36,length*.52,.26),(.07,length*.66,.045),5,T)
    elif name=='Head':
        geo.cyl((HEAD[name].x,HEAD[name].y,HEAD[name].z-.06),.15,.40,8,12)
        geo.box((0,.45,0),(.60,.79,.58),7,T)
        geo.box((0,.49,.30),(.48,.07,.035),2,T)
        geo.box((0,.70,.31),(.055,.3,.035),3,T)
    elif 'Hand' in name:
        geo.box((0,.18,0),(.28,.34,.28),7,T)
        for i in range(4): geo.box((-.105+i*.07,.30,.075),(.059,.13,.19),0,T)
        geo.box((.16,.13,0),(.10,.22,.15),5,T)
    elif 'Foot' in name:
        # Foot bone points forward; local Z follows the template foot orientation.
        center=(HEAD[name]+TAIL[name])*.5
        geo.box((center.x,center.y,HEAD[name].z-.055),(.43,.76,.30),5)
        geo.box((center.x,center.y-.18,HEAD[name].z+.04),(.44,.35,.18),7)
    else:
        wide=.35 if 'Arm' in name else .43
        # Joint cores fill the gaps between rigid armor plates.
        geo.box((0,.015,0),(wide*.78,.24,wide*.78),8,T)
        geo.box((0,length*.5,0),(wide,length*.86,wide),7,T)
        for y in [length*.10,length*.83]: geo.box((0,y,0),(wide+.045,.08,wide+.045),5,T)
        if 'UpperArm' in name: geo.box((0,.12,0),(.49,.28,.48),5,T)
        if 'LowerLeg' in name: geo.box((0,length*.30,.22),(.28,.48,.065),0,T)
    o=geo.obj(name,rig_col,.045 if 'Hand' not in name else .02)
    group=o.vertex_groups.new(name=name); group.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('R15 rigid skin','ARMATURE'); mod.object=rig; o.parent=rig
    o['display_only']='Original armor mannequin, not a finished avatar asset.'

def transform(rot,pos):
    m=rot.to_matrix().to_4x4() if isinstance(rot,Quaternion) else rot.to_4x4(); m.translation=Vector(pos); return m
def orient_bone(name,a,b):
    y=(b-a).normalized(); rest_y=(TAIL[name]-HEAD[name]).normalized()
    q=rest_y.rotation_difference(y) @ REST[name].to_quaternion()
    return transform(q,a)
def joint(a,target,L1,L2,pole):
    delta=target-a; d=delta.length; u=delta.normalized(); dc=min(max(d,.03),L1+L2-.002)
    pole=Vector(pole); v=pole-u*pole.dot(u)
    if v.length<.01: v=Vector((0,1,0))-u*u.y
    v.normalize(); x=(L1*L1-L2*L2+dc*dc)/(2*dc); h=math.sqrt(max(0,L1*L1-x*x))
    elbow=a+u*x+v*h
    return elbow,d-(L1+L2)

max_grip_error=0; max_leg_extension=0; correction_max=0; min_tip=100
def pose_at(p):
    global max_grip_error,max_leg_extension,correction_max,min_tip
    desired={}
    root=Vector((0,0,3.13))+Vector(p['root'])
    lowerR=Euler(tuple(math.radians(v) for v in p['pelvis']),'XYZ').to_matrix()
    upperR=Euler(tuple(math.radians(v) for v in p['body']),'XYZ').to_matrix()
    # Root remains a stable export basis; translation is local pelvis posing.
    desired['Root']=REST['Root'].copy(); desired['HumanoidRootNode']=REST['HumanoidRootNode'].copy()
    desired['LowerTorso']=transform(lowerR@REST['LowerTorso'].to_3x3(),root)
    upperhead=desired['LowerTorso']@REST['LowerTorso'].inverted()@HEAD['UpperTorso']
    desired['UpperTorso']=transform(upperR@REST['UpperTorso'].to_3x3(),upperhead)
    headpos=desired['UpperTorso']@REST['UpperTorso'].inverted()@HEAD['Head']
    headR=Euler(tuple(math.radians(v) for v in p['head']),'XYZ').to_matrix()
    desired['Head']=transform(headR@REST['Head'].to_3x3(),headpos)
    swq=rotation(p['angles']); swR=swq.to_matrix(); grip=Vector(p['p']); original=grip.copy()
    shoulders={s:desired['UpperTorso']@REST['UpperTorso'].inverted()@HEAD[s+'UpperArm'] for s in ['Right','Left']}
    # Project the shared grip into both arm reach spheres; never stretch either arm.
    for iteration in range(10):
        for side in ['Right','Left']:
            if side=='Left' and p['left_grip']<.99: continue
            off=swR@Vector((0,.20,0 if side=='Right' else -.53))
            limit=sum((TAIL[side+n]-HEAD[side+n]).length for n in ['UpperArm','LowerArm'])-.015
            delta=grip+off-shoulders[side]
            if delta.length>limit: grip-=delta.normalized()*(delta.length-limit)
    correction_max=max(correction_max,(original-grip).length)
    sword=transform(swq,grip)
    for side,sign in [('Right',-1),('Left',1)]:
        wrist=grip+swR@Vector((0,.20,0 if side=='Right' else -.53))
        if side=='Left' and p['left_grip']<1:
            free=shoulders[side]+Vector((.40,-.18,-1.15))
            wrist=free.lerp(wrist,p['left_grip'])
        a=shoulders[side]; u=side+'UpperArm'; l=side+'LowerArm'; h=side+'Hand'
        elbow,over=joint(a,wrist,(TAIL[u]-HEAD[u]).length,(TAIL[l]-HEAD[l]).length,(sign*.9,.20,-.55))
        desired[u]=orient_bone(u,a,elbow); desired[l]=orient_bone(l,elbow,wrist)
        # Same bone-to-grip relation on every frame; local hand +Y reaches around hilt.
        handR=swR@Matrix.Diagonal((1,-1,-1))
        desired[h]=transform(handR,wrist)
        if side=='Left' and p['left_grip']<1:
            freeQ=orient_bone(h,wrist,wrist+Vector((0,-.25,-.1))).to_quaternion()
            desired[h]=transform(freeQ.slerp(handR.to_quaternion(),p['left_grip']),wrist)
        if side=='Right' or p['left_grip']>=.99:
            err=(desired[h]@Vector((0,.20,0))-(grip+swR@Vector((0,0,0 if side=='Right' else -.53)))).length
            max_grip_error=max(max_grip_error,err)
    for side,key,index in [('Left','lf',0),('Right','rf',1)]:
        u=side+'UpperLeg'; l=side+'LowerLeg'; f=side+'Foot'
        hip=desired['LowerTorso']@REST['LowerTorso'].inverted()@HEAD[u]
        foot=Vector(p[key]); foot.z+=HEAD[f].z
        ankle=foot+(HEAD[l]+(TAIL[l]-HEAD[l])-HEAD[f])
        knee,over=joint(hip,ankle,(TAIL[u]-HEAD[u]).length,(TAIL[l]-HEAD[l]).length,(0,-1,.04))
        max_leg_extension=max(max_leg_extension,over)
        desired[u]=orient_bone(u,hip,knee); desired[l]=orient_bone(l,knee,ankle)
        footQ=Quaternion((0,0,1),math.radians(p['footyaw'][index]))@REST[f].to_quaternion()
        desired[f]=transform(footQ,foot)
    for name in ORDER:
        parent=PARENT[name]
        local=desired[parent].inverted()@desired[name] if parent else desired[name]
        rig.pose.bones[name].matrix_basis=LOCAL[name].inverted()@local
    prop.matrix_world=sword
    min_tip=min(min_tip,(sword@Vector((0,0,3.55))).z)
    return desired,sword

rig.animation_data_create(); prop.animation_data_create()
manifest=[]
for clip in CLIPS:
    n=round(clip['duration']*FPS); duration=n/FPS
    action=bpy.data.actions.new(clip['name']); action.use_fake_user=True; action['loop']=clip['loop']; action['description']=clip['description']
    pa=bpy.data.actions.new('PROP__'+clip['name']); pa.use_fake_user=True
    rig.animation_data.action=action; prop.animation_data.action=pa
    previous={}; prevprop=None
    for frame in range(n+1):
        t=frame/n*clip['duration']; S.frame_set(frame+1); pose_at(sample(clip,t))
        for pb in rig.pose.bones:
            if pb.name in previous and pb.rotation_quaternion.dot(previous[pb.name])<0: pb.rotation_quaternion.negate()
            previous[pb.name]=pb.rotation_quaternion.copy()
            pb.keyframe_insert('location',frame=frame+1,group=pb.name); pb.keyframe_insert('rotation_quaternion',frame=frame+1,group=pb.name)
        if prevprop and prop.rotation_quaternion.dot(prevprop)<0: prop.rotation_quaternion.negate()
        prevprop=prop.rotation_quaternion.copy()
        prop.keyframe_insert('location',frame=frame+1); prop.keyframe_insert('rotation_quaternion',frame=frame+1)
    for name,t in clip['events'].items(): action.pose_markers.new(name).frame=round(t*FPS)+1
    for a in [action,pa]:
        for layer in a.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for k in fc.keyframe_points: k.interpolation='LINEAR'
    manifest.append({k:v for k,v in clip.items() if k!='keys'}|{'frames':n+1,'duration_exported':duration,'fbx':'exports/animations/'+clip['name']+'.fbx'})
    print('BAKED',clip['name'],n+1,flush=True)

# Export each clip individually with only deform skeleton and neutral mannequin.
for o in bpy.context.selected_objects: o.select_set(False)
rig.select_set(True)
for o in rig_col.objects:
    if o.type=='MESH': o.select_set(True)
bpy.context.view_layer.objects.active=rig
for clip in manifest:
    rig.animation_data.action=bpy.data.actions[clip['name']]
    S.frame_start=1; S.frame_end=clip['frames']; S.frame_set(1)
    bpy.ops.export_scene.fbx(filepath=str(ROOT/clip['fbx']),use_selection=True,object_types={'ARMATURE','MESH'},axis_forward='-Z',axis_up='Y',apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',global_scale=1,add_leaf_bones=False,bake_anim=True,bake_anim_use_nla_strips=False,bake_anim_use_all_actions=False,bake_anim_force_startend_keying=True,bake_anim_step=1,bake_anim_simplify_factor=0,mesh_smooth_type='FACE',path_mode='AUTO')
    print('EXPORTED',clip['name'],flush=True)

# Static weapon FBX with handle origin, UVs and separate material slots.
for o in bpy.context.selected_objects: o.select_set(False)
weapon.select_set(True); bpy.context.view_layer.objects.active=weapon
rig.animation_data.action=None; prop.animation_data.action=None; prop.matrix_world=Matrix.Identity(4)
bpy.ops.export_scene.fbx(filepath=str(ROOT/'exports'/'AshenOath_Greatsword.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',bake_anim=False,mesh_smooth_type='FACE',path_mode='AUTO')
weapon.select_set(False)

# Curated timeline: press Space to see weight and a range of distinct actions.
showcase=['Equip','Idle','WalkForward','RunForward','Light_01','Light_02','Light_03','Heavy_Charge','Heavy_Hold','Heavy_Release','Guard_Enter','Guard_Impact','Parry','Riposte','Dodge_Backward','Land','Idle']
cursor=1; timeline=[]
for obj,prefix in [(rig,''),(prop,'PROP__')]:
    track=obj.animation_data.nla_tracks.new(); track.name='SHOWCASE / press Space'
    cursor=1
    for name in showcase:
        a=bpy.data.actions[prefix+name]; strip=track.strips.new(name,cursor,a); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
        if not prefix:
            S.timeline_markers.new(name,frame=cursor); timeline.append({'name':name,'start':cursor,'end':int(strip.frame_end)})
        cursor=int(strip.frame_end)+1
S.frame_start=1; S.frame_end=cursor-1
S['usage']='Space: showcase. All 34 body actions and paired PROP actions are saved. Use select_clip.py to switch both together.'
S['rig_source']='Official Roblox R15 technical armature; original weapon, mannequin and choreography.'
S['root_motion']='In-place. Gameplay controller drives translation; cue timings in animation_manifest.json.'

# Preview stage with no dependency on existing map assets.
geo=Geo(); geo.cyl((0,0,-.14),3.3,.22,5,96); geo.cyl((0,0,-.27),3.45,.13,3,96); stage=geo.obj('Preview plinth',stage_col,.035)
floor=Geo(); floor.box((0,0,-.39),(200,200,.1),8); floor.obj('Backdrop',stage_col)
world=bpy.data.worlds.new('Neutral studio'); world.use_nodes=True; S.world=world; world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.22,1); world.node_tree.nodes['Background'].inputs[1].default_value=.35
def area(name,loc,energy,col,size,target=(0,0,3)):
    data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.color=col; data.shape='DISK'; data.size=size
    ob=bpy.data.objects.new(name,data); stage_col.objects.link(ob); ob.location=loc; ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
area('Softbox / cool',(2,-6,9),1350,(.74,.86,1),5)
area('Rim / warm',(-4,3,7),1800,(1,.65,.33),4)
area('Fill',(5,1,4),850,(.40,.64,1),4)
def camera(name,loc,target,scale):
    d=bpy.data.cameras.new(name); ob=bpy.data.objects.new(name,d); stage_col.objects.link(ob); ob.location=loc; ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler(); d.type='ORTHO'; d.ortho_scale=scale; return ob
cam=camera('Camera / choreography',(9,-15,8),(0,0,3),10.8)
camera('Camera / front',(0,-18,5),(0,0,3),10.8)
camera('Camera / weapon',(5,-12,5),(0,0,1.2),6.6)
S.camera=cam; S.render.engine='BLENDER_EEVEE'; S.render.resolution_x=1200; S.render.resolution_y=1200; S.render.resolution_percentage=100; S.render.image_settings.file_format='PNG'; S.view_settings.view_transform='AgX'
S.frame_set(20); bpy.context.view_layer.update()
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':
            ar.spaces.active.region_3d.view_distance=12; ar.spaces.active.region_3d.view_location=(0,0,3); ar.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            ar.spaces.active.shading.type='SOLID'; ar.spaces.active.shading.color_type='MATERIAL'; ar.spaces.active.shading.show_cavity=True; ar.spaces.active.clip_end=500
bpy.context.view_layer.objects.active=rig; rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'AshenOath_R15.blend'))
report={'clips':len(CLIPS),'fps':FPS,'weapon_vertices':len(weapon.data.vertices),'weapon_triangles':sum(len(p.vertices)-2 for p in weapon.data.polygons),'rig_bones':ORDER,'max_hand_grip_error':max_grip_error,'max_shared_grip_reach_correction':correction_max,'max_leg_overextension':max_leg_extension,'minimum_blade_tip_z':min_tip,'studio_import_verified':False,'root_motion':'In-place','showcase':timeline}
(ROOT/'animation_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(ROOT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('WEAPON_COMPLETE',report,flush=True)
S.render.filepath=str(ROOT/'previews'/'01_ready_stance.png'); bpy.ops.render.render(write_still=True)
