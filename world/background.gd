class_name Background
extends Node2D
## Parallax2D の層（空・雲・遠景・田んぼ・電柱・近景）。空はグラデーション、山並み・木・雲は Gemini の絵。
## 海辺（6日目の砂浜）では、山並み・田んぼ・電柱・木立ちのかわりに、水平線の空・太陽・灯台の手前の海・灯台を見せる。
## どれだけ海辺か（0〜1）は SeasideZone が set_seaside で入れる（だんだん入れかわる）

const SKY_SHADER := preload("res://world/shaders/sky_gradient.gdshader")
const DESATURATE := preload("res://world/shaders/desaturate.gdshader")
## 海辺の太陽と灯台が、画面の中をどれだけゆっくり動くか（遠くほど小さい）。x は海辺に入ってから歩いた距離に対して
const SUN_SCROLL := 0.06
const LIGHT_SCROLL := 0.35
## 海辺に入ったときの、太陽と灯台の位置（画面の幅に対する割合）
const SUN_START := 0.72
const LIGHT_START := 1.05

## 海辺の空の絵を描いたときの空の色（昼）。これと今の空の色の比で、空の絵を染める
const SEA_SKY_DAY := Color("#8EC5E0")

## どれだけ海辺か（0〜1）
var seaside := 0.0

@onready var _sky: ColorRect = $Sky/SkyRect
var _sky_mat: ShaderMaterial
## 異界（神隠しルート）で層の絵の色を抜くシェーダー。はじめて使うときにかける
var _desat_mat: ShaderMaterial
var _desat := 0.0


func _ready() -> void:
	add_to_group("background")
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter("sky_color", _sky.color)
	_sky.material = _sky_mat
	# 動きを減らす設定のときは雲を流さない
	if UiAnim.reduced():
		$Clouds.autoscroll = Vector2.ZERO


## 海辺の景色にどれだけ入れかえるか（amount 0〜1）。walked は海辺に入ってから歩いた距離（太陽と灯台を動かす）
func set_seaside(amount: float, walked: float) -> void:
	seaside = clampf(amount, 0.0, 1.0)
	for n in [$SeaSun, $SeaSky, $SeaMid, $SeaLight]:
		n.modulate.a = seaside
		n.visible = seaside > 0.0
	for n in [$Far, $Fields, $Wires, $Near]:
		n.modulate.a = 1.0 - seaside
		n.visible = seaside < 1.0
	var vw := get_viewport_rect().size.x
	$SeaSun/Sun.position.x = vw * SUN_START - walked * SUN_SCROLL
	$SeaLight/Lighthouse.position.x = vw * LIGHT_START - walked * LIGHT_SCROLL


## 異界でどれだけ色を抜くか（0〜1）。空は TimeOfDay が空の色ごと褪せさせるので、ほかの層の絵にかける
func set_desaturate(amount: float) -> void:
	if is_equal_approx(amount, _desat):
		return
	_desat = amount
	if _desat_mat == null:
		if amount <= 0.0:
			return
		_desat_mat = ShaderMaterial.new()
		_desat_mat.shader = DESATURATE
		_apply_desat(self)
		# 手前の木の枝など、背景の外にある景色の層も
		for n in get_tree().get_nodes_in_group("desaturate_with_world"):
			_apply_desat(n)
	_desat_mat.set_shader_parameter("amount", amount)


func _apply_desat(n: Node) -> void:
	if n is CanvasItem and n != _sky and (n as CanvasItem).material == null:
		(n as CanvasItem).material = _desat_mat
	for c in n.get_children():
		_apply_desat(c)


## 空の色（時間帯・季節）。上は濃く、地平線は白くかすむグラデーションにする（sky_gradient.gdshader）
func set_sky_color(c: Color) -> void:
	_sky.color = c
	_sky_mat.set_shader_parameter("sky_color", c)
	# 海辺の空の絵は昼の青空で描いてあるので、夕方の空の色に合わせて染める（昼の空の色との比）
	var k := Color(c.r / SEA_SKY_DAY.r, c.g / SEA_SKY_DAY.g, c.b / SEA_SKY_DAY.b)
	$SeaSky/Strip.self_modulate = Color(minf(k.r, 1.0), minf(k.g, 1.0), minf(k.b, 1.0))
