class_name Background
extends Node2D
## Parallax2D の3層（空・遠景・近景）。仮素材は単色と簡単な図形。

@onready var _sky: ColorRect = $Sky/SkyRect


func set_sky_color(c: Color) -> void:
	_sky.color = c
