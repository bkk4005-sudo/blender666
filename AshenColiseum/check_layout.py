import bpy, math, json
from mathutils import Vector
from pathlib import Path
s=bpy.context.scene
deps=bpy.context.evaluated_depsgraph_get()
routes=[]
for q in range(4):
    a=q*math.pi/2; d=Vector((math.cos(a),math.sin(a),0)); side=Vector((-d.y,d.x,0))
    for offset in [-1.4,0,1.4]:
        origin=d*24+side*offset+Vector((0,0,2.8))
        hit,loc,normal,index,obj,matrix=s.ray_cast(deps,origin,d,distance=36)
        routes.append({'court':q+1,'lateral_offset':offset,'clear':not hit,'obstacle':obj.name if hit else None})
report={'routes_at_character_torso_height':routes,'all_routes_clear':all(r['clear'] for r in routes),'mesh_count':sum(o.type=='MESH' for o in s.objects),'empty_spawn_guides':sum(o.name.startswith('Court_') and '_Player_' in o.name for o in s.objects),'studio_playtest':False}
(Path(__file__).resolve().parent/'layout_check.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
assert report['all_routes_clear'], 'A route is blocked'
assert report['empty_spawn_guides']==8
