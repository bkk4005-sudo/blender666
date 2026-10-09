import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parent; folder=root/'previews'/'frames'; folder.mkdir(exist_ok=True)
s=bpy.context.scene; rig=bpy.data.objects['R15_AshenOath']; prop=bpy.data.objects['Sword motion / paired PROP actions']
for ob in [rig,prop]:
    for tr in ob.animation_data.nla_tracks: tr.mute=True
s.render.engine='BLENDER_EEVEE'; s.render.resolution_x=720; s.render.resolution_y=720; s.render.resolution_percentage=100
s.camera=bpy.data.objects['Camera / choreography']; s.camera.data.ortho_scale=10.5
if hasattr(s,'eevee') and hasattr(s.eevee,'taa_render_samples'): s.eevee.taa_render_samples=24
plan=[('Idle',30),('Light_01',None),('Light_02',None),('Light_03',None),('Heavy_Charge',None),('Heavy_Hold',21),('Heavy_Release',None),('Idle',30)]
index=0; shots=[]
for name,limit in plan:
    rig.animation_data.action=bpy.data.actions[name]; prop.animation_data.action=bpy.data.actions['PROP__'+name]
    end=limit or round(bpy.data.actions[name].frame_range[1]); start_index=index
    for f in range(1,end+1):
        s.frame_set(f); s.render.filepath=str(folder/('%04d.png'%index)); bpy.ops.render.render(write_still=True); index+=1
        if index%20==0: print('MOTION_FRAME',index,flush=True)
    shots.append({'clip':name,'start':start_index,'end':index-1})
(root/'previews'/'shots.json').write_text(json.dumps(shots,indent=2),encoding='utf-8')
print('MOTION_COMPLETE',index,flush=True)
