class_name GlowLayer
extends CanvasLayer
## 夜の灯り（提灯・街灯・送り火・星・懐中電灯）を描く層。
## ゲームの世界の CanvasModulate（時間帯の色）の外にあるので、夜でも暗くならない。
## 日のシーンの Props の下に置き、子の位置はその日の中の座標（足もとが y = 604）で書く。
## プレイヤーより手前に描かれるので、光の輪は淡く（不透明度 0.3 程度まで）する。


func _ready() -> void:
	layer = 1
	follow_viewport_enabled = true
	_sync()


func _process(_delta: float) -> void:
	_sync()


## 親（日のシーン）の位置と、見えている／いないに合わせる（CanvasLayer は親から引き継がないため）
func _sync() -> void:
	var p := get_parent() as CanvasItem
	if p == null:
		return
	offset = (p as Node2D).global_position if p is Node2D else Vector2.ZERO
	visible = p.is_visible_in_tree()
