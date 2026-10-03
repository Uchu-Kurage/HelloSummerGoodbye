class_name ItemFanfare
extends Node2D
## アイテムを手に入れたときの演出。主人公の胸の前にアイテムの絵が現れ、頭の上まで浮かび上がって少しとまり、消える。
## ファンファーレ（fanfare）は Hud.celebrate_item が鳴らす。主人公の子にするので、歩いてもついてくる。
## 動きを減らす設定では、浮き上がり・拡大・光の回転をやめ、頭の上でフェードするだけにする。

## 現れる高さ（胸の前）と、浮かび上がった先（帽子の上）。主人公の足もとからの距離
const FROM_Y := -70.0
const TO_Y := -222.0
const ICON_SIZE := 52.0
const RISE_TIME := 0.5
const HOLD_TIME := 1.1
const OUT_TIME := 0.35
## まわりの光の筋
const RAYS := 8
const RAY_FROM := 40.0
const RAY_TO := 54.0
const RAY_SPIN := 0.6
## 浮かんでいるあいだの小さな上下
const BOB_HEIGHT := 3.0
const BOB_SPEED := 3.0

var item: ItemData
var _rays := 0.0
var _t := 0.0
var _y := FROM_Y
var _tween: Tween


func _ready() -> void:
	z_index = 20
	var reduced := UiAnim.reduced()
	_y = TO_Y if reduced else FROM_Y
	position.y = _y
	modulate.a = 0.0
	scale = Vector2.ONE if reduced else Vector2(0.4, 0.4)
	_tween = create_tween()
	if reduced:
		_tween.tween_property(self, "modulate:a", 1.0, UiTokens.TIME_SMALL)
		_tween.tween_property(self, "_rays", 1.0, UiTokens.TIME_SMALL)
	else:
		_tween.tween_property(self, "_y", TO_Y, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "scale", Vector2.ONE, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "modulate:a", 1.0, UiTokens.TIME_SMALL)
		_tween.tween_property(self, "_rays", 1.0, UiTokens.TIME_SMALL)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, OUT_TIME)
	_tween.tween_callback(queue_free)


## すぐに消す（日の切り替わりなど）
func dismiss() -> void:
	if _tween:
		_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, UiTokens.TIME_SMALL_OUT)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if not UiAnim.reduced():
		_t += delta
	position.y = _y + sin(_t * BOB_SPEED) * BOB_HEIGHT * _rays
	queue_redraw()


func _draw() -> void:
	# うしろの丸い紙色のかげ（絵が景色にまぎれないように）
	draw_circle(Vector2.ZERO, ICON_SIZE * 0.72, Color(UiTokens.PAPER, 0.75))
	if _rays > 0.0:
		var spin := _t * RAY_SPIN
		for i in RAYS:
			var a := spin + TAU * i / RAYS
			var dir := Vector2.from_angle(a)
			var reach := RAY_FROM + (RAY_TO - RAY_FROM) * _rays
			draw_line(dir * RAY_FROM, dir * reach, Color(UiTokens.ACCENT, 0.8 * _rays), 3.0, true)
	var h := ICON_SIZE / 2.0
	if item and item.icon:
		var sz := item.icon.get_size()
		var k := ICON_SIZE / maxf(sz.x, sz.y)
		draw_texture_rect(item.icon, Rect2(-sz * k / 2.0, sz * k), false)
	else:
		var c := item.placeholder_color if item else WorldPalette.SIGN_POST
		draw_rect(Rect2(-h - 3, -h - 3, ICON_SIZE + 6, ICON_SIZE + 6), WorldPalette.SIGN_POST)
		draw_rect(Rect2(-h, -h, ICON_SIZE, ICON_SIZE), c)
