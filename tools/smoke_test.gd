extends Node
## 自動の動作確認。godot --headless res://tools/smoke_test.tscn で実行する。
## タイトル → 本編を右へ歩き続け、日付の進み・読み込み日数・アイテム取得・エンディングを確かめる。

var _log: Array[String] = []
var _fail := false
## タイムカプセル埋めで、掘りながら出た話の数と、星の場面を見たか
var _capsule_lines := 0
var _capsule_stars_seen := false
## 帽子を受け止める：さけび返した回数と、タケルの最後の一言
var _hat_shouts := 0
var _hat_last_line := ""
var _hat_missed_tap_ignored := false
## 会話で出たせりふ（_finish_talk が入れる）
var _seen_lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# このノードがシーン切り替えで消えないよう、ダミーを current_scene にする
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 60
	# 見たエンディングの記録は、ふだんの記録を消さないよう別のファイルに
	EndingRecord.path = EPI_RECORD
	DirAccess.remove_absolute(EPI_RECORD)
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

	# バス停で待っている祖父母が、向こうから声をかけてくる（全ルート共通）。聞きおえて、祠のわきの鈴を拾ってから走る
	var hud0: Hud = main.get_node("HUD")
	var box0: TreasureBox = main.get_node("BoxLayer/TreasureBox")
	Input.action_press("move_right")
	var guard0 := 0
	while not (GameState.has_talked(&"grandma_arrive") and GameState.has_talked(&"grandpa") and GameState.is_collected(&"rusty_bell")) and guard0 < 900:
		await get_tree().physics_frame
		guard0 += 1
		if hud0.is_talking():
			Input.action_release("move_right")
			await _finish_talk(hud0, box0)
			Input.action_press("move_right")
		elif hud0.current_target() is ItemPickup:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.3)
			TouchControls.fire_action(&"interact")
			TouchControls.fire_action(&"interact")
			Input.action_press("move_right")
	Input.action_release("move_right")
	guard0 = 0
	while hud0.is_message_open() and guard0 < 30:
		TouchControls.fire_action(&"interact")
		await _wait(0.2)
		guard0 += 1
	await _wait(1.5)
	check(GameState.has_talked(&"grandma_arrive") and GameState.has_talked(&"grandpa"), "day 1: grandparents wait at the bus stop")
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
		if target is Npc and not (target as Npc).get_parent() is Cameo and not GameState.has_talked((target as Npc).npc_data.id) \
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
	# エンディングの宝箱：拾わずに通り過ぎた8日目の置き手紙は影のまま、ビー玉は「タケルに あげた」のまま
	var end_scene := get_tree().current_scene
	if end_scene and end_scene.name == "Ending":
		var eb: TreasureBox = end_scene.get_node("TreasureBox")
		var ghost: Array = eb._slots.filter(func(sl): return sl.item.id == skipped.id)
		check(ghost.size() == 1 and ghost[0].missed and ghost[0].theme_type_variation == &"SlotMissed",
			"ending box: the skipped day 8 item stays a shadow (%s)" % skipped.id)
		check(TreasureBox.missed_hint(skipped) == "8/20　ひみつきちの どこか", "ending box: shadow hint %s" % TreasureBox.missed_hint(skipped))
		var marble_slot: Array = eb._slots.filter(func(sl): return sl.item.id == &"marble")
		check(marble_slot.size() == 1 and not marble_slot[0].missed and marble_slot[0].note == "タケルに あげた", "ending box: the marble slot keeps タケルに あげた")
		check(eb._slots.filter(func(sl): return sl.missed).size() == 1, "ending box: only the one skipped item is a shadow")
	check(GameState.holds(&"river_stone") and GameState.was_received(&"river_stone"), "river stone received from takeru")
	check(GameState.find_item(&"river_stone").text().begins_with("タケルがくれた"), "river stone text changes on the route")
	# ミニゲームの結果：親友ルートはどれも「よくできた」をねらったので、アイテムの一言が よくできた のほうになる
	for pair in [[&"ishikiri", &"river_stone", "タケルがくれた。つめたくて、すべすべ。%dかい はねた。" % GameState.game_value(&"ishikiri")],
			[&"katanuki", &"broken_katanuki", "タケルのぶん。ひよこが まっぷたつ。ぼくのは きれいに ぬけた。"],
			[&"kabuto", &"bug_cage", "なかで ごそごそ いってる。ツノが いちばん でかいやつ。"],
			[&"dive", &"ramune_bottle", "ふたりで のんだ。からっぽ。ぼくの しぶきの ほうが でかかった。"]]:
		check(GameState.game_grade(pair[0]) == GameState.Grade.GOOD and GameState.has_flag(StringName(String(pair[0]) + "_good"))
			and GameState.item_grade(pair[1]) == GameState.Grade.GOOD and GameState.find_item(pair[1]).text() == pair[2],
			"grade good (%s): %s" % [pair[0], GameState.find_item(pair[1]).text()])
	# 3日目：「お、きたな。」→「いしきり しょうぶな。」→ 石切り → ビー玉の選択肢
	var ishi_at := _seen_lines.find("いしきり しょうぶな。なんかい はねるか。")
	var give_at := _seen_lines.find("……これ、すげえ きれいじゃん。")
	check(_seen_lines.find("お、きたな。") >= 0 and _seen_lines.find("お、きたな。") < ishi_at and ishi_at < give_at,
		"day 3: stone skipping comes before the marble choice (%d < %d)" % [ishi_at, give_at])
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
	var bridge_npc: NpcData = load("res://data/npcs/natsumi_bridge.tres")
	check(not GameState.has_flag(&"natsumi_declined") and not FlagCondition.met(bridge_npc.appear_if), "pencil not returned -> no natsumi on the day 3 bridge")
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

	# 石切り：よくできた（7回以上）。跳ねた回数はアイテムの一言になる
	check(GameState.ishikiri_best >= IshikiriGame.GOOD_SKIPS and GameState.ishikiri_result == &"win" and GameState.has_flag(&"ishikiri_win"),
		"ishikiri: good throw beats takeru (%d)" % GameState.ishikiri_best)
	check(GameState.game_value(&"ishikiri") == GameState.ishikiri_best, "ishikiri: skip count recorded (%d)" % GameState.game_value(&"ishikiri"))
	var stone: ItemData = GameState.find_item(&"river_stone")
	check(stone == null or not stone.text().contains("%d"), "ishikiri: item text has the count")
	check(IshikiriGame.result_for(5) == &"draw" and IshikiriGame.result_for(4) == &"lose", "ishikiri: draw at 5, lose at 4")

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

	# カブトムシとり・型抜き・飛び込み：よくできたで遊んだ
	check(GameState.has_flag(&"kabuto_clean"), "kabuto: big male caught")
	check(GameState.was_received(&"bug_cage"), "kabuto: bug cage after catching")
	check(GameState.katanuki_result == &"clean" and GameState.has_flag(&"katanuki_clean"), "katanuki: carved out cleanly (%s)" % GameState.katanuki_result)
	check(GameState.dive_result == &"perfect" and GameState.has_flag(&"dive_perfect"), "dive: big splash (%s)" % GameState.dive_result)
	check(GameState.was_received(&"ramune_bottle"), "dive: ramune after the dive")


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
	check(GameState.day_time(GameState.get_day(8), 0.0) >= 0.85, "no route -> normal day 9 is at night (the last night with grandpa)")
	check(GameState.day_time(GameState.get_day(3), 0.0) == 0.0 and GameState.day_time(GameState.get_day(3), 1.0) == 1.0, "no route -> day 4 has no time keys (morning to night)")
	check(is_equal_approx(GameState.day_time(GameState.get_day(4), 0.0), TimeKeys.EVENING) and is_equal_approx(GameState.day_time(GameState.get_day(4), 1.0), 1.0),
		"no route -> day 5 starts in the evening (time keys)")
	check(is_equal_approx(GameState.day_time(GameState.get_day(9), 1.0), 0.15), "no route -> day 10 ends in the morning")
	GameState.set_flag(&"route_takeru")
	check(GameState.day_time(GameState.get_day(8), 0.0) >= 0.8, "takeru day 9 is at night")
	var dawn := TimeOfDay.sample_light(GameState.day_time(GameState.get_day(5), 0.0))
	check(is_equal_approx(GameState.day_time(GameState.get_day(5), 0.0), TimeKeys.DAWN) and dawn.b > dawn.r and dawn.v < 0.9, "takeru day 6 starts at dawn (dark blue)")
	check(is_equal_approx(GameState.day_time(GameState.get_day(5), 0.6), 0.0) and is_equal_approx(GameState.day_time(GameState.get_day(5), 1.0), TimeKeys.NOON),
		"takeru day 6: dawn -> morning at 0.6 -> noon")
	GameState.flags = keep_flags
	# 時間帯のキー：補間、同じ x の2つで時間が飛ぶ、並び順
	var jump: Array[Vector2] = [Vector2(0, 0.9), Vector2(0.15, 0.9), Vector2(0.15, 0.0), Vector2(1, 0.15)]
	check(is_equal_approx(TimeKeys.sample(jump, 0.1), 0.9) and is_equal_approx(TimeKeys.sample(jump, 0.15), 0.0)
		and is_equal_approx(TimeKeys.sample(jump, 1.0), 0.15) and TimeKeys.sample(jump, 0.5) > 0.0, "time keys: jump at the same x")
	var empty: Array[Vector2] = []
	check(is_equal_approx(TimeKeys.sample(empty, 0.5), 0.5), "time keys: none -> 0..1")
	check(TimeKeys.is_sorted(jump) and not TimeKeys.is_sorted([Vector2(0.5, 0), Vector2(0.2, 1)] as Array[Vector2]), "time keys: order check")
	for di in GameState.day_count():
		var dd := GameState.get_day(di)
		var all_keys: Array = [dd.time_keys]
		for v in dd.variants:
			all_keys.append(v.time_keys)
		for k in all_keys:
			check(TimeKeys.is_sorted(k), "day %d time keys sorted %s" % [di + 1, str(k)])
	check(GameState.summer_progress(8, 31) > GameState.summer_progress(7, 21), "summer progress increases")
	var c0 := TimeOfDay.sky_color(0.4, 0.0)
	var c1 := TimeOfDay.sky_color(0.4, 1.0)
	check(c1.s < c0.s, "sky fades late summer")
	await _wait(6.0)
	_check_engawa_data()
	_check_engawa_takeru()
	await _check_missed()
	_engawa_seen.clear()
	await _natsumi_route()
	_check_engawa_natsumi()
	_engawa_seen.clear()
	await _kamikakushi_route()
	_check_engawa_kamikakushi()
	_engawa_seen.clear()
	await _normal_route()
	_check_engawa_normal()
	await _natsumi_declined_route("takeru")
	await _natsumi_declined_route("bell")
	await _check_debug_jump()
	await _check_grades()
	await _check_cameos()
	await _check_epilogue()
	await _check_minigames()


# --- ミニゲーム（共通の土台）-------------------------------------------------------

## 作り直したミニゲーム（共通の土台 MinigameBase）
const MINI_NAMES := ["ishikiri", "katanuki", "kabuto", "dive", "sketch", "kingyo", "kaigara", "senko",
	"kakurenbo", "yomise", "suzu_michi", "onigokko", "sentaku", "shoryouma", "kakurenbo_jiji", "seiza"]
## ルートを通すとき「ふつう」で遊ぶミニゲーム（せりふ・一言の差分を両方確かめるため）。ほかは「よくできた」をねらう
const ROUTE_NORMAL_GAMES := ["kakurenbo", "yomise", "suzu_michi", "kakurenbo_jiji", "seiza"]
## ミニゲームの記録（_play_mini が入れる）：名前 -> [ふつう／よくできた, 遊んだ秒数]
var _mini := {}


## ミニゲームを、キーボードだけ（touch = false）かタッチだけで、最後まで遊ぶ。good：よくできたをねらう。
## 始める前の説明は決定（タップ）で閉じ、遊んでいるあいだは game.bot() の入力を送り、おわったら「つぎへ」
func _play_mini(game: MinigameBase, good: bool, touch: bool, retry := false) -> void:
	var played := 0.0
	var g := 0
	var retried := false
	while is_instance_valid(game) and not game.done and g < 6000:
		g += 1
		await get_tree().process_frame
		if not is_instance_valid(game):
			break
		match game.state:
			MinigameBase.State.INTRO:
				if touch:
					await _touch(_to_screen(game.center_tap()))
				else:
					await _key(KEY_SPACE)
			MinigameBase.State.PLAY:
				played += get_process_delta_time()
				var b: Dictionary = game.bot(good)
				if b.is_empty():
					continue
				if touch:
					if b.get("key") == KEY_LEFT and game.arrows and not b.has("tap_only"):
						await _touch(_to_screen(game.frame._left.get_global_rect().get_center()))
					elif b.get("key") == KEY_RIGHT and game.arrows and not b.has("tap_only"):
						await _touch(_to_screen(game.frame._right.get_global_rect().get_center()))
					else:
						await _touch(_to_screen(b["tap"]))
				else:
					await _key(b["key"])
				await get_tree().process_frame
			MinigameBase.State.RESULT:
				await _wait(0.3)
				var items := game.frame.result_items()
				if items.size() < 2:
					continue
				var pick: Control = items[1] if retry and not retried else items[0]
				retried = retried or (retry and pick == items[1])
				if touch:
					await _touch(_to_screen(pick.get_global_rect().get_center()))
				else:
					if pick == items[1]:
						await _key(KEY_RIGHT)
					await _key(KEY_ENTER)
	_mini[game.game_name] = [game.grade, played]


func _check_minigames() -> void:
	# 前の確かめ（タイトル画面など）が決定キーを取らないよう、シーンを外してから遊ぶ
	get_tree().unload_current_scene()
	get_tree().paused = false
	await get_tree().process_frame
	var keep_scale := Engine.time_scale
	Engine.time_scale = 4.0
	for n in MINI_NAMES:
		for run in [[true, false], [false, true]]:
			var good: bool = run[0]
			var touch: bool = run[1]
			var tag := "minigame %s (%s, %s): " % [n, "touch" if touch else "keyboard", "good" if good else "normal"]
			InputMode._apply(touch, not touch)
			var game: MinigameBase = Hud.MINIGAMES[n].new()
			game.game_name = n
			get_tree().root.add_child(game)
			await get_tree().process_frame
			check(game.state == MinigameBase.State.INTRO and game.intro_text != "", tag + "starts with a one-line intro")
			if touch:
				# 「もどる」と左右のボタンが画面の中にあり、72px 以上で、はしから 40px 以上はなれている
				var vr := get_viewport().get_visible_rect().grow(-UiTokens.SCREEN_MARGIN + 1)
				var btns: Array[Control] = [game.frame._quit]
				if game.arrows:
					btns.append_array([game.frame._left, game.frame._right] as Array[Control])
				await get_tree().process_frame
				game.frame.set_arrows(game.arrows)
				var inside := btns.all(func(b): return b.visible and vr.encloses(b.get_global_rect()) and b.size.x >= UiTokens.TOUCH_MIN and b.size.y >= UiTokens.TOUCH_MIN)
				check(inside, tag + "touch buttons on screen %s" % str(btns.map(func(b): return b.get_global_rect())))
				game.frame.set_arrows(false)
			await _play_mini(game, good, touch)
			var rec: Array = _mini.get(n, [-1, 0.0])
			check(rec[0] == (GameState.Grade.GOOD if good else GameState.Grade.NORMAL), tag + "grade %d" % rec[0])
			check(rec[1] > 0.5 and rec[1] <= 60.0, tag + "ends within a minute (%.1fs)" % rec[1])
			if is_instance_valid(game):
				game.queue_free()
			await get_tree().process_frame
		# やめる（Esc）と「ふつう」。もういちど遊んでも、記録は最初の回
		InputMode._apply(false, true)
		var q: MinigameBase = Hud.MINIGAMES[n].new()
		q.game_name = n
		get_tree().root.add_child(q)
		await _wait(0.3)
		await _key(KEY_SPACE)
		await _wait(0.3)
		await _key(KEY_ESCAPE)
		await _until(func(): return q.done, 3.0)
		check(q.done and q.quit_by_player and q.grade == GameState.Grade.NORMAL, "minigame %s: Esc quits as ふつう" % n)
		q.queue_free()
		# タッチ：「もどる」をタップしてやめる
		InputMode._apply(true, false)
		var qt: MinigameBase = Hud.MINIGAMES[n].new()
		qt.game_name = n
		get_tree().root.add_child(qt)
		await _wait(0.3)
		await _touch(_to_screen(qt.center_tap()))
		await _wait(0.3)
		await _touch(_to_screen(qt.frame._quit.get_global_rect().get_center()))
		await _until(func(): return qt.done, 3.0)
		check(qt.done and qt.quit_by_player and qt.grade == GameState.Grade.NORMAL, "minigame %s: もどる (touch) quits as ふつう" % n)
		qt.queue_free()
		InputMode._apply(false, true)
		var r: MinigameBase = Hud.MINIGAMES[n].new()
		r.game_name = n
		get_tree().root.add_child(r)
		await _play_mini(r, false, false, true)
		check(r.round_count == 2 and r.grade == GameState.Grade.NORMAL, "minigame %s: もういちど keeps the first result (%d rounds)" % [n, r.round_count])
		if is_instance_valid(r):
			r.queue_free()
		await get_tree().process_frame
	# 会話の中でやめる：Esc で「ふつう」になり、会話はそのまま「ふつう」のせりふへ進む（進行が止まらない）
	GameState.reset()
	var qhud: Hud = load("res://ui/hud.tscn").instantiate()
	get_tree().root.add_child(qhud)
	await _wait(0.3)
	var npc: NpcData = load("res://data/npcs/grandma_laundry.tres")
	qhud.start_talk(npc, npc.lines)
	var seen: Array[String] = []
	var quit_sent := false
	var guard := 0
	while qhud.is_talking() and guard < 400:
		guard += 1
		if qhud.minigame():
			if not quit_sent:
				quit_sent = true
				await _wait(0.4)
				await _key(KEY_ESCAPE)
		elif qhud.is_message_open():
			var t: String = qhud._msg_text.text
			if seen.is_empty() or seen[-1] != t:
				seen.append(t)
			qhud.advance_message()
		await _wait(0.05)
	check(quit_sent and not qhud.is_talking() and GameState.game_grade(&"sentaku") == GameState.Grade.NORMAL
		and seen.has("ちょっと ぬれちゃったね。まあ いいさ。"), "minigame quit in a talk: ふつう, and the talk goes on %s" % str(seen))
	qhud.queue_free()
	await get_tree().process_frame
	# 秘密基地づくり：Esc でやめると、残りのすき間をタケルが埋めて、先へ進む
	var keep_cells := GameState.base_cells.duplicate()
	GameState.base_cells.clear()
	var bb: BaseBuild = Hud.MINIGAMES["base_build"].new()
	get_tree().root.add_child(bb)
	await _wait(0.6)
	await _key(KEY_SPACE)
	await _key(KEY_ESCAPE)
	var ended := [false]
	bb.finished.connect(func(): ended[0] = true)
	await _until(func(): return ended[0], 5.0)
	check(ended[0] and bb.quit_by_player and GameState.base_done(), "base build: Esc quits, takeru fills the rest (%d cells)" % GameState.base_cells.size())
	bb.queue_free()
	GameState.base_cells = keep_cells
	Engine.time_scale = keep_scale


# --- エピローグ「それから」 ----------------------------------------------------

const EPI_RECORD := "user://endings_smoke.cfg"


func _open_title() -> Node:
	get_tree().change_scene_to_file("res://ui/title.tscn")
	await _wait(0.6)
	return get_tree().current_scene


func _check_epilogue() -> void:
	# 本編の4ルート（ノーマル・親友・初恋・神隠し）を通したので、4つとも記録されている
	check(EndingRecord.seen_count() == 4 and EndingRecord.all_seen(), "ending record: all 4 endings seen after the route runs (%d)" % EndingRecord.seen_count())
	var cf := ConfigFile.new()
	check(cf.load(EPI_RECORD) == OK and cf.get_section_keys(EndingRecord.SECTION).size() == 4, "ending record: saved to user:// as 4 booleans")
	# 3つ以下では「それから」が出ない。印の数は見た数
	DirAccess.remove_absolute(EPI_RECORD)
	for n in 5:
		if n > 0:
			EndingRecord.mark(EndingRecord.ROUTES[n - 1])
		var t := await _open_title()
		var has_epi: bool = t.menu_texts().has(Strings.MENU_EPILOGUE)
		check(t.marks.seen == n and has_epi == (n == 4), "title: %d endings seen -> marks %d, それから %s" % [n, t.marks.seen, has_epi])
	await _play_epilogue(false)
	await _play_epilogue(true)


## エピローグを最初から最後まで遊ぶ（touch：タッチだけ／そうでなければキーボードだけ）
func _play_epilogue(touch: bool) -> void:
	var tag := "epilogue (%s): " % ("touch" if touch else "keyboard")
	var keep_scale := Engine.time_scale
	Engine.time_scale = 3.0
	var t := await _open_title()
	var vs := get_viewport().get_visible_rect().size
	if touch:
		await _touch(_to_screen(vs / 2.0))
		await _wait(0.6)
		var item: Control = null
		for c in t._list.get_children():
			if c is MenuItem and (c as MenuItem).text == Strings.MENU_EPILOGUE:
				item = c
		await _touch(_to_screen(item.get_global_rect().get_center()))
	else:
		await _key(KEY_ENTER)
		await _wait(0.6)
		await _key(KEY_RIGHT)
		await _key(KEY_ENTER)
	check(await _until(func(): return get_tree().current_scene and get_tree().current_scene.name == "Main", 6.0) and GameState.epilogue, tag + "それから opens the epilogue")
	var main := get_tree().current_scene
	await _wait(0.6)
	var hud: Hud = main.get_node("HUD")
	var player: Player = main.get_node("Player")
	var day: DayBase = null
	for c in main.get_node("Days").get_children():
		if c is DayBase:
			day = c
	check(GameState.day_count() == 1 and day and day.scene_file_path == "res://days/epilogue.tscn" and day.get_node("Items").get_child_count() == 0,
		tag + "one day, no items")
	check(hud.card_text().contains("31") and GameState.summer_progress_of(GameState.current_day()) == 1.0, tag + "date card 8/31 (%s), summer at the end" % hud.card_text())
	check(is_equal_approx(GameState.day_time(GameState.current_day(), 0.0), 0.45) and is_equal_approx(GameState.day_time(GameState.current_day(), 1.0), 0.85), tag + "time keys 0.45 -> 0.85")
	check(player.body_scale > 1.0, tag + "the grown-up is taller")
	# 右へ歩きつづける。会話は決定（タップ）で送り、神社の二人は決定（タップ）で早送り
	var hold := InputEventScreenTouch.new()
	hold.index = 0
	hold.position = _to_screen(Vector2(vs.x * 0.8, vs.y * 0.75))
	hold.pressed = true
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	Input.parse_input_event(hold if touch else right)
	var seen: Array[String] = []
	var kids_skipped := false
	var g := 0.0
	var kids: Node2D = day.get_node("Props/Kids")
	var bell := false
	var kids_state := [false, 1.0, 1.0]
	while is_instance_valid(main) and get_tree().current_scene == main and g < 90.0:
		await _wait(0.12)
		g += 0.12
		if not is_instance_valid(kids) or not is_instance_valid(hud):
			break
		bell = day.get("bell_rang")
		kids_state = [kids.done, kids.speed, kids.modulate.a]
		if kids.started and not kids.done and not kids_skipped:
			kids_skipped = true
			if touch:
				var tap := InputEventScreenTouch.new()
				tap.index = 1
				tap.position = _to_screen(Vector2(vs.x * 0.75, vs.y * 0.4))
				tap.pressed = true
				Input.parse_input_event(tap)
				await get_tree().process_frame
				tap.pressed = false
				Input.parse_input_event(tap)
			else:
				await _key(KEY_ENTER)
		if hud.is_talking() and hud.is_message_open():
			var line: String = hud._msg_text.text
			if seen.is_empty() or seen[-1] != line:
				seen.append(line)
			if touch:
				# 歩く指を離してから、一言パネルをタップ（1本目の指のタップだけがクリックになる）。そのあと、また押しつづける
				hold.pressed = false
				Input.parse_input_event(hold)
				await _touch(_to_screen(hud._msg.get_global_rect().get_center()))
				hold.pressed = true
				Input.parse_input_event(hold)
			else:
				await _key(KEY_ENTER)
	hold.pressed = false
	right.pressed = false
	Input.parse_input_event(hold if touch else right)
	check(bell, tag + "the bell rang once at the shrine by the bus stop")
	check(kids_state[0] and kids_state[1] == UiTokens.SKIP_SPEED and kids_state[2] < 0.01, tag + "the two children ran up and faded (fast-forwarded)")
	check(seen.has("……おそいぞ、とかいもん。"), tag + "the man at the base: ……おそいぞ、とかいもん。")
	var a := seen.find("おかえり。")
	check(a >= 0 and seen.find("……きょうは、なにしたの？") > a and seen.find("……ただいま") > seen.find("……きょうは、なにしたの？"), tag + "grandma, then ……ただいま %s" % str(seen))
	check(get_tree().current_scene and get_tree().current_scene.name == "Ending", tag + "then the treasure box")
	var end_scene := get_tree().current_scene
	if end_scene == null or end_scene.name != "Ending":
		Engine.time_scale = keep_scale
		return
	var box: TreasureBox = end_scene.get_node("TreasureBox")
	await _until(func(): return box.is_open and box._tween == null, 40.0)
	await _wait(0.5)
	var every := GameState.every_item()
	check(box.header_caption.text == Strings.EPILOGUE_TITLE and box._slots.size() == every.size() and every.size() >= 30,
		tag + "final box: every route's items (%d)" % box._slots.size())
	check(box._slots.all(func(sl): return sl.collected and not sl.missed and sl.note == ""), tag + "final box: no shadows, no notes")
	check(box.page_count() > 1 and box.page_slots().size() < box._slots.size(), tag + "final box: pages (%d)" % box.page_count())
	var ids := {}
	if touch:
		for p in box.page_count():
			for sl in box.page_slots():
				ids[sl.item.id] = true
			if p < box.page_count() - 1:
				await _touch(_to_screen(box._next.get_global_rect().get_center()))
				await _wait(0.2)
		await _touch(_to_screen(box.page_slots()[0].get_global_rect().get_center()))
		await _wait(0.2)
		check(box._detail_name.text == box.page_slots()[0].item.display_name, tag + "tap a slot shows it")
		await _touch(_to_screen(box._prev.get_global_rect().get_center()))
		await _wait(0.2)
		check(box.page == box.page_count() - 2, tag + "まえ goes back a page")
	else:
		await _key(KEY_DOWN)
		for p in box.page_count():
			for sl in box.page_slots():
				ids[sl.item.id] = true
			if p < box.page_count() - 1:
				for i in box._cols:
					await _key(KEY_RIGHT)
				await _wait(0.2)
		check(box.page == box.page_count() - 1, tag + "right at the row end turns the page (%d)" % box.page)
		var f := get_viewport().gui_get_focus_owner()
		check(f is ItemSlot and box._detail_name.text == (f as ItemSlot).item.display_name, tag + "the focused slot shows its line")
		await _key(KEY_LEFT)
	check(ids.size() == every.size(), tag + "every item can be seen across the pages (%d / %d)" % [ids.size(), every.size()])
	# タイトルへ
	var back: MenuItem = end_scene._list.get_child(0)
	check(back.text == Strings.EPILOGUE_TO_TITLE, tag + "タイトルへ")
	if touch:
		await _touch(_to_screen(back.get_global_rect().get_center()))
	else:
		back.grab_focus()
		await _key(KEY_ENTER)
	check(await _until(func(): return get_tree().current_scene and get_tree().current_scene.name == "Title", 6.0) and not GameState.epilogue
		and GameState.day_count() == 10, tag + "back to the title, the main days restored")
	Engine.time_scale = keep_scale


# --- 他ルートの人物の顔出し ----------------------------------------------------

## ルート（DebugJump の番号）と日の番号 -> そこに出る顔出しの id（ルート分岐表・各ルートの「他ルートの人物の顔出し」）
const CAMEO_EXPECT := {
	[1, 4]: [&"shinyu_d4_natsumi"], [1, 5]: [&"shinyu_d5_natsumi"], [1, 7]: [&"shinyu_d7_fox"],
	[2, 5]: [&"hatsukoi_d5_takeru"], [2, 7]: [&"hatsukoi_d7_takeru", &"hatsukoi_d7_fox"],
	[5, 5]: [&"kamikakushi_d5_natsumi", &"kamikakushi_d5_takeru"], [5, 6]: [&"kamikakushi_d6_natsumi", &"kamikakushi_d6_takeru"],
	[5, 8]: [&"kamikakushi_d8_bicycle", &"kamikakushi_d8_gakuban"],
	[0, 5]: [&"normal_d5_fox", &"normal_d5_natsumi", &"normal_d5_takeru"], [0, 7]: [&"normal_d7_boxes", &"normal_d7_takeru"],
}
## 話しかけると返す一言（ほかは話しかけられない）
const CAMEO_LINES := {
	&"shinyu_d4_natsumi": "……（えを かいている）", &"shinyu_d5_natsumi": "あいつ、なつみ。え ばっか かいてる。",
	&"hatsukoi_d5_takeru": "あーっ！ われた！", &"hatsukoi_d7_takeru": "……ぐう",
	&"normal_d5_takeru": "あーっ！ われた！", &"normal_d7_takeru": "よう。",
}


func _cameo_day(main: Node, day_number: int) -> DayBase:
	for c in main.get_node("Days").get_children():
		if c is DayBase and c.day_data and c.day_data.day_number == day_number:
			return c
	return null


func _check_cameos() -> void:
	var keep_scale := Engine.time_scale
	Engine.time_scale = 1.0
	# 1〜4日目（共通の日）と10日目には、顔出しを置かない（3日目の橋の上のなつみなどと重ならない）
	for d in CameoData.all():
		check(d.day_number >= 4 and d.day_number <= 8, "cameo %s: not on a shared day or day 10 (day %d)" % [d.id, d.day_number])
	check(not CameoData.all().any(func(d): return d.day_number == 4 and d.route != &"shinyu"), "cameo: day 4 only in the takeru route (the others share day 4)")
	for key in CAMEO_EXPECT:
		var route: int = key[0]
		var day: int = key[1]
		DebugJump.apply(route, day - 1)
		get_tree().change_scene_to_file("res://world/main.tscn")
		await _wait(1.0)
		var main := get_tree().current_scene
		var hud: Hud = main.get_node("HUD")
		var dn := _cameo_day(main, day)
		if dn == null:
			check(false, "cameo: day %d scene for route %d" % [day, route])
			continue
		var shown: Array = dn.cameos().filter(func(c): return c.is_shown()).map(func(c): return String(c.data.id))
		shown.sort()
		var want_ids: Array = CAMEO_EXPECT[key].map(func(i): return String(i))
		want_ids.sort()
		check(shown == want_ids, "cameo route %d day %d: %s" % [route, day, str(shown)])
		# ほかの日・ほかのルートの顔出しは出ていない
		for other in main.get_node("Days").get_children():
			if other is DayBase and other != dn:
				for c in other.cameos():
					check(not c.is_shown() or CAMEO_EXPECT.get([route, other.day_data.day_number], []).has(c.data.id), "cameo %s hidden on route %d" % [c.data.id, route])
		for c in dn.cameos():
			if not c.is_shown():
				continue
			var want: String = CAMEO_LINES.get(c.data.id, "")
			check(c.talkable() == (want != ""), "cameo %s: talkable only with a line" % c.data.id)
			if want == "":
				continue
			# 話しかけても、フラグ・好感度・話したかどうか・ルート・エンディングは変わらない
			var before := [GameState.flags.duplicate(), GameState.natsumi_heart, GameState.talked.duplicate(), GameState.current_route(),
				GameState.current_ending().id, GameState.collected.duplicate(), GameState.game_grades.duplicate()]
			c.npc().interact(hud)
			var seen: Array[String] = []
			var g := 0
			while hud.is_talking() and g < 60:
				g += 1
				if hud.is_message_open():
					seen.append(hud._msg_text.text)
				hud.advance_message()
				await _wait(0.05)
			var after := [GameState.flags.duplicate(), GameState.natsumi_heart, GameState.talked.duplicate(), GameState.current_route(),
				GameState.current_ending().id, GameState.collected.duplicate(), GameState.game_grades.duplicate()]
			check(seen.has(want) and seen.filter(func(t): return t != want).is_empty(), "cameo %s: one line only %s" % [c.data.id, str(seen)])
			check(before == after, "cameo %s: talking changes nothing" % c.data.id)
		# お面の子：近づくと、ゆっくり消える（急に消えない）
		for c in dn.cameos():
			if c.is_shown() and c.data.kind == CameoData.Kind.GLIMPSE:
				check(not c.talkable(), "cameo %s: the fox child cannot be talked to" % c.data.id)
				var player: Node2D = main.get_node("Player")
				player.global_position.x = c.global_position.x - Cameo.VANISH_FROM + 10.0
				await _wait(0.15)
				var mid := c.modulate.a
				await _wait(UiTokens.TIME_GLIMPSE_VANISH + 0.3)
				check(c.gone and mid > 0.05 and mid < 0.99 and c.modulate.a < 0.01, "cameo %s: fades out slowly when approached (%.2f -> %.2f)" % [c.data.id, mid, c.modulate.a])
	# ノーマル5日目のお面の子は、お面を選んだあとは出ない
	DebugJump.apply(0, 4)
	GameState.set_mask(&"kitsune")
	check(not CameoData.all().filter(func(d): return d.id == &"normal_d5_fox")[0].is_shown(), "cameo: the fox child is gone after choosing a mask")
	Engine.time_scale = keep_scale


# --- ミニゲームの結果（ふつう／よくできた） ------------------------------------------

## 会話ごとに、ミニゲームの結果を ふつう と よくできた の両方で出す。
## [会話, ミニゲーム, 先に持っているもの, アイテム, ふつうの一言, よくできたの一言, ふつうのせりふ, よくできたのせりふ]
## （一言・せりふが変わらないものは ""。ミニゲームは遊ばずに、結果だけ入れて終わらせる。遊んだときの結果は、ルートの通しで確かめる）
const GRADE_CASES := [
	["takeru_river", "ishikiri", [&"marble"], &"river_stone", "タケルがくれた。つめたくて、すべすべ。", "タケルがくれた。つめたくて、すべすべ。7かい はねた。", "", ""],
	["takeru_festival", "katanuki", [], &"broken_katanuki", "タケルのぶん。ひよこが まっぷたつ。", "タケルのぶん。ひよこが まっぷたつ。ぼくのは きれいに ぬけた。", "", ""],
	["takeru_trap", "kabuto", [], &"bug_cage", "なかで ごそごそ いってる。", "なかで ごそごそ いってる。ツノが いちばん でかいやつ。", "", ""],
	["takeru_dive", "dive", [], &"ramune_bottle", "ふたりで のんだ。からっぽ。", "ふたりで のんだ。からっぽ。ぼくの しぶきの ほうが でかかった。", "", ""],
	["natsumi_river", "sketch", [], &"river_sketch", "なつみが『いいね』って いった。", "なつみが『いいね』って いった。ちょっと じまん。", "", ""],
	["natsumi_festival", "kingyo", [], &"goldfish_bag", "あかいのが 1ぴき。なまえは まだない。", "あかいのが 2ひき。なまえは まだない。", "はい、1ぴき もってきな。", "はい、2ひき もってきな。"],
	["natsumi_sea", "kaigara", [], &"sakura_shell", "なつみと はんぶんこ した。", "なつみと はんぶんこ した。いちばん ピンクの やつ。", "", ""],
	["natsumi_senko", "senko", [], &"senko_ash", "ぼくのが さきに おちた。", "なつみのが さきに おちた。", "", ""],
	["fox_rain", "kakurenbo", [&"rusty_bell"], &"", "", "", "みつかっちゃった。", "……はやいね。みつかっちゃった。"],
	["fox_market", "yomise", [], &"yomise_ame", "あおくて つめたい。たべちゃ だめって いわれた。", "あおくて つめたい。いちばん きれいなのと とりかえた。", "", ""],
	# おがらのもえさし・いろのないひまわりは、道で先に拾ってから遊ぶ
	["fox_mukaebi", "suzu_michi", [&"ogara_ember"], &"ogara_ember", "むかえびの あと。まだ すこし あったかい。", "むかえびの あと。まよわずに いけた。", "", ""],
	["fox_gray", "onigokko", [&"gray_sunflower"], &"gray_sunflower", "いろが ない。でも、さいてる。", "いろが ない。でも、さいてる。つかまえたら、わらってた。", "", ""],
	["grandma_laundry", "sentaku", [], &"", "", "", "ちょっと ぬれちゃったね。まあ いいさ。", "ぜんぶ まにあったねえ。ありがとね。"],
	["grandma_bon", "shoryouma", [], &"", "", "", "ちょっと かたむいてるけど、だいじょうぶ。", "りっぱな うまだねえ。"],
	["grandpa_hide", "kakurenbo_jiji", [], &"", "", "", "……ここだ。むかしから、ここなんだ。", "だれにも みつからなかったんだがな。"],
	["grandpa_stars", "seiza", [], &"", "", "", "", "……よく みつけたな。"],
]


func _check_grades() -> void:
	get_tree().change_scene_to_file("res://ui/title.tscn")
	await _wait(0.5)
	var hud: Hud = load("res://ui/hud.tscn").instantiate()
	get_tree().root.add_child(hud)
	var box: TreasureBox = load("res://ui/treasure_box.tscn").instantiate()
	get_tree().root.add_child(box)
	await _wait(0.3)
	var tested := {}
	for c in GRADE_CASES:
		var npc: NpcData = load("res://data/npcs/%s.tres" % c[0])
		for g in [GameState.Grade.NORMAL, GameState.Grade.GOOD]:
			var tag := "%s %s: " % [c[1], "よくできた" if g == GameState.Grade.GOOD else "ふつう"]
			GameState.reset()
			# 宝箱にそのルートのアイテムが並ぶよう、ルートのフラグを立てておく（川の石は、会話の中で立つ）
			var who := String(c[0]).get_slice("_", 0)
			if who == "takeru" and c[0] != "takeru_river":
				GameState.set_flag(&"route_takeru")
			elif who == "natsumi":
				GameState.set_flag(&"route_natsumi")
			elif who == "fox":
				GameState.set_flag(&"route_kamikakushi")
			for id in c[2]:
				GameState.collect(GameState.find_item(id))
			var heart0 := GameState.natsumi_heart
			var seen := await _talk_with_grade(hud, npc, g)
			check(GameState.game_grade(StringName(c[1])) == g and GameState.has_flag(StringName(c[1] + ("_good" if g == GameState.Grade.GOOD else "_miss"))),
				tag + "recorded")
			if c[3] != &"":
				var item := GameState.find_item(c[3])
				var want: String = c[5] if g == GameState.Grade.GOOD else c[4]
				check(GameState.is_collected(c[3]) and item.text() == want, tag + "item text %s" % item.text())
				# 宝箱（エンディングも同じ宝箱）と縁側の場面で、同じ一言
				box.open()
				await _wait(0.6)
				var slot: Array = box._slots.filter(func(sl): return sl.item.id == c[3])
				if slot.size() == 1:
					box._show_detail(slot[0])
				check(slot.size() == 1 and box._detail_text.text == want, tag + "box text %s" % box._detail_text.text)
				box.close()
				await _wait(0.5)
				check(Engawa.item_note(item) == Strings.ENGAWA_ITEM_NOTE % [item.display_name, want], tag + "engawa text %s" % Engawa.item_note(item))
			else:
				check(seen.size() > 0, tag + "talk finished")
			var line_now: String = c[7] if g == GameState.Grade.GOOD else c[6]
			var line_other: String = c[6] if g == GameState.Grade.GOOD else c[7]
			if line_now != "":
				check(seen.has(line_now), tag + "line %s" % line_now)
			if line_other != "":
				check(not seen.has(line_other), tag + "not the other line %s" % line_other)
			if GameState.NATSUMI_GAMES.has(StringName(c[1])):
				# 好感度：会話の選択肢（最初のもの）の分を引いて、よくできたら +1
				tested[c[1] + str(g)] = GameState.natsumi_heart - heart0
			if c[1] == "ishikiri":
				var a := seen.find("いしきり しょうぶな。なんかい はねるか。")
				check(a > seen.find("お、きたな。") and a < seen.find("……これ、すげえ きれいじゃん。"), tag + "stone skipping before the marble choice")
				check(GameState.gone_note(&"marble") != "" and GameState.has_flag(&"route_takeru"), tag + "marble given, route set")
	for gname in GameState.NATSUMI_GAMES:
		var gs := String(gname)
		check(tested.get(gs + str(GameState.Grade.GOOD), 0) - tested.get(gs + str(GameState.Grade.NORMAL), 0) == 1,
			"natsumi %s: よくできた gives +1 heart (%s)" % [gs, str([tested.get(gs + "0"), tested.get(gs + "1")])])
	# 石切り：ビー玉を持っていない／「わたさない」でも、石切りは遊べて、またな で帰る。もう一度話しても、石切りは くりかえさない
	GameState.reset()
	var tr: NpcData = load("res://data/npcs/takeru_river.tres")
	var seen1 := await _talk_with_grade(hud, tr, GameState.Grade.NORMAL)
	var seen2 := await _talk_with_grade(hud, tr, GameState.Grade.NORMAL)
	check(seen1.has("いしきり しょうぶな。なんかい はねるか。") and seen1.has("なんだ。まあいいや、またな。") and not GameState.is_collected(&"river_stone"),
		"ishikiri without the marble: played, then またな")
	check(not seen2.has("いしきり しょうぶな。なんかい はねるか。") and seen2.has("なんだ。まあいいや、またな。"), "ishikiri: not replayed when talking again")
	hud.queue_free()
	box.queue_free()
	await _wait(0.2)


## 会話を最後まで進める。ミニゲームは結果 g を入れてすぐ終わらせ、選択肢は最初のものを選ぶ。出たせりふを返す
func _talk_with_grade(hud: Hud, npc: NpcData, g: int) -> Array[String]:
	var seen: Array[String] = []
	hud.start_talk(npc, npc.lines)
	var guard := 0
	while hud.is_talking() and guard < 400:
		guard += 1
		var mg := hud.minigame()
		if mg:
			if not mg.has_meta("graded"):
				mg.set_meta("graded", true)
				mg.set("grade", g)
				mg.finished.emit()
		elif hud.is_choosing():
			hud.choose(0)
		elif hud.is_message_open():
			var t: String = hud._msg_text.text
			if seen.is_empty() or seen[-1] != t:
				seen.append(t)
			hud.advance_message()
		await _wait(0.05)
	return seen
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
	check(not [&"route_takeru", &"route_natsumi", &"route_kamikakushi"].any(func(f): return GameState.has_flag(f)) and GameState.collected.size() == 10,
		"debug: default route has no route flag %s" % str(GameState.flags.keys()))
	check(GameState.mask_kind == &"kitsune" and GameState.was_received(&"festival_mask") and GameState.has_flag(&"jiji_play"), "debug: default route up to day 9 (fox mask, hide and seek)")
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










## 秘密基地づくり：ためしに置けない場所を押し、はめたピースを外してから、ヒントの一手どおりに最後まで埋める
func _play_base_build(hud: Hud) -> void:
	var game: BaseBuild = hud.minigame()
	var pz := GameState.base_puzzle()
	await _wait(0.6)
	check(game.frame.intro_visible(), "base build: starts with a one-line intro")
	await _key(KEY_SPACE)
	await _wait(0.5)
	check(not game.frame.intro_visible(), "base build: Space closes the intro")
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
		if hud.is_message_open():
			_seen_lines.append(hud._msg_text.text)
		if hud.minigame() is MinigameBase:
			var mg: MinigameBase = hud.minigame()
			await _play_mini(mg, not ROUTE_NORMAL_GAMES.has(mg.game_name), false)
		elif hud.minigame() is HatGame:
			await _play_hat(hud.minigame(), true)
		elif hud.minigame() is CapsuleGame:
			await _play_capsule(hud.minigame())
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
		if target is Npc and not (target as Npc).get_parent() is Cameo and not GameState.has_talked((target as Npc).npc_data.id) and not (target as Npc).npc_data.auto_talk:
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
	for pair in [[&"river_sketch", "なつみが『いいね』って いった。ちょっと じまん。"], [&"goldfish_bag", "あかいのが 2ひき。なまえは まだない。"],
			[&"sakura_shell", "なつみと はんぶんこ した。いちばん ピンクの やつ。"]]:
		check(GameState.find_item(pair[0]).text() == pair[1], "natsumi grade good: %s" % GameState.find_item(pair[0]).text())
	check(_seen_lines.has("はい、2ひき もってきな。") and not _seen_lines.has("はい、1ぴき もってきな。"), "kingyo good: two fish in the bag")
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
	# 線香花火：戻さないでいると、ぼくのが先に落ちる（線香花火の画面だけで確かめる）
	var keep := GameState.flags.duplicate()
	var keep_heart := GameState.natsumi_heart
	var keep_grades := [GameState.game_grades.duplicate(), GameState.item_grades.duplicate()]
	GameState.flags.clear()
	var senko: SenkoGame = Hud.MINIGAMES["senko"].new()
	senko.game_name = "senko"
	get_tree().root.add_child(senko)
	await _play_mini(senko, false, false)
	# 画面だけで遊んだので、HUD のかわりに結果を記録する
	check(senko.mine_fell and not senko.hers_fell and senko.grade == GameState.Grade.NORMAL, "senko: not centering drops mine first (ふつう)")
	GameState.record_grade(&"senko", senko.grade)
	check(GameState.has_flag(&"senko_miss") and GameState.find_item(&"senko_ash").text() == "ぼくのが さきに おちた。", "senko: ash text when mine fell first")
	if is_instance_valid(senko):
		senko.queue_free()
	GameState.flags = keep
	GameState.game_grades = keep_grades[0]
	GameState.item_grades = keep_grades[1]
	GameState.natsumi_heart = keep_heart
	GameState.add_heart(5)
	check(GameState.natsumi_heart == GameState.HEART_MAX, "hearts stop at the max")


const NATSUMI_ITEMS := [&"river_sketch", &"handkerchief", &"goldfish_bag", &"sakura_shell", &"movie_flyer", &"senko_ash", &"natsumi_drawing"]
var _drawing_opened := false


## なつみの画面：それぞれ高得点になるように遊ぶ（映画会と絵は見届ける）
func _play_natsumi(game: NatsumiScreen) -> void:
	var n := 0
	if game is BusWindow:
		# バスの窓：2回 手をふりかえし、見えなくなったら まえを向く
		var bw := game as BusWindow
		bw.wave()
		bw.wave()
		while not bw.can_close() and n < 20000:
			await get_tree().process_frame
			n += 1
		_kk["buswin"] = bw.waves
		bw.close_view()
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
		if target is Npc and not (target as Npc).get_parent() is Cameo and not GameState.has_talked((target as Npc).npc_data.id) and not (target as Npc).npc_data.auto_talk \
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
	# ミニゲーム（ROUTE_NORMAL_GAMES は ふつう、ほかは よくできた で遊んだ）
	for g in ["kakurenbo", "sentaku", "yomise", "suzu_michi", "onigokko"]:
		check(_mini.has(g), "kamikakushi: played %s %s" % [g, str(_mini.get(g))])
	# ミニゲームの結果：かくれんぼ（お面の子が自分から出てきた）・物々交換（ふつうの あめ玉）・道探し（2回もどされた）は ふつう
	check(GameState.has_flag(&"kakurenbo_miss") and _seen_lines.has("みつかっちゃった。") and not _seen_lines.has("……はやいね。みつかっちゃった。"),
		"kakurenbo ふつう: みつかっちゃった。")
	check(GameState.has_flag(&"yomise_miss") and GameState.find_item(&"yomise_ame").text() == "あおくて つめたい。たべちゃ だめって いわれた。", "yomise ふつう: candy text")
	# おがらのもえさしは、道探しの前に拾う（森の入口）。あとで遊んだ結果も記録される
	check(GameState.has_flag(&"suzu_michi_miss") and GameState.item_grade(&"ogara_ember") == GameState.Grade.NORMAL
		and GameState.find_item(&"ogara_ember").text() == "むかえびの あと。まだ すこし あったかい。", "suzu michi ふつう: ember text")
	check(GameState.game_grade(&"onigokko") == GameState.Grade.GOOD and GameState.find_item(&"gray_sunflower").text() == "いろが ない。でも、さいてる。つかまえたら、わらってた。",
		"onigokko よくできた: sunflower text %s" % GameState.find_item(&"gray_sunflower").text())
	check(_kk.get("bell", []) == [true, 2], "bus: the bell rings only once %s" % str(_kk.get("bell")))
	var unknown := Strings.DATE_MONTH % Strings.DATE_UNKNOWN + " " + Strings.DATE_DAY % Strings.DATE_UNKNOWN
	check(not d7_card_before.contains(Strings.DATE_UNKNOWN) and cards.get("d7_end", "") == unknown,
		"day 7: the date turns to ？？ beyond the smoke (%s -> %s)" % [d7_card_before, cards.get("d7_end", "")])
	check(cards.get(7, "") == unknown and cards.get(8, "") == unknown, "days 8-9: date stays ？？ (%s / %s)" % [cards.get(7, ""), cards.get(8, "")])
	check(max_ow.get(7, 0.0) > 0.9 and max_ow.get(8, 0.0) > 0.9 and max_ow.get(3, 0.0) == 0.0, "otherworld: colors fade on days 8-9 only %s" % str(max_ow))
	check(max_ow.get(4, 0.0) > 0.3 and max_ow.get(4, 0.0) < 0.9, "day 5: the night market is faintly otherworldly (%.2f)" % max_ow.get(4, 0.0))
	check(cards.get(9, "").ends_with("16") and cards.get("d10_after", "").ends_with("31"), "day 10: wakes on 8/16, flips to 8/31 (%s -> %s)" % [cards.get(9, ""), cards.get("d10_after", "")])
	check(d10_start_time >= 0.89 and d10_after_time >= 0.0 and d10_after_time < 0.3, "day 10: night at the shrine, then morning (%.2f -> %.2f)" % [d10_start_time, d10_after_time])
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
	check(GameState.has_talked(&"grandma_laundry"), "kamikakushi day 4 shares the laundry scene")
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


# --- ノーマルルート（祖父母） -----------------------------------------------------

## 1日目から歩いて、誰のフラグも立てずに（なつみ・タケルの川・鈴を避ける）、祖父母と10日目のバスまで。
## 会話は最初の選択肢（お面は きつね）、ミニゲームは ぜんぶ遊ぶ
func _normal_route() -> void:
	GameState.reset()
	_kk.clear()
	get_tree().change_scene_to_file("res://world/main.tscn")
	await _wait(0.5)
	var main := get_tree().current_scene
	var hud: Hud = main.get_node("HUD")
	var box: TreasureBox = main.get_node("BoxLayer/TreasureBox")
	var streamer: DayStreamer = main.get_node("DayStreamer")
	var tod: TimeOfDay = main.get_node("TimeOfDay")
	var paths := {}
	var sasabune_seen := false
	var cars_gone := false
	var max_rain := 0.0
	var rain_end := -1.0
	_seen_lines.clear()
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
		if loaded.has(day):
			var scene_node := loaded[day] as Node
			var sb := scene_node.get_node_or_null("Props/Sasabune") as CanvasItem
			sasabune_seen = sasabune_seen or (sb != null and sb.visible)
			var car := scene_node.get_node_or_null("Props/Car1") as CanvasItem
			cars_gone = cars_gone or (car != null and not car.visible)
		if day == 3:
			max_rain = maxf(max_rain, tod.rain)
			var x := player_x(main) - 3 * GameState.DAY_LENGTH_PX
			if x > 3500.0:
				rain_end = tod.rain
		if hud.is_talking():
			Input.action_release("move_right")
			await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		var target := hud.current_target()
		if target is Npc and not (target as Npc).get_parent() is Cameo and not GameState.has_talked((target as Npc).npc_data.id) and not (target as Npc).npc_data.auto_talk \
				and not (target as Npc).npc_data.id in [&"natsumi", &"takeru_river"]:
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.2)
			await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		if target is ItemPickup and (target as ItemPickup).item.id != &"rusty_bell":
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.3)
			# 置き手紙は、先に中身を読む
			while hud.is_talking():
				_seen_lines.append(hud._msg_text.text)
				TouchControls.fire_action(&"interact")
				await _wait(0.1)
			TouchControls.fire_action(&"interact")
			TouchControls.fire_action(&"interact")
			Input.action_press("move_right")
	Input.action_release("move_right")
	await _wait(1.5)
	check([&"route_takeru", &"route_natsumi", &"route_kamikakushi", &"rusty_bell_found"].all(func(f): return not GameState.has_flag(f)),
		"normal: no route flag %s" % str(GameState.flags.keys()))
	for i in range(3, 10):
		check(str(paths.get(i, "")).ends_with("day_%02d_normal.tscn" % (i + 1)), "normal day %d: %s" % [i + 1, paths.get(i, "")])
	for id in [&"grandma_arrive", &"grandpa", &"grandma_walk", &"grandpa_river", &"grandma_laundry", &"grandma_festival", &"grandpa_mask",
			&"aunt", &"grandma_bon", &"cousin", &"aunt_bye", &"grandma_quiet", &"grandma_letter", &"grandpa_play", &"grandpa_hide",
			&"grandpa_stars", &"grandpa_farewell_normal", &"grandma_farewell_normal"]:
		check(GameState.has_talked(id), "normal talks: %s" % id)
	check(sasabune_seen, "normal day 3: the sasabune with the sail floats down the river")
	check(GameState.has_flag(&"sentaku_good"), "sentaku: all the laundry in before the rain")
	check(max_rain > 0.9 and rain_end == 0.0, "normal day 4: rain on the engawa and the shrine, then it clears (max %.2f, after %.2f)" % [max_rain, rain_end])
	check(GameState.mask_kind == &"kitsune" and GameState.has_flag(&"mask_kitsune") and GameState.find_item(&"festival_mask").icon.resource_path.ends_with("mask_kitsune.png"),
		"festival: the fox mask (icon %s)" % GameState.find_item(&"festival_mask").icon.resource_path)
	check(_seen_lines.has("……きつね、か。"), "festival: grandpa reacts to the fox mask")
	check(_seen_lines.has("……なんだったかな。") and _seen_lines.has(Strings.WHISTLE_NOTE + "　～　" + Strings.WHISTLE_NOTE), "normal day 9: the whistle and \"……なんだったかな。\"")
	check(_seen_lines.has("またらいねん　タケル"), "normal day 8: the letter reads またらいねん")
	check(GameState.has_flag(&"shoryouma_good"), "shoryouma: 8 straight legs")
	check(cars_gone, "normal day 7: the relatives' cars drive away")
	check(GameState.has_flag(&"kakurenbo_jiji_miss") and GameState.has_flag(&"seiza_miss"), "kakurenbo with grandpa / seiza: played as ふつう")
	# ミニゲームの結果で、直後のせりふが変わる（洗濯物・精霊馬は よくできた、かくれんぼ・星座は ふつう）
	check(_seen_lines.has("ぜんぶ まにあったねえ。ありがとね。") and not _seen_lines.has("ちょっと ぬれちゃったね。まあ いいさ。"), "sentaku よくできた: ぜんぶ まにあった")
	check(_seen_lines.has("りっぱな うまだねえ。") and not _seen_lines.has("ちょっと かたむいてるけど、だいじょうぶ。"), "shoryouma よくできた: りっぱな うま")
	check(GameState.has_flag(&"kakurenbo_jiji_miss") and _seen_lines.has("……ここだ。むかしから、ここなんだ。") and not _seen_lines.has("だれにも みつからなかったんだがな。"),
		"kakurenbo with grandpa ふつう: ……ここだ。むかしから、ここなんだ。")
	check(not _seen_lines.has("……よく みつけたな。"), "seiza ふつう: no extra line")
	var wh := NormalProp.new()
	wh.kind = NormalProp.Kind.WHISTLE
	wh.show_on_event = "whistle"
	get_tree().root.add_child(wh)
	var hidden_first := not wh.visible
	wh.on_talk_event("whistle")
	check(hidden_first and wh.visible, "normal day 9: the ♪ appears when grandpa whistles")
	wh.queue_free()
	check(_kk.get("buswin", 0) == 2, "bus window: waved back twice")
	for id in [&"festival_mask", &"senko_hanabi", &"straw_hat", &"onigiri_wrap"]:
		check(GameState.was_received(id), "normal: received %s" % id)
	for id in [&"bus_ticket", &"marble", &"river_stone", &"cicada_shell", &"hozuki", &"friend_letter"]:
		check(GameState.is_collected(id) and not GameState.was_received(id), "normal: picked %s" % id)
	var scene := get_tree().current_scene
	check(scene and scene.name == "Ending", "normal: ending reached")
	if scene and scene.name == "Ending":
		var end_box: TreasureBox = scene.get_node("TreasureBox")
		check(GameState.current_ending().id == &"default" and end_box.header_caption.text == Strings.ENDING_TITLE, "normal ending shown: %s" % end_box.header_caption.text)
		check(end_box._slots[-1].item.id == &"onigiri_wrap" and end_box._slots[-1].collected, "normal: the onigiri wrap appears last")
		# 1日目の鈴だけ拾わなかった
		check(end_box._found[0] == end_box._found[1] - 1, "normal: every treasure but the bell %s" % str(end_box._found))
	# 4日目に「かえる」を選ぶと、5日目からはノーマル（データの上で）
	var keep := GameState.flags.duplicate()
	GameState.flags.clear()
	GameState.set_flag(&"rusty_bell_found")
	GameState.set_flag(&"bell_rang")
	check(GameState.day_scene_path(GameState.get_day(4)).ends_with("day_05_normal.tscn") and GameState.current_ending().id == &"default", "bell, went home -> normal from day 5")
	GameState.flags = keep


func player_x(main: Node) -> float:
	return (main.get_node("Player") as Node2D).global_position.x


# --- 縁側の場面（日の切り替わりの中） -------------------------------------------------

## ルート → { 終わった日（1 始まり） → { empty, items, picked, lines, hint } }
var _engawa_seen := {}
## 何回目の縁側の場面か（1回目はキーボード、2回目はタッチ、3回目は「とばす」で確かめる。あとは自動）
var _engawa_count := 0
var _engawa_busy := false
var _engawa_layout_checked := false


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if _engawa_busy or scene == null or not ("engawa" in scene):
		return
	var e: Engawa = scene.engawa
	if e and e.is_open():
		_engawa_busy = true
		# 矢印キー・タッチのイベントで、歩く道の押しつづけ（move_right）が離されるので、終わったらもどす
		var held := Input.is_action_pressed("move_right")
		await _drive_engawa(e)
		if held:
			Input.action_press("move_right")
		_engawa_busy = false


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _touch(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.position = pos
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _until(cond: Callable, limit := 10.0) -> bool:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


## キャンバスの座標（UI）を、入力イベントの座標（ウィンドウ）に直す
func _to_screen(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func _drive_engawa(e: Engawa) -> void:
	_engawa_count += 1
	var n := _engawa_count
	var route := String(GameState.current_route())
	var day := GameState.current_day_index  # 日の切り替わりの暗転の中で、もう次の日になっている
	var rec := {"empty": e.empty, "items": [], "picked": &"", "lines": [], "mode": "auto"}
	_engawa_seen[route] = _engawa_seen.get(route, {})
	_engawa_seen[route][day] = rec
	check(get_tree().paused, "engawa pauses the game (day %d)" % day)
	if e.empty:
		var t0 := Time.get_ticks_msec()
		await _until(func(): return not e.is_open())
		rec["ms"] = (Time.get_ticks_msec() - t0) * Engine.time_scale
		return
	await _until(func(): return e.phase == Engawa.Phase.ASK)
	if n == 3:
		# 「とばす」相当（ui_cancel）で場面ごととばす
		rec["mode"] = "skip"
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = true
		Input.parse_input_event(esc)
		await get_tree().process_frame
		rec["skipped"] = e.phase == Engawa.Phase.OUTRO
		await _until(func(): return not e.is_open())
		return
	if n == 1:
		# キーボード：決定で問いかけを全文に → 並んだら右キーで枠を選び、決定で見せる
		rec["mode"] = "key"
		await _key(KEY_ENTER)
		rec["ask_all"] = not e._panel.is_typing()
	await _until(func(): return e.phase == Engawa.Phase.PICK and e._phase_t > Engawa.PICK_GUARD + 0.1)
	var slots := e.slots()
	for s in slots:
		rec["items"].append(s.item.id)
	rec["hint"] = e._hint_label.text
	if not _engawa_layout_checked:
		_engawa_layout_checked = true
		await _check_engawa_layout(e)
	if n == 1:
		await _key(KEY_RIGHT)
		await _key(KEY_RIGHT)
		var f := get_viewport().gui_get_focus_owner()
		rec["focused"] = (f as ItemSlot).item.id if f is ItemSlot else &""
		rec["marked"] = f is ItemSlot and (f as ItemSlot).selected
		rec["hint"] = e._hint_label.text
		await _key(KEY_ENTER)
	elif n == 2:
		# タッチ：最後の枠をタップで即決定
		rec["mode"] = "touch"
		var last: ItemSlot = slots[-1]
		# 見せたあとは、案内の小札が見せたものの一言になるので、案内はタッチに切りかわったところで見る
		InputMode._apply(true, false)
		rec["hint"] = e._hint_label.text
		await _touch(_to_screen(last.get_global_rect().get_center()))
		rec["touch_target"] = last.item.id
		rec["note"] = e._hint_label.text
	else:
		e.pick(slots[0])
	await _until(func(): return e.phase != Engawa.Phase.PICK)
	rec["picked"] = e.shown_item.id if e.shown_item else &""
	rec["lines"] = e.lines.duplicate()
	if n == 2:
		# タッチで文字送り → 全文 → 次の行
		while e.is_open() and e.phase == Engawa.Phase.REPLY:
			await _touch(_to_screen(Vector2(640, 360)))
			await _wait(0.05)
	elif n == 1:
		while e.is_open() and e.phase == Engawa.Phase.REPLY:
			await _key(KEY_ENTER)
			await _wait(0.05)
	await _until(func(): return not e.is_open(), 30.0)
	rec["closed"] = not e.is_open()


## 縦横比をかえても、縁側の場面の UI がはみ出さず、押せる部分が 72px 以上・画面端から 40px 以上あく
func _check_engawa_layout(e: Engawa) -> void:
	var win := get_tree().root
	var keep_size := win.size
	var keep_base := win.content_scale_size
	for spec in [[Vector2i(1280, 720), UiTokens.BASE_SIZE], [Vector2i(2340, 1080), UiTokens.BASE_SIZE],
			[Vector2i(1600, 1200), UiTokens.BASE_SIZE], [Vector2i(2340, 1080), UiTokens.COMPACT_BASE_SIZE]]:
		win.size = spec[0]
		win.content_scale_size = spec[1]
		await get_tree().process_frame
		await get_tree().process_frame
		var vis := e._root.get_global_rect()
		var inner := vis.grow(-UiTokens.SCREEN_MARGIN + 1)
		var ok := true
		var why := ""
		for c in [e._panel, e._skip, e._hint] + e.slots():
			var r: Rect2 = c.get_global_rect()
			if not inner.encloses(r):
				ok = false
				why += " %s%s" % [c.name, str(r)]
		for c in [e._skip] + e.slots():
			if c.size.x < UiTokens.TOUCH_MIN or c.size.y < UiTokens.TOUCH_MIN:
				ok = false
				why += " small %s" % c.name
		check(ok, "engawa layout fits %s base %s (screen %s)%s" % [str(spec[0]), str(spec[1]), str(vis.size), why])
	win.size = keep_size
	win.content_scale_size = keep_base
	await get_tree().process_frame


func _engawa_lines(route: String, day: int) -> Array:
	return _engawa_seen.get(route, {}).get(day, {}).get("lines", [])


func _engawa_rec(route: String, day: int) -> Dictionary:
	return _engawa_seen.get(route, {}).get(day, {})


func _engawa_days() -> Array:
	var days := []
	for r in _engawa_seen:
		days.append_array(_engawa_seen[r].keys())
	days.sort()
	return days


func _reply_lines(item: StringName, route: StringName) -> Array:
	var r := EngawaReply.find(item, route)
	return r.lines if r else []


## 返事のデータ：フォルダの .tres をぜんぶ読み、ルート → 共通 → 「なんにも」の順に探す
func _check_engawa_data() -> void:
	var files := Array(DirAccess.get_files_at(EngawaReply.DIR)).filter(func(f): return f.ends_with(".tres"))
	check(EngawaReply.all().size() == files.size() and files.size() >= 28, "engawa replies: every .tres in data/engawa is read (%d)" % files.size())
	check(_reply_lines(&"river_stone", &"shinyu")[0].begins_with("おじいちゃん：あそこの せがれか"), "engawa reply: route first (shinyu river stone)")
	check(_reply_lines(&"river_stone", &"normal")[0].begins_with("おじいちゃん：いい いしだ"), "engawa reply: then the shared one")
	check(_reply_lines(&"no_such_item", &"normal") == ["おじいちゃん：そういう ひも ある"], "engawa reply: unknown item -> なんにも")
	check(_reply_lines(&"", &"kamikakushi") == ["おじいちゃん：そういう ひも ある"], "engawa reply: なんにも")
	for r in EngawaReply.all():
		for line in r.lines:
			var body: String = line.substr(line.find("：") + 1)
			check(body.length() <= 22, "engawa reply line is short: %s" % line)


## 親友ルート（はじめの通しの道）：1回目はキーボード、2回目はタッチ、3回目は「とばす」
func _check_engawa_takeru() -> void:
	check(_engawa_days() == [1, 2, 3, 4, 5, 6, 7, 8, 9], "engawa: days 1-9 only, not day 10 %s" % str(_engawa_days()))
	check(_engawa_layout_checked, "engawa layout checked")
	var k := _engawa_rec("normal", 1)
	check(k.get("mode") == "key" and k.get("ask_all", false), "engawa keyboard: accept shows the whole question")
	check(k.get("items", []).has(&"bus_ticket") and k.get("items", []).has(&"blue_pencil"), "engawa day 1: the items picked up that day %s" % str(k.get("items")))
	check(k.get("marked", false) and k.get("picked") == k.get("focused") and k.get("picked") != &"", "engawa keyboard: arrows + enter shows the focused item (%s)" % k.get("picked"))
	check(k.get("hint") == Strings.ENGAWA_PICK_KEY, "engawa keyboard hint")
	check(k.get("lines") == _reply_lines(k.get("picked", &""), &"normal") and not k.get("lines", []).is_empty(), "engawa keyboard: reply for %s %s" % [k.get("picked"), str(k.get("lines"))])
	check(k.get("closed", false), "engawa keyboard: closes after the reply")
	var t := _engawa_rec("normal", 2)
	check(t.get("mode") == "touch" and t.get("picked") == t.get("touch_target") and t.get("picked") == &"marble", "engawa touch: tap shows the item at once (%s)" % t.get("picked"))
	check(t.get("hint") == Strings.ENGAWA_PICK_TOUCH, "engawa touch hint")
	var shown := GameState.find_item(t.get("picked", &""))
	check(shown != null and t.get("note") == Engawa.item_note(shown) and t.get("note", "").ends_with("「%s」" % shown.text()),
		"engawa: the shown item's line under the reply (%s)" % t.get("note"))
	check(t.get("lines") == ["おじいちゃん：ビーだまか。わしも むかし あつめた"] and t.get("closed", false), "engawa touch: reply read through by tapping")
	check(_engawa_rec("shinyu", 3).get("skipped", false), "engawa: ui_cancel skips the whole scene")
	check(_engawa_rec("shinyu", 4).get("picked") == &"base_plaque" and _engawa_lines("shinyu", 4).has("ぼく：ひみつ"), "engawa shinyu day 4: base plaque reply %s" % str(_engawa_lines("shinyu", 4)))
	check(_engawa_rec("shinyu", 8).get("items", [1]) == [&""] and _engawa_lines("shinyu", 8) == ["おじいちゃん：そういう ひも ある"],
		"engawa: nothing picked up -> なんにも %s" % str(_engawa_rec("shinyu", 8)))
	for d in range(1, 10):
		var rec := _engawa_rec("shinyu" if d >= 3 else "normal", d)
		check(not rec.get("empty", true), "engawa shinyu day %d: grandparents are there" % d)


func _check_engawa_natsumi() -> void:
	check(_engawa_days() == [1, 2, 3, 4, 5, 6, 7, 8, 9], "engawa natsumi: days 1-9 %s" % str(_engawa_days()))
	check(_engawa_lines("hatsukoi", 3) == ["おばあちゃん：あら、じょうずに かけたね。", "おばあちゃん：だれと かいたの？", "ぼく：なつみ", "おばあちゃん：ああ、なつみちゃん"],
		"engawa natsumi day 3: river sketch %s" % str(_engawa_lines("hatsukoi", 3)))
	check(_engawa_rec("hatsukoi", 9).get("picked") == &"senko_ash" and _engawa_lines("hatsukoi", 9)[-1] == "ぼく：うん", "engawa natsumi day 9: senko ash")


func _check_engawa_kamikakushi() -> void:
	check(_engawa_days() == [1, 2, 3, 4, 5, 6, 7, 8, 9], "engawa kamikakushi: days 1-9 %s" % str(_engawa_days()))
	check(_engawa_lines("kamikakushi", 4)[-1] == "おじいちゃん：……さっき、すずの おとが した きが したな",
		"engawa kamikakushi day 4: grandpa heard the bell after the reply %s" % str(_engawa_lines("kamikakushi", 4)))
	check(_engawa_lines("kamikakushi", 5).has("ぼく：……おまつりの おく"), "engawa kamikakushi day 5: night market candy")
	check(_engawa_lines("kamikakushi", 6)[-1] == "おじいちゃん：……", "engawa kamikakushi day 6: grandpa says nothing")
	for d in [7, 8, 9]:
		var rec := _engawa_rec("kamikakushi", d)
		check(rec.get("empty", false) and rec.get("lines", [1]).is_empty() and rec.get("ms", 0.0) > 1500.0 and rec.get("ms", 0.0) < 3500.0,
			"engawa kamikakushi day %d: nobody there, only the smoke (%s)" % [d, str(rec)])
	for d in [1, 2, 3, 4, 5, 6]:
		check(not _engawa_rec("kamikakushi" if d >= 4 else "normal", d).get("empty", true), "engawa kamikakushi day %d: grandparents are there" % d)
	# 異界の日：季節の色は7日目で止まり、10日目は本当の日付の進み具合
	var s7 := GameState.summer_progress_of(GameState.get_day(6))
	check(GameState.is_otherworld(GameState.get_day(7)) and GameState.is_otherworld(GameState.get_day(8)) and not GameState.is_otherworld(GameState.get_day(6)),
		"kamikakushi: days 8-9 are otherworld days")
	check(GameState.summer_progress_of(GameState.get_day(7)) == s7 and GameState.summer_progress_of(GameState.get_day(8)) == s7
		and GameState.summer_progress_of(GameState.get_day(9)) > s7, "kamikakushi: the season stops at day 7 on days 8-9")
	check(GameState.day_date(GameState.get_day(9)) == ["8", "16"], "kamikakushi day 10: wakes on 8/16 (date_label_override)")


func _check_engawa_normal() -> void:
	check(_engawa_days() == [1, 2, 3, 4, 5, 6, 7, 8, 9], "engawa normal: days 1-9 %s" % str(_engawa_days()))
	check(_engawa_lines("normal", 5) == ["おばあちゃん：よく にあってるよ"], "engawa normal day 5: festival mask %s" % str(_engawa_lines("normal", 5)))
	check(_engawa_rec("normal", 9).get("picked") == &"straw_hat" and _engawa_lines("normal", 9) == ["おばあちゃん：あら、おじいちゃんの。にあうねえ"], "engawa normal day 9: straw hat")
	for d in range(1, 10):
		check(not _engawa_rec("normal", d).get("empty", true), "engawa normal day %d: grandparents are there" % d)



# --- 初恋ルート：2日目の誘いを「やめとく」 -----------------------------------------------

var _declined := {}


## 2日目に色えんぴつを返して、あしたの川への誘いに「やめとく」と答える。
## mode "takeru"：キーボードで「やめとく」を選び、3日目にタケルへビー玉を「わたす」（親友ルートに入れる）。
## mode "bell"：タッチで「やめとく」を選び、タケルには話しかけない。4日目に鈴を持っていれば、神社でお面の子が誘う
func _natsumi_declined_route(mode: String) -> void:
	GameState.reset()
	_declined.clear()
	get_tree().change_scene_to_file("res://world/main.tscn")
	await _wait(0.5)
	var main := get_tree().current_scene
	var hud: Hud = main.get_node("HUD")
	var box: TreasureBox = main.get_node("BoxLayer/TreasureBox")
	var streamer: DayStreamer = main.get_node("DayStreamer")
	var stop_day := 3
	Input.action_press("move_right")
	var t := 0.0
	while t < 500.0 and get_tree().current_scene == main and _declined.get("tries", 0) <= 2:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var day := GameState.current_day_index
		# 3日目の川原の、遠くの橋の上のなつみ
		var loaded: Dictionary = streamer._loaded
		if loaded.has(2) and day == 2:
			var nb := (loaded[2] as Node).get_node_or_null("Props/NatsumiBridge") as Npc
			if nb:
				_declined["bridge_present"] = nb._present
		if day == stop_day and not Transition.is_busy():
			_declined["day4_scene"] = (loaded[3] as Node).scene_file_path if loaded.has(3) else ""
			if mode == "takeru":
				break
		if hud.is_talking():
			Input.action_release("move_right")
			if hud.speaker_name() == "なつみ" and day == 1:
				await _decline_natsumi(hud, box, mode)
			elif mode == "bell" and hud.speaker_name() == "おめんの子":
				# 神社で鈴が鳴り、お面の子が「あそぼ」と誘う（ここで確かめて終わる）
				_declined["fox_invite"] = true
				break
			else:
				await _finish_talk(hud, box)
			Input.action_press("move_right")
			continue
		var target := hud.current_target()
		if target is Npc and not (target as Npc).get_parent() is Cameo and not GameState.has_talked((target as Npc).npc_data.id) and not (target as Npc).npc_data.auto_talk:
			var id := (target as Npc).npc_data.id
			if mode == "bell" and id == &"takeru_river":
				continue
			Input.action_release("move_right")
			TouchControls.fire_action(&"interact")
			await _wait(0.2)
			if id == &"natsumi_bridge":
				_declined["bridge_line"] = hud._msg_text.text
			if hud.speaker_name() == "なつみ" and day == 1:
				await _decline_natsumi(hud, box, mode)
			else:
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
	var tag := "natsumi declined (%s): " % mode
	check(_declined.get("choices", []) == ["いく", "やめとく"], tag + "the invitation offers いく / やめとく %s" % str(_declined.get("choices")))
	check(_declined.get("picked_by", "") == mode, tag + "やめとく chosen by %s" % ("keyboard" if mode == "takeru" else "touch"))
	check(_declined.get("reply", "") == "……そっか。", tag + "she says ……そっか。 (%s)" % _declined.get("reply", ""))
	check(GameState.gone_note(&"blue_pencil") != "" and not GameState.holds(&"blue_pencil"), tag + "the pencil was handed back anyway")
	check(not GameState.has_flag(&"route_natsumi") and GameState.has_flag(&"natsumi_declined"), tag + "no natsumi route flag")
	# 1日目の「ごめん」と2日目の「そらの いろ、きれいだった」の2つだけ（「やめとく」は好感度の選択肢ではない）
	check(GameState.natsumi_heart == 2, tag + "いく/やめとく is not a heart choice (%d)" % GameState.natsumi_heart)
	check(_declined.get("bridge_present", false), tag + "day 3: natsumi drawing on the far bridge")
	check(_declined.get("bridge_line", "") == "……（ぺこり）", tag + "the bridge natsumi only bows (%s)" % _declined.get("bridge_line", ""))
	if mode == "takeru":
		check(GameState.has_flag(&"route_takeru"), tag + "giving the marble to takeru starts the takeru route")
		check(str(_declined.get("day4_scene", "")).ends_with("day_04_takeru.tscn"), tag + "day 4 is the takeru scene (%s)" % _declined.get("day4_scene", ""))
	else:
		check(not GameState.has_flag(&"route_takeru") and GameState.has_flag(&"rusty_bell_found"), tag + "no takeru flag, bell in hand")
		check(str(_declined.get("day4_scene", "")).ends_with("day_04_kamikakushi.tscn"), tag + "day 4 is the bell shrine scene (%s)" % _declined.get("day4_scene", ""))
		check(_declined.get("fox_invite", false), tag + "the masked child invites on day 4")


## なつみとの会話を最後まで送る。あしたの誘いの選択肢では「やめとく」を、キーボード（"takeru"）かタッチ（"bell"）で選ぶ
func _decline_natsumi(hud: Hud, box: TreasureBox, mode: String) -> void:
	_declined["tries"] = _declined.get("tries", 0) + 1
	var guard := 0
	while hud.is_talking() and guard < 300:
		guard += 1
		if hud.is_choosing():
			var items := hud._choice_list.items()
			var texts := items.map(func(b): return (b as Button).text)
			if texts.has("やめとく"):
				_declined["choices"] = texts
				# 出てすぐは受けつけないので、少し待つ
				while Time.get_ticks_msec() - hud._choice_at < Hud.CHOICE_GUARD * 1000.0 + 100.0:
					await get_tree().process_frame
				var target: Button = items[texts.find("やめとく")]
				if mode == "takeru":
					await _key(KEY_RIGHT)
					var guard_k := 0
					while get_viewport().gui_get_focus_owner() != target and guard_k < 4:
						await _key(KEY_RIGHT)
						guard_k += 1
					await _key(KEY_ENTER)
				else:
					await _touch(_to_screen(target.get_global_rect().get_center()))
				await get_tree().process_frame
				if not hud.is_choosing():
					_declined["picked_by"] = mode
				await _wait(0.6)
				_declined["reply"] = hud._msg_text.text
			else:
				hud.choose(0)
		else:
			TouchControls.fire_action(&"interact")
		await _wait(0.1)



# --- 宝箱の影（拾い逃したアイテム） -------------------------------------------------

func _check_missed() -> void:
	GameState.reset()
	# 1日目を越えて2日目にいる：1日目のものは影、2日目（いまいる日）と先の日のものは影にしない
	GameState.current_day_index = 1
	var ticket := GameState.find_item(&"bus_ticket")
	check(GameState.is_missed(ticket) and GameState.is_missed(GameState.find_item(&"rusty_bell")), "missed: day 1 items become shadows on day 2")
	check(not GameState.is_missed(GameState.find_item(&"marble")) and not GameState.is_missed(GameState.find_item(&"river_stone")), "missed: today and later days stay plain")
	check(not GameState.is_missed(GameState.find_item(&"blue_pencil")), "missed: the pencil (not counted) is never a shadow")
	check(TreasureBox.missed_hint(ticket) == "7/21　バスていの どこか", "missed hint: %s" % TreasureBox.missed_hint(ticket))
	# 他ルートのアイテムは影にしない（ルートなし＝ノーマルで9日目）
	GameState.current_day_index = 9
	check(not GameState.is_missed(GameState.find_item(&"base_plaque")) and not GameState.is_missed(GameState.find_item(&"gray_sunflower"))
		and GameState.is_missed(GameState.find_item(&"straw_hat")), "missed: only the current route's items")
	# 神隠し：異界の日は日付を「？？/？？」で
	GameState.set_flag(&"route_kamikakushi")
	var sun := GameState.find_item(&"gray_sunflower")
	check(GameState.is_missed(sun) and TreasureBox.missed_hint(sun) == "？？/？？　いろの ない むらの どこか", "missed hint (otherworld): %s" % TreasureBox.missed_hint(sun))
	check(TreasureBox.missed_hint(GameState.find_item(&"fox_mask")) == "？？/？？　よいちの おくの じんじゃの どこか", "missed hint (otherworld day 9)")
	check(not GameState.is_missed(GameState.find_item(&"festival_mask")), "missed: the normal route's mask is not in the kamikakushi box")
	# 親友：あげたビー玉は「タケルに あげた」のまま。川の石のヒントはルートで変わる
	GameState.reset()
	GameState.collect(GameState.find_item(&"marble"))
	GameState.give_away(GameState.find_item(&"marble"), "タケルに あげた")
	GameState.set_flag(&"route_takeru")
	GameState.current_day_index = 5
	check(not GameState.is_missed(GameState.find_item(&"marble")), "missed: the marble given to takeru is not a shadow")
	check(GameState.find_item(&"river_stone").place_hint_text() == "かわらの いわ", "missed hint: the river stone is on the rock in the takeru route")
	for it in GameState.all_items():
		if it.day_number < 10 and not GameState.is_extra(it):
			check(it.place_hint_text() != "", "every day 1-9 item has a place hint (%s)" % it.id)
	# 宝箱の画面：3日目から始めて（1・2日目は拾っていない）、影の枠をキーボードとタップで選ぶ
	GameState.reset()
	GameState.start_day_index = 2
	get_tree().change_scene_to_file("res://world/main.tscn")
	await _wait(0.8)
	var main := get_tree().current_scene
	var box: TreasureBox = main.get_node("BoxLayer/TreasureBox")
	TouchControls.fire_action(&"open_box")
	await _wait(1.0)
	check(box.is_open, "missed: box opens")
	var by_id := {}
	for sl in box._slots:
		by_id[sl.item.id] = sl
	check(by_id[&"bus_ticket"].missed and by_id[&"marble"].missed and by_id[&"bus_ticket"].theme_type_variation == &"SlotMissed",
		"missed: day 1-2 slots are shadows in the box")
	check(not by_id[&"river_stone"].missed and by_id[&"river_stone"].theme_type_variation == &"SlotEmpty", "missed: today's slot stays plain")
	check(not by_id[&"bus_ticket"].content.visible and by_id[&"bus_ticket"]._ghost.visible, "missed: the shadow shows only the outline (no name)")
	# キーボード：矢印で最初の枠（バスの切符）へ
	await _key(KEY_RIGHT)
	await _wait(0.2)
	var f := get_viewport().gui_get_focus_owner()
	check(f is ItemSlot and (f as ItemSlot).missed and box._detail_name.text == Strings.BOX_EMPTY_NAME,
		"missed keyboard: the shadow slot can be focused (%s)" % box._detail_name.text)
	check(box._detail_date.text == TreasureBox.missed_hint((f as ItemSlot).item) and (f as ItemSlot).selected,
		"missed keyboard: date and place hint (%s)" % box._detail_date.text)
	# タップ：ビー玉の影
	var mslot: ItemSlot = by_id[&"marble"]
	await _touch(_to_screen(mslot.get_global_rect().get_center()))
	await _wait(0.2)
	check(box._detail_name.text == Strings.BOX_EMPTY_NAME and box._detail_date.text == "7/23　みちばたの どこか",
		"missed touch: tapping the shadow shows the hint (%s)" % box._detail_date.text)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(0.8)
	check(not box.is_open, "missed: box closes")
