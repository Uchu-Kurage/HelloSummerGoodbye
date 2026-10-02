extends Node
## 自動の動作確認。godot --headless res://tools/smoke_test.tscn で実行する。
## タイトル → 本編を右へ歩き続け、日付の進み・読み込み日数・アイテム取得・エンディングを確かめる。

var _log: Array[String] = []
var _fail := false


func _ready() -> void:
	# このノードがシーン切り替えで消えないよう、ダミーを current_scene にする
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 60
	await _run()
	print("\n".join(_log))
	print("SMOKE ", "FAILED" if _fail else "OK")
	get_tree().quit(1 if _fail else 0)


func check(cond: bool, msg: String) -> void:
	_log.append(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail = true


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _run() -> void:
	get_tree().change_scene_to_file("res://ui/title.tscn")
	await _wait(0.5)
	check(get_tree().current_scene.name == "Title", "title scene")
	GameState.reset()
	get_tree().change_scene_to_file("res://world/main.tscn")
	await _wait(0.5)
	var main := get_tree().current_scene
	check(main.name == "Main", "main scene")
	var player: Player = main.get_node("Player")
	var streamer: DayStreamer = main.get_node("DayStreamer")
	var camera: CameraController = main.get_node("Camera")

	# 左へは画面の外へ出られない
	Input.action_press("move_left")
	await _wait(1.0)
	Input.action_release("move_left")
	check(player.global_position.x >= camera.left_edge(), "left wall holds (x=%d)" % player.global_position.x)

	# 宝箱を開いて閉じる
	TouchControls.fire_action(&"open_box")
	await _wait(0.8)
	check(get_tree().paused, "box pauses game")
	TouchControls.fire_action(&"open_box")
	await _wait(0.8)
	check(not get_tree().paused, "box closes")

	# 一時停止
	TouchControls.fire_action(&"pause")
	await _wait(0.5)
	check(main.get_node("PauseMenu").is_open, "pause opens")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(0.5)
	check(not get_tree().paused, "pause closes with ui_cancel")

	var max_loaded := 0
	var seen_days: Array[int] = []
	var skip_day := 3  # この日のアイテムはわざと拾わない
	var max_cam := -INF
	var cam_back := false
	Input.action_press("move_right")
	var t := 0.0
	while t < 400.0 and get_tree().current_scene == main:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not is_instance_valid(main) or not main.is_inside_tree():
			break
		max_loaded = maxi(max_loaded, streamer.loaded_count())
		if not seen_days.has(GameState.current_day_index):
			seen_days.append(GameState.current_day_index)
		if camera.position.x < max_cam - 0.5:
			cam_back = true
		max_cam = maxf(max_cam, camera.position.x)
		var hud: Hud = main.get_node("HUD")
		var target := hud.current_target()
		# NPC に話しかけて、せりふを最後まで送る
		if target is Npc:
			Input.action_release("move_right")
			var npc_data: NpcData = (target as Npc).npc_data
			TouchControls.fire_action(&"interact")
			await _wait(0.2)
			check(hud.is_talking() and player.talking, "talk starts: %s" % npc_data.display_name)
			var x0 := player.global_position.x
			Input.action_press("move_right")
			await _wait(0.3)
			check(absf(player.global_position.x - x0) < 1.0, "player stands still while talking")
			Input.action_release("move_right")
			for i in npc_data.lines.size() * 2 + 2:
				if not hud.is_talking():
					break
				TouchControls.fire_action(&"interact")
				await _wait(0.1)
			check(not hud.is_talking() and not player.talking, "talk ends after all lines")
			check(GameState.has_talked(npc_data.id), "talk remembered")
			# 話し終えたら、吹き出しの出ない先まで歩いて進める
			Input.action_press("move_right")
			while hud.current_target() is Npc:
				await get_tree().physics_frame
			continue
		# アイテムの近くで拾う
		if target is ItemPickup and GameState.current_day_index != skip_day:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.3)
			check(hud.is_message_open(), "message shown day %d" % (GameState.current_day_index + 1))
			TouchControls.fire_action(&"interact")
			TouchControls.fire_action(&"interact")
			Input.action_press("move_right")
	Input.action_release("move_right")
	await _wait(1.5)
	check(seen_days.size() == GameState.day_count(), "visited all days %s" % str(seen_days))
	check(max_loaded <= 3, "max loaded days %d" % max_loaded)
	check(not cam_back, "camera never moved left")
	check(GameState.collected.size() == GameState.day_count() - 1, "collected %d items" % GameState.collected.size())
	var skipped := GameState.get_day(skip_day).items[0]
	check(not GameState.is_collected(skipped.id), "skipped item remains empty")
	check(get_tree().current_scene and get_tree().current_scene.name == "Ending", "ending reached")
	check(GameState.summer_progress(8, 31) > GameState.summer_progress(7, 21), "summer progress increases")
	var c0 := TimeOfDay.sky_color(0.4, 0.0)
	var c1 := TimeOfDay.sky_color(0.4, 1.0)
	check(c1.s < c0.s, "sky fades late summer")
	await _wait(6.0)
