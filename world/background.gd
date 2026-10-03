class_name Background
extends Node2D
## Parallax2D の層（空・雲・遠景・田んぼ・電柱・近景）。空はグラデーション、山並み・木・雲は CC0 の絵。

const SKY_SHADER := preload("res://world/shaders/sky_gradient.gdshader")

@onready var _sky: ColorRect = $Sky/SkyRect
var _sky_mat: ShaderMaterial


func _ready() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter("sky_color", _sky.color)
	_sky.material = _sky_mat
	# 動きを減らす設定のときは雲を流さない
	if UiAnim.reduced():
		$Clouds.autoscroll = Vector2.ZERO


## 空の色（時間帯・季節）。上は濃く、地平線は白くかすむグラデーションにする（sky_gradient.gdshader）
func set_sky_color(c: Color) -> void:
	_sky.color = c
	_sky_mat.set_shader_parameter("sky_color", c)
