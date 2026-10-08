extends Node2D
## ゲーム本体。日の切り替わり・エンディングへの移行・一時停止と宝箱の開閉をまとめる。

## 日の終わりのこの手前で、日の切り替わり演出を始める
const DAY_END_TRIGGER := 120.0
## 次の日のはじめの、このくらい先から歩き出す
const NEXT_DAY_START := 200.0
## 最後の日の終点（右端からの距離）
const END_MARGIN := 240.0
const START_X := 220.0
const ENDING_SCENE := "res://ui/ending.tscn"
const ENGAWA_SCENE := preload("res://ui/engawa.tscn")
const TITLE_SCENE := "res://ui/title.tscn"
## エピローグ「それから」の主人公（おとな）の背丈（子どもの何倍か）
const ADULT_SCALE := 1.3

@onready var player: Player = $Player
@onready var camera: CameraController = $Camera
@onready var streamer: DayStreamer = $DayStreamer
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var box: TreasureBox = $BoxLayer/TreasureBox
@onready var debug_label: Label = $DebugLayer/DebugLabel

var _debug: DebugJump
## 縁側の場面（日の切り替わりの中。1〜9日目の終わり）
var engawa: Engawa
var _changing_day := false
var _ending := false


func _ready() -> void:
	# 本編は BGM なし（夏の環境音だけ）。デバッグのジャンプや「もういちど」から来ても止める
	SfxPlayer.stop_music()
	# ふだんは1日目の左端から。デバッグのジャンプでは、その日のはじめから
	var start := GameState.start_day_index
	GameState.current_day_index = start
	var x := START_X if start == 0 else start * GameState.DAY_LENGTH_PX + NEXT_DAY_START
	player.position = Vector2(x, Player.GROUND_Y)
	camera.snap()
	streamer.update_now()
	if GameState.epilogue:
		player.body_scale = ADULT_SCALE
	hud.player = player
	hud.box = box
	hud.set_day(GameState.current_day())
	hud.show_walk_hint()
	pause_menu.box_requested.connect(_on_pause_box)
	pause_menu.title_requested.connect(func(): Transition.change_scene(TITLE_SCENE))
	box.closed.connect(_on_box_closed)
	if DebugJump.available():
		_debug = DebugJump.new()
		_debug.closed.connect(_on_box_closed)
		add_child(_debug)
		pause_menu.debug_requested.connect(_on_pause_debug)
	debug_label.visible = false
	engawa = ENGAWA_SCENE.instantiate()
	add_child(engawa)


func _physics_process(_delta: float) -> void:
	if _changing_day or _ending:
		return
	var L := GameState.DAY_LENGTH_PX
	var idx := streamer.player_day_index()
	var x := player.global_position.x
	if idx >= GameState.day_count() - 1:
		if x >= GameState.world_length() - END_MARGIN:
			_go_ending()
	elif x >= (idx + 1) * L - DAY_END_TRIGGER:
		_change_day(idx + 1)


func _process(_delta: float) -> void:
	if debug_label.visible:
		debug_label.text = "fps %d  days %s  x %d" % [
			Engine.get_frames_per_second(), str(streamer.loaded_indices()), player.global_position.x]


func _change_day(next: int) -> void:
	_changing_day = true
	player.locked = true
	hud.close_message()
	var d := GameState.get_day(next)
	var on_dark := func():
		player.position.x = next * GameState.DAY_LENGTH_PX + NEXT_DAY_START
		camera.snap()
		streamer.update_now()
		GameState.set_current_day(next)
	var on_reveal := func(): hud.flip_to_day(d)
	# 暗転のあと、日付の前に、終わった日（next - 1）の縁側の場面。最後の日（帰る日）の終わりにはない
	var ended := next - 1
	var interlude := func(): await engawa.play(ended)
	await Transition.play_day_change(GameState.day_date_text(d), GameState.day_title(d), on_dark, on_reveal, interlude)
	player.locked = false
	_changing_day = false


## エピローグの終わり（おばあちゃんとの会話の @event epilogue_box）。会話を読み終えたら、最後の宝箱（エンディングの画面）へ
func finish_epilogue() -> void:
	if _ending:
		return
	if hud.is_talking():
		await hud.talk_finished
	_go_ending()


func _go_ending() -> void:
	_ending = true
	player.locked = true
	Transition.change_scene(ENDING_SCENE)


func _input(event: InputEvent) -> void:
	if get_tree().paused or Transition.is_busy() or _ending:
		return
	if event.is_action_pressed("pause"):
		SfxPlayer.play("accept")
		pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_box") and not hud.is_in_minigame():
		box.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and OS.is_debug_build():
		# 開発用：F3 で読み込み状況の表示、F4 で日の終わりの手前へ移動（ルートと日を選んでとぶのは、ひとやすみの「デバッグ」）
		if event.physical_keycode == KEY_F3:
			debug_label.visible = not debug_label.visible
		elif event.physical_keycode == KEY_F4:
			var idx := streamer.player_day_index()
			player.position.x = (idx + 1) * GameState.DAY_LENGTH_PX - DAY_END_TRIGGER - 300.0
			if idx >= GameState.day_count() - 1:
				player.position.x = GameState.world_length() - END_MARGIN - 300.0


func _on_pause_box() -> void:
	pause_menu.cover()
	box.open()


func _on_pause_debug() -> void:
	pause_menu.cover()
	_debug.open()


func _on_box_closed() -> void:
	if pause_menu.is_open and pause_menu.covered:
		pause_menu.uncover()
