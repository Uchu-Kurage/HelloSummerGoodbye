class_name ExamineSpot
extends Npc
## 調べるところ（章「あの夏へ」）。近づくと「E」／「しらべる」の吹き出しが出て、調べると心の声やせりふが出る。
## 人ではないので、せりふはシーンに直接書く（NpcData は読み込み時に作る）。会話の @find / @event / @flag も使える。
## require_flags が立っていないあいだは、調べても locked_lines だけ出る（空ならそもそも調べられない）。

@export var kind: ChapterArt.Kind = ChapterArt.Kind.APPLE_TABLE
@export var width := 160.0
## 話す人の名前（空なら地の文。「ぼく：（……）」のように行の頭で変えられる）
@export var speaker := ""
@export var lines: Array[String] = []
## 2回目以降のせりふ（空なら lines をくり返す）
@export var repeat_lines_text: Array[String] = []
@export var locked_lines: Array[String] = []
@export var require_flags: Array[StringName] = []
## 吹き出しを出す高さ
@export var spot_height := 170.0
## 人として立たせる（なつみ・看護師など。仮の姿。向きも変える）。見た目の色と背丈は look から
@export var as_person := false
@export var look: NpcData
## 近づいただけで話しはじめる（最初の1回）
@export var auto_talk_on := false
## これが立つまでは、いないことにする（なつみと話したあとに通りかかるタケル、など）
@export var appear_flags: Array[StringName] = []


func _ready() -> void:
	face_player = as_person
	var d := NpcData.new()
	d.id = StringName("examine_%s_%s" % [get_parent().get_parent().name if get_parent() and get_parent().get_parent() else "", name])
	d.display_name = speaker
	d.lines = lines
	d.repeat_lines = repeat_lines_text
	d.height = spot_height
	d.placeholder_color = WorldPalette.PLAYER_HAT
	if look:
		d.height = look.height
		d.placeholder_color = look.placeholder_color
		d.skin_color = look.skin_color
		d.hair_color = look.hair_color
		d.shirt_color = look.shirt_color
		d.pants_color = look.pants_color
		d.hair_full = look.hair_full
		d.stoop = look.stoop
		d.sprite = look.sprite
	d.auto_talk = auto_talk_on
	if not appear_flags.is_empty():
		var c := FlagCondition.new()
		c.require_all = appear_flags
		d.appear_if = c
	npc_data = d
	super()


func can_interact() -> bool:
	if not super():
		return false
	return requirements_met() or not locked_lines.is_empty()


func requirements_met() -> bool:
	for f in require_flags:
		if not GameState.has_flag(f):
			return false
	return true


func bubble_text(touch: bool) -> String:
	return Strings.EXAMINE_TOUCH if touch else Strings.EXAMINE_KEY


func interact(hud: Node) -> void:
	if not can_interact():
		return
	if not requirements_met():
		hud.start_talk(npc_data, locked_lines, self)
		return
	super(hud)


func _draw_body() -> void:
	if as_person:
		# 絵（look.sprite）があれば絵、なければ仮の姿
		super()
	else:
		ChapterArt.draw(_visual, kind, width)


## 家具・絵は、近づいても向きを変えたり息づかいで揺れたりしない
func _process(delta: float) -> void:
	if as_person:
		super(delta)
	else:
		_visual.queue_redraw()
