# 使い方: python3 tools/art/process_painted.py <雲の画像> <山並みの画像> <枝の画像>
# 生成AIの絵（背景はマゼンタ #FF00FF の単色）を切り抜き、world/scenery/painted/ に PNG で書き出す。
# 必要: pillow, numpy
from PIL import Image, ImageFilter
import numpy as np
import sys
ARGS=sys.argv[1:4]
O='world/scenery/painted/'
M=np.array([250.0,8.0,248.0])
def key(path):
    a=np.array(Image.open(path).convert('RGB')).astype(float)
    m=np.minimum(a[...,0],a[...,2])-a[...,1]
    alpha=np.clip((205.0-m)/175.0,0,1)
    # 小さなノイズ（JPEG のにじみ）を消す
    al=Image.fromarray((alpha*255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3))
    alpha=np.array(al).astype(float)/255
    safe=np.maximum(alpha,1e-3)[...,None]
    fg=(a-(1-alpha)[...,None]*M)/safe
    fg=np.clip(fg,0,255)
    # 紫のにじみを消す：R と B の両方が G より大きいぶん（＝マゼンタの成分）を引く
    spill=np.clip(np.minimum(fg[...,0],fg[...,2])-fg[...,1],0,None)
    fg[...,0]-=spill; fg[...,2]-=spill
    # ふちを 1px 内側へ縮める（にじんだ輪郭を残さない）
    al=Image.fromarray((alpha*255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))
    alpha=np.array(al).astype(float)/255
    return fg,alpha
def save(fg,alpha,name):
    rgba=np.dstack([fg,alpha*255]).astype(np.uint8)
    im=Image.fromarray(rgba,'RGBA'); bb=im.getbbox(); im=im.crop(bb)
    im.save(O+name,optimize=True); print(name,im.size)
    return im
# 入道雲
fg,al=key(ARGS[0]); save(fg,al,'cloud_tower.png')
# 山並み：下の 400 行まで。右端の 300px を左端に重ねてなじませ、横にくり返せる 1 枚にする
fg,al=key(ARGS[1]); fg=fg[:400]; al=al[:400]
W=fg.shape[1]; ov=300
t=np.linspace(0,1,ov)[None,:]; t=t*t*(3-2*t)
fg2=fg[:,:W-ov].copy(); al2=al[:,:W-ov].copy()
fg2[:,:ov]=fg[:,W-ov:]*(1-t[...,None])+fg[:,:ov]*t[...,None]
a_lin=al[:,W-ov:]*(1-t)+al[:,:ov]*t
# まん中ほど輪郭をくっきりさせ、半透明の山の影がだぶらないようにする（両端はもとのまま）
k=1+12*t*(1-t)
al2[:,:ov]=np.clip((a_lin-0.5)*k+0.5,0,1)
# 片方にしかない部分は、ある方の色を使う（半透明の色が混ざってにじまないように）
aR=al[:,W-ov:][...,None]; aL=al[:,:ov][...,None]; tt=t[...,None]
w=(aR*(1-tt))/np.maximum(aR*(1-tt)+aL*tt,1e-4)
fg2[:,:ov]=fg[:,W-ov:]*w+fg[:,:ov]*(1-w)
rgba=np.dstack([fg2,al2*255]).astype(np.uint8); im=Image.fromarray(rgba,'RGBA')
top=im.getbbox()[1]; im=im.crop((0,top,im.width,im.height)); im.save(O+'mountains.png',optimize=True); print('mountains',im.size)
# 手前の枝：左右の端をぼかして消す（パララックスで流れるので、切れ目を見せない）
fg,al=key(ARGS[2])
w=al.shape[1]; x=np.arange(w)
fade=np.clip(np.minimum(x/90.0,(w-1-x)/70.0),0,1); fade=fade*fade*(3-2*fade)
al=al*fade[None,:]
save(fg,al,'branch.png')
