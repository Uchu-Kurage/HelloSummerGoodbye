class_name DayBase
extends Node2D
## 各日のシーンの共通の土台。DayStreamer が day_data を入れてから木に追加する。
## - Boundary：日の境目（x = 0）。電柱や木を置いて背景のつなぎ目を隠す場所
## - Sign：その日のタイトルを書いた看板
## - ItemSpots：アイテムを置く位置（Marker2D）。足りなければ等間隔に置く
## - Props：家などの小物を置く場所

const GROUND_Y := 600.0
const PICKUP_SCENE := preload("res://world/item_pickup.tscn")

var day_data: DayData
## タイトル画面の背景として使うとき true（アイテムを置かない）
var preview := false

@onready var _sign_label: Label = $Sign/Board/Label


func _ready() -> void:
	if day_data == null:
		return
	_sign_label.text = Strings.DATE_FULL % [day_data.month, day_data.day] + "\n" + GameState.day_title(day_data)
	if preview:
		# タイトルの背景では景色だけを見せる
		$Sign.hide()
		$Props.hide()
	else:
		_spawn_items()
	queue_redraw()


func _spawn_items() -> void:
	var spots: Array[Node] = $ItemSpots.get_children()
	var items := GameState.day_items(day_data)
	var n := items.size()
	for i in n:
		var item := items[i]
		# 人からもらうものは道に置かない
		if GameState.is_collected(item.id) or not item.on_ground:
			continue
		var p: ItemPickup = PICKUP_SCENE.instantiate()
		p.item = item
		if i < spots.size():
			p.position = (spots[i] as Node2D).position
		else:
			p.position = Vector2(GameState.DAY_LENGTH_PX * (i + 1) / (n + 1), GROUND_Y)
		$Items.add_child(p)


## 会話の @event を、Props の下の小物に知らせる（水しぶき、バスの出発など）
func on_talk_event(event_name: String) -> void:
	for c in $Props.get_children():
		if c.has_method("on_talk_event"):
			c.on_talk_event(event_name)


## 道：足もと（GROUND_Y + 4）が道の奥のほうに入るよう、少し上から始める
const ROAD_TOP := 592.0
const ROAD_BOTTOM := 676.0


func _draw() -> void:
	var L := GameState.DAY_LENGTH_PX
	var P := WorldPalette
	draw_rect(Rect2(0, ROAD_TOP - 6, L, 900), P.GROUND)
	draw_rect(Rect2(0, ROAD_TOP, L, ROAD_BOTTOM - ROAD_TOP), P.ROAD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	# 土のむら（明るいところ・暗いところ）
	for i in int(L / 50):
		var c := Vector2(rng.randf() * L, rng.randf_range(ROAD_TOP + 10, ROAD_BOTTOM - 8))
		var r := rng.randf_range(20, 70)
		var col := P.ROAD_LIGHT if rng.randf() < 0.5 else P.ROAD_DARK
		draw_set_transform(c, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, r, Color(col, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# わだち（車輪の跡）
	for y in [ROAD_TOP + 22.0, ROAD_TOP + 58.0]:
		draw_rect(Rect2(0, y, L, 7), Color(P.ROAD_DARK, 0.28))
		draw_rect(Rect2(0, y + 7, L, 2), Color(P.ROAD_LIGHT, 0.35))
	# 小石
	for i in int(L / 22):
		var c := Vector2(rng.randf() * L, rng.randf_range(ROAD_TOP + 6, ROAD_BOTTOM - 4))
		var r := rng.randf_range(1.5, 3.5)
		draw_circle(c + Vector2(0, 1), r, Color(P.ROAD_DARK, 0.5))
		draw_circle(c, r, P.ROAD_LIGHT)
	# 道の両はしの草（奥は道にかぶさり、手前は道からはみ出す）
	_grass_edge(rng, L, ROAD_TOP, -1.0)
	_grass_edge(rng, L, ROAD_BOTTOM, 1.0)


## 道のふちの草。dir = -1 は奥（上にのびる）、1 は手前
func _grass_edge(rng: RandomNumberGenerator, L: float, y: float, dir: float) -> void:
	var P := WorldPalette
	draw_rect(Rect2(0, y - 3 if dir < 0 else y, L, 3), P.GROUND_DARK)
	for i in int(L / 7):
		var x := rng.randf() * L
		var h := rng.randf_range(5, 14)
		var lean := rng.randf_range(-4, 4)
		var base_y := y + dir * -2.0 if dir < 0 else y + 2.0
		var tip := Vector2(x + lean, base_y + (h if dir < 0 else -h))
		var col := P.GROUND_DARK if rng.randf() < 0.5 else P.GROUND
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, base_y), Vector2(x + 2.5, base_y), tip]), col)
