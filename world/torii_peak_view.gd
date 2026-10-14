class_name ToriiPeakView
extends Node2D
## 「鳥居と山のてっぺんが重なって見える」場所（タケルの秘密の場所／急の缶の場所）。
## 遠くの山のてっぺん（ゆっくり動く）と、近くの鳥居（速く動く）を、カメラの動きに合わせて描く。
## 2つが重なるのは、カメラの位置が1か所のときだけ（Parallax2D と同じ考え方：奥ほど画面に張りついて動く）。
## 重なる位置は overlap_cam_x（その日の中のカメラの x）で決める。overlap(cam_x) が 1.0 なら完全に重なっている。
## どの日のシーンでも使える（日の左はしからの距離で決める）。

## 重なるときのカメラの x（その日の中の位置）
@export var overlap_cam_x := 2000.0
## 重なったとき、2つを画面のまん中からどれだけ右に置くか（px）
@export var screen_offset := 200.0
## 奥行き：画面に張りつく割合（0＝動かない 〜 1＝世界と同じに動く）。山のほうが奥
@export var peak_scroll := 0.12
@export var torii_scroll := 0.5
## 重なっているとみなす画面上のずれ（px）
@export var tolerance := 36.0
## 山のてっぺんと鳥居の大きさ・高さ（画面の下から）
@export var peak_height := 360.0
@export var torii_height := 150.0
@export var horizon_y := 330.0

const TORII_TEX: Texture2D = preload("res://world/scenery/painted/prop_torii.png")

var _cam: Camera2D


## 日の左はしから見た、いまのカメラの x（カメラがなければ 0）
func cam_x_in_day() -> float:
	var cam := _camera()
	if cam == null:
		return 0.0
	return cam.global_position.x - _day_left()


## 山と鳥居の、画面の中での横の位置（画面のまん中からの距離 px）。カメラの x の関数
func peak_offset(cam_x: float) -> float:
	return screen_offset - (cam_x - overlap_cam_x) * peak_scroll


func torii_offset(cam_x: float) -> float:
	return screen_offset - (cam_x - overlap_cam_x) * torii_scroll


## 重なり具合（1.0＝ぴったり、0.0＝tolerance 以上ずれている）
func overlap(cam_x: float) -> float:
	var gap := absf(peak_offset(cam_x) - torii_offset(cam_x))
	return clampf(1.0 - gap / tolerance, 0.0, 1.0)


## いま重なって見えるか
func is_overlapping() -> bool:
	return overlap(cam_x_in_day()) > 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := _camera()
	if cam == null:
		return
	var cx := cam.global_position.x - _day_left()
	var base := to_local(Vector2(cam.global_position.x, 604.0))
	var ground := base.y
	# 山のてっぺん：遠くの青い、とがった山（画面の下から数えた高さ）
	var px := base.x + peak_offset(cx)
	var top_y := ground - horizon_y - peak_height * 0.0 - 130.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(px - 260, ground - horizon_y + 40), Vector2(px, top_y), Vector2(px + 260, ground - horizon_y + 40)]), Color(0.52, 0.62, 0.72, 0.9))
	draw_colored_polygon(PackedVector2Array([
		Vector2(px - 38, top_y + 62), Vector2(px, top_y), Vector2(px + 38, top_y + 62)]), Color(0.92, 0.94, 0.96, 0.95))
	# 鳥居：山のてっぺんの真下あたりに立つ（重なると、てっぺんが鳥居の笠木の上に乗って見える）
	var tx := base.x + torii_offset(cx)
	var k := torii_height / TORII_TEX.get_height()
	var w := TORII_TEX.get_width() * k
	draw_texture_rect(TORII_TEX, Rect2(tx - w / 2.0, ground - horizon_y + 40.0 - torii_height, w, torii_height), false)


func _camera() -> Camera2D:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_2d()
	return _cam


func _day_left() -> float:
	var n := get_parent()
	while n and not n is DayBase:
		n = n.get_parent()
	return (n as Node2D).global_position.x if n else 0.0
