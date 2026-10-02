class_name ItemPickup
extends Interactable
## 拾えるアイテム。近づくと「E」／「ひろう」の吹き出しが出る。

const BOB_HEIGHT := 6.0
const BOB_SPEED := 2.2
const ICON_SIZE := 44.0
## 拾ったときに立ち止まる時間
const PICKUP_HOLD := 0.6

var item: ItemData
var _picked := false
var _t := 0.0
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	super()
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


func can_interact() -> bool:
	return not _picked


func bubble_text(touch: bool) -> String:
	return Strings.PICKUP_TOUCH if touch else Strings.PICKUP_KEY


func interact(hud: Node) -> void:
	if _picked:
		return
	pick()
	SfxPlayer.play("pickup")
	if hud.player:
		hud.player.hold(PICKUP_HOLD)
	hud.show_item_message(item)


func pick() -> void:
	if _picked:
		return
	_picked = true
	set_deferred("monitoring", false)
	notify_left()
	GameState.collect(item)
	var tw := create_tween().set_parallel().set_trans(UiTokens.TRANS).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position:y", _visual.position.y - 60.0, UiTokens.TIME_PANEL * 2)
	tw.tween_property(_visual, "modulate:a", 0.0, UiTokens.TIME_PANEL * 2)
	tw.chain().tween_callback(queue_free)
