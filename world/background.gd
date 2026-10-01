class_name Background
extends Node2D
## Parallax2D の3層（空・遠景・近景）。仮素材は単色と簡単な図形。

@onready var _sky: ColorRect = $Sky/SkyRect


func _ready() -> void:
	# 動きを減らす設定のときは雲を流さない
	if UiAnim.reduced():
		$Clouds.autoscroll = Vector2.ZERO


func set_sky_color(c: Color) -> void:
	_sky.color = c
