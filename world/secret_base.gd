@tool
class_name SecretBase
extends Node2D
## 秘密基地（親友ルートの 4・8・9日目で使い回す）。足もとが原点。
## 盤（BasePuzzle）のマスに、4日目のミニゲームではめた材料（GameState.base_cells）を描く。
## - BUILD（4日目）：作りかけ。雨の間は、ふさいでいない屋根のマス（と、すだれ）から雨だれが落ちる。入口は空いたまま
## - QUIET（8日目）：4日目の形のまま。入口に段ボールの戸（6日目にタケルの家の前にあった箱と同じ）
## - NIGHT（9日目）：夜。懐中電灯（プレイヤー）が近づくと、材料ごとに光の見え方が変わる

enum Mode { BUILD, QUIET, NIGHT }

@export var mode: Mode = Mode.BUILD:
	set(v):
		mode = v
		queue_redraw()

const P := preload("res://world/world_palette.gd")
## 世界の中での1マスの大きさ
const CELL := 26.0
const DRIP_SPEED := 260.0
## 懐中電灯の光が届く距離
const LIGHT_REACH := 520.0

var _t := 0.0
var _rain := 0.0
var _glow: Node2D
var _player: Node2D


func _ready() -> void:
	add_to_group("secret_base")
	if Engine.is_editor_hint():
		return
	GameState.base_changed.connect(queue_redraw)
	# 「かいいん」の札をもらったら柱に下げる
	GameState.item_collected.connect(func(_it): queue_redraw())
	GameState.item_gone.connect(func(_it): queue_redraw())
	# 8・9日目に記録がない（4日目を通っていない）ときは、板でふさいだことにしておく
	if mode != Mode.BUILD and GameState.base_cells.is_empty():
		var wood := GameState.base_material(&"wood")
		var cells := GameState.base_puzzle().holes()
		for i in cells.size():
			GameState.base_cells[cells[i]] = wood.id
			GameState.base_cell_piece[cells[i]] = 100 + int(i / 4.0)
	if mode == Mode.NIGHT:
		var layer := GlowLayer.new()
		add_child(layer)
		_glow = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = m
		_glow.draw.connect(_draw_night)
		layer.add_child(_glow)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if mode == Mode.BUILD:
		var tod := get_tree().get_first_node_in_group("time_of_day")
		_rain = tod.rain if tod else 0.0
		if not UiAnim.reduced():
			_t += delta
		if _rain > 0.0:
			queue_redraw()
	elif _glow:
		_glow.queue_redraw()


## 盤の左上（足もとが原点、真ん中にそろえる）
static func board_origin(pz: BasePuzzle) -> Vector2:
	return Vector2(-pz.width() * CELL / 2.0, -pz.height() * CELL)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-195, -182, 390, 182), P.WOOD_DARK, false, 2.0)
		return
	var pz := GameState.base_puzzle()
	var o := board_origin(pz)
	BaseArt.draw_board(self, pz, o, CELL, mode != Mode.BUILD)
	# 「かいいん」の札（入口の柱に下げる）
	if GameState.holds(&"base_plaque"):
		var pc := o + Vector2(BaseArt.plaque_cell(pz)) * CELL + Vector2(CELL / 2.0, 0)
		draw_line(pc, pc + Vector2(-16, 18), P.WOOD_DARK, 2.0)
		draw_line(pc, pc + Vector2(16, 18), P.WOOD_DARK, 2.0)
		draw_rect(Rect2(pc + Vector2(-30, 18), Vector2(60, 28)), P.SIGN_BOARD)
		draw_rect(Rect2(pc + Vector2(-30, 18), Vector2(60, 28)), P.WOOD_DARK, false, 2.0)
	if mode == Mode.BUILD and _rain > 0.0:
		_draw_drips(pz, o)


## ふさいでいない屋根のマス（と、すだれ）から、雨がぽたぽた落ちる
func _draw_drips(pz: BasePuzzle, o: Vector2) -> void:
	var c := Color(P.RAIN_STREAK, P.RAIN_STREAK.a * _rain)
	for x in pz.width():
		var leak := false
		var top := 0
		for y in pz.height():
			var cell := Vector2i(x, y)
			if not pz.is_roof(cell):
				continue
			var m := GameState.base_cell(cell)
			if m == null or m.leaks:
				leak = true
				top = y + 1
		if not leak:
			continue
		var y0 := o.y + top * CELL
		var fall := -y0
		var y := y0 + fposmod(_t * DRIP_SPEED + x * 37.0, fall)
		var px := o.x + (x + 0.5) * CELL
		draw_line(Vector2(px, y), Vector2(px, y + 10), c, 2.0)


## 夜（9日目）。懐中電灯（プレイヤー）が近いほど、材料ごとの光がはっきり見える
func _draw_night() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var k := 0.35
	if _player:
		k += 0.65 * clampf(1.0 - absf(_player.global_position.x - global_position.x) / LIGHT_REACH, 0.0, 1.0)
	var pz := GameState.base_puzzle()
	BaseArt.draw_night(_glow, pz, board_origin(pz), CELL, k)
