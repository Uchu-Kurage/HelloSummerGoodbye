class_name PhotoSpot
extends ExamineSpot
## 写真のポイント（章「あの夏へ」の破）。近づくと「E」／「とる」の吹き出しが出る。
## カメラを持っていて、フィルムが残っていれば、撮れる。撮ると現像前の写真のアイテムが手に入り、心の声が一言出る。
## フィルムがなければ「フィルムが ない」。撮り直しはできない（撮ったポイントは、もう撮れない）。
## 撮るかどうかはプレイヤーが選ぶ（ポイントは15か所、フィルムは12枚）。

## 写真のデータの ID（data/photos/<id>.tres）
@export var photo_id: StringName
## 撮ったあとに続けて出すせりふ（「タケル：撮んなよ。恥ずかしいだろ」など）
@export var after_lines: Array[String] = []


func _ready() -> void:
	super()
	# 撮る前のせりふ・くり返しのせりふは使わない（撮ったあとは、調べられない）
	npc_data.lines = []


func can_interact() -> bool:
	if not GameState.has_camera() or GameState.photo_taken(photo_id):
		return false
	return true


func bubble_text(touch: bool) -> String:
	return Strings.PHOTO_TOUCH if touch else Strings.PHOTO_KEY


func interact(hud: Node) -> void:
	if not can_interact():
		return
	if GameState.film_left <= 0:
		var me := NpcData.new()
		me.id = StringName("photo_nofilm")
		me.display_name = ""
		me.placeholder_color = WorldPalette.PLAYER_HAT
		hud.start_talk(me, [Strings.NO_FILM] as Array[String], null, self)
		return
	var p := GameState.photo_data(photo_id)
	if p == null or not GameState.take_photo(p):
		return
	SfxPlayer.play("shutter")
	var me := NpcData.new()
	me.id = StringName("photo_" + String(photo_id))
	me.display_name = ""
	me.placeholder_color = WorldPalette.PLAYER_HAT
	var lines: Array[String] = []
	lines.append(p.inner_voice if p.inner_voice.begins_with("ぼく：") else "ぼく：" + p.inner_voice)
	lines.append_array(after_lines)
	hud.start_talk(me, lines, null, self)
