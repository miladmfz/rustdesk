from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]
master=Image.open(ROOT/'res/branding/kowsardesk-master.png').convert('RGBA')
outputs={}
def save(im,path):
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True);im.save(p)
 outputs[path]={'size':list(im.size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def resized(n):return master.resize((n,n),Image.Resampling.LANCZOS)
for path,n in [('res/icon.png',1024),('res/mac-icon.png',1024),('res/32x32.png',32),('res/64x64.png',64),('res/128x128.png',128),('res/128x128@2x.png',256),('flutter/assets/icon.png',512),('fastlane/metadata/android/en-US/images/icon.png',512)]:save(resized(n),path)
for path in ['res/icon.ico','res/tray-icon.ico','flutter/windows/runner/resources/app_icon.ico']:
 p=ROOT/path;master.save(p,format='ICO',sizes=[(n,n) for n in [16,20,24,32,40,48,64,128,256]])
 outputs[path]={'ico_sizes':[16,20,24,32,40,48,64,128,256],'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
for density,n in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 base=f'flutter/android/app/src/main/res/mipmap-{density}/'
 for name in ['ic_launcher.png','ic_launcher_round.png']:save(resized(n),base+name)
 side=round(n*108/48); inset=round(side*0.66)
 fg=Image.new('RGBA',(side,side));fg.alpha_composite(resized(inset),((side-inset)//2,(side-inset)//2));save(fg,base+'ic_launcher_foreground.png')
 # Android status icons use only alpha. Preserve the brand silhouette in white.
 small=resized(round(n/2));white=Image.new('RGBA',small.size,'white');white.putalpha(small.getchannel('A'));save(white,base+'ic_stat_logo.png')
def wordmark(path,color,size=(600,120)):
 im=Image.new('RGBA',size);icon=resized(size[1]);im.alpha_composite(icon,(0,0))
 font_size=round(size[1]*.44)
 while True:
  font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',font_size)
  if font.getlength('KowsarDesk') <= size[0]-size[1]-12 or font_size<=6:break
  font_size-=1
 ImageDraw.Draw(im).text((size[1]+10,size[1]*.17),'KowsarDesk',font=font,fill=color)
 save(im,path)
wordmark('flutter/assets/logo.png','#24476a');wordmark('flutter/assets/logo_light.png','#24476a');wordmark('flutter/assets/logo_dark.png','#f3ce70')
wordmark('libs/portable/src/res/label.png','#ffffff',(96,32))
# Keep macOS and iOS source assets consistent, although this release builds Windows/Android only.
for p in (ROOT/'flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'):
 old=Image.open(p);im=resized(old.width);bg=Image.new('RGBA',im.size,'#ffffff');bg.alpha_composite(im);save(bg.convert('RGB'),p.relative_to(ROOT).as_posix())
master.save(ROOT/'flutter/macos/Runner/AppIcon.icns',format='ICNS')
outputs['flutter/macos/Runner/AppIcon.icns']={'sha256':hashlib.sha256((ROOT/'flutter/macos/Runner/AppIcon.icns').read_bytes()).hexdigest()}
(ROOT/'res/branding/manifest.json').write_text(json.dumps({'master_sha256':hashlib.sha256((ROOT/'res/branding/kowsardesk-master.png').read_bytes()).hexdigest(),'assets':outputs},indent=2))
print(f'PASS: generated {len(outputs)} brand assets from approved master')
