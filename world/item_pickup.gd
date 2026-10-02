class_name ItemPickup
extends Area2D
## 拾えるアイテム。プレイヤーが範囲に入ると HUD（グループ pickup_listener）に知らせる。

const BOB_HEIGHT := 6.0
const BOB_SPEED := 2.2
const ICON_SIZE := 44.0

var item: ItemData
var _picked := false
var _t := 0.0
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if item and item.icon:
		var s := Sprite2D.new()
		s.texture = item.icon
		_visual.add_child(s)
	_visual.draw.connect(_draw_placeholder)
	_visual.queue_redraw()


func _draw_placeholder() -> void:
	if item == null or item.icon:
		return
	var h := ICON_SIZE / 2.0
	_visual.draw_rect(Rect2(-h - 3, -h - 3, ICON_SIZE + 6, ICON_SIZE + 6), WorldPalette.SIGN_POST)
	_visual.draw_rect(Rect2(-h, -h, ICON_SIZE, ICON_SIZE), item.placeholder_color)


func _process(delta: float) -> void:
	if _picked:
		return
	if not UiAnim.reduced():
		_t += delta
	_visual.position.y = -40.0 + sin(_t * BOB_SPEED) * BOB_HEIGHT


## HUD が吹き出しを出す位置（画面座標）
func bubble_screen_position() -> Vector2:
	return get_global_transform_with_canvas() * Vector2(0, -110)


func can_pick() -> bool:
	return not _picked


func pick() -> void:
	if _picked:
		return
	_picked = true
	set_deferred("monitoring", false)
	get_tree().call_group("pickup_listener", "on_pickup_exited", self)
	GameState.collect(item)
	var tw := create_tween().set_parallel().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position:y", _visual.position.y - 60.0, UiTokens.TIME_PANEL * 2)
	tw.tween_property(_visual, "modulate:a", 0.0, UiTokens.TIME_PANEL * 2)
	tw.chain().tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	if body is Player and not _picked:
		get_tree().call_group("pickup_listener", "on_pickup_entered", self)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		get_tree().call_group("pickup_listener", "on_pickup_exited", self)


func _exit_tree() -> void:
	if not _picked and is_inside_tree():
		get_tree().call_group("pickup_listener", "on_pickup_exited", self)
