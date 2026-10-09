from pathlib import Path
import sys,json,subprocess
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parent
sys.path.insert(0,str(root/'tools'))
import imageio_ffmpeg
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
folder=root/'previews'; frames=sorted((folder/'frames').glob('*.png'))
subprocess.run([ffmpeg,'-y','-framerate','30','-i',str(folder/'frames'/'%04d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(folder/'03_combat_demo.mp4')],check=True,capture_output=True)
gif=[]
for f in frames[::2]:
    with Image.open(f) as im: gif.append(im.convert('RGB').resize((480,480),Image.Resampling.LANCZOS))
gif[0].save(folder/'03_combat_demo.gif',save_all=True,append_images=gif[1:],duration=67,loop=0,optimize=False)
shots=json.loads((folder/'shots.json').read_text())
heavy=next(x for x in shots if x['clip']=='Heavy_Release')['start']
samples=[(43,'01 / ЗАМАХ'),(49,'02 / ПРОХОД ЧЕРЕЗ ЦЕЛЬ'),(55,'03 / ИНЕРЦИЯ'),(heavy+4,'04 / ЗАГРУЗКА ТЯЖЁЛОГО УДАРА'),(heavy+12,'05 / УДАР СВЕРХУ'),(heavy+27,'06 / ВОССТАНОВЛЕНИЕ')]
sheet=Image.new('RGB',(1440,1040),(12,17,22)); draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
for i,(index,title) in enumerate(samples):
    x=(i%3)*480; y=(i//3)*520
    with Image.open(folder/'frames'/('%04d.png'%index)) as im: sheet.paste(im.convert('RGB').resize((480,480),Image.Resampling.LANCZOS),(x,y))
    draw.text((x+18,y+485),title,font=font,fill=(211,185,135))
sheet.save(folder/'04_motion_sheet.jpg',quality=94)
manifest=json.loads((root/'animation_manifest.json').read_text())
lines=['-- Original Ashen Oath animation timings. Seconds, 30 fps baked clips.','-- Animation asset IDs are assigned after publishing in Roblox Studio.','return {']
for c in manifest:
    lines.append('    ["'+c['name']+'"] = {')
    lines.append('        Duration = '+str(c['duration_exported'])+', Loop = '+str(c['loop']).lower()+',')
    lines.append('        SuggestedTravel = '+str(c['travel_studs'])+',')
    lines.append('        Markers = {')
    for k,v in c['events'].items(): lines.append('            ["'+k+'"] = '+str(v)+',')
    lines.extend(['        },','    },'])
lines.append('}')
(root/'CombatTimings.luau').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('PACKAGED',len(frames),'frames',len(manifest),'clips')
