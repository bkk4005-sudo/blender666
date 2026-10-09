"""Original Ashen Coliseum. Built only from procedural geometry, no external assets."""
import bpy, math, random, json, sys
from pathlib import Path
from mathutils import Vector
from collections import defaultdict

ROOT = Path(__file__).resolve().parent
random.seed(7421)
bpy.ops.wm.read_factory_settings(use_empty=True)
S = bpy.context.scene
S.unit_settings.system = 'NONE'
S['project'] = 'Ashen Coliseum / Колизей пепельной короны'
S['scale_convention'] = '1 Blender unit = 1 intended Roblox stud; verify importer scale before publishing'
S['original_work'] = 'New geometry created from scratch. No Eclipse Sanctum assets used.'
S['layout'] = 'Central coliseum + four 26-unit dueling courts, each with opposing spawns and an observation perimeter.'

def stone(name, color, rough=.8, metallic=0, noise=True):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    n=m.node_tree.nodes; l=m.node_tree.links; p=n.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metallic
    if noise:
        tex=n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=3.8; tex.inputs['Detail'].default_value=3
        coord=n.new('ShaderNodeTexCoord'); l.new(coord.outputs['Object'],tex.inputs['Vector'])
        ramp=n.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position=.19; ramp.color_ramp.elements[0].color=(*[v*.55 for v in color],1)
        ramp.color_ramp.elements[1].position=.82; ramp.color_ramp.elements[1].color=(*[min(v*1.3,1) for v in color],1)
        l.new(tex.outputs['Fac'],ramp.inputs[0]); l.new(ramp.outputs[0],p.inputs['Base Color'])
        bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.22; bump.inputs['Distance'].default_value=.07
        l.new(tex.outputs['Fac'],bump.inputs['Height']); l.new(bump.outputs[0],p.inputs['Normal'])
    return m

MAT={}
for i in range(6): MAT['stone'+str(i)]=stone('Basalt / variation '+str(i),(.235+i*.016,.257+i*.016,.274+i*.015))
MAT['trim']=stone('Worn limestone / carved edges',(.46,.45,.395))
MAT['dark']=stone('Deep joint / black stone',(.085,.105,.122))
MAT['floor']=stone('Arena paving / ash',(.34,.35,.32))
MAT['sand']=stone('Fighting surface / pale mineral',(.48,.465,.39))
MAT['metal']=stone('Oxidized bronze',(.24,.16,.065),.38,.72)
MAT['gold']=stone('Brass inlay',(.54,.36,.115),.3,.68)
MAT['rock']=stone('Cliff / slate',(.14,.17,.19))
MAT['red']=stone('Oxblood woven banners',(.22,.022,.032),.85,0,False)
MAT['blue']=stone('Dusk blue woven banners',(.04,.14,.21),.85,0,False)
MAT['green']=stone('Old moss',(.12,.20,.095))
MAT['leaf']=stone('Cypress foliage',(.045,.095,.065))
MAT['wood']=stone('Dark wood',(.12,.07,.034))
MAT['water']=stone('Still water',(.035,.16,.18),.17,.25,False)
MAT['ember']=stone('Warm basalt',(.25,.16,.125))
def glow(name,color,power):
    m=stone(name,color,.4,0,False); p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=power; return m
MAT['fire']=glow('Flame / amber',(1,.27,.025),5)
MAT['core']=glow('Flame / heart',(1,.72,.22),9)
MAT['rune']=glow('Moon shrine / soft mineral light',(.18,.58,.7),2)

# Static architectural geometry is batched by district and material.
G=defaultdict(lambda: [[],[]]); DIST='00 / Foundation'
def mesh(mat,verts,faces):
    v,f=G[(DIST,mat)]; start=len(v); v.extend(verts); f.extend(tuple(start+i for i in face) for face in faces)
def box(pos,size,mat='stone0',ang=0):
    x,y,z=pos; a,b,c=[t/2 for t in size]; co,si=math.cos(ang),math.sin(ang)
    pts=[(x+u*co-v*si,y+u*si+v*co,z+w) for u,v,w in [(-a,-b,-c),(a,-b,-c),(a,b,-c),(-a,b,-c),(-a,-b,c),(a,-b,c),(a,b,c),(-a,b,c)]]
    mesh(mat,pts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def cylinder(pos,r,depth,mat='stone0',segments=24,top=None):
    x,y,z=pos; rt=r if top is None else top
    vs=[(x+rr*math.cos(i*math.tau/segments),y+rr*math.sin(i*math.tau/segments),zz) for rr,zz in [(r,z-depth/2),(rt,z+depth/2)] for i in range(segments)]
    faces=[tuple(reversed(range(segments))),tuple(range(segments,2*segments))]
    faces.extend((i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)); mesh(mat,vs,faces)
def ring(center,ri,ro,z,h,mat='trim',start=0,end=math.tau,n=96):
    x,y=center; vs=[]
    for i in range(n+1):
        a=start+(end-start)*i/n
        for r,zz in [(ri,z),(ro,z),(ri,z+h),(ro,z+h)]: vs.append((x+r*math.cos(a),y+r*math.sin(a),zz))
    fs=[]
    for i in range(n):
        a=i*4; b=a+4; fs.extend([(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)])
    fs.extend([(0,1,3,2),(n*4,n*4+2,n*4+3,n*4+1)]); mesh(mat,vs,fs)
def radial(r,a,z,center=(0,0)): return (center[0]+r*math.cos(a),center[1]+r*math.sin(a),z)
def arch(center,angle,width,spring,thick,depth,mat='trim'):
    # Upright semicircular voussoirs; center is the base of the portal.
    x,y,z=center; ux,uy=math.cos(angle),math.sin(angle); vx,vy=-uy,ux; r=width/2
    for sign in [-1,1]:
        for j in range(max(1,int(spring/.68))):
            h=spring/max(1,int(spring/.68)); box((x+sign*(r+thick/2)*ux,y+sign*(r+thick/2)*uy,z+(j+.5)*h),(thick-.025,depth,h-.025),mat,angle)
        box((x+sign*(r+thick/2)*ux,y+sign*(r+thick/2)*uy,z+spring-.08),(thick+.22,depth+.2,.22),'trim',angle)
    for i in range(13):
        t0=i*math.pi/13+.008; t1=(i+1)*math.pi/13-.008; vs=[]
        for d in [-depth/2,depth/2]:
            for rr,t in [(r,t0),(r+thick,t0),(r+thick,t1),(r,t1)]:
                u=rr*math.cos(t); vs.append((x+u*ux+d*vx,y+u*uy+d*vy,z+spring+rr*math.sin(t)))
        mesh(mat,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def light(name,pos,color,power,radius=2):
    d=bpy.data.lights.new(name,'POINT'); d.energy=power; d.color=color; d.shadow_soft_size=radius
    o=bpy.data.objects.new(name,d); S.collection.objects.link(o); o.location=pos
def torch(x,y,z,lights=True):
    cylinder((x,y,z+.22),.57,.44,'dark',8); cylinder((x,y,z+1),.23,1.3,'metal',8)
    cylinder((x,y,z+1.7),.42,.22,'gold',10,top=.64)
    for j in range(6):
        a=j*math.tau/6; cylinder((x+.47*math.cos(a),y+.47*math.sin(a),z+1.94),.045,.65,'metal',6)
    cylinder((x,y,z+2.07),.4,.65,'fire',9,top=.1)
    cylinder((x+.07,y,z+2.55),.17,.55,'core',7,top=0)
    if lights: light('Brazier / warm pool',(x,y,z+2.6),(1,.40,.13),180,1.1)
def banner(pos,angle,mat='red',length=3.4):
    x,y,z=pos; co,si=math.cos(angle),math.sin(angle)
    box((x,y,z+.1),(2.1,.09,.09),'metal',angle)
    vs=[]; nx,ny=10,14
    for j in range(ny+1):
        for i in range(nx+1):
            u=(i/nx-.5)*1.7; depth=.16*math.sin(i*.65+j*.48)*j/ny
            zz=z-j/ny*length-(.30*(1-abs(u)/.85) if j==ny else 0)
            vs.append((x+u*co-depth*si,y+u*si+depth*co,zz))
    fs=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)]
    mesh(mat,vs,fs)
    # Raised brass diamond insignia in front of the cloth.
    vs=[(x+u*co+.19*si,y+u*si-.19*co,z+zz) for u,zz in [(0,-.65),(.28,-1.15),(0,-1.65),(-.28,-1.15)]]; mesh('gold',vs,[(0,1,2,3)])
def cliff(center,r,depth,seed):
    rng=random.Random(seed); x,y=center; n=40; vs=[]
    for level,(zz,rr) in enumerate([(-depth,r*.76),(-depth*.6,r*1.02),(-2,r*1.06),(-.45,r)]):
        for i in range(n):
            a=i*math.tau/n; rad=rr*(1+rng.uniform(-.065,.065)); vs.append((x+rad*math.cos(a),y+rad*math.sin(a),zz+rng.uniform(-.4,.25)))
    fs=[]
    for j in range(3):
        for i in range(n):
            a=j*n+i; b=j*n+(i+1)%n
            fs.extend([(a,b,a+n),(b,b+n,a+n)])
    fs.append(tuple(range(3*n,4*n))); mesh('rock',vs,fs)
def paving(center,r,mat='floor'):
    cylinder((center[0],center[1],-.13),r,.3,'dark',96)
    # Concentric cut stone bands with individually staggered joints.
    cylinder((center[0],center[1],.025),2,.08,mat,32)
    for j in range(int((r-2)/1.35)+1):
        ri=2+j*1.35; ro=min(r,ri+1.31)
        if ro<=ri: continue
        n=max(12,int(math.tau*ri/2.8)); offset=(j%2)*math.pi/n
        for i in range(n): ring(center,ri,ro,.005,.10,mat if random.random()<.72 else 'stone'+str(random.randrange(2,6)),offset+i*math.tau/n+.004,offset+(i+1)*math.tau/n-.004,3)
def compass(center,r,z=.13):
    ring(center,r-.08,r+.08,z,.035,'gold')
    for i in range(16):
        a=i*math.tau/16; length=r*.9 if i%4==0 else r*.6 if i%2==0 else r*.35
        origin=Vector((center[0],center[1],z+.04)); tip=Vector(radial(length,a,z+.04,center)); side=Vector((-math.sin(a)*.28,math.cos(a)*.28,0))
        mesh('gold',[tuple(origin),tuple(origin+side),tuple(tip),tuple(origin-side)],[(0,1,2),(0,2,3)])

def limb(p1,p2,r1,r2,mat='stone2',n=8):
    a,b=Vector(p1),Vector(p2); axis=(b-a).normalized(); u=axis.cross(Vector((0,0,1)))
    if u.length<.01: u=axis.cross(Vector((0,1,0)))
    u.normalize(); v=axis.cross(u); verts=[]
    for p,r in [(a,r1),(b,r2)]:
        for i in range(n): verts.append(tuple(p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))))
    mesh(mat,verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])

def guardian(pos,angle,scale=1):
    """Original carved armored guardian, sword down, mounted on a plinth."""
    x,y,z=pos
    def p(xx,yy,zz): return (x+scale*(xx*math.cos(angle)-yy*math.sin(angle)),y+scale*(xx*math.sin(angle)+yy*math.cos(angle)),z+scale*zz)
    box(p(0,0,.3),(1.9*scale,1.9*scale,.6*scale),'dark',angle)
    box(p(0,0,.7),(1.65*scale,1.65*scale,.22*scale),'trim',angle)
    for side in [-1,1]:
        box(p(side*.32,-.08,.92),(.38*scale,.7*scale,.28*scale),'stone3',angle)
        limb(p(side*.32,0,1),p(side*.26,0,2.1),.20*scale,.26*scale,'stone3')
        limb(p(side*.26,0,2.1),p(side*.22,0,2.7),.25*scale,.29*scale,'stone3')
        limb(p(side*.7,0,3.65),p(side*.65,-.25,3.0),.30*scale,.20*scale,'trim')
        limb(p(side*.65,-.25,3),p(side*.13,-.53,2.9),.20*scale,.15*scale,'stone3')
        cylinder(p(side*.7,0,3.7),.36*scale,.26*scale,'dark',8)
    limb(p(0,0,2.55),p(0,0,3.65),.38*scale,.65*scale,'stone2')
    cylinder(p(0,0,3.94),.18*scale,.3*scale,'dark',8)
    cylinder(p(0,0,4.29),.34*scale,.55*scale,'trim',8,top=.28*scale)
    cylinder(p(0,0,4.68),.30*scale,.25*scale,'trim',8,top=0)
    box(p(0,-.305,4.28),(.48*scale,.035*scale,.065*scale),'dark',angle)
    box(p(0,-.58,2.78),(.76*scale,.13*scale,.14*scale),'gold',angle)
    box(p(0,-.58,1.93),(.17*scale,.07*scale,1.6*scale),'metal',angle)
    cylinder(p(0,-.58,3),.08*scale,.45*scale,'metal',8)
    # Faceted stone cloak hanging behind the armor.
    mesh('dark',[p(-.55,.24,3.65),p(.55,.24,3.65),p(.77,.43,1.0),p(0,.64,.9),p(-.77,.43,1.0)],[(0,1,3),(1,2,3),(0,3,4)])

# Raised central island and stepped foundations.
cliff((0,0),36.7,10,3)
for r,z,h in [(36,-.9,1.0),(35.5,-.3,.35),(30.4,-.2,.2)]: cylinder((0,0,z),r,h,'dark' if r==36 else 'trim',128)
DIST='01 / Coliseum / ceremonial floor'
paving((0,0),25.4,'sand'); compass((0,0),9)
for r in [14,22.4,24.6]: ring((0,0),r,r+.13,.12,.035,'gold')
for i in range(32):
    a=i*math.tau/32; box(radial(23.5,a,.15),(.75,.12,.05),'dark',a)
# Tiered stands with four generous axial circulation corridors.
DIST='02 / Coliseum / seating galleries'
for level in range(5):
    ri=25.8+level*.95
    for q in range(4):
        start=q*math.pi/2+.125; end=(q+1)*math.pi/2-.125
        ring((0,0),ri,ri+.9,.12, .52+level*.64,'stone'+str(level),start,end,32)
        ring((0,0),ri-.015,ri+.91,.65+level*.64,.12,'trim',start,end,32)
    for q in range(4):
        a=q*math.pi/2+math.pi/4
        for j in range(2): box(radial(ri+.22+j*.4,a,.43+level*.64+j*.28),(.42,1.8,.25),'dark',a)
for q in range(4):
    ring((0,0),30.65,31.55,.0,4.4,'dark',q*math.pi/2+.12,(q+1)*math.pi/2-.12,32)
    ring((0,0),30.45,31.8,4.4,.32,'trim',q*math.pi/2+.12,(q+1)*math.pi/2-.12,32)
# Open two-storey arcades: real voids rather than black arch decals.
DIST='03 / Coliseum / double arcade'
N=40; R=33.2; step=math.tau/N
for i in range(N):
    a=(i+.5)*step; tang=a+math.pi/2
    for base,width,spring in [(0,3.72,3.65),(7.3,3.65,2.25)]:
        if base==0 and i%10 in [0,9]: continue
        arch(radial(R,a,base),tang,width,spring,.52,1.35,'stone'+str(i%6))
    pa=i*step
    for course in range(18):
        if i%10==0 and course<11: continue
        box(radial(R,pa,(course+.5)*.7),(1.5,1.5,.674),'stone'+str((i+course)%6),pa)
    for z in [.2,6.75,7.12,12.05,12.65]: box(radial(R,pa,z),(1.85,1.9,.25),'trim',pa)
    # Exterior attached pilasters / deeply articulated silhouette.
    if i%10!=0: box(radial(R+.95,pa,6.1),(.6,.66,11.4),'trim',pa)
    if i%2==0 and i%10!=0: banner(radial(R+1.04,pa,6.55),tang,'red',3.0)
for z,h in [(6.55,.34),(7.02,.28),(11.75,.32),(12.4,.42)]: ring((0,0),31.8,34.5,z,h,'trim')
ring((0,0),32.1,34.2,12.82,.65,'stone3')
for i in range(80):
    a=i*math.tau/80; box(radial(33.2,a,13.65),(1.25,.84,1),'stone3',a)
    box(radial(33.2,a,14.2),(1.45,1.03,.16),'trim',a)

# Four monumental entrances, readable from each approach.
DIST='04 / Coliseum / axial gatehouses'
for q in range(4):
    a=q*math.pi/2; t=a+math.pi/2
    arch(radial(35.0,a,0),t,6,4.6,.9,2.6,'trim')
    for side in [-1,1]:
        p=Vector(radial(35,a,0))+Vector((-math.sin(a),math.cos(a),0))*side*4.5
        box((p.x,p.y,4.8),(2.2,3.0,9.6),'stone2',a)
        for z in [.3,8.4,9.6]: box((p.x,p.y,z),(2.5,3.35,.4),'trim',a)
        cylinder((p.x,p.y,10.4),.8,1.3,'dark',8,top=.2)
        torch(p.x+math.cos(a)*1.45,p.y+math.sin(a)*1.45,.2)
        inside=Vector(radial(28.2,a,0))+Vector((-math.sin(a),math.cos(a),0))*side*4.1
        guardian((inside.x,inside.y,.3),a-math.pi/2,.8)
    box(radial(35,a,8.35),(2.9,11.8,.45),'trim',a)
    banner(radial(36.55,a,8),t,'red',2.8)

CENTERS=[(60,0),(0,60),(-60,0),(0,-60)]
NAMES=['05 / Court I / Ember forge','06 / Court II / Moon sanctuary','07 / Court III / Thorn garden','08 / Court IV / Fallen kings']
for q,center in enumerate(CENTERS):
    DIST=NAMES[q]; cx,cy=center; a=q*math.pi/2
    cliff(center,15.6,8,40+q)
    cylinder((cx,cy,-.6),15.3,1.1,'dark',96); cylinder((cx,cy,-.27),14.9,.32,'trim',96)
    paving(center,12.8,'floor'); ring(center,12.85,14.7,.01,.22,'stone2')
    ring(center,10.7,10.86,.12,.05,'gold'); ring(center,12.5,12.65,.13,.05,'trim'); compass(center,3.5)
    # Unobstructed 21-unit fighting disk; spawn markers face each other.
    for sign in [-1,1]:
        p=radial(7.8,a+sign*math.pi/2,.14,center)
        ring((p[0],p[1]),.82,1.05,.14,.025,'gold',n=32)
        box(p,(1.0,.11,.06),'gold',a)
    # Peripheral wall leaves broad access at inward-facing bridge.
    for i in range(32):
        ang=a+i*math.tau/32
        if abs(((ang-(a+math.pi)+math.pi)%math.tau)-math.pi)<.26: continue
        for j in range(2):
            ring(center,14.15,14.7,.23+j*.56,.53,'stone'+str((i+j)%6),ang+.015,ang+math.tau/32-.015,3)
        ring(center,14.0,14.85,1.35,.17,'trim',ang,ang+math.tau/32,3)
    for side in [-1,1]:
        p=radial(13.6,a+math.pi+side*.38,0,center); torch(*p)
    # Eight visitor seats outside the combat boundary.
    for k in range(8):
        ang=a-.95+k*1.9/7; p=radial(13.3,ang,.55,center)
        box(p,(.72,1.55,.25),'trim',ang)
        for offset in [-.55,.55]:
            box((p[0]-math.sin(ang)*offset,p[1]+math.cos(ang)*offset,.3),(.5,.25,.5),'dark',ang)
    # Architectural backdrop facing the central coliseum.
    for k in [-2,-1,0,1,2]:
        ang=a+k*.21; p=radial(14,ang,0,center)
        height=[4.8,6.2,5.2,4.7][q]
        cylinder((p[0],p[1],.28),.7,.55,'trim',12)
        cylinder((p[0],p[1],height/2+.5),.43,height,'trim',12,top=.36)
        for z in [1,height+.4,height+.65]: cylinder((p[0],p[1],z),.62,.2,'trim',12)
    # Continuous carved entablature, stepped crown and smaller side arcades.
    height=[4.8,6.2,5.2,4.7][q]
    for zz,ri,ro,hh in [(height+.7,13.25,14.7,.28),(height+1,13.05,14.9,.22),(height+1.25,13.4,14.5,.42)]:
        ring(center,ri,ro,zz,hh,'trim' if hh<.4 else 'stone2',a-.48,a+.48,32)
    for side in [-1,1]:
        for kk in range(3):
            ang=a+side*(.69+kk*.24)
            pp=radial(14,ang,0,center)
            arch(pp,ang+math.pi/2,2.5,2.3,.37,.7,'stone3')
            ring(center,13.5,14.5,4.03,.22,'trim',ang-.13,ang+.13,6)
        pp=radial(14,a+side*.49,0,center)
        banner((pp[0],pp[1],height+.45),a+math.pi/2,'blue' if q==1 else 'red',2.6)
    if q==0:
        # Forge: heavy chimney, bronze sun and twin fire basins.
        p=radial(14.5,a,0,center)
        box((p[0],p[1],4),(2.2,4.3,8),'ember',a)
        for z in [1.0,4.9,7.8]: box((p[0],p[1],z),(2.6,4.7,.35),'dark',a)
        arch((p[0]-1.2,p[1],.4),a+math.pi/2,2.3,1.7,.4,.4,'metal')
        box((p[0]-1.25,p[1],1.6),(.04,2.1,2.1),'fire',a)
        for side in [-1,1]:
            pp=radial(12.8,a+side*.72,0,center); torch(*pp)
        for k in range(7): box((p[0],p[1]+(k-3)*.5,8.5),(.3,.18,1.2),'metal',a)
    elif q==1:
        # Moon sanctuary: reflecting pools and a tall crescent-like ring.
        for side in [-1,1]:
            pp=radial(12.9,a+side*.57,0,center)
            cylinder((pp[0],pp[1],.35),1.4,.5,'trim',32); cylinder((pp[0],pp[1],.62),1.2,.06,'water',40)
        p=radial(14.1,a,5.5,center)
        # vertical sculptural halo in local tangent plane
        vs=[]; faces=[]
        for i in range(65):
            th=i*math.tau/64
            for rr,d in [(1.8,-.18),(2.05,-.18),(1.8,.18),(2.05,.18)]: vs.append((p[0]+rr*math.cos(th),p[1]+d,p[2]+rr*math.sin(th)))
        for i in range(64):
            b=i*4; c=b+4; faces.extend([(b,b+1,c+1,c),(b+2,c+2,c+3,b+3),(b,b+4,b+6,b+2),(b+1,b+3,c+3,c+1)])
        mesh('gold',vs,faces); cylinder((p[0],p[1],2.4),.42,3.5,'rune',6,top=0)
        light('Moon / pale blue', (p[0],p[1]-1,4),(.25,.65,1),300,3)
    elif q==2:
        # Cloister garden: cypresses and climbing growth stay off the fighting floor.
        for k in [-2,-1,1,2]:
            pp=radial(14.1,a+k*.33,0,center)
            cylinder((pp[0],pp[1],.28),.85,.5,'trim',12)
            cylinder((pp[0],pp[1],1.5),.18,2.5,'wood',8)
            for j in range(4): cylinder((pp[0],pp[1],2+j*.85),.92-j*.14,2.5,'leaf',9,top=.1)
        for k in range(65):
            ang=a+random.uniform(-1,1); rr=random.uniform(13.7,14.8); p=radial(rr,ang,random.uniform(.15,.5),center)
            cylinder(p,random.uniform(.15,.4),.2,'green',7,top=.1)
    else:
        # Fallen kings: sarcophagus-like memorial and broken obelisks.
        for k in [-1,0,1]:
            p=radial(13.9,a+k*.4,0,center)
            box((p[0],p[1],.35),(1.9,1.9,.7),'dark',a)
            cylinder((p[0],p[1],2.8),.78,4.2,'stone2',4,top=.48)
            cylinder((p[0],p[1],5.3),.7,.9,'trim',4,top=0)
            banner((p[0],p[1]-.55,4.4),0,'blue',2.2)
        for k in range(12):
            pp=radial(random.uniform(13,14),a+random.choice([-1,1])*random.uniform(.7,1.0),.35,center)
            box(pp,(random.uniform(.35,.9),.5,.55),'stone2',random.random()*3)
        pp=radial(13.5,a,0,center); guardian(pp,a-math.pi/2,1.35)
    # Broad stone bridge with repeating floor joints, balustrades and buttresses.
    DIST='09 / Bridges / '+str(q+1)
    for j in range(13):
        rr=36.2+j*.73
        box(radial(rr,a,-.05),(.7,5.8,.4),'stone'+str(j%6),a)
        for side in [-1,1]:
            p=Vector(radial(rr,a,.7))+Vector((-math.sin(a),math.cos(a),0))*side*3
            box(tuple(p),(.75,.38,1.1),'stone2',a)
            box((p.x,p.y,1.3),(.76,.57,.18),'trim',a)
    for rr in [36.3,40.3,44.3]:
        for side in [-1,1]:
            p=Vector(radial(rr,a,0))+Vector((-math.sin(a),math.cos(a),0))*side*3
            box((p.x,p.y,.8),(.75,.75,1.7),'trim',a)
            if rr==40.3: torch(p.x,p.y,1.7)
        box(radial(rr,a,-2.7),(1,6.3,5),'dark',a)

# Small perimeter lanterns and central ceremonial braziers.
DIST='10 / Dressing / inner lighting'
for i in range(12):
    a=(i+.5)*math.tau/12; p=radial(25.1,a,.25); torch(*p)
for q in range(4):
    a=q*math.pi/2
    for side in [-1,1]:
        p=radial(31.2,a+side*.12,4.75); torch(*p,lights=False)

# Rock outcrops anchor the architecture into a twilight basin.
DIST='11 / Landscape / distant slate'
for i in range(38):
    a=random.random()*math.tau; rr=random.uniform(96,150); radius=random.uniform(3,9); h=random.uniform(5,15)
    p=radial(rr,a,-11+h/2)
    verts=[]; n=9
    for zz,rad in [(-h/2,radius),(-h*.1,radius*.85),(h*.35,radius*.55),(h*.5,radius*.18)]:
        for k in range(n):
            t=k*math.tau/n; r=rad*random.uniform(.65,1.3)
            verts.append((p[0]+r*math.cos(t),p[1]+r*math.sin(t),p[2]+zz+random.uniform(-.5,.5)))
    faces=[]
    for j in range(3):
        for k in range(n):
            b=j*n+k; c=j*n+(k+1)%n; faces.extend([(b,c,b+n),(c,c+n,b+n)])
    faces.append(tuple(range(27,36))); mesh('rock',verts,faces)
cylinder((0,0,-11.5),220,1,'dark',128)

# Commit meshes; bevel edges catch restrained warm/cool light.
for (district,key),(verts,faces) in G.items():
    col=bpy.data.collections.get(district)
    if not col: col=bpy.data.collections.new(district); S.collection.children.link(col)
    me=bpy.data.meshes.new(district+' / '+key); me.from_pydata(verts,[],faces); me.materials.append(MAT[key]); me.update()
    ob=bpy.data.objects.new(district.split(' / ')[-1]+' • '+key,me); col.objects.link(ob)
    if key not in ['fire','core','water','rune','rock','red','blue','leaf','green']:
        mod=ob.modifiers.new('Hand softened masonry edges','BEVEL'); mod.width=.035; mod.segments=2
        mod.limit_method='ANGLE'
    ob['district']=district; ob['export_note']='Separate by gameplay module before Roblox import. Procedural shaders require baking.'

# Explicit gameplay helpers (non-rendering empties).
col=bpy.data.collections.new('12 / Gameplay layout / guides only'); S.collection.children.link(col)
for q,c in enumerate(CENTERS):
    for sign in [-1,1]:
        a=q*math.pi/2+sign*math.pi/2
        ob=bpy.data.objects.new('Court_%d_Player_%s'%(q+1,'A' if sign==1 else 'B'),None); col.objects.link(ob); ob.location=radial(7.8,a,.2,c); ob.empty_display_type='ARROWS'; ob.empty_display_size=1.4
    ob=bpy.data.objects.new('Court_%d_ClearCombatRadius_10.5'% (q+1),None); col.objects.link(ob); ob.location=(*c,.2); ob.empty_display_type='CIRCLE'; ob.empty_display_size=10.5

world=bpy.data.worlds.new('Blue hour / clear twilight'); S.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.25,.34,1); world.node_tree.nodes['Background'].inputs[1].default_value=.3
d=bpy.data.lights.new('Moonrise / broad shadows','SUN'); ob=bpy.data.objects.new('Moonrise / broad shadows',d); S.collection.objects.link(ob); d.energy=1.1; d.angle=.14; d.color=(.61,.77,1); ob.rotation_euler=(.45,-.5,-.4)
def area(name,location,power,color,size,target=(0,0,0)):
    d=bpy.data.lights.new(name,'AREA'); d.energy=power; d.color=color; d.shape='DISK'; d.size=size
    o=bpy.data.objects.new(name,d); S.collection.objects.link(o); o.location=location; o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Late sun / warm stone edges',(-45,-60,65),70000,(1,.66,.35),65)
area('Sky fill',(40,45,80),55000,(.40,.61,1),75)

def camera(name,pos,target,lens=48,ortho=None):
    d=bpy.data.cameras.new(name); o=bpy.data.objects.new(name,d); S.collection.objects.link(o); o.location=pos; o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler(); d.lens=lens; d.clip_end=1000
    if ortho: d.type='ORTHO'; d.ortho_scale=ortho
    return o
cams=[camera('Camera / master plan',(116,-148,155),(0,0,0),48,164),camera('Camera / coliseum interior',(20,-25,18),(0,7,5),24),camera('Camera / four courts plan',(0,-.1,200),(0,0,0),48,172),camera('Camera / fallen kings court',(23,-39,20),(0,-61,2),36)]
S.camera=cams[0]
S.cycles.samples=32
S.cycles.use_denoising=True
# Eevee is the portable preview renderer on this workstation.
S.render.engine='CYCLES' if '--cycles' in sys.argv else 'BLENDER_EEVEE'
S.cycles.device='CPU'
S.render.resolution_x=1800; S.render.resolution_y=1500; S.render.resolution_percentage=100
S.render.image_settings.file_format='PNG'
S.view_settings.view_transform='AgX'
S.render.film_transparent=False
# Blender 5 compositor output, preserving architecture contrast.
S.use_nodes=True
nt=bpy.data.node_groups.new('Atmosphere finishing','CompositorNodeTree'); S.compositing_node_group=nt; nt.nodes.clear(); rl=nt.nodes.new('CompositorNodeRLayers');
nt.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor'); out=nt.nodes.new('NodeGroupOutput'); nt.links.new(rl.outputs['Image'],out.inputs['Image'])
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type=='VIEW_3D':
            ar.spaces.active.clip_end=1000
            ar.spaces.active.region_3d.view_distance=170
            ar.spaces.active.region_3d.view_location=(0,0,0)
            ar.spaces.active.region_3d.view_rotation=cams[0].rotation_euler.to_quaternion()
            ar.spaces.active.shading.type='SOLID'
            ar.spaces.active.shading.color_type='MATERIAL'
            ar.spaces.active.shading.light='STUDIO'
            ar.spaces.active.shading.show_shadows=True
            ar.spaces.active.shading.show_cavity=True
            ar.spaces.active.shading.cavity_type='BOTH'
S.render.filepath=str(ROOT/'renders'/'01_overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'AshenColiseum.blend'))
report={'mesh_objects':len([o for o in S.objects if o.type=='MESH']),'vertices':sum(len(o.data.vertices) for o in S.objects if o.type=='MESH'),'polygons_before_bevel':sum(len(o.data.polygons) for o in S.objects if o.type=='MESH'),'courts':4,'clear_fighting_diameter':21,'source':'Original procedural geometry','roblox_import_verified':False}
(ROOT/'build_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('BUILD_COMPLETE',report,flush=True)
if '--render' in sys.argv:
    bpy.ops.render.render(write_still=True)






