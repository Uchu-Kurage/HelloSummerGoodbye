class_name Cameo
extends Node2D
## 他ルートの人物の顔出し（CameoData）を1つ置く。足もと（道）が原点。日のシーンの土台（DayBase）が Props の下に置く。
## - PERSON：Npc を使い回す。一言（line）があれば話しかけると一言だけ返す。話したことは記録せず、フラグも好感度もかえない
## - GLIMPSE：お面の子。遠くに一瞬見えて、近づくとゆっくり消える（UiTokens.TIME_GLIMPSE_VANISH）。話しかけられない
## - OBJECT：持ち物だけ（world/scenery_prop.gd の絵）
## 出すかどうか（ルート・追加の条件）は、置いたときと、フラグが変わったときに決める

const NPC_SCENE := preload("res://world/npc.tscn")
const SCENERY_PROP := preload("res://world/scenery_prop.gd")
## お面の子の遠くの姿（田んぼに立つ絵。足もとは稲や煙にかくれている）
const GLIMPSE_TEX: Texture2D = preload("res://world/scenery/painted/fox_far.png")
const GLIMPSE_H := 150.0
## この距離まで近づくと消える（主人公が画面の左寄りにいるので、画面に入ってすぐ）
const VANISH_FROM := 620.0
## 奥へずらしたものの大きさと、かすみ（奥へ 100px で 0.8 倍）
const DEPTH_SCALE := 0.002
const DEPTH_FADE := 0.0012

var data: CameoData
## お面の子が消えたあと（その日はもう出ない）
var gone := false
var _npc: Npc
var _shown := false
var _player: Node2D


func setup(d: CameoData) -> void:
	data = d
	name = String(d.id)
	position = Vector2(d.x, DayBase.GROUND_Y + 4.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if data == null:
		return
	match data.kind:
		CameoData.Kind.PERSON:
			_npc = NPC_SCENE.instantiate()
			_npc.npc_data = _npc_data()
			_npc.remember_talk = false
			_npc.visual_scale = depth_scale()
			_npc.visual_lift = data.depth
			add_child(_npc)
			if data.tilt != 0.0:
				_npc.get_node("Visual").rotation_degrees = data.tilt
		CameoData.Kind.OBJECT:
			var p: Node2D = SCENERY_PROP.new()
			p.set("kind", data.prop_kind)
			if data.prop_width > 0.0:
				p.set("width", data.prop_width)
			p.position = Vector2(0, -data.depth)
			p.scale = Vector2.ONE * depth_scale()
			add_child(p)
	_refresh(false)
	GameState.flags_changed.connect(func(): _refresh(true))


## 奥へずらした分の大きさ
func depth_scale() -> float:
	return maxf(0.4, 1.0 - data.depth * DEPTH_SCALE)


## いま出しているか
func is_shown() -> bool:
	return _shown and not gone


## 話しかけられるか（自動の動作確認からも使う）
func talkable() -> bool:
	return _shown and _npc != null and _npc.can_interact()


func npc() -> Npc:
	return _npc


## 話しかけたときに使う NpcData：見た目は各ルートのものを写し、一言だけにする。話し終えても何も立てない
func _npc_data() -> NpcData:
	var d: NpcData = data.npc.duplicate() if data.npc else NpcData.new()
	d.id = data.id
	var one: Array[String] = []
	if data.line != "":
		one.append(data.line)
	d.lines = one
	d.repeat_lines = [] as Array[String]
	d.appear_if = null
	d.set_flags = [] as Array[StringName]
	d.auto_talk = false
	d.alt_sprite = null
	d.alt_sprite_event = ""
	if data.sprite:
		d.sprite = data.sprite
	if data.height > 0.0:
		d.height = data.height
	return d


func _refresh(fade: bool) -> void:
	var want := data.is_shown() and not gone
	if want == _shown and fade:
		return
	_shown = want
	if _npc:
		_npc.set_deferred("monitoring", want)
		if not want:
			_npc.notify_left()
	if not fade:
		visible = want
		return
	# フラグが変わって出たり消えたりするときは、ゆっくり
	if want:
		modulate.a = 0.0
		visible = true
		UiAnim.fade(self, 1.0, UiTokens.TIME_FADE * 2)
	else:
		UiAnim.fade(self, 0.0, UiTokens.TIME_FADE * 2)


func _process(_delta: float) -> void:
	if data == null or data.kind != CameoData.Kind.GLIMPSE or gone or not visible:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if global_position.x - _player.global_position.x < VANISH_FROM:
		vanish()


## お面の子が、ゆっくり消える（急に消さない）
func vanish() -> void:
	if gone:
		return
	gone = true
	UiAnim.fade(self, 0.0, UiTokens.TIME_GLIMPSE_VANISH)


func _draw() -> void:
	if data == null or data.kind != CameoData.Kind.GLIMPSE:
		return
	var tex := data.sprite if data.sprite else GLIMPSE_TEX
	var h := (data.height if data.height > 0.0 else GLIMPSE_H) * depth_scale()
	var w := tex.get_width() * h / tex.get_height()
	# こちらを見て立つ。遠いので少しかすむ
	draw_texture_rect(tex, Rect2(-w / 2.0, -data.depth - h, w, h), false, Color(1, 1, 1, clampf(0.92 - data.depth * DEPTH_FADE, 0.5, 1.0)))
