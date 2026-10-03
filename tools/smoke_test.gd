extends Node
## 自動の動作確認。godot --headless res://tools/smoke_test.tscn で実行する。
## タイトル → 本編を右へ歩き続け、日付の進み・読み込み日数・アイテム取得・エンディングを確かめる。

var _log: Array[String] = []
var _fail := false
## 型抜きでタケルの型が割れたとき、主人公が削っていた部分
var _katanuki_takeru_broke_at := -1
## 石切りのお手本で、タケルが数えたことば
var _ishikiri_demo_count := ""
## カブトムシが落ちて、また木にもどったのを見たか
var _kabuto_saw_fall_recover := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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

	# 押しつづけると走りだし、離すと歩きにもどる（ふつうの速さにして、物理フレームで数える）
	var keep_scale := Engine.time_scale
	Engine.time_scale = 1.0
	Input.action_press("move_right")
	await _frames(10)
	check(player.is_walking() and not player.is_dashing(), "walks when the key is pressed")
	await _frames(int((Player.DASH_DELAY + Player.DASH_RAMP) * 60) + 4)
	check(player.is_dashing(), "dashes after holding (%.0f px/s)" % player.velocity.x)
	Input.action_release("move_right")
	await _frames(2)
	Input.action_press("move_right")
	await _frames(10)
	check(not player.is_dashing(), "back to walking after letting go")
	Input.action_release("move_right")
	await _frames(2)
	Engine.time_scale = keep_scale

	var max_loaded := 0
	var seen_days: Array[int] = []
	check(GameState.current_ending().id == &"default", "no route -> default ending")
	var hud: Hud = main.get_node("HUD")
	var box: TreasureBox = main.get_node("BoxLayer/TreasureBox")
	var paths := {}
	var max_rain := 0.0
	var rain_after := -1.0
	var stood_still_checked := false
	var takeru_left_day7 := false
	var skip_day := 7  # この日のアイテムはわざと拾わない
	var rain_after_build := -1.0
	var max_cam := -INF
	var cam_back := false
	Input.action_press("move_right")
	var t := 0.0
	while t < 600.0 and get_tree().current_scene == main:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not is_instance_valid(main) or not main.is_inside_tree():
			break
		max_loaded = maxi(max_loaded, streamer.loaded_count())
		var day := GameState.current_day_index
		if not seen_days.has(day):
			seen_days.append(day)
		# 分岐：場面の差し替え（いま入った日のシーン）
		var loaded: Dictionary = streamer._loaded
		if loaded.has(day) and not paths.has(day):
			paths[day] = (loaded[day] as Node).scene_file_path
		# 4日目の夕立：降って、やむ
		var tod: TimeOfDay = main.get_node("TimeOfDay")
		if day == 3:
			max_rain = maxf(max_rain, tod.rain)
		if day == 4 and rain_after < 0.0:
			rain_after = tod.rain
		# 基地を仕上げて会話が終わると、まだ雨の場所にいても雨がやむ
		if day == 3 and GameState.is_collected(&"base_plaque") and rain_after_build < 0.0:
			await _wait(2.5)
			rain_after_build = tod.rain
		# 7日目：けんかのあと、タケルは帰ってしまう
		if day == 6 and loaded.has(6):
			var road := (loaded[6] as Node).get_node_or_null("Props/TakeruRoad") as Npc
			if road and GameState.has_talked(&"takeru_okuribi") and not road.can_interact():
				takeru_left_day7 = true
		if camera.position.x < max_cam - 0.5:
			cam_back = true
		max_cam = maxf(max_cam, camera.position.x)
		# 向こうから声をかけてきた会話も含めて、会話は最後まで送る
		if hud.is_talking():
			Input.action_release("move_right")
			await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		var target := hud.current_target()
		# 窓をあける（10日目のバス）
		if target is BusWindow:
			TouchControls.fire_action(&"interact")
			await _wait(0.2)
			continue
		# NPC に話しかけて、せりふを最後まで送る（なつみには話しかけない＝親友ルートへ）
		# 向こうから声をかけてくる人（auto_talk）は、話しかけずに待つ
		if target is Npc and not GameState.has_talked((target as Npc).npc_data.id) \
				and (target as Npc).npc_data.id != &"natsumi" and not (target as Npc).npc_data.auto_talk:
			Input.action_release("move_right")
			var npc_data: NpcData = (target as Npc).npc_data
			TouchControls.fire_action(&"interact")
			await _wait(0.2)
			check(hud.is_talking() and player.talking, "talk starts: %s (%s)" % [npc_data.display_name, npc_data.id])
			if not stood_still_checked:
				stood_still_checked = true
				var x0 := player.global_position.x
				Input.action_press("move_right")
				await _wait(0.3)
				check(absf(player.global_position.x - x0) < 1.0, "player stands still while talking")
				Input.action_release("move_right")
			await _finish_talk(hud, box)
			check(not hud.is_talking() and not player.talking, "talk ends after all lines")
			check(GameState.has_talked(npc_data.id), "talk remembered")
			Input.action_press("move_right")
			continue
		# アイテムの近くで拾う
		if target is ItemPickup and day != skip_day:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.3)
			check(hud.is_message_open(), "message shown day %d" % (day + 1))
			TouchControls.fire_action(&"interact")
			TouchControls.fire_action(&"interact")
			Input.action_press("move_right")
	Input.action_release("move_right")
	await _wait(1.5)
	check(seen_days.size() == GameState.day_count(), "visited all days %s" % str(seen_days))
	check(max_loaded <= 3, "max loaded days %d" % max_loaded)
	check(not cam_back, "camera never moved left")
	check(GameState.collected.size() == GameState.day_count() - 1, "collected %d items %s" % [GameState.collected.size(), str(GameState.collected.keys())])
	var skipped := GameState.day_items(GameState.get_day(skip_day))[0]
	check(not GameState.is_collected(skipped.id), "skipped item remains empty (%s)" % skipped.id)
	check(get_tree().current_scene and get_tree().current_scene.name == "Ending", "ending reached")

	# 親友ルート
	check(GameState.has_flag(&"route_takeru") and not GameState.has_flag(&"route_natsumi"), "route flag: takeru")
	check(GameState.gone_note(&"marble") == "タケルに あげた", "marble given to takeru")
	check(GameState.holds(&"river_stone") and GameState.was_received(&"river_stone"), "river stone received from takeru")
	check(GameState.find_item(&"river_stone").text().begins_with("タケルがくれた"), "river stone text changes on the route")
	for i in range(3, 10):
		check(str(paths.get(i, "")).ends_with("day_%02d_takeru.tscn" % (i + 1)), "day %d swapped: %s" % [i + 1, paths.get(i, "")])
	check(max_rain > 0.9 and rain_after == 0.0, "day 4 rain falls and stops (max %.2f)" % max_rain)
	check(rain_after_build == 0.0, "rain stops after the base is finished (%.2f)" % rain_after_build)
	check(GameState.base_cells.size() == GameState.base_puzzle().holes().size(), "base: every hole cell remembered")
	check(GameState.base_cell(Vector2i(5, 0)).id == &"wood", "base: materials remembered per cell")
	check(GameState.was_received(&"base_plaque"), "base plaque from takeru")
	for i in [7, 8]:
		var b := _base_in(paths, i)
		check(b != "", "base reused on day %d (%s)" % [i + 1, b])
	for id in [&"takeru_base", &"takeru_festival", &"takeru_festival_home", &"takeru_dawn", &"takeru_trap", &"takeru_dive", &"takeru_okuribi", &"takeru_capsule"]:
		check(GameState.has_talked(id), "takeru talks on his own: %s" % id)
	check(not GameState.has_talked(&"natsumi"), "natsumi was not talked to")
	check(takeru_left_day7, "takeru goes home angry on day 7")
	var buried := GameState.gone.keys().filter(func(k): return GameState.gone[k] == Strings.BURIED_NOTE)
	check(buried.size() == 1, "one item buried in the time capsule %s" % str(buried))
	for id in [&"broken_katanuki", &"bug_cage", &"capsule_map", &"takeru_hat"]:
		check(GameState.was_received(id), "received from takeru: %s" % id)
	if get_tree().current_scene and get_tree().current_scene.name == "Ending":
		var end_box: TreasureBox = get_tree().current_scene.get_node("TreasureBox")
		check(end_box.header_caption.text == GameState.current_ending().title and GameState.current_ending().id == &"takeru",
			"takeru ending shown: %s" % end_box.header_caption.text)
		var notes := {}
		for sl in end_box._slots:
			notes[sl.item.id] = sl.note
		check(notes.get(&"marble", "") == "タケルに あげた", "ending slot: marble given")
		check(buried.size() == 1 and notes.get(buried[0], "") == Strings.BURIED_NOTE, "ending slot: buried item")
		check(end_box._slots[-1].item.id == &"takeru_hat" and end_box._slots[-1].collected, "hat appears last")

	# 石切り：ひらたい石を、ちょうどいいところで3回投げて、タケルに勝つ
	check(GameState.ishikiri_best == 7 and GameState.ishikiri_result == &"win" and GameState.has_flag(&"ishikiri_win"),
		"ishikiri: flat stone at the sweet spot beats takeru (%d)" % GameState.ishikiri_best)
	check(_ishikiri_demo_count.contains("いち、にー、さん、しー、ご！"), "ishikiri: takeru counts his demo (%s)" % _ishikiri_demo_count)
	check(IshikiriGame.skips_for(IshikiriGame.STONES[0], IshikiriGame.SWEET_SPOT + 0.1) == 7 \
		and IshikiriGame.skips_for(IshikiriGame.STONES[0], 0.1) < 3 and IshikiriGame.skips_for(IshikiriGame.STONES[0], IshikiriGame.PULL_MAX) < 3,
		"ishikiri: too early or pulled too far skips less")
	check(IshikiriGame.result_for(5) == &"draw" and IshikiriGame.result_for(4) == &"lose", "ishikiri: draw at 5, lose at 4")
	# まるい石・おおきい石（石切りの画面だけで確かめる）。0回なら「ぽちゃん！」
	var keep_ishi := GameState.flags.duplicate()
	var ishi := IshikiriGame.new()
	get_tree().root.add_child(ishi)
	await _play_ishikiri(ishi, [&"round", &"big", &"round"], [0.0, IshikiriGame.SWEET_SPOT, IshikiriGame.SWEET_SPOT])
	check(ishi.throws == [0, 3, 1] and ishi.has_meta("plop"), "ishikiri: round 0 (plop), big 3, round 1 -> %s" % str(ishi.throws))
	check(GameState.ishikiri_result == &"lose", "ishikiri: best 3 loses")
	ishi.queue_free()
	GameState.flags = keep_ishi
	GameState.ishikiri_best = 7
	GameState.ishikiri_result = &"win"

	# カブトムシとり：気づきかけたら止まり、一度も落とさずにつかむ
	check(GameState.kabuto_drops == 0 and GameState.has_flag(&"kabuto_clean"), "kabuto: caught without dropping (%d)" % GameState.kabuto_drops)
	check(GameState.was_received(&"bug_cage"), "kabuto: bug cage after catching")
	# 押しっぱなしだと落ちる。落ちても元にもどり、最後はつかめる（カブトムシとりの画面だけで確かめる）
	var keep_kabuto := GameState.flags.duplicate()
	var greedy_k := KabutoGame.new()
	greedy_k.rng.seed = 6
	get_tree().root.add_child(greedy_k)
	await _play_kabuto(greedy_k, false)
	check(greedy_k.drops >= 1 and _kabuto_saw_fall_recover, "kabuto: moving while it is wary drops it, and it climbs back (%d)" % greedy_k.drops)
	check(GameState.kabuto_drops >= 1 and GameState.has_flag(&"kabuto_dropped"), "kabuto: still caught after dropping")
	greedy_k.queue_free()
	GameState.flags = keep_kabuto
	GameState.kabuto_drops = 0

	# 型抜き：少し削っては離して、きれいに抜く。とちゅうでタケルの型が割れる
	check(GameState.katanuki_result == &"clean" and GameState.has_flag(&"katanuki_clean"), "katanuki: carved out cleanly (%s)" % GameState.katanuki_result)
	check(_katanuki_takeru_broke_at == KatanukiGame.TAKERU_BREAK_PART, "katanuki: takeru breaks his when we reach the tail (%d)" % _katanuki_takeru_broke_at)
	# 押しつづけると割れる（型抜きの画面だけで確かめる）。そのあとタケルも割る
	var keep_kata := GameState.flags.duplicate()
	var greedy := KatanukiGame.new()
	get_tree().root.add_child(greedy)
	await _play_katanuki(greedy, false)
	check(GameState.katanuki_result == &"broken" and greedy.part <= 1, "katanuki: holding on breaks it (part %d)" % greedy.part)
	check(greedy.takeru_broken, "katanuki: takeru breaks his too when we break first")
	greedy.queue_free()
	GameState.flags = keep_kata
	GameState.katanuki_result = &"clean"

	# 飛び込み：ぴったりで跳び、タケルの一言とラムネ
	check(GameState.dive_result == &"perfect" and GameState.has_flag(&"dive_perfect"), "dive: jumped together (%s)" % GameState.dive_result)
	check(GameState.was_received(&"ramune_bottle"), "dive: ramune after the dive")
	# はやすぎ・おそいは、飛び込みの画面だけで確かめる
	var keep_dive := GameState.flags.duplicate()
	var early := DiveGame.new()
	get_tree().root.add_child(early)
	await _play_dive(early, false)
	check(GameState.dive_result == &"early", "dive: released too early -> early")
	early.queue_free()
	var late := DiveGame.new()
	get_tree().root.add_child(late)
	var n2 := 0
	while late.phase != DiveGame.Phase.WAIT and n2 < 100:
		await get_tree().process_frame
		n2 += 1
	late._hold.press()
	n2 = 0
	while not late._called and n2 < 2000:
		await get_tree().process_frame
		n2 += 1
	check(late.result == &"late" and late._called, "dive: holding too long -> takeru jumps first and calls")
	late._hold.release()
	n2 = 0
	while late.phase != DiveGame.Phase.DONE and n2 < 2000:
		await get_tree().process_frame
		n2 += 1
	check(GameState.dive_result == &"late", "dive: still jumps when released late")
	late.queue_free()
	GameState.flags = keep_dive

	# なつみの分岐とふつうのエンディングは、データの上で確かめる
	var keep_flags := GameState.flags.duplicate()
	GameState.flags.clear()
	GameState.set_flag(&"route_natsumi")
	check(GameState.current_ending().id == &"natsumi", "natsumi route -> natsumi ending")
	check(GameState.day_scene_path(GameState.get_day(9)).ends_with("day_10_natsumi.tscn"), "natsumi day 10 scene")
	check(GameState.day_items(GameState.get_day(3))[0].id == &"cicada_shell", "natsumi route keeps normal items")
	GameState.flags.clear()
	check(GameState.current_ending().id == &"default", "flags cleared -> default ending")
	check(GameState.day_scene_path(GameState.get_day(4)) == GameState.get_day(4).scene_path, "no route -> original day 5")
	check(GameState.find_item(&"river_stone").text() == "つめたくて、すべすべ。", "no route -> normal river stone text")
	check(GameState.day_time(GameState.get_day(8), 0.0) == 0.0, "no route -> normal time of day")
	GameState.set_flag(&"route_takeru")
	check(GameState.day_time(GameState.get_day(8), 0.0) >= 0.8, "takeru day 9 is at night")
	check(GameState.day_tint(GameState.get_day(5), 0.0).b > GameState.day_tint(GameState.get_day(5), 0.0).r, "takeru day 6 dawn is blue")
	GameState.flags = keep_flags
	check(GameState.summer_progress(8, 31) > GameState.summer_progress(7, 21), "summer progress increases")
	var c0 := TimeOfDay.sky_color(0.4, 0.0)
	var c1 := TimeOfDay.sky_color(0.4, 1.0)
	check(c1.s < c0.s, "sky fades late summer")
	await _wait(6.0)
	await _check_debug_jump()


## デバッグのジャンプ：ルートと日を選ぶと、そこまでの状態を作ってその日のはじめから始まる
func _check_debug_jump() -> void:
	DebugJump.apply(1, 7)
	check(GameState.has_flag(&"route_takeru") and GameState.has_flag(&"takeru_d7_jump"), "debug: takeru flags up to day 7")
	check(not GameState.holds(&"marble") and GameState.gone_note(&"marble") != "", "debug: marble given to takeru")
	check(GameState.was_received(&"ramune_bottle") and GameState.dive_result == &"perfect", "debug: dive done before day 8")
	check(GameState.is_collected(&"takeru_letter") == false and GameState.collected.size() == 7, "debug: items of days 1-7 (%d)" % GameState.collected.size())
	DebugJump.apply(2, 4)
	check(GameState.has_flag(&"route_natsumi") and not GameState.has_flag(&"route_takeru"), "debug: natsumi flags")
	DebugJump.apply(0, 9)
	check(GameState.flags.is_empty() and GameState.collected.size() == 9, "debug: default route keeps flags empty")
	# 画面から：タイトルの「デバッグ」で、タケルの8日目を選ぶ
	get_tree().change_scene_to_file("res://ui/title.tscn")
	await _wait(0.5)
	var title := get_tree().current_scene
	var dj: DebugJump = null
	for c in title.get_children():
		if c is DebugJump:
			dj = c
	check(dj != null, "debug: title has the jump screen")
	if dj == null:
		return
	title._on_debug()
	await _wait(0.5)
	check(dj.is_open, "debug: jump screen opens")
	dj._route_items[1].pressed.emit()
	dj._day_items[7].pressed.emit()
	await _wait(1.5)
	var main := get_tree().current_scene
	check(main.name == "Main", "debug: jumped into the game")
	if main.name != "Main":
		return
	var streamer: DayStreamer = main.get_node("DayStreamer")
	check(streamer.player_day_index() == 7 and GameState.current_day_index == 7, "debug: starts on day 8")
	var day8: Node = null
	for c in main.get_node("Days").get_children():
		if c is DayBase and c.day_data == GameState.get_day(7):
			day8 = c
	check(day8 != null and day8.scene_file_path.ends_with("day_08_takeru.tscn"), "debug: takeru day 8 scene")


## その日の差し替えシーンに秘密基地があるか（あればモードの名前）
func _base_in(paths: Dictionary, day: int) -> String:
	if not paths.has(day):
		return ""
	var scene: Node = (load(paths[day]) as PackedScene).instantiate()
	var b := scene.get_node_or_null("Props/Base") as SecretBase
	var out: String = SecretBase.Mode.keys()[b.mode] if b else ""
	scene.free()
	return out


## カブトムシとり：careful なら、食べているときだけ進み、気づきかけたら止まる。そうでなければ押しっぱなし
func _play_kabuto(game: KabutoGame, careful: bool) -> void:
	var n := 0
	var fell := false
	while game.phase == KabutoGame.Phase.APPROACH and n < 6000:
		n += 1
		var go := not careful or game.bug == KabutoGame.Bug.EAT
		if go and not game._hold.is_down:
			game._hold.press()
		elif not go and game._hold.is_down:
			game._hold.release()
		if game.bug == KabutoGame.Bug.FALLEN:
			fell = true
		elif fell and game.bug == KabutoGame.Bug.EAT:
			_kabuto_saw_fall_recover = true
		await get_tree().process_frame
	if game._hold.is_down:
		game._hold.release()
	game.grab()
	n = 0
	while is_instance_valid(game) and game.phase != KabutoGame.Phase.DONE and n < 2000:
		await get_tree().process_frame
		n += 1


## 石切り：お手本を見て、石を選び、held 秒押して離す（3回）
func _play_ishikiri(game: IshikiriGame, ids: Array, helds: Array) -> void:
	var n := 0
	while game.phase == IshikiriGame.Phase.DEMO or (game.phase == IshikiriGame.Phase.SHOW and game._demo):
		if game._line.text.contains("ご！"):
			_ishikiri_demo_count = game._line.text
		await get_tree().process_frame
		n += 1
		if n > 2000:
			return
	for i in ids.size():
		n = 0
		while game.phase != IshikiriGame.Phase.PICK and n < 2000:
			await get_tree().process_frame
			n += 1
		game.choose_id(ids[i])
		await get_tree().process_frame
		game._hold.press()
		game._hold.held_time = helds[i]
		game._hold.release()
		n = 0
		while game.phase in [IshikiriGame.Phase.FLY, IshikiriGame.Phase.SHOW] and n < 2000:
			if game._line.text.contains(Strings.ISHI_PLOP):
				game.set_meta("plop", true)
			await get_tree().process_frame
			n += 1
	n = 0
	while is_instance_valid(game) and game.phase != IshikiriGame.Phase.DONE and n < 2000:
		await get_tree().process_frame
		n += 1


## 型抜き：careful なら、ひびが「多め」になったら離して落ち着くのを待つ。そうでなければ押しつづける
func _play_katanuki(game: KatanukiGame, careful: bool) -> void:
	var n := 0
	while game.phase != KatanukiGame.Phase.CARVE and n < 100:
		await get_tree().process_frame
		n += 1
	n = 0
	while game.phase == KatanukiGame.Phase.CARVE and n < 6000:
		n += 1
		if not game._hold.is_down:
			if not careful or game.crack <= 0.05:
				game._hold.press()
		elif careful and game.crack >= KatanukiGame.CRACK_SOME:
			game._hold.release()
		if game.takeru_broken and _katanuki_takeru_broke_at < 0:
			_katanuki_takeru_broke_at = game.part
		await get_tree().process_frame
	n = 0
	while is_instance_valid(game) and game.phase != KatanukiGame.Phase.DONE and n < 2000:
		await get_tree().process_frame
		n += 1


## 飛び込み：押しつづけて、タケルの「の！」で離す（perfect = false なら、すぐ離す）
func _play_dive(game: DiveGame, perfect: bool) -> void:
	var n := 0
	while game.phase != DiveGame.Phase.WAIT and n < 100:
		await get_tree().process_frame
		n += 1
	game._hold.press()
	n = 0
	while perfect and not game._said_no and n < 600:
		await get_tree().process_frame
		n += 1
	game._hold.release()
	n = 0
	while is_instance_valid(game) and game.phase != DiveGame.Phase.DONE and n < 2000:
		await get_tree().process_frame
		n += 1


## 秘密基地づくり：ためしに置けない場所を押し、はめたピースを外してから、ヒントの一手どおりに最後まで埋める
func _play_base_build(hud: Hud) -> void:
	var game: BaseBuild = hud.minigame()
	var pz := GameState.base_puzzle()
	await _wait(0.6)
	check(GameState.base_cells.size() == 5, "takeru places the first piece (%d cells)" % GameState.base_cells.size())
	var touch: TouchControls = hud.get_parent().get_node("TouchControls")
	check(touch._suppressed, "top-right touch buttons hidden during the minigame")
	check(GameState.base_puzzle().width() == 15 and GameState.base_puzzle().height() == 7, "puzzle layout loads")
	check(game._line.text.contains(GameState.base_material(&"wood").takeru_line), "takeru comments on his piece")
	# 骨組みのマスには置けない
	game.select(1)
	check(not game.place_held(Vector2i(4, 0)), "piece does not fit on the frame")
	game._drop_held(false)
	# タケルのピースを外して、もとにもどす
	game.pick_up(0)
	check(GameState.base_cells.is_empty() and game._held == 0, "placed piece can be picked up")
	check(game.place_held_at(Vector2i(5, 0)), "picked piece can be placed again")
	var guard := 0
	while not GameState.base_done() and guard < 30:
		guard += 1
		var mv := game.next_move()
		if mv.is_empty():
			break
		game.select(mv[0])
		game._rot[mv[0]] = mv[1]
		game.place_held_at(mv[2])
		await _wait(0.2)
	check(GameState.base_done(), "base build: all holes filled (%d moves)" % guard)
	var n := 0
	while hud.is_in_minigame() and n < 80:
		await _wait(0.1)
		n += 1
	check(not hud.is_in_minigame(), "base build finishes when all holes are filled")
	check(not touch._suppressed, "top-right touch buttons come back after the minigame")


## 会話を最後まで送る。選択肢は最初のものを選び、宝箱から選ぶときは手もとの最初のものを選ぶ
func _finish_talk(hud: Hud, box: TreasureBox) -> void:
	var guard := 0
	while hud.is_talking() and guard < 300:
		guard += 1
		if hud.minigame() is DiveGame:
			await _play_dive(hud.minigame(), true)
		elif hud.minigame() is KabutoGame:
			await _play_kabuto(hud.minigame(), true)
		elif hud.minigame() is IshikiriGame:
			await _play_ishikiri(hud.minigame(), [&"flat", &"flat", &"flat"], [IshikiriGame.SWEET_SPOT, IshikiriGame.SWEET_SPOT, IshikiriGame.SWEET_SPOT])
		elif hud.minigame() is KatanukiGame:
			await _play_katanuki(hud.minigame(), true)
		elif hud.is_in_minigame():
			await _play_base_build(hud)
		elif box.is_open:
			await _wait(0.8)
			for sl in box._slots:
				if sl.collected:
					sl.pressed.emit()
					break
			await _wait(0.6)
		elif hud.is_choosing():
			hud.choose(0)
		else:
			TouchControls.fire_action(&"interact")
		await _wait(0.1)
