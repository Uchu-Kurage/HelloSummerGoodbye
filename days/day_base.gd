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
	_sign_label.text = Strings.DATE_FULL % [day_data.month, day_data.day] + "\n" + day_data.title
	if preview:
		# タイトルの背景では景色だけを見せる
		$Sign.hide()
		$Props.hide()
	else:
		_spawn_items()
	queue_redraw()


func _spawn_items() -> void:
	var spots: Array[Node] = $ItemSpots.get_children()
	var n := day_data.items.size()
	for i in n:
		var item := day_data.items[i]
		if GameState.is_collected(item.id):
			continue
		var p: ItemPickup = PICKUP_SCENE.instantiate()
		p.item = item
		if i < spots.size():
			p.position = (spots[i] as Node2D).position
		else:
			p.position = Vector2(GameState.DAY_LENGTH_PX * (i + 1) / (n + 1), GROUND_Y)
		$Items.add_child(p)


func _draw() -> void:
	var L := GameState.DAY_LENGTH_PX
	draw_rect(Rect2(0, GROUND_Y, L, 900), WorldPalette.GROUND)
	draw_rect(Rect2(0, GROUND_Y + 24, L, 56), WorldPalette.ROAD)
	draw_rect(Rect2(0, GROUND_Y, L, 6), WorldPalette.GROUND_DARK)
