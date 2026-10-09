"""Open with Blender --python select_clip.py -- Light_01. Selects both action tracks."""
import bpy,sys
name=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'Light_01'
s=bpy.context.scene
if name=='Showcase':
    for obname in ['R15_AshenOath','Sword motion / paired PROP actions']:
        obj=bpy.data.objects[obname]; obj.animation_data.action=None
        for tr in obj.animation_data.nla_tracks: tr.mute=False
    s.frame_start=1; s.frame_end=774
else:
    for obname,prefix in [('R15_AshenOath',''),('Sword motion / paired PROP actions','PROP__')]:
        obj=bpy.data.objects[obname]
        for tr in obj.animation_data.nla_tracks: tr.mute=True
        obj.animation_data.action=bpy.data.actions[prefix+name]
    s.frame_start=1; s.frame_end=round(bpy.data.actions[name].frame_range[1])
s.frame_set(1)
print('CLIP_READY',name)
