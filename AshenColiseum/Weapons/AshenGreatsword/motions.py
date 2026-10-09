"""Original two-handed greatsword choreography. Seconds, Blender Z-up / -Y front.
Poses describe a shared sword grip, body counter-rotation and planted feet.
All angles below are world-space degrees, not imported animation data.
"""
from math import sin, cos, pi
from mathutils import Vector, Euler, Quaternion

FPS=30
BASE={'p':(-.10,-.82,4.08),'angles':(23,-18,8),'body':(6,0,-8),'pelvis':(0,0,0),'root':(0,0,-.19),'lf':(.64,-.28,0),'rf':(-.65,.38,0),'footyaw':(-8,6),'head':(-4,0,5),'left_grip':1.0}
def pose(**kw):
    p=BASE.copy(); p.update(kw); return p
IDLE=pose()
GUARD=pose(p=(-.05,-.90,4.55),angles=(50,64,78),body=(10,0,-5),root=(0,.03,-.29))
HIGH=pose(p=(-.35,-.24,5.22),angles=(-48,-12,0),body=(-9,-5,-21),pelvis=(0,0,-10),root=(-.08,.10,-.26))
LOW=pose(p=(.30,-1.02,3.63),angles=(145,15,-5),body=(22,0,22),pelvis=(5,0,12),root=(.10,-.22,-.35),lf=(.64,-.66,0))
RIGHT=pose(p=(-.74,-.23,4.48),angles=(64,-108,-25),body=(-3,-4,-37),pelvis=(0,0,-16),root=(-.11,.12,-.24))
LEFT=pose(p=(.62,-.55,3.95),angles=(115,104,30),body=(15,5,34),pelvis=(2,0,15),root=(.08,-.14,-.26),lf=(.64,-.58,0))

CLIPS=[]
def clip(name,duration,keys=None,loop=False,events=None,kind='action',description='',travel=0):
    CLIPS.append(dict(name=name,duration=duration,keys=keys or [(0,IDLE),(duration,IDLE)],loop=loop,events=events or {},kind=kind,description=description,travel_studs=travel))

clip('Idle',3.2,loop=True,kind='idle',description='Low guard, slow breathing; blade inertia lags chest.')
for name,d,kind in [('WalkForward',1.20,'walk_f'),('WalkBackward',1.32,'walk_b'),('StrafeLeft',1.28,'walk_l'),('StrafeRight',1.28,'walk_r'),('RunForward',.86,'run')]:
    clip(name,d,loop=True,kind=kind,events={'FootL':0,'FootR':d/2},description='In-place locomotion. Drive gameplay root separately.')

clip('Equip',1.8,[(0,pose(p=(-.95,.25,3.5),angles=(155,-90,0),left_grip=0)),(.38,pose(p=(-.85,.05,3.8),angles=(117,-85,0),left_grip=0)),(.83,pose(p=(-.48,-.55,4.4),angles=(40,-45,-15),left_grip=.25)),(1.16,pose(p=(-.10,-.86,4.22),angles=(15,-18,8))),(1.8,IDLE)],events={'WeaponVisible':0,'LeftGrip':1.0,'Ready':1.65})
clip('Unequip',1.6,[(0,IDLE),(.32,pose(p=(-.18,-.9,4.03),angles=(35,-30,4))),(.8,pose(p=(-.65,-.55,3.72),angles=(108,-68,0),left_grip=0)),(1.35,pose(p=(-.95,.25,3.5),angles=(155,-90,0),left_grip=0)),(1.6,pose(p=(-.95,.25,3.5),angles=(155,-90,0),left_grip=0))],events={'LeftRelease':.55,'WeaponHidden':1.5})

clip('Light_01',1.40,[(0,IDLE),(.20,pose(p=(-.48,-.46,4.35),angles=(45,-70,-20),body=(0,0,-20))),(.43,RIGHT),(.53,pose(p=(-.62,-.56,4.40),angles=(72,-58,-12),body=(6,-3,-16),root=(-.06,-.02,-.3))),(.65,pose(p=(.05,-1.12,4.08),angles=(93,28,12),body=(13,3,18),root=(.07,-.18,-.3),lf=(.64,-.58,0))),(.78,LEFT),(.97,pose(p=(.54,-.55,3.9),angles=(118,105,28),body=(13,4,26),root=(.07,-.12,-.26),lf=(.64,-.58,0))),(1.40,IDLE)],events={'Windup':0,'Swing':.46,'ActiveStart':.52,'ActiveEnd':.75,'ComboOpen':.90,'RecoveryEnd':1.40},description='Right shoulder lead, diagonal cut, heavy left follow-through.',travel=.6)
clip('Light_02',1.48,[(0,IDLE),(.26,pose(p=(.59,-.55,4.06),angles=(62,109,25),body=(0,0,30),pelvis=(0,0,12))),(.48,pose(p=(.67,-.34,4.22),angles=(72,121,30),body=(1,0,38),root=(.08,.05,-.25))),(.60,pose(p=(.40,-.94,4.12),angles=(88,62,10),body=(10,2,18),root=(0,-.1,-.29))),(.72,pose(p=(-.38,-.98,3.97),angles=(99,-48,-15),body=(12,-3,-23),root=(-.06,-.20,-.31))),(.85,pose(p=(-.68,-.39,3.92),angles=(112,-115,-25),body=(10,-3,-36),pelvis=(0,0,-16),root=(-.07,-.13,-.27))),(1.04,pose(p=(-.64,-.42,3.94),angles=(106,-105,-20),body=(9,0,-25))),(1.48,IDLE)],events={'Windup':0,'Swing':.51,'ActiveStart':.58,'ActiveEnd':.81,'ComboOpen':.95,'RecoveryEnd':1.48},description='Backhand return with opposite hip drive.',travel=.6)
clip('Light_03',1.88,[(0,IDLE),(.37,HIGH),(.61,pose(p=(-.28,-.22,5.3),angles=(-60,-8,0),body=(-12,-3,-17),root=(-.03,.10,-.29))),(.73,pose(p=(-.18,-.52,5.07),angles=(18,-8,0),body=(5,0,-5),root=(0,-.07,-.3))),(.85,pose(p=(.03,-1.02,4.22),angles=(95,4,0),body=(21,0,13),root=(.04,-.22,-.39),lf=(.64,-.72,0))),(1.02,LOW),(1.27,LOW),(1.88,IDLE)],events={'Windup':0,'Swing':.67,'ActiveStart':.78,'ActiveEnd':1.02,'RecoveryEnd':1.88},description='Overhead finisher with braced front leg and long recovery.',travel=.9)
clip('Heavy_Charge',1.1,[(0,IDLE),(.35,pose(p=(-.4,-.5,4.65),angles=(-4,-42,-8),body=(-4,0,-14))),(.82,HIGH),(1.1,HIGH)],events={'ChargeStart':0,'ChargeReady':1.1},description='Deliberate lift; knees load before the overhead strike.')
clip('Heavy_Hold',1.4,[(0,HIGH),(1.4,HIGH)],loop=True,kind='hold',description='Tension, restrained tremor and loaded legs.')
clip('Heavy_Release',1.52,[(0,HIGH),(.13,pose(p=(-.25,-.19,5.35),angles=(-62,-10,0),body=(-13,0,-22),root=(-.06,.05,-.32))),(.25,pose(p=(-.18,-.57,5.10),angles=(12,-3,0),body=(10,0,-7),root=(0,-.12,-.36))),(.39,pose(p=(.03,-1.04,4.03),angles=(112,5,0),body=(26,0,12),root=(.05,-.29,-.44),lf=(.64,-.83,0))),(.50,pose(p=(.18,-1.0,3.52),angles=(152,9,0),body=(27,0,16),root=(.08,-.25,-.42),lf=(.64,-.83,0))),(.77,LOW),(1.04,pose(p=(.23,-.84,3.73),angles=(111,6,0),body=(13,0,9),root=(.04,-.09,-.28))),(1.52,IDLE)],events={'Swing':.14,'ActiveStart':.28,'Impact':.41,'ActiveEnd':.51,'RecoveryEnd':1.52},description='Fast release, decisive arrest, slow lifting recovery.',travel=1.1)
clip('Running_Attack',1.65,[(0,pose(p=(-.47,-.53,3.94),angles=(81,-92,-10),body=(15,0,-26))),(.30,RIGHT),(.47,pose(p=(-.37,-.99,4.23),angles=(82,-30,0),body=(18,0,-2),root=(0,-.13,-.34),lf=(.64,-.78,0))),(.65,LEFT),(.92,LEFT),(1.65,IDLE)],events={'Swing':.34,'ActiveStart':.43,'ActiveEnd':.66,'RecoveryEnd':1.65},travel=2)
clip('Thrust',1.60,[(0,IDLE),(.34,pose(p=(-.40,-.27,3.85),angles=(90,-4,0),body=(7,0,-24),root=(-.05,.16,-.24))),(.59,pose(p=(-.05,-1.17,3.96),angles=(89,0,0),body=(15,0,8),root=(.02,-.25,-.38),lf=(.64,-.80,0))),(.78,pose(p=(-.04,-1.15,3.96),angles=(90,0,0),body=(14,0,8),root=(.02,-.23,-.36),lf=(.64,-.80,0))),(1.03,pose(p=(-.23,-.59,3.85),angles=(93,-8,0),body=(8,0,-10))),(1.60,IDLE)],events={'Swing':.40,'ActiveStart':.51,'ActiveEnd':.79,'RecoveryEnd':1.60},travel=1.1)

clip('Guard_Enter',.40,[(0,IDLE),(.30,GUARD),(.40,GUARD)],events={'GuardOn':.26})
clip('Guard_Loop',2.0,[(0,GUARD),(2,GUARD)],loop=True,kind='guard')
clip('Guard_Exit',.48,[(0,GUARD),(.48,IDLE)],events={'GuardOff':0})
clip('Guard_Impact',.66,[(0,GUARD),(.10,pose(p=(-.12,-.64,4.43),angles=(64,65,82),body=(-8,0,-12),root=(0,.16,-.37))),(.23,pose(p=(-.08,-.67,4.4),angles=(61,66,80),body=(-3,0,-10),root=(0,.12,-.33))),(.66,GUARD)],events={'Impact':.05,'RecoveryEnd':.66})
clip('Guard_Break',1.9,[(0,GUARD),(.18,pose(p=(-.58,-.11,4.18),angles=(98,-55,-20),body=(-22,-5,-18),root=(0,.23,-.38),left_grip=.3)),(.53,pose(p=(-.83,-.12,3.63),angles=(145,-70,-10),body=(28,5,-12),root=(-.04,.19,-.55),left_grip=0)),(1.12,pose(p=(-.72,-.14,3.60),angles=(144,-60,-10),body=(22,0,-8),root=(0,.14,-.46),left_grip=0)),(1.9,IDLE)],events={'GuardOff':0,'StaggerStart':.12,'RecoveryEnd':1.9})
clip('Parry',1.05,[(0,IDLE),(.17,pose(p=(-.38,-.74,4.2),angles=(48,-45,65),body=(1,0,-19))),(.30,pose(p=(.22,-1.03,4.5),angles=(38,58,87),body=(8,0,22),root=(.05,-.10,-.28))),(.46,pose(p=(.37,-.88,4.49),angles=(47,83,90),body=(6,0,29))),(.62,GUARD),(1.05,IDLE)],events={'ParryStart':.22,'ParryEnd':.39,'RecoveryEnd':1.05},description='Short committed deflection; narrow timing window.')
clip('Riposte',2.30,[(0,IDLE),(.40,HIGH),(.65,pose(p=(-.29,-.20,5.3),angles=(-63,-15,0),body=(-11,0,-21),root=(0,.08,-.31))),(.86,pose(p=(-.07,-1.0,4.22),angles=(94,0,0),body=(23,0,9),root=(0,-.25,-.43),lf=(.64,-.85,0))),(1.05,LOW),(1.45,LOW),(2.30,IDLE)],events={'Swing':.69,'ActiveStart':.80,'Impact':.96,'ActiveEnd':1.08,'RecoveryEnd':2.30},travel=.7)

for name,angle in [('Hit_Front',0),('Hit_Back',180),('Hit_Left',90),('Hit_Right',-90)]:
    front=angle==0; side=1 if angle==90 else -1 if angle==-90 else 0
    hit=pose(p=(-.22+side*.2,-.55,3.93),angles=(52,-18+side*28,8),body=(-15 if front else 20 if angle==180 else 4,side*17,side*22),root=(side*.12,.16 if front else -.12,-.32))
    clip(name,.80,[(0,IDLE),(.12,hit),(.28,hit),(.8,IDLE)],events={'Impact':0,'RecoveryEnd':.8})
for name,direction in [('Dodge_Forward',(0,-1)),('Dodge_Backward',(0,1)),('Dodge_Left',(1,0)),('Dodge_Right',(-1,0))]:
    dx,dy=direction
    p=pose(p=(-.28+dx*.1,-.57,3.87),angles=(50,-28,10),body=(-dy*20,dx*14,-dx*12),root=(dx*.18,dy*.18,-.49),lf=(.64+dx*.23,-.28+dy*.30,.04),rf=(-.65+dx*.23,.38+dy*.30,.04))
    clip(name,.92,[(0,IDLE),(.13,pose(root=(0,0,-.4),body=(12,0,-8))),(.32,p),(.56,p),(.92,IDLE)],events={'DodgeStart':.13,'DodgeEnd':.53,'RecoveryEnd':.92},description='Directional low step; gameplay translation is external.',travel=3.8)
clip('Jump',.72,[(0,IDLE),(.17,pose(root=(0,0,-.5),body=(16,0,-8))),(.40,pose(root=(0,0,.02),lf=(.64,-.1,.34),rf=(-.65,.1,.27),p=(-.1,-.86,4.2),angles=(32,-18,8))),(.72,pose(root=(0,0,-.12),lf=(.64,-.1,.34),rf=(-.65,.1,.27)))],events={'Takeoff':.25},description='Pose-only jump; root height comes from game physics.')
AIR=pose(root=(0,0,-.12),lf=(.64,-.1,.25),rf=(-.65,.1,.18),body=(10,0,-8))
clip('Fall',1.0,[(0,AIR),(1,AIR)],loop=True,kind='hold')
clip('Land',.83,[(0,AIR),(.14,pose(root=(0,0,-.52),body=(22,0,-8),p=(-.12,-.89,3.85),angles=(46,-18,8))),(.34,pose(root=(0,0,-.43),body=(17,0,-8))),( .83,IDLE)],events={'FootPlant':.06,'RecoveryEnd':.83})

def rotation(angles):
    # Tilt from upright, azimuth around body, then edge alignment around blade.
    pitch,yaw,roll=angles
    return Quaternion((0,0,1),yaw*pi/180) @ Quaternion((1,0,0),pitch*pi/180) @ Quaternion((0,0,1),roll*pi/180)

def sample(clip,t):
    keys=clip['keys']; p=keys[-1][1].copy()
    for (ta,a),(tb,b) in zip(keys,keys[1:]):
        if ta<=t<=tb:
            u=(t-ta)/(tb-ta); u=u*u*(3-2*u)
            p={k:(tuple(x+(y-x)*u for x,y in zip(a[k],b[k])) if isinstance(a[k],tuple) else a[k]+(b[k]-a[k])*u) for k in a}
            break
    phase=2*pi*t/clip['duration']; kind=clip['kind']
    if kind in ['idle','hold','guard']:
        amp=.024 if kind=='idle' else .012
        p['p']=tuple(v+(amp*sin(phase-.25) if i==2 else 0) for i,v in enumerate(p['p']))
        p['body']=(p['body'][0]+.6*sin(phase),p['body'][1],p['body'][2]+.35*sin(phase))
    if kind.startswith('walk') or kind=='run':
        run=kind=='run'; stride=.56 if run else .36; lift=.26 if run else .15
        for key,ph in [('lf',phase),('rf',phase+pi)]:
            foot=list(BASE[key]); shift=stride*cos(ph); foot[2]=lift*max(0,sin(ph))
            if kind=='walk_b': foot[1]-=shift
            elif kind in ['walk_l','walk_r']: foot[0]+=shift*(1 if kind=='walk_l' else -1)
            else: foot[1]+=shift
            p[key]=tuple(foot)
        p['root']=(.045*sin(phase),0,-.24+(.028 if run else .018)*cos(2*phase))
        p['body']=(14 if run else 7,1.2*sin(phase),-8+3*sin(phase))
        p['p']=(-.12+.025*sin(phase-.2),-.83,4.07+.025*cos(2*phase-.4))
    if clip['name'].startswith(('Light_','Heavy_')) or clip['name'] in ['Thrust','Riposte','Running_Attack']:
        # The strike rotates and loads the planted legs instead of sliding the support feet.
        p['lf']=BASE['lf']; p['rf']=BASE['rf']
    return p
