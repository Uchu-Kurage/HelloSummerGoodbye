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
	_sign_label.text = GameState.day_date_text(day_data) + "\n" + GameState.day_title(day_data)
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


## アイテムを道に落とす（会話の @drop。走り去った人が落としていくものなど）。x はその日の中の位置
func drop_item(item: ItemData, x: float) -> void:
	if GameState.is_collected(item.id):
		return
	var p: ItemPickup = PICKUP_SCENE.instantiate()
	p.item = item
	p.position = Vector2(x, GROUND_Y)
	$Items.add_child(p)


## 会話の @event を、Props の下の小物に知らせる（水しぶき、バスの出発など）
func on_talk_event(event_name: String) -> void:
	for c in $Props.get_children():
		if c.has_method("on_talk_event"):
			c.on_talk_event(event_name)


## 道：足もと（GROUND_Y + 4）が道の奥のほうに入るよう、少し上から始める
const ROAD_TOP := 592.0
const ROAD_BOTTOM := 676.0
## 道の絵（Google Gemini で生成し、背景を切り抜いたもの）。上から奥の草・土の道・手前の草。
## 絵の中で土の道がある行（px）。この範囲が ROAD_TOP〜ROAD_BOTTOM に重なるように描く
const ROAD_TEX: Texture2D = preload("res://world/scenery/painted/road.png")
const ROAD_TEX_DIRT := Vector2(40, 194)


func _draw() -> void:
	var L := GameState.DAY_LENGTH_PX
	var k := (ROAD_BOTTOM - ROAD_TOP) / (ROAD_TEX_DIRT.y - ROAD_TEX_DIRT.x)
	var h := ROAD_TEX.get_height() * k
	var top := ROAD_TOP - ROAD_TEX_DIRT.x * k
	draw_rect(Rect2(0, top + h - 8.0, L, 900), WorldPalette.GROUND)
	# 1日の長さにちょうど収まる枚数だけ横に並べる（日の境目でもつながる）
	var n := maxi(1, roundi(L / (ROAD_TEX.get_width() * k)))
	var tile := L / n
	for i in n:
		draw_texture_rect(ROAD_TEX, Rect2(i * tile - 1.0, top, tile + 2.0, h), false)
