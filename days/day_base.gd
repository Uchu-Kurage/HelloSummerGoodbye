class_name DayBase
extends Node2D
## 各日のシーンの共通の土台。DayStreamer が day_data を入れてから木に追加する。
## - Boundary：日の境目（x = 0）。電柱や木を置いて背景のつなぎ目を隠す場所
## - Sign：その日のタイトルを書いた看板
## - ItemSpots：アイテムを置く位置（Marker2D）。足りなければ等間隔に置く
## - Props：家などの小物を置く場所

const GROUND_Y := 600.0
const PICKUP_SCENE := preload("res://world/item_pickup.tscn")
const CAMEO_SCENE := preload("res://world/cameo.tscn")

var day_data: DayData
## タイトル画面の背景として使うとき true（アイテムを置かない）
var preview := false

@onready var _sign_label: Label = $Sign/Board/Label


func _ready() -> void:
	if day_data == null:
		return
	_sign_label.text = GameState.day_date_text(day_data) + "\n" + GameState.day_title(day_data)
	if GameState.is_indoor(day_data):
		# 家の中・病室：外の景色の小物と看板は出さず、壁と床を描く
		$Boundary.hide()
		$Sign.hide()
		$Props/Tree.hide()
	if preview:
		# タイトルの背景では景色だけを見せる
		$Sign.hide()
		$Props.hide()
	else:
		_spawn_items()
		_spawn_cameos()
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


## 他ルートの人物の顔出し（res://data/cameos/）。その日の分をぜんぶ置き、出すかどうかは Cameo がルートとフラグで決める
func _spawn_cameos() -> void:
	for d in CameoData.for_day(day_data.day_number):
		var c: Cameo = CAMEO_SCENE.instantiate()
		c.setup(d)
		$Props.add_child(c)
		# 遠くの姿は、手前の小物（家・送り火など）のうしろに描く
		if d.depth > 0.0:
			$Props.move_child(c, 0)


## その日の顔出し（自動の動作確認からも使う）
func cameos() -> Array[Cameo]:
	var out: Array[Cameo] = []
	for c in $Props.get_children():
		if c is Cameo:
			out.append(c)
	return out


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


## 室内の壁と床の色（仮素材）
const INDOOR_WALL := Color("#E4DCC9")
const INDOOR_WALL_LOW := Color("#CDBFA3")
const INDOOR_FLOOR := Color("#A98862")
const INDOOR_FLOOR_LINE := Color("#8C6E4D")


func _draw() -> void:
	var L := GameState.DAY_LENGTH_PX
	if day_data and GameState.is_indoor(day_data):
		_draw_indoor(L)
		return
	var k := (ROAD_BOTTOM - ROAD_TOP) / (ROAD_TEX_DIRT.y - ROAD_TEX_DIRT.x)
	var h := ROAD_TEX.get_height() * k
	var top := ROAD_TOP - ROAD_TEX_DIRT.x * k
	draw_rect(Rect2(0, top + h - 8.0, L, 900), WorldPalette.GROUND)
	# 1日の長さにちょうど収まる枚数だけ横に並べる（日の境目でもつながる）
	var n := maxi(1, roundi(L / (ROAD_TEX.get_width() * k)))
	var tile := L / n
	for i in n:
		draw_texture_rect(ROAD_TEX, Rect2(i * tile - 1.0, top, tile + 2.0, h), false)


## 室内：壁と床（高さは画面の上端から下端まで）
func _draw_indoor(L: float) -> void:
	draw_rect(Rect2(-1, -300, L + 2, 300 + ROAD_TOP + 8.0), INDOOR_WALL)
	draw_rect(Rect2(-1, ROAD_TOP - 90.0, L + 2, 98.0), INDOOR_WALL_LOW)
	draw_rect(Rect2(-1, ROAD_TOP + 8.0, L + 2, 900), INDOOR_FLOOR)
	var x := 0.0
	while x < L:
		draw_line(Vector2(x, ROAD_TOP + 8.0), Vector2(x, ROAD_TOP + 140.0), INDOOR_FLOOR_LINE, 2.0)
		x += 160.0
	draw_line(Vector2(0, ROAD_TOP + 8.0), Vector2(L, ROAD_TOP + 8.0), INDOOR_FLOOR_LINE, 4.0)
