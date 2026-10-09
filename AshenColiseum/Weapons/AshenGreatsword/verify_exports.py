import bpy,json,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parent
manifest=json.loads((root/'animation_manifest.json').read_text())
s=bpy.context.scene; rig=bpy.data.objects['R15_AshenOath']; prop=bpy.data.objects['Sword motion / paired PROP actions']
expected={}; grip_errors=[]; loops=[]; foot_drift=[]
for ob in [rig,prop]:
    for tr in ob.animation_data.nla_tracks: tr.mute=True
for c in manifest:
    rig.animation_data.action=bpy.data.actions[c['name']]; prop.animation_data.action=bpy.data.actions['PROP__'+c['name']]
    samples=sorted(set([1,c['frames'],max(2,round(c['frames']*.45))]))
    expected[c['name']]={}
    first=None; feet=[]
    for f in range(1,c['frames']+1):
        s.frame_set(f); bpy.context.view_layer.update()
        if f in samples: expected[c['name']][f]={n:list(rig.matrix_world@rig.pose.bones[n].head) for n in ['LowerTorso','Head','LeftHand','RightHand','LeftFoot','RightFoot']}
        right=rig.matrix_world@rig.pose.bones['RightHand'].matrix@Vector((0,.20,0))
        grip_errors.append((right-prop.matrix_world.translation).length)
        if f==1: first={n:rig.pose.bones[n].matrix.copy() for n in rig.pose.bones.keys()}
        if f==c['frames'] and c['loop']:
            loops.append({'clip':c['name'],'max_matrix_delta':max(max(abs(first[n][r][k]-rig.pose.bones[n].matrix[r][k]) for r in range(4) for k in range(4)) for n in first)})
        if c['name'].startswith(('Light_','Heavy_')):
            feet.append([rig.pose.bones[n].head.copy() for n in ['LeftFoot','RightFoot']])
    if feet: foot_drift.append({'clip':c['name'],'max_drift':max((p-feet[0][i]).length for frame in feet for i,p in enumerate(frame))})
results=[]
for c in manifest:
    bpy.ops.wm.read_factory_settings(use_empty=True); bpy.context.scene.render.fps=30
    bpy.ops.import_scene.fbx(filepath=str(root/c['fbx']),use_anim=True,anim_offset=0,ignore_leaf_bones=False)
    r=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    maximum=0
    for frame,bones in expected[c['name']].items():
        bpy.context.scene.frame_set(frame); bpy.context.view_layer.update()
        for n,pos in bones.items(): maximum=max(maximum,(r.matrix_world@r.pose.bones[n].head-Vector(pos)).length)
    results.append({'clip':c['name'],'max_joint_position_error':maximum,'bones':len(r.data.bones),'has_animation':r.animation_data is not None and r.animation_data.action is not None})
    print('ROUNDTRIP',c['name'],maximum,flush=True)
report={'fbx_roundtrip':results,'max_actual_right_grip_error':max(grip_errors),'loop_seams':loops,'planted_attack_feet':foot_drift,'studio_import_verified':False}
(root/'export_checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert max(grip_errors)<.02, 'Right grip drifts'
assert all(x['max_matrix_delta']<.002 for x in loops), 'Loop seam'
assert all(x['max_drift']<.002 for x in foot_drift), 'Attack foot sliding'
assert all(x['max_joint_position_error']<.02 and x['has_animation'] for x in results), 'FBX pose changed'
print('ALL_EXPORT_CHECKS_PASSED',flush=True)
