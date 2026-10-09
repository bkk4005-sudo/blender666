"""Record structural primitives without rebuilding/saving the authored .blend."""
from pathlib import Path
import json
root=Path(__file__).resolve().parent.parent
code=(root/'AshenColiseum/build_scene.py').read_text(encoding='utf-8').split('# Commit meshes;')[0]
code=code.replace("ROOT = Path(__file__).resolve().parent", "ROOT = Path(__file__).resolve().parent.parent / 'AshenColiseum'\nCOLLIDERS=[]")
code=code.replace("def box(pos,size,mat='stone0',ang=0):", "def box(pos,size,mat='stone0',ang=0):\n    COLLIDERS.append(dict(kind='box',district=DIST,pos=pos,size=size,mat=mat,angle=ang))")
code=code.replace("def cylinder(pos,r,depth,mat='stone0',segments=24,top=None):", "def cylinder(pos,r,depth,mat='stone0',segments=24,top=None):\n    COLLIDERS.append(dict(kind='cylinder',district=DIST,pos=pos,r=r,depth=depth,mat=mat,top=top))")
code=code.replace("def ring(center,ri,ro,z,h,mat='trim',start=0,end=math.tau,n=96):", "def ring(center,ri,ro,z,h,mat='trim',start=0,end=math.tau,n=96):\n    COLLIDERS.append(dict(kind='ring',district=DIST,center=center,ri=ri,ro=ro,z=z,h=h,mat=mat,start=start,end=end,n=n))")
scope={'__file__':str(Path(__file__).resolve()),'__name__':'__main__'}
exec(compile(code,str(root/'AshenColiseum/build_scene.py'),'exec'),scope)
items=[]
for p in scope['COLLIDERS']:
    if p['mat'] not in ('dark','trim','sand','floor','wood') and not p['mat'].startswith('stone'): continue
    if p['district'].startswith(('10 /','11 /')): continue
    if p['kind']=='box' and (min(p['size'])<.16 or p['size'][2]<.15): continue
    if p['kind']=='cylinder' and (p['r']<1 or p['depth']<.14): continue
    if p['kind']=='ring' and (p['h']<.15 or p['ro']-p['ri']<.3): continue
    items.append(p)
out=root/'roblox-transfer/export/colliders.json'
out.write_text(json.dumps(items,separators=(',',':')),encoding='utf-8')
print('COLLIDERS',len(items),'all',len(scope['COLLIDERS']),flush=True)
