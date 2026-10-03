# 使い方: python3 tools/art/process_painted.py 名前=画像 [名前=画像 ...]
#   例: python3 tools/art/process_painted.py mountains=山.jpg trees=木.jpg clouds_small=雲.jpg
# 生成AIの絵（背景はマゼンタ #FF00FF の単色）を切り抜き、world/scenery/painted/<名前>.png に書き出す。
# 名前ごとの処理（RECIPES）：
#   cloud_*       … 切り抜いて、まわりの余白を落とす
#   clouds_small  … 離れて浮かぶ雲を1つずつ切り分ける（cloud_small_1.png, _2, …）
#   mountains / trees / paddies … 横にくり返せる帯にする（右端を左端に重ねてなじませる）
#   branch / cloud_wide … 左右の端をぼかす（絵の端で切れている部分を見せない）
# 必要: pillow, numpy
import sys
from PIL import Image, ImageFilter
import numpy as np

OUT = 'world/scenery/painted/'
# JPEG のマゼンタ（少しにごる）
M = np.array([250.0, 8.0, 248.0])
# 帯：[使う行の範囲（上, 下。None は最後まで）, 左右を重ねる幅]
STRIPS = {
	'mountains': [(0, 400), 300],
	'trees': [(0, None), 240],
	'paddies': [(0, 300), 260],
}
## 左右の端をぼかす幅：[左, 右]
EDGE_FADES = {
	'branch': [90.0, 70.0],
	'cloud_wide': [280.0, 260.0],
}


def key(path):
	a = np.array(Image.open(path).convert('RGB')).astype(float)
	# マゼンタらしさ：R と B が G よりどれだけ大きいか
	m = np.minimum(a[..., 0], a[..., 2]) - a[..., 1]
	alpha = np.clip((205.0 - m) / 175.0, 0, 1)
	# 小さなノイズ（JPEG のにじみ）を消す
	al = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3))
	alpha = np.array(al).astype(float) / 255
	safe = np.maximum(alpha, 1e-3)[..., None]
	fg = np.clip((a - (1 - alpha)[..., None] * M) / safe, 0, 255)
	# 紫のにじみを消す：R と B の両方が G より大きいぶん（＝マゼンタの成分）を引く
	spill = np.clip(np.minimum(fg[..., 0], fg[..., 2]) - fg[..., 1], 0, None)
	fg[..., 0] -= spill
	fg[..., 2] -= spill
	# ふちを 1px 内側へ縮める（にじんだ輪郭を残さない）
	al = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))
	alpha = np.array(al).astype(float) / 255
	return fg, alpha


def to_image(fg, alpha):
	return Image.fromarray(np.dstack([fg, alpha * 255]).astype(np.uint8), 'RGBA')


def save(im, name, crop=True):
	if crop:
		im = im.crop(im.getbbox())
	im.save(OUT + name + '.png', optimize=True)
	print(name, im.size)


def strip(fg, al, rows, ov):
	"""右端 ov px を左端に重ねてなじませ、横にくり返せる1枚にする。上の透明な部分は落とす"""
	fg = fg[rows[0]:rows[1]]
	al = al[rows[0]:rows[1]]
	w = fg.shape[1]
	t = np.linspace(0, 1, ov)[None, :]
	t = t * t * (3 - 2 * t)
	fg2 = fg[:, :w - ov].copy()
	al2 = al[:, :w - ov].copy()
	a_r = al[:, w - ov:]
	a_l = al[:, :ov]
	a_lin = a_r * (1 - t) + a_l * t
	# まん中ほど輪郭をくっきりさせ、半透明の影がだぶらないようにする（両端はもとのまま）
	k = 1 + 30 * t * (1 - t)
	al2[:, :ov] = np.clip((a_lin - 0.5) * k + 0.5, 0, 1)
	# 片方にしかない部分は、ある方の色を使う
	wr = (a_r * (1 - t)) / np.maximum(a_r * (1 - t) + a_l * t, 1e-4)
	fg2[:, :ov] = fg[:, w - ov:] * wr[..., None] + fg[:, :ov] * (1 - wr[..., None])
	im = to_image(fg2, al2)
	top = im.getbbox()[1]
	return im.crop((0, top, im.width, im.height))


def split(fg, al, name):
	"""離れた雲を1つずつ切り分ける（列ごとに透明なすき間で区切る）"""
	cols = (al > 0.05).any(axis=0)
	parts = []
	x = 0
	while x < len(cols):
		if cols[x]:
			s = x
			while x < len(cols) and cols[x]:
				x += 1
			if x - s > 20:
				parts.append((s, x))
		x += 1
	for i, (s, e) in enumerate(parts):
		save(to_image(fg[:, s:e], al[:, s:e]), '%s_%d' % (name, i + 1))


def edge_fade(fg, al, left, right):
	w = al.shape[1]
	x = np.arange(w)
	fade = np.clip(np.minimum(x / left, (w - 1 - x) / right), 0, 1)
	fade = fade * fade * (3 - 2 * fade)
	return to_image(fg, al * fade[None, :])


def main():
	for arg in sys.argv[1:]:
		name, path = arg.split('=', 1)
		fg, al = key(path)
		if name in STRIPS:
			rows, ov = STRIPS[name]
			save(strip(fg, al, rows, ov), name, crop=False)
		elif name == 'clouds_small':
			split(fg, al, 'cloud_small')
		elif name in EDGE_FADES:
			save(edge_fade(fg, al, *EDGE_FADES[name]), name)
		else:
			save(to_image(fg, al), name)


main()
