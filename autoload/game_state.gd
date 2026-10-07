extends Node
## ゲーム全体の状態（拾ったアイテム、現在の日など）。セーブはしない。

signal item_collected(item: ItemData)
## アイテムを手ばなしたとき（人にあげた・うめた）
signal item_gone(item: ItemData)
signal day_changed(index: int)
## フラグが立ったとき（日の場面の差し替え、NPC の出入りに使う）
signal flags_changed
## 秘密基地のすき間に材料をはめたとき
signal base_changed

## 1日の横幅（px）。あとで調整する
const DAY_LENGTH_PX := 3840.0
## 夏休みの期間（仮）
const SUMMER_START := Vector2i(7, 20)
const SUMMER_END := Vector2i(8, 31)
const DAY_LIST_PATH := "res://data/day_list.tres"
## 秘密基地づくり（ペントミノ式の型はめ）の盤とピース
const BASE_PUZZLE_PATH := "res://data/base_puzzle.tres"
const _MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var day_list: DayList
var current_day_index := 0
## 本編をはじめる日（ふだんは 0。デバッグのジャンプで変える）
var start_day_index := 0
## id -> 拾った順の番号
var collected: Dictionary = {}
## 人から「もらった」アイテムの id（宝箱の「〜に もらった」の表示用）
var received: Dictionary = {}
## 手ばなしたアイテム：id -> 宝箱の枠に出すひとこと（「タケルにあげた」「うめた」など）
var gone: Dictionary = {}
## 話しかけたことのある NPC の id
var talked: Dictionary = {}
## 立っているフラグ（エンディングの分岐など）。セーブはしない
var flags: Dictionary = {}
## 秘密基地の盤のマス（Vector2i）-> はめた材料の id。4日目に作り、8・9日目はこれで見た目を組み立てる
var base_cells: Dictionary = {}
## 秘密基地の盤のマス -> はめたピースの番号（ピースのふちを描くため）
var base_cell_piece: Dictionary = {}
var _base_puzzle: BasePuzzle
## 飛び込み（7日目）の結果：&"perfect"（ぴったり）／&"early"（はやすぎ）／&"late"（おそい）。空ならまだ
var dive_result := &""
## 石切り（3日目）で3回投げたうち、いちばんよく跳ねた回数と、タケルとの勝負の結果（&"win"／&"draw"／&"lose"）。空ならまだ
var ishikiri_best := 0
var ishikiri_result := &""
## 帽子を受け止めた（true）か、顔に当たった（false）か。エンディングでは使わない
var hat_caught := false
## タイムカプセルを埋めた場所（0 左／1 まんなか／2 右）。-1 ならまだ
var capsule_spot := -1
## カブトムシとり（6日目）で落とした回数。-1 ならまだ
var kabuto_drops := -1
## 型抜き（5日目）の結果：&"clean"（ぬけた）／&"broken"（われた）。空ならまだ
var katanuki_result := &""
## なつみの好感度（初恋ルート）。エンディングの差分だけに使う（ルートから外れる条件にはしない）
var natsumi_heart := 0

## 5日目に祖父に買ってもらったお面の種類（&"kitsune"／&"hyottoko"／&"okame"。ノーマルルート）。空ならまだ。
## アイテムは1つ（festival_mask）で、見た目（icon）だけを種類でかえる
var mask_kind := &""
const MASK_KINDS := [&"kitsune", &"hyottoko", &"okame"]
const MASK_ICON := "res://data/items/icons/mask_%s.svg"
var _mask_default_icon: Texture2D

## 好感度の最大（会話の選択肢 9 か所＋ミニゲーム 4 種）と、エンディングの段階のしきい値（遊んでみて調整する）
const HEART_MAX := 13
const HEART_HIGH := 10
const HEART_MID := 5


func _ready() -> void:
	day_list = load(DAY_LIST_PATH)
	_base_puzzle = load(BASE_PUZZLE_PATH)
	var mask := find_item(&"festival_mask")
	_mask_default_icon = mask.icon if mask else null


func reset() -> void:
	collected.clear()
	received.clear()
	gone.clear()
	talked.clear()
	flags.clear()
	base_cells.clear()
	base_cell_piece.clear()
	dive_result = &""
	katanuki_result = &""
	natsumi_heart = 0
	ishikiri_best = 0
	kabuto_drops = -1
	capsule_spot = -1
	hat_caught = false
	var map := find_item(&"capsule_map")
	if map:
		map.icon = null
	ishikiri_result = &""
	mask_kind = &""
	var mask := find_item(&"festival_mask")
	if mask:
		mask.icon = _mask_default_icon
	current_day_index = 0
	start_day_index = 0


func day_count() -> int:
	return day_list.days.size()


func get_day(index: int) -> DayData:
	return day_list.days[clampi(index, 0, day_count() - 1)]


func current_day() -> DayData:
	return get_day(current_day_index)


func world_length() -> float:
	return DAY_LENGTH_PX * day_count()


func set_current_day(index: int) -> void:
	if index == current_day_index:
		return
	current_day_index = index
	day_changed.emit(index)


func collect(item: ItemData, from_someone := false) -> void:
	if is_collected(item.id):
		return
	collected[item.id] = collected.size()
	if from_someone:
		received[item.id] = true
	if item.collect_flag != &"":
		set_flag(item.collect_flag)
	item_collected.emit(item)


func is_collected(id: StringName) -> bool:
	return collected.has(id)


## いま手もとにあるか（拾って、まだ手ばなしていない）
func holds(id: StringName) -> bool:
	return collected.has(id) and not gone.has(id)


func was_received(id: StringName) -> bool:
	return received.has(id)


## アイテムを手ばなす。宝箱の枠には note を出す
func give_away(item: ItemData, note: String) -> void:
	if not holds(item.id):
		return
	gone[item.id] = note
	item_gone.emit(item)


func gone_note(id: StringName) -> String:
	return gone.get(id, "")


## id からアイテムを探す（ルートの差し替えのアイテムも含む）
func find_item(id: StringName) -> ItemData:
	for d in day_list.days:
		for it in d.items + d.extra_items:
			if it and it.id == id:
				return it
		for v in d.variants:
			if v == null:
				continue
			for it in v.items:
				if it and it.id == id:
					return it
	return null


func has_talked(id: StringName) -> bool:
	return talked.has(id)


func mark_talked(id: StringName) -> void:
	talked[id] = true


func has_flag(f: StringName) -> bool:
	return flags.has(f)


func set_flag(f: StringName) -> void:
	if flags.has(f):
		return
	flags[f] = true
	flags_changed.emit()


func base_puzzle() -> BasePuzzle:
	return _base_puzzle


func base_material(id: StringName) -> BaseMaterial:
	for p in _base_puzzle.pieces:
		if p.material and p.material.id == id:
			return p.material
	return null


## そのマスにはめた材料（まだなら null）
func base_cell(c: Vector2i) -> BaseMaterial:
	return base_material(base_cells.get(c, &""))


## ピースを盤にはめる（cells は盤のマス）
func base_place(piece: int, cells: Array[Vector2i], material: BaseMaterial) -> void:
	for c in cells:
		base_cells[c] = material.id
		base_cell_piece[c] = piece
	base_changed.emit()


## はめたピースを盤から外す
func base_remove(piece: int) -> void:
	for c in base_cell_piece.keys():
		if base_cell_piece[c] == piece:
			base_cells.erase(c)
			base_cell_piece.erase(c)
	base_changed.emit()


## 飛び込みの結果を記録する。会話で分けられるよう、フラグ dive_perfect / dive_early / dive_late も立てる
func set_dive_result(r: StringName) -> void:
	dive_result = r
	set_flag(StringName("dive_" + r))


## 石切りの結果を記録する。会話で分けられるよう、フラグ ishikiri_win / ishikiri_draw / ishikiri_lose も立てる
func set_ishikiri_best(n: int, r: StringName) -> void:
	ishikiri_best = n
	ishikiri_result = r
	set_flag(StringName("ishikiri_" + r))


## 帽子を受け止めたかを記録する。フラグ hat_caught（受け止めた）／ hat_face（顔に当たった）も立てる
func set_hat_result(c: bool) -> void:
	hat_caught = c
	set_flag(&"hat_caught" if c else &"hat_face")


## タイムカプセルを埋めた場所を記録し、タケルの地図の絵を作る（バツじるしは、となりにずれている）
func set_capsule_spot(i: int) -> void:
	capsule_spot = i
	var map := find_item(&"capsule_map")
	if map:
		map.icon = CapsuleGame.map_texture(i)


## カブトムシとりの結果を記録する。会話で分けられるよう、フラグ kabuto_clean（一度も落とさない）／ kabuto_dropped も立てる
func set_kabuto_result(drops: int) -> void:
	kabuto_drops = drops
	set_flag(&"kabuto_clean" if drops == 0 else &"kabuto_dropped")


## 型抜きの結果を記録する。会話で分けられるよう、フラグ katanuki_clean / katanuki_broken も立てる
func set_katanuki_result(r: StringName) -> void:
	katanuki_result = r
	set_flag(StringName("katanuki_" + r))


## なつみの好感度を上げる（会話の @heart、ミニゲームの高得点）。
## しきい値をこえたらフラグ natsumi_heart_mid / natsumi_heart_high を立てる（10日目の場面とエンディングの段階を選ぶため）
func add_heart(n := 1) -> void:
	natsumi_heart = mini(natsumi_heart + n, HEART_MAX)
	if natsumi_heart >= HEART_MID:
		set_flag(&"natsumi_heart_mid")
	if natsumi_heart >= HEART_HIGH:
		set_flag(&"natsumi_heart_high")


## なつみルートのミニゲーム（スケッチ・金魚すくい・貝がら拾い・線香花火）の結果。
## 会話で分けられるよう、フラグ <name>_good（高得点）／ <name>_miss を立てる。高得点なら好感度 +1
func set_natsumi_game(game: StringName, good: bool) -> void:
	var f := StringName(String(game) + ("_good" if good else "_miss"))
	if has_flag(f):
		return
	set_flag(f)
	if good:
		add_heart()


## ノーマルルートのミニゲーム（洗濯物の取り込み・精霊馬づくり・星座さがし・かくれんぼ）の結果。
## 会話で分けられるよう、フラグ <name>_good（うまくいった）／ <name>_miss を立てる。どちらでも話は進む
func set_game_result(game: StringName, good: bool) -> void:
	set_flag(StringName(String(game) + ("_good" if good else "_miss")))


## 5日目のお面の種類を記録し、お面のアイテムの絵をその種類にする。フラグ mask_<種類> も立てる（祖父の一言を分けるため）
func set_mask(kind: StringName) -> void:
	if not MASK_KINDS.has(kind):
		push_warning("お面の種類がわからない: " + kind)
		return
	mask_kind = kind
	set_flag(StringName("mask_" + kind))
	var mask := find_item(&"festival_mask")
	if mask:
		mask.icon = load(MASK_ICON % kind)


## 屋根と壁のすき間が、ぜんぶふさがったか
func base_done() -> bool:
	for c in _base_puzzle.holes():
		if not base_cells.has(c):
			return false
	return true


## その日に使う差し替え（なければ null）
func day_variant(d: DayData) -> DayVariant:
	for v in d.variants:
		if v and FlagCondition.met(v.condition):
			return v
	return null


func day_scene_path(d: DayData) -> String:
	var v := day_variant(d)
	return v.scene_path if v and v.scene_path != "" else d.scene_path


## その日の場面の値（時間帯・異界・縁側）を持つもの。差し替えがあればその DayVariant、なければ DayData
func _day_spec(d: DayData) -> Resource:
	var v := day_variant(d)
	return v if v else d


## 異界の日か（神隠しルートの8・9日目）
func is_otherworld(d: DayData) -> bool:
	return _day_spec(d).is_otherworld


## 日付の札・日の切り替わり・看板に出す [月, 日]（文字）。
## date_label_override（「月/日」）があればそれ、異界の日は「？？」、ほかは本当の日付
func day_date(d: DayData) -> Array[String]:
	var o: String = _day_spec(d).date_label_override
	if o != "":
		var parts := o.replace("／", "/").split("/")
		if parts.size() == 2:
			return [parts[0].strip_edges(), parts[1].strip_edges()]
		push_warning("date_label_override は「月/日」の形で書く: " + o)
	if is_otherworld(d):
		return [Strings.DATE_UNKNOWN, Strings.DATE_UNKNOWN]
	return [str(d.month), str(d.day)]


func day_date_text(d: DayData) -> String:
	return Strings.DATE_FULL % day_date(d)


## 宝箱の枠の日付 [月, 日]（本当の日付。異界の日だけ「？？」）
func item_date(d: DayData) -> Array[String]:
	if is_otherworld(d):
		return [Strings.DATE_UNKNOWN, Strings.DATE_UNKNOWN]
	return [str(d.month), str(d.day)]


func day_title(d: DayData) -> String:
	var v := day_variant(d)
	return v.title if v and v.title != "" else d.title


## その日に拾える／もらえるアイテム（ルートの差し替えがあればそちら）
func day_items(d: DayData) -> Array[ItemData]:
	var v := day_variant(d)
	return v.items if v and not v.items.is_empty() else d.items


## その日の時間帯のキー（差し替えがあればそちら。空なら TimeKeys.DEFAULT として扱う）
func day_time_keys(d: DayData) -> Array[Vector2]:
	return _day_spec(d).time_keys


## その日の中の位置（0.0〜1.0）の時間の値（早朝 -0.15／朝 0.00／昼 0.25／夕方 0.60／夜 0.85／夜の終わり 1.00）
func day_time(d: DayData, progress: float) -> float:
	return TimeKeys.sample(day_time_keys(d), progress)


## いまのルート（縁側の場面の返事の選び方など）：&"shinyu"／&"hatsukoi"／&"kamikakushi"／&"normal"
func current_route() -> StringName:
	if has_flag(&"route_natsumi"):
		return &"hatsukoi"
	if has_flag(&"route_takeru"):
		return &"shinyu"
	if has_flag(&"route_kamikakushi"):
		return &"kamikakushi"
	return &"normal"


## 縁側の場面に誰もいない日か：異界の日と、異界に入った日（次の日が異界の日。神隠しルートの7日目）
func engawa_empty(index: int) -> bool:
	if is_otherworld(get_day(index)):
		return true
	return index + 1 < day_count() and is_otherworld(get_day(index + 1))


## 縁側の場面で、返事のあとに足す行（その日の engawa_extra_flag が立っていなければ空）
func engawa_extra_lines(d: DayData) -> Array[String]:
	var spec := _day_spec(d)
	var f: StringName = spec.engawa_extra_flag
	if f == &"" or not has_flag(f):
		return []
	return spec.engawa_extra_lines


## その日に拾って、いま手もとにあるアイテム（縁側の場面で見せるもの）。人に返すもの（extra_items）も持っていれば入れる
func engawa_items(d: DayData) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in day_items(d) + d.extra_items:
		if it and holds(it.id) and not out.has(it):
			out.append(it)
	return out


## いまのフラグで迎えるエンディング（条件に合う最初のもの）
func current_ending() -> EndingData:
	for e in day_list.endings:
		if e and FlagCondition.met(e.condition):
			return e
	return null


## 宝箱に並べる全アイテム（いまのフラグで決まるルートのもの）。
## 人に返すもの（extra_items。なつみの色えんぴつなど）は、持っているあいだだけ、その日の枠のうしろに出す
func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for d in day_list.days:
		out.append_array(day_items(d))
		for it in d.extra_items:
			if it and holds(it.id):
				out.append(it)
	return out


## 拾い逃したか（宝箱の影）：その日を越えた（次の日に入った）のに拾っていない、いまのルートのアイテム。
## まだ来ていない日のもの・手ばなしたもの（あげた・うめた）・枠に数えないもの（色えんぴつ）は影にしない
func is_missed(item: ItemData) -> bool:
	if item == null or is_collected(item.id) or gone.has(item.id) or is_extra(item):
		return false
	var d := day_for_item(item)
	if d == null or not day_items(d).has(item):
		return false
	return day_list.days.find(d) < current_day_index


## 宝箱の枠に数えないもの（extra_items）か
func is_extra(item: ItemData) -> bool:
	for d in day_list.days:
		if d.extra_items.has(item):
			return true
	return false


func day_for_item(item: ItemData) -> DayData:
	for d in day_list.days:
		if d.day_number == item.day_number:
			return d
	return null


## 夏の進み具合（0.0〜1.0）。空の色・環境音などはこの値から決める
func summer_progress(month: int, day: int) -> float:
	var start := _day_of_year(SUMMER_START.x, SUMMER_START.y)
	var end := _day_of_year(SUMMER_END.x, SUMMER_END.y)
	return clampf(float(_day_of_year(month, day) - start) / float(end - start), 0.0, 1.0)


## その日の夏の進み具合。異界の日は、異界に入る直前の日（異界の日でない、いちばん近い前の日）の値で止める
func summer_progress_of(d: DayData) -> float:
	var i := day_list.days.find(d)
	while i > 0 and is_otherworld(get_day(i)):
		i -= 1
	var base := get_day(i) if i >= 0 else d
	return summer_progress(base.month, base.day)


static func _day_of_year(month: int, day: int) -> int:
	var n := day
	for m in range(month - 1):
		n += _MONTH_DAYS[m]
	return n
