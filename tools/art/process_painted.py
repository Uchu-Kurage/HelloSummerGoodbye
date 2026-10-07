# 使い方: python3 tools/art/process_painted.py 名前=画像 [名前=画像 ...]
#   例: python3 tools/art/process_painted.py mountains=山.jpg trees=木.jpg clouds_small=雲.jpg
# 生成AIの絵（背景はマゼンタ #FF00FF の単色）を切り抜き、world/scenery/painted/<名前>.png に書き出す。
# 名前ごとの処理（RECIPES）：
#   cloud_*       … 切り抜いて、まわりの余白を落とす
#   clouds_small / stones / thickets / lanterns / boxes / player / base_materials / player_mg* / takeru_mg* … 横に並んだものを1つずつ切り分ける
#                   （SPLITS の名前に番号をつけて書き出す。例: stone_1.png, stone_2.png, …）
#   mountains / trees / paddies / river / road … 横にくり返せる帯にする（右端を左端に重ねてなじませる）
#   branch / cloud_wide … 左右の端をぼかす（絵の端で切れている部分を見せない）
#   item_<アイテムID> … アイテムの絵。正方形 256px の PNG にして data/items/icons/ に書き出す
#   sentaku_clothes（CUTS） … 決めた横の範囲で切り分ける（くつしたのように2つに分かれたものがあるとき）
#   bg_*（BACKGROUNDS） … ミニゲームの背景。空をマゼンタにした絵を、空だけ透明にして ui/minigame_bg/ に書き出す
# 必要: pillow, numpy
import sys
from PIL import Image, ImageFilter
import numpy as np

OUT = 'world/scenery/painted/'
# 帯：[使う行の範囲（上, 下。None は最後まで）, 左右を重ねる幅]
STRIPS = {
	'mountains': [(0, 400), 300],
	'trees': [(0, None), 240],
	'paddies': [(0, 300), 260],
	'river': [(0, None), 220],
	'road': [(0, None), 200],
	# 初恋ルート：6日目の砂浜の道（ふだんの道のかわりに敷く）
	'sand': [(0, None), 200],
	# 6日目の背景：灯台の手前に見える海（中景）
	'sea_mid': [(0, None), 200],
}
## 切り抜く前に、元の絵のこの範囲だけを使う：[左, 上, 右, 下]（None は端まで）
## 同じ絵から2つ取り出すときは、名前を変えて2回わたす（例: prop_diverock=岩.jpg dive_pool=岩.jpg）
CROPS = {
	# 縁側は上から見た床が大きいので、手前のふちと脚だけ
	'prop_engawa': [None, 255, None, None],
	# 坂道は左と下の、紙のちぎれたふちを落とす
	'prop_slope': [40, None, 1000, 535],
	# 飛び込み岩の絵から、岩だけ（淵は川の帯を暗くして描く）
	'prop_diverock': [None, None, 472, None],
	# 神隠しルート：祠の絵の左のバス停の札は落とす（バス停は別の絵がある）
	'prop_hokora': [222, None, None, None],
	# 送り火の煙：足もとの地面の線は落とす
	'okuribi_smoke': [None, None, None, 940],
	# ノーマルルート：ミニゲームの背景の、下のふちの色の帯や線を落とす
	'bg_sentaku': [None, None, None, 402],
	'bg_bus_window': [None, 92, None, 408],
	# きゅうりとなす：下の地面の帯を落とす
	'shoryouma_veg': [None, None, None, 370],
}
## ミニゲームの背景で、空（や窓の外）をマゼンタにしたもの：透明にして、絵の大きさのまま ui/minigame_bg/<名前から bg_ を除いたもの>.png に書き出す。
## 透明なところには、ゲームの中で空の色（時間・夕立の雲・夜空）を描く
BACKGROUNDS = ('bg_sentaku', 'bg_shoryouma', 'bg_seiza', 'bg_kakurenbo_jiji', 'bg_bus_window')
BG_OUT = 'ui/minigame_bg/'
## 横に並べて描いたが、2つに分かれたもの（くつした）があって自動では切り分けられない絵：名前 -> [書き出す名前, 横の範囲（元の絵の px）]
CUTS = {
	'sentaku_clothes': ['sentaku_cloth', [(0, 228), (228, 388), (388, 512), (512, 655), (655, 828), (828, 1024)]],
}
## アイテムの絵（item_<アイテムID>）：切り抜いて、正方形・ITEM_SIZE px の PNG にし、data/items/icons/<アイテムID>.png に書き出す
ITEM_SIZE = 256
ITEM_OUT = 'data/items/icons/'


def item_icon(im):
	im = im.crop(im.getbbox())
	side = int(max(im.size) * 1.08)
	sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
	sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
	return sq.resize((ITEM_SIZE, ITEM_SIZE), Image.LANCZOS)
## 1枚に横に並んだものを切り分けるときの、書き出す名前
SPLITS = {
	'clouds_small': 'cloud_small',
	'stones': 'stone',
	'thickets': 'thicket',
	'lanterns': 'lantern',
	'boxes': 'box',
	'player': 'player',
	'base_materials': 'base_mat',
	'player_mg1': 'player_mg1',
	'player_mg2': 'player_mg2',
	'takeru_mg1': 'takeru_mg1',
	'takeru_mg2': 'takeru_mg2',
	# 初恋ルート（なつみ）
	'radio_kids': 'radio_kid',
	'shells': 'shell',
	'natsumi_mg1': 'natsumi_mg1',
	'puddles': 'puddle',
	# 神隠しルート（お面の子）
	'sunflowers': 'sunflower',
	'fox_mg1': 'fox_mg1',
	# ノーマルルート（祖父母。プロンプトは tools/art/prompts_normal.md）
	'grandpa_mg1': 'grandpa_mg1',
	'grandma_mg1': 'grandma_mg1',
	'cars': 'car',
	'shoryouma_veg': 'shoryouma_veg',
}
## 左右の端をぼかす幅：[左, 右]
EDGE_FADES = {
	'branch': [90.0, 70.0],
	'cloud_wide': [280.0, 260.0],
	'prop_slope': [140.0, 40.0],
	# 灯台の岬は絵の左のはしで切れているので、海にとけこむようにぼかす
	'lighthouse': [220.0, 1.0],
}


## 背景のマゼンタが、まん中だけ明るい桃色になっている絵（光のにじみ・グラデーション）。
## 桃色の部分も背景として抜けるよう、マゼンタらしさを明るさとの比で見る（紫のものがない絵だけに使う）
RATIO_KEY = ('prop_hozuki', 'prop_mask_board', 'item_river_stone', 'item_marble', 'item_bus_ticket')
## 紫のもの（なす）がある絵。暗い紫は背景のマゼンタとまちがえないよう、暗いところは抜かず、紫のにじみ消しもかけない
KEEP_DARK = ('shoryouma_veg',)


def key(path, crop=None, ratio=False, keep_dark=False):
	im = Image.open(path).convert('RGB')
	if crop:
		w, h = im.size
		im = im.crop((crop[0] or 0, crop[1] or 0, crop[2] or w, crop[3] or h))
	a = np.array(im).astype(float)
	# マゼンタらしさ：R と B が G よりどれだけ大きいか
	m = np.minimum(a[..., 0], a[..., 2]) - a[..., 1]
	# 背景のマゼンタは絵によって少しちがう（#FF00FF より暗い・くすんだことがある）ので、
	# 絵のふち（上下左右の端の数 px）のうち、マゼンタらしいところの色から決める
	edge = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
	em = np.minimum(edge[:, 0], edge[:, 2]) - edge[:, 1]
	edge = edge[em > 60] if (em > 60).any() else np.array([[250.0, 8.0, 248.0]])
	M = np.median(edge, axis=0)
	m_bg = float(min(M[0], M[2]) - M[1])
	alpha = np.clip((m_bg - 30.0 - m) / (m_bg - 60.0), 0, 1)
	if ratio:
		r = m / np.maximum(np.maximum(a[..., 0], a[..., 2]), 1.0)
		alpha = np.minimum(alpha, np.clip((0.5 - r) / 0.25, 0, 1))
	# 背景のマゼンタは明るいので、R と B のどちらも暗いところは絵の一部
	protect = np.clip((190.0 - np.maximum(a[..., 0], a[..., 2])) / 50.0, 0, 1) if keep_dark else np.zeros(m.shape)
	alpha = np.maximum(alpha, protect)
	# 小さなノイズ（JPEG のにじみ）を消す
	al = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3))
	alpha = np.array(al).astype(float) / 255
	safe = np.maximum(alpha, 1e-3)[..., None]
	fg = np.clip((a - (1 - alpha)[..., None] * M) / safe, 0, 255)
	# 紫のにじみを消す：R と B の両方が G より大きいぶん（＝マゼンタの成分）を引く
	spill = np.clip(np.minimum(fg[..., 0], fg[..., 2]) - fg[..., 1], 0, None) * (1.0 - protect)
	fg[..., 0] -= spill
	fg[..., 2] -= spill
	# ふちを 1px 内側へ縮める（にじんだ輪郭を残さない）
	al = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))
	alpha = np.array(al).astype(float) / 255
	return bleed(fg, alpha), alpha


def bleed(fg, alpha, solid=0.95, steps=14):
	"""半透明のふちの色を、すぐ内側の不透明な部分の色で置きかえる。
	ふちにはマゼンタが混ざった色（赤茶っぽいにじみ）が残りやすく、表示で輪郭のように見えるため。
	透明な部分にも色をのばしておくと、拡大・縮小したときもふちがにごらない"""
	# ふちから 2px 内側までは色がにごっていることがあるので、それより内側だけを「きれいな色」とする
	core = Image.fromarray(((alpha >= solid) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
	filled = np.array(core) > 0
	out = fg.copy()
	out[~filled] = 0
	for _ in range(steps):
		acc = np.zeros_like(out)
		cnt = np.zeros(alpha.shape)
		for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
			sh = np.roll(np.roll(out, dy, axis=0), dx, axis=1)
			sf = np.roll(np.roll(filled, dy, axis=0), dx, axis=1)
			acc += sh * sf[..., None]
			cnt += sf
		grow = (~filled) & (cnt > 0)
		out[grow] = acc[grow] / cnt[grow][..., None]
		filled = filled | grow
	# 不透明なところから遠い細い線（笹の茎など）は、黒く残さず、もとの色のままにする
	out[~filled] = fg[~filled]
	return out


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
	# 上の透明な部分を落とす（JPEG のノイズの点が残っていても、行の中でまとまって見えるところから）
	rows = np.nonzero((al2 > 0.1).sum(axis=1) > 4)[0]
	top = int(rows[0]) if len(rows) else 0
	return im.crop((0, top, im.width, im.height))


def _components(mask):
	"""つながった部分ごとに番号をつける（上下左右のとなりでつながる）。小さすぎるものは捨てる"""
	h, w = mask.shape
	label = np.zeros((h, w), dtype=np.int32)
	n = 0
	for y0 in range(h):
		for x0 in range(w):
			if not mask[y0, x0] or label[y0, x0]:
				continue
			n += 1
			stack = [(y0, x0)]
			label[y0, x0] = n
			while stack:
				y, x = stack.pop()
				for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					yy, xx = y + dy, x + dx
					if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not label[yy, xx]:
						label[yy, xx] = n
						stack.append((yy, xx))
	return label, n


def split(fg, al, name):
	"""離れて並んだものを1つずつ切り分ける。左から順に番号をつける。
	ふれあっているものも分けられるよう、こい部分（不透明に近いところ）だけでつながりを見る"""
	step = 4
	small = al[::step, ::step] > 0.85
	label, n = _components(small)
	# 小さすぎる部分（細いひもの切れはしなど）は先に消しておく
	for i in range(1, n + 1):
		if (label == i).sum() * step * step < 2500:
			label[label == i] = 0
	# 細い部分（草の葉・提灯のひも）も、いちばん近い部分のものとして広げて含める
	# 細い線を落とさないよう、ブロックごとの最大値で縮める
	hh, ww = label.shape
	pad = np.zeros((hh * step, ww * step))
	pad[:min(al.shape[0], hh * step), :min(al.shape[1], ww * step)] = al[:hh * step, :ww * step]
	full = pad.reshape(hh, step, ww, step).max(axis=(1, 3)) > 0.05
	h, w = full.shape
	queue = list(zip(*np.nonzero(label)))
	head = 0
	while head < len(queue):
		y, x = queue[head]
		head += 1
		for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			yy, xx = y + dy, x + dx
			if 0 <= yy < h and 0 <= xx < w and full[yy, xx] and not label[yy, xx]:
				label[yy, xx] = label[y, x]
				queue.append((yy, xx))
	# 上から段に分け（縦に重なるものは同じ段）、段ごとに左から順に番号をつける
	boxes = []
	for i in range(1, n + 1):
		ys, xs = np.nonzero(label == i)
		if len(xs) == 0:
			continue
		boxes.append((ys.min(), ys.max(), xs.min(), i))
	boxes.sort()
	rows = []
	for b in boxes:
		if rows and b[0] < rows[-1][0]:
			rows[-1][0] = max(rows[-1][0], b[1])
			rows[-1][1].append(b)
		else:
			rows.append([b[1], [b]])
	parts = []
	for r, (_, bs) in enumerate(rows):
		for b in sorted(bs, key=lambda b: b[2]):
			parts.append((r, b[3]))
	# 各部分を元の大きさにもどし、少し広げて（ふちの半透明を含める）その部分だけを残す
	for k, (_, i) in enumerate(parts):
		m = Image.fromarray(((label == i) * 255).astype(np.uint8)).resize((al.shape[1], al.shape[0]), Image.NEAREST)
		m = np.array(m.filter(ImageFilter.MaxFilter(9))).astype(float) / 255
		save(to_image(fg, al * m), '%s_%d' % (name, k + 1))


def edge_fade(fg, al, left, right):
	w = al.shape[1]
	x = np.arange(w)
	fade = np.clip(np.minimum(x / left, (w - 1 - x) / right), 0, 1)
	fade = fade * fade * (3 - 2 * fade)
	return to_image(fg, al * fade[None, :])


def main():
	for arg in sys.argv[1:]:
		name, path = arg.split('=', 1)
		fg, al = key(path, CROPS.get(name), name in RATIO_KEY, name in KEEP_DARK)
		if name.startswith('item_'):
			im = item_icon(to_image(fg, al))
			im.save(ITEM_OUT + name[5:] + '.png', optimize=True)
			print(name[5:], im.size)
		elif name in CUTS:
			out, cuts = CUTS[name]
			im = to_image(fg, al)
			for k, (x0, x1) in enumerate(cuts):
				save(im.crop((x0, 0, x1, im.height)), '%s_%d' % (out, k + 1))
		elif name in BACKGROUNDS:
			im = to_image(fg, al)
			im.save(BG_OUT + name[3:] + '.png', optimize=True)
			print(name[3:], im.size)
		elif name in STRIPS:
			rows, ov = STRIPS[name]
			save(strip(fg, al, rows, ov), name, crop=False)
		elif name in SPLITS:
			split(fg, al, SPLITS[name])
		elif name in EDGE_FADES:
			save(edge_fade(fg, al, *EDGE_FADES[name]), name)
		else:
			im = to_image(fg, al)
			save(im, name)


main()
