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
## タイムカプセル埋めで、掘りながら出た話の数と、星の場面を見たか
var _capsule_lines := 0
var _capsule_stars_seen := false
## 帽子を受け止める：さけび返した回数と、タケルの最後の一言
var _hat_shouts := 0
var _hat_last_line := ""
var _hat_missed_tap_ignored := false


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
	print("SMOKE ", "FAILED" if _fail else "OK")
	get_tree().quit(1 if _fail else 0)


func check(cond: bool, msg: String) -> void:
	_log.append(("ok   " if cond else "FAIL ") + msg)
	# 途中で止まったときも、どこまで進んだかわかるように、その場でも出す
	print(_log[-1])
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
	# 1日目になつみが落とす色えんぴつは、宝箱の枠に数えない（2日目に話しかけなければ、持ったまま）
	var counted := GameState.collected.keys().filter(func(id): return not GameState.is_extra(GameState.find_item(id)))
	var slots := GameState.all_items().filter(func(it): return not GameState.is_extra(it)).size()
	check(counted.size() == slots - 1, "collected %d items %s" % [counted.size(), str(GameState.collected.keys())])
	check(GameState.holds(&"blue_pencil") and not GameState.has_flag(&"route_natsumi"), "day 1: natsumi drops the blue pencil (kept without returning it)")
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

	# 帽子を受け止める：窓を開け、帽子をタップして受け止め、3回さけび返す。石切りで勝ったので、タケルの最後の一言は「つぎは まけねーぞー！」
	check(GameState.hat_caught and GameState.has_flag(&"hat_caught"), "hat: caught by tapping the hat")
	check(_hat_missed_tap_ignored, "hat: a tap away from the hat does not catch it")
	check(_hat_shouts == Strings.HAT_SHOUTS.size(), "hat: shouted back %d times" % _hat_shouts)
	check(_hat_last_line.contains(Strings.HAT_LAST_WIN), "hat: takeru's last line from the stone skipping (%s)" % _hat_last_line)
	check(HatGame.last_line() == Strings.HAT_LAST_WIN, "hat: last line for a win")
	# 帽子をタップしないと顔に当たって、ひざに乗る（帽子を受け止める画面だけで確かめる）。それでも帽子は手に入る
	var keep_hat := GameState.flags.duplicate()
	var face := HatGame.new()
	get_tree().root.add_child(face)
	await _play_hat(face, false)
	check(face.landed and not face.caught and not GameState.hat_caught and GameState.has_flag(&"hat_face"),
		"hat: not tapping -> lands on the lap")
	check(face.phase == HatGame.Phase.DONE, "hat: still finishes without tapping or shouting")
	face.queue_free()
	GameState.flags = keep_hat
	GameState.hat_caught = true

	# タイムカプセル埋め：まんなかに埋め、掘るごとに話が進み、懐中電灯を消して星を見る。地図のバツじるしは、となり
	check(GameState.capsule_spot == 1, "capsule: buried in the middle (%d)" % GameState.capsule_spot)
	check(_capsule_lines == Strings.CAPSULE_DIG_LINES.size(), "capsule: one line per scoop (%d)" % _capsule_lines)
	check(_capsule_stars_seen, "capsule: flashlight goes off and the stars show")
	check(GameState.find_item(&"capsule_map").icon != null and CapsuleGame.map_mark(1) != 1 and CapsuleGame.map_mark(0) == 1 and CapsuleGame.map_mark(2) == 1,
		"capsule: the map's X is next to the chosen spot")
	check(GameState.was_received(&"capsule_map"), "capsule: map after the stars")

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
	check(GameState.day_items(GameState.get_day(3))[0].id == &"handkerchief", "natsumi route swaps items (day 4: handkerchief)")
	check(GameState.day_scene_path(GameState.get_day(9)).ends_with("day_10_natsumi.tscn") and GameState.current_ending().id == &"natsumi",
		"natsumi low: nobody on the paddy path")
	GameState.set_flag(&"natsumi_heart_mid")
	check(GameState.current_ending().id == &"natsumi_mid" and GameState.day_items(GameState.get_day(9))[0].id == &"onigiri_wrap", "natsumi mid ending keeps the onigiri")
	GameState.set_flag(&"natsumi_heart_high")
	check(GameState.current_ending().id == &"natsumi_high" and GameState.day_scene_path(GameState.get_day(9)).ends_with("day_10_natsumi_high.tscn")
		and GameState.day_items(GameState.get_day(9))[0].id == &"natsumi_drawing", "natsumi high: day 10 with the drawing")
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
	await _natsumi_route()
	await _kamikakushi_route()
	await _check_debug_jump()


## デバッグのジャンプ：ルートと日を選ぶと、そこまでの状態を作ってその日のはじめから始まる
func _check_debug_jump() -> void:
	DebugJump.apply(1, 7)
	check(GameState.has_flag(&"route_takeru") and GameState.has_flag(&"takeru_d7_jump"), "debug: takeru flags up to day 7")
	check(not GameState.holds(&"marble") and GameState.gone_note(&"marble") != "", "debug: marble given to takeru")
	check(GameState.was_received(&"ramune_bottle") and GameState.dive_result == &"perfect", "debug: dive done before day 8")
	check(GameState.is_collected(&"takeru_letter") == false and GameState.collected.size() == 8, "debug: items of days 1-7 with the bell (%d)" % GameState.collected.size())
	DebugJump.apply(2, 4)
	check(GameState.has_flag(&"route_natsumi") and not GameState.has_flag(&"route_takeru"), "debug: natsumi flags")
	check(GameState.gone_note(&"blue_pencil") != "" and GameState.natsumi_heart == 4 + 1, "debug: natsumi pencil returned, hearts up to day 4 (%d)" % GameState.natsumi_heart)
	DebugJump.apply(2, 9)
	check(GameState.has_flag(&"natsumi_heart_high") and GameState.current_ending().id == &"natsumi_high", "debug: natsumi high reaches the high ending")
	DebugJump.apply(3, 9)
	check(GameState.current_ending().id == &"natsumi_mid", "debug: natsumi mid (%d)" % GameState.natsumi_heart)
	DebugJump.apply(4, 9)
	check(GameState.current_ending().id == &"natsumi" and GameState.find_item(&"senko_ash").text().begins_with("ぼくのが"), "debug: natsumi low")
	DebugJump.apply(0, 9)
	check(GameState.flags.keys() == [&"rusty_bell_found"] and GameState.collected.size() == 10, "debug: default route only has the bell flag %s" % str(GameState.flags.keys()))
	DebugJump.apply(5, 9)
	check(GameState.has_flag(&"route_kamikakushi") and GameState.was_received(&"fox_mask") and GameState.current_ending().id == &"kamikakushi",
		"debug: kamikakushi up to day 9")
	check(GameState.day_scene_path(GameState.get_day(9)).ends_with("day_10_kamikakushi.tscn"), "debug: kamikakushi day 10 scene")
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


## 帽子を受け止める：窓を開け（押しつづける）、catch なら近づいた帽子をタップして受け止め、3回さけび返す
func _play_hat(game: HatGame, catch: bool) -> void:
	var n := 0
	if game.phase != HatGame.Phase.LOOK:
		while is_instance_valid(game) and game.phase != HatGame.Phase.DONE and n < 2000:
			await get_tree().process_frame
			n += 1
		return
	while game.phase == HatGame.Phase.LOOK and n < 600:
		await get_tree().process_frame
		n += 1
	game._hold.press()
	n = 0
	while game.phase == HatGame.Phase.OPEN and n < 600:
		await get_tree().process_frame
		n += 1
	game._hold.release()
	n = 0
	while not game.landed and n < 600:
		if catch and game.catchable():
			# 帽子から少し外れたところをタップしても、つかめない
			game.tap_at(game._hat_pos() + Vector2(game.size.y, 0))
			_hat_missed_tap_ignored = not game.landed
			game.tap_at(game._hat_pos())
		await get_tree().process_frame
		n += 1
	n = 0
	while not game._hold.enabled and game.phase != HatGame.Phase.CURVE and n < 600:
		await get_tree().process_frame
		n += 1
	if catch:
		for i in Strings.HAT_SHOUTS.size():
			game._hold.press()
			game._hold.release()
			await get_tree().process_frame
		_hat_shouts = game.shouts
	n = 0
	while is_instance_valid(game) and game.phase != HatGame.Phase.DONE and n < 2000:
		if catch and game._last_said and _hat_last_line == "":
			_hat_last_line = game._line.text
		await get_tree().process_frame
		n += 1


## タイムカプセル埋め：まんなかを選び、話が出るのを数えながら掘って、缶を置き、土を寄せ、ならす。星の場面は見届ける
func _play_capsule(game: CapsuleGame) -> void:
	var n := 0
	if game.game_name == "capsule_stars":
		while is_instance_valid(game) and game.phase != CapsuleGame.Phase.DONE and n < 2000:
			if game.phase == CapsuleGame.Phase.STARS and game._t > 1.0:
				_capsule_stars_seen = true
			await get_tree().process_frame
			n += 1
		return
	if game.phase != CapsuleGame.Phase.PICK:
		# 前の呼び出しで遊び終えて、閉じているところ
		while is_instance_valid(game) and game.phase != CapsuleGame.Phase.DONE and n < 2000:
			await get_tree().process_frame
			n += 1
		return
	await get_tree().process_frame
	game.choose_spot(1)
	var lines := {}
	while game.phase == CapsuleGame.Phase.DIG and n < 100:
		n += 1
		game._hold.press()
		game._hold.release()
		lines[game._line.text] = true
		await get_tree().process_frame
	_capsule_lines = lines.size()
	game._hold.press()
	game._hold.release()
	game._hold.press()
	n = 0
	while game.phase == CapsuleGame.Phase.COVER and n < 600:
		await get_tree().process_frame
		n += 1
	n = 0
	while game._takeru_pats < CapsuleGame.PATS and n < 600:
		await get_tree().process_frame
		n += 1
	for i in CapsuleGame.PATS:
		game._hold.press()
		game._hold.release()
	n = 0
	while is_instance_valid(game) and game.phase != CapsuleGame.Phase.DONE and n < 2000:
		await get_tree().process_frame
		n += 1


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
		elif hud.minigame() is HatGame:
			await _play_hat(hud.minigame(), true)
		elif hud.minigame() is CapsuleGame:
			await _play_capsule(hud.minigame())
		elif hud.minigame() is KabutoGame:
			await _play_kabuto(hud.minigame(), true)
		elif hud.minigame() is IshikiriGame:
			await _play_ishikiri(hud.minigame(), [&"flat", &"flat", &"flat"], [IshikiriGame.SWEET_SPOT, IshikiriGame.SWEET_SPOT, IshikiriGame.SWEET_SPOT])
		elif hud.minigame() is KatanukiGame:
			await _play_katanuki(hud.minigame(), true)
		elif hud.minigame() is NatsumiScreen:
			await _play_natsumi(hud.minigame())
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


# --- 初恋ルート（なつみ） -------------------------------------------------------

## 1日目から歩いて、なつみに色えんぴつを返し、10日目のバスまで。会話は最初の選択肢、ミニゲームは高得点をねらう。
## 8日目だけ最初の選択肢（「また こんど」）が好みでないので、好感度は 8＋4＝12（高）
func _natsumi_route() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://world/main.tscn")
	await _wait(0.5)
	var main := get_tree().current_scene
	var hud: Hud = main.get_node("HUD")
	var box: TreasureBox = main.get_node("BoxLayer/TreasureBox")
	var streamer: DayStreamer = main.get_node("DayStreamer")
	var paths := {}
	var held_pencil_day2 := false
	Input.action_press("move_right")
	var t := 0.0
	while t < 600.0 and get_tree().current_scene == main:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not is_instance_valid(main) or not main.is_inside_tree():
			break
		var day := GameState.current_day_index
		var loaded: Dictionary = streamer._loaded
		if loaded.has(day) and not paths.has(day):
			paths[day] = (loaded[day] as Node).scene_file_path
		if day == 1 and GameState.holds(&"blue_pencil"):
			held_pencil_day2 = true
		if hud.is_talking():
			Input.action_release("move_right")
			await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		var target := hud.current_target()
		if target is Npc and not GameState.has_talked((target as Npc).npc_data.id) and not (target as Npc).npc_data.auto_talk:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.2)
			await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		if target is ItemPickup:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.3)
			TouchControls.fire_action(&"interact")
			TouchControls.fire_action(&"interact")
			Input.action_press("move_right")
	Input.action_release("move_right")
	await _wait(1.5)
	check(held_pencil_day2 and GameState.gone_note(&"blue_pencil") == "なつみに かえした", "natsumi: pencil picked on day 1 and returned on day 2")
	check(GameState.has_flag(&"route_natsumi") and not GameState.has_flag(&"route_takeru"), "natsumi: route flag")
	for i in range(2, 9):
		check(str(paths.get(i, "")).ends_with("day_%02d_natsumi.tscn" % (i + 1)), "natsumi day %d swapped: %s" % [i + 1, paths.get(i, "")])
	check(str(paths.get(9, "")).ends_with("day_10_natsumi_high.tscn"), "natsumi day 10 (high): %s" % paths.get(9, ""))
	for id in [&"natsumi_paddy", &"natsumi", &"natsumi_river", &"natsumi_rain", &"natsumi_festival", &"natsumi_festival_home",
			&"natsumi_sea", &"natsumi_movie", &"natsumi_okuribi", &"natsumi_typhoon", &"natsumi_senko"]:
		check(GameState.has_talked(id), "natsumi talks: %s" % id)
	for g in ["sketch", "kingyo", "kaigara", "senko"]:
		check(GameState.has_flag(StringName(g + "_good")), "natsumi minigame high score: %s" % g)
	check(GameState.natsumi_heart == 12, "natsumi hearts: 8 choices + 4 minigames (%d)" % GameState.natsumi_heart)
	check(GameState.has_flag(&"natsumi_promise"), "natsumi: fireworks promise on day 5")
	check(GameState.find_item(&"senko_ash").text() == "なつみのが さきに おちた。", "natsumi: her senko fell first")
	for id in NATSUMI_ITEMS:
		check(GameState.was_received(id), "natsumi gives: %s" % id)
	check(GameState.is_collected(&"cancel_notice"), "natsumi: notice picked up on day 8")
	check(_drawing_opened, "natsumi: the drawing is unrolled on the bus")
	var scene := get_tree().current_scene
	check(scene and scene.name == "Ending", "natsumi: ending reached")
	if scene and scene.name == "Ending":
		var end_box: TreasureBox = scene.get_node("TreasureBox")
		check(GameState.current_ending().id == &"natsumi_high" and end_box.header_caption.text == GameState.current_ending().title, "natsumi high ending shown")
		check(end_box._slots[-1].item.id == &"natsumi_drawing" and end_box._slots[-1].collected, "natsumi: the drawing appears last")
		check(not end_box._slots.any(func(sl): return sl.item.id == &"blue_pencil"), "natsumi: returned pencil is not in the box")
		# 1日目の鈴の枠も入れて、全部見つけた（返した色えんぴつは数えない）
		var slots := GameState.all_items().filter(func(it): return not GameState.is_extra(it)).size()
		check(end_box._found == [slots, slots] and slots == GameState.day_count() + 1, "natsumi: every treasure found %s" % str(end_box._found))
	# 線香花火：とちゅうで離すと、ぼくのが先に落ちる（線香花火の画面だけで確かめる）
	var keep := GameState.flags.duplicate()
	var keep_heart := GameState.natsumi_heart
	GameState.flags.clear()
	var senko := SenkoGame.new()
	get_tree().root.add_child(senko)
	await get_tree().process_frame
	senko._hold.press()
	var n := 0
	while senko.burn < 2.0 and n < 2000:
		await get_tree().process_frame
		n += 1
	senko._hold.release()
	n = 0
	while senko.phase != SenkoGame.Phase.DONE and n < 3000:
		await get_tree().process_frame
		n += 1
	check(senko.mine_fell and not senko.hers_fell and GameState.has_flag(&"senko_miss"), "senko: letting go drops mine first")
	check(GameState.find_item(&"senko_ash").text() == "ぼくのが さきに おちた。", "senko: ash text when mine fell first")
	senko.queue_free()
	GameState.flags = keep
	GameState.natsumi_heart = keep_heart
	GameState.add_heart(5)
	check(GameState.natsumi_heart == GameState.HEART_MAX, "hearts stop at the max")


const NATSUMI_ITEMS := [&"river_sketch", &"handkerchief", &"goldfish_bag", &"sakura_shell", &"movie_flyer", &"senko_ash", &"natsumi_drawing"]
var _drawing_opened := false


## なつみの画面：それぞれ高得点になるように遊ぶ（映画会と絵は見届ける）
func _play_natsumi(game: NatsumiScreen) -> void:
	var n := 0
	if game is SketchGame:
		var sk := game as SketchGame
		while sk.step < SketchGame.STEPS and n < 2000:
			if sk.phase == SketchGame.Phase.CHOOSE:
				sk.choose(sk.correct_index())
			await get_tree().process_frame
			n += 1
	elif game is KingyoGame:
		var kg := game as KingyoGame
		while kg.phase != KingyoGame.Phase.BROKEN and kg.phase != KingyoGame.Phase.DONE and n < 20000:
			if kg.phase == KingyoGame.Phase.PLAY and kg.fish_under_poi().size() > 0:
				kg.scoop()
			await get_tree().process_frame
			n += 1
	elif game is KaigaraGame:
		var kc := game as KaigaraGame
		while kc.phase != KaigaraGame.Phase.END and n < 20000:
			if kc.can_pick():
				kc.pick(kc.sakura_slot() if kc.sakura_slot() >= 0 else 0)
			await get_tree().process_frame
			n += 1
	elif game is SenkoGame:
		var sg := game as SenkoGame
		await get_tree().process_frame
		sg._hold.press()
		while sg.phase == SenkoGame.Phase.BURN or sg.phase == SenkoGame.Phase.GUIDE:
			await get_tree().process_frame
			n += 1
			if n > 20000:
				break
		sg._hold.release()
	elif game is KakurenboGame:
		# かくれんぼ：はしから順に調べる（隠れているのは いちばん右。2回はずすと鈴のヒント）
		var kk := game as KakurenboGame
		kk.hiding = Strings.KAKURENBO_SPOTS.size() - 1
		for i in Strings.KAKURENBO_SPOTS.size():
			kk.check_spot(i)
			if kk.tries == KakurenboGame.MISS_HINT:
				_kk["hint"] = kk._hint_t >= 0.0
			await _wait(0.2)
		_kk["kakurenbo_tries"] = kk.tries
	elif game is YomiseGame:
		# 物々交換：まずわざとちがう店を選んで断られ、そのあと順に交換する
		var yg := game as YomiseGame
		yg.trade((yg.good_slot() + 1) % yg.order.size())
		while yg.phase == YomiseGame.Phase.TRADE and n < 100:
			yg.trade(yg.good_slot())
			await _wait(0.1)
			n += 1
		_kk["yomise"] = [yg.held, yg.trades, yg.refusals]
	elif game is SuzuMichiGame:
		# 鈴の音で道探し：光がゆれたほうへ。1か所目だけ、わざと反対へ行ってもどされる
		var sm := game as SuzuMichiGame
		var missed := false
		while sm.phase != SuzuMichiGame.Phase.END and n < 20000:
			if sm.phase == SuzuMichiGame.Phase.LISTEN and sm.heard_side() >= 0:
				if not missed:
					missed = true
					sm.choose(1 - sm.heard_side())
				else:
					sm.choose(sm.heard_side())
			await get_tree().process_frame
			n += 1
		_kk["suzu_michi"] = [sm.fork, sm.wrong]
	elif game is OnigokkoGame:
		# 鬼ごっこ：押しつづけて追いつき、そのあとは押しつづけて逃げる（最後はつかまる）
		var og := game as OnigokkoGame
		while og.phase != OnigokkoGame.Phase.END and n < 20000:
			if og.phase in [OnigokkoGame.Phase.CHASE, OnigokkoGame.Phase.FLEE] and not og.hold().is_down:
				og.hold().press()
			if og.phase == OnigokkoGame.Phase.FLEE:
				_kk["oni_swapped"] = true
			await get_tree().process_frame
			n += 1
		_kk["oni_end"] = og.phase == OnigokkoGame.Phase.END
	elif game is SuzuFuru:
		# 鈴を振る：いちどめだけ鳴る。2回目は鳴らない。とじられるまで待って、とじる
		var sf := game as SuzuFuru
		sf.shake()
		await get_tree().process_frame
		sf.shake()
		_kk["bell"] = [sf.rang, sf.shakes]
		while not sf.can_close() and n < 2000:
			await get_tree().process_frame
			n += 1
		sf.shake()
	elif game is DrawingReveal:
		var dr := game as DrawingReveal
		while not dr.is_open() and n < 2000:
			await get_tree().process_frame
			n += 1
		_drawing_opened = dr.is_open()
		var ev := InputEventAction.new()
		ev.action = &"ui_accept"
		ev.pressed = true
		Input.parse_input_event(ev)
	n = 0
	while is_instance_valid(game) and not game.done and n < 4000:
		await get_tree().process_frame
		n += 1
	while is_instance_valid(game) and game.is_inside_tree() and n < 6000:
		await get_tree().process_frame
		n += 1


# --- 神隠しルート（お面の子） -----------------------------------------------------

## ミニゲームなどの記録（_play_natsumi が入れる）
var _kk := {}


## 1日目から歩いて、祠のわきの鈴を拾い、4日目に神社でお面の子と遊ぶ（なつみ・タケルには話しかけない）。
## 7日目に送り火の煙をくぐると日付が「？？」になり、8・9日目は「？？」のまま色が抜ける。
## 10日目は送り火の夜の神社で目覚め、日付が 8/31 までめくれて、バスで鈴が一度だけ鳴る
func _kamikakushi_route() -> void:
	GameState.reset()
	_kk.clear()
	get_tree().change_scene_to_file("res://world/main.tscn")
	await _wait(0.5)
	var main := get_tree().current_scene
	var hud: Hud = main.get_node("HUD")
	var box: TreasureBox = main.get_node("BoxLayer/TreasureBox")
	var streamer: DayStreamer = main.get_node("DayStreamer")
	var tod: TimeOfDay = main.get_node("TimeOfDay")
	var player: Player = main.get_node("Player")
	var paths := {}
	var cards := {}
	var max_ow := {}
	var bell_text_d1 := ""
	var d10_start_time := -1.0
	var d10_after_time := -1.0
	var d7_card_before := ""
	Input.action_press("move_right")
	var t := 0.0
	while t < 600.0 and get_tree().current_scene == main:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not is_instance_valid(main) or not main.is_inside_tree():
			break
		var day := GameState.current_day_index
		var loaded: Dictionary = streamer._loaded
		if loaded.has(day) and not paths.has(day):
			paths[day] = (loaded[day] as Node).scene_file_path
		# 日の切り替わりが終わって、札がめくれたあとの日付
		if paths.has(day) and not cards.has(day) and not Transition.is_busy():
			cards[day] = hud.card_text()
		if not Transition.is_busy():
			max_ow[day] = maxf(max_ow.get(day, 0.0), tod.otherworld)
		if day == 0 and GameState.is_collected(&"rusty_bell") and bell_text_d1 == "":
			bell_text_d1 = GameState.find_item(&"rusty_bell").text()
		if day == 6 and d7_card_before == "" and not Transition.is_busy():
			d7_card_before = hud.card_text()
		if day == 6:
			cards["d7_end"] = hud.card_text()
		if day == 9:
			var L := GameState.DAY_LENGTH_PX
			var p := (player.global_position.x - 9 * L) / L
			if d10_start_time < 0.0 and p > 0.1:
				d10_start_time = GameState.day_time(GameState.get_day(9), p)
			if p > 0.5:
				d10_after_time = GameState.day_time(GameState.get_day(9), p)
				cards["d10_after"] = hud.card_text()
		if hud.is_talking():
			Input.action_release("move_right")
			await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		var target := hud.current_target()
		if target is Npc and not GameState.has_talked((target as Npc).npc_data.id) and not (target as Npc).npc_data.auto_talk \
				and not (target as Npc).npc_data.id in [&"natsumi", &"takeru_river"]:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.2)
			await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		if target is ItemPickup:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.3)
			TouchControls.fire_action(&"interact")
			TouchControls.fire_action(&"interact")
			Input.action_press("move_right")
	Input.action_release("move_right")
	await _wait(1.5)
	check(bell_text_d1 == "ふっても ならない。", "kamikakushi: the bell does not ring on day 1 (%s)" % bell_text_d1)
	check(GameState.has_flag(&"route_kamikakushi") and not GameState.has_flag(&"route_takeru") and not GameState.has_flag(&"route_natsumi"),
		"kamikakushi: route flag %s" % str(GameState.flags.keys()))
	check(GameState.find_item(&"rusty_bell").text() == "ときどき、かってに なる。", "kamikakushi: the bell text changes after day 4")
	check(GameState.has_talked(&"grandpa_bell"), "kamikakushi: grandpa notices the bell on day 3")
	for i in range(3, 10):
		check(str(paths.get(i, "")).ends_with("day_%02d_kamikakushi.tscn" % (i + 1)), "kamikakushi day %d swapped: %s" % [i + 1, paths.get(i, "")])
	for id in [&"fox_rain", &"fox_festival", &"fox_market", &"fox_market_bye", &"fox_mukaebi", &"fox_hilltop", &"fox_okuribi", &"fox_gray", &"fox_shrine", &"grandpa_farewell_kk"]:
		check(GameState.has_talked(id), "kamikakushi talks: %s" % id)
	for id in [&"yomise_ame", &"fox_mask"]:
		check(GameState.was_received(id), "kamikakushi: received %s" % id)
	for id in [&"ogara_ember", &"blue_hozuki", &"gray_sunflower", &"onigiri_wrap"]:
		check(GameState.is_collected(id), "kamikakushi: picked %s" % id)
	check(_kk.get("hint", false) and _kk.get("kakurenbo_tries", 0) >= 1, "kakurenbo: found him (bell hint after misses) %s" % str(_kk))
	check(_kk.get("yomise", []) == [YomiseGame.GOAL, 3, 1], "yomise: refused once, 3 trades to the candy %s" % str(_kk.get("yomise")))
	check(_kk.get("suzu_michi", []) == [SuzuMichiGame.FORKS, 1], "suzu michi: through the forest, sent back once %s" % str(_kk.get("suzu_michi")))
	check(_kk.get("oni_swapped", false) and _kk.get("oni_end", false), "onigokko: caught him, then got caught")
	check(_kk.get("bell", []) == [true, 2], "bus: the bell rings only once %s" % str(_kk.get("bell")))
	var unknown := Strings.DATE_MONTH % Strings.DATE_UNKNOWN + " " + Strings.DATE_DAY % Strings.DATE_UNKNOWN
	check(not d7_card_before.contains(Strings.DATE_UNKNOWN) and cards.get("d7_end", "") == unknown,
		"day 7: the date turns to ？？ beyond the smoke (%s -> %s)" % [d7_card_before, cards.get("d7_end", "")])
	check(cards.get(7, "") == unknown and cards.get(8, "") == unknown, "days 8-9: date stays ？？ (%s / %s)" % [cards.get(7, ""), cards.get(8, "")])
	check(max_ow.get(7, 0.0) > 0.9 and max_ow.get(8, 0.0) > 0.9 and max_ow.get(3, 0.0) == 0.0, "otherworld: colors fade on days 8-9 only %s" % str(max_ow))
	check(max_ow.get(4, 0.0) > 0.3 and max_ow.get(4, 0.0) < 0.9, "day 5: the night market is faintly otherworldly (%.2f)" % max_ow.get(4, 0.0))
	check(cards.get(9, "").ends_with("16") and cards.get("d10_after", "").ends_with("31"), "day 10: wakes on 8/16, flips to 8/31 (%s -> %s)" % [cards.get(9, ""), cards.get("d10_after", "")])
	check(d10_start_time > 0.9 and d10_after_time >= 0.0 and d10_after_time < 0.3, "day 10: night at the shrine, then morning (%.2f -> %.2f)" % [d10_start_time, d10_after_time])
	check(TimeSkip.dates_between(Vector2i(8, 16), Vector2i(8, 31)).size() == 16, "time skip riffles 8/16..8/31")
	var scene := get_tree().current_scene
	check(scene and scene.name == "Ending", "kamikakushi: ending reached")
	if scene and scene.name == "Ending":
		var end_box: TreasureBox = scene.get_node("TreasureBox")
		check(GameState.current_ending().id == &"kamikakushi" and end_box.header_caption.text == GameState.current_ending().title, "kamikakushi ending shown")
		var ids := end_box._slots.map(func(sl): return sl.item.id)
		check(ids.has(&"fox_mask") and ids.has(&"gray_sunflower") and ids.has(&"rusty_bell"), "kamikakushi: otherworld items stay in the box")
		check(GameState.item_date(GameState.get_day(7)) == [Strings.DATE_UNKNOWN, Strings.DATE_UNKNOWN] and GameState.item_date(GameState.get_day(9))[1] == "31",
			"box: days 8-9 slots are dated ？？")
	# 4日目に「かえる」を選ぶと、ルートは立たない（データの上で）。親友・初恋ルートでは神社の場面にならない
	var keep := GameState.flags.duplicate()
	GameState.flags.clear()
	GameState.set_flag(&"rusty_bell_found")
	check(GameState.day_scene_path(GameState.get_day(3)).ends_with("day_04_kamikakushi.tscn") and GameState.day_scene_path(GameState.get_day(4)) == GameState.get_day(4).scene_path,
		"with the bell and no route: shrine on day 4, normal day 5")
	check(GameState.current_ending().id == &"default", "bell but went home -> default ending")
	GameState.set_flag(&"route_takeru")
	check(GameState.day_scene_path(GameState.get_day(3)).ends_with("day_04_takeru.tscn"), "takeru route wins over the bell")
	GameState.flags = keep
