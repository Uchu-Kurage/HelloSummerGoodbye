class_name ItemPickup
extends Interactable
## 拾えるアイテム。近づくと「E」／「ひろう」の吹き出しが出る。

const BOB_HEIGHT := 6.0
const BOB_SPEED := 2.2
const ICON_SIZE := 44.0
## 拾ったときに立ち止まる時間（アイテムが頭の上に浮かび上がるまで）
const PICKUP_HOLD := 1.0

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
	# 会話でもらったなど、ほかのところで手に入ったら道からも消える
	GameState.item_collected.connect(func(it: ItemData):
		if item and it.id == item.id and not _picked:
			_picked = true
			set_deferred("monitoring", false)
			notify_left()
			UiAnim.fade(self, 0.0, UiTokens.TIME_FADE).tween_callback(queue_free))


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
	hud.celebrate_item(item)
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
	# 道の上の絵はその場で消え、かわりに主人公の前に浮かび上がる（ItemFanfare）
	var tw := create_tween()
	tw.tween_property(_visual, "modulate:a", 0.0, UiTokens.TIME_SMALL)
	tw.tween_callback(queue_free)
