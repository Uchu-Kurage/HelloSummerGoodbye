class_name EndingRecord
extends RefCounted
## 見たエンディングの記録（DESIGN.md「3. 作らないもの」の例外の、小さなセーブ）。
## user:// の ConfigFile に、ノーマル・親友・初恋・神隠しの4つを真偽値で持つ。それ以外（アイテム・好感度など）は保存しない。
## Web 版では user:// はブラウザ（IndexedDB）に残る。記録を消す操作はつけない。
## 4つすべて見たか（all_seen）は、章「あの夏へ」を開く条件に使う。タイトルの印（EndingMarks）は見た数だけ出す。
## 章のために、ほかに2つだけ持つ：章を終えたか（chapter_seen）と、親友ルート9日目にタイムカプセルへ入れたアイテムの ID（capsule_item。急で缶から出す）。

const PATH := "user://endings.cfg"
const SECTION := "seen"
## 章「あの夏へ」の記録の置き場所
const CHAPTER_SECTION := "chapter"
## GameState.current_route() の値（初恋は高・中・低のどれでも hatsukoi）
const ROUTES: Array[StringName] = [&"normal", &"shinyu", &"hatsukoi", &"kamikakushi"]

## 読み込み・保存する先（自動の動作確認では、ふだんの記録を消さないよう別のファイルにする）
static var path := PATH


static func _load() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(path)
	return cf


## そのルートのエンディングを見たことにする（エンディングに入った時点で呼ぶ）
static func mark(route: StringName) -> void:
	if not ROUTES.has(route):
		return
	var cf := _load()
	if cf.get_value(SECTION, String(route), false):
		return
	cf.set_value(SECTION, String(route), true)
	var err := cf.save(path)
	if err != OK:
		push_warning("見たエンディングを保存できなかった: %d" % err)


static func has_seen(route: StringName) -> bool:
	return bool(_load().get_value(SECTION, String(route), false))


## 見たエンディングの数（0〜4）
static func seen_count() -> int:
	var cf := _load()
	var n := 0
	for r in ROUTES:
		if cf.get_value(SECTION, String(r), false):
			n += 1
	return n


## 4つすべて見たか（老年期の章を開く条件に使う予定）
static func all_seen() -> bool:
	return seen_count() == ROUTES.size()


## 章「あの夏へ」を最後まで遊んだことにする
static func mark_chapter_seen() -> void:
	var cf := _load()
	cf.set_value(CHAPTER_SECTION, "seen", true)
	_save(cf)


static func chapter_seen() -> bool:
	return bool(_load().get_value(CHAPTER_SECTION, "seen", false))


## 章がこのあと始まるか（4つすべて見ていて、まだ終えていない）
static func chapter_pending() -> bool:
	return all_seen() and not chapter_seen()


## 親友ルート9日目にタイムカプセルへ入れたアイテムを記録する（何度か遊んだら、最後のもの）
static func set_capsule_item(id: StringName) -> void:
	var cf := _load()
	cf.set_value(CHAPTER_SECTION, "capsule_item", String(id))
	_save(cf)


## 記録したタイムカプセルのアイテムの ID（記録がなければ空）
static func capsule_item() -> StringName:
	return StringName(String(_load().get_value(CHAPTER_SECTION, "capsule_item", "")))


static func _save(cf: ConfigFile) -> void:
	var err := cf.save(path)
	if err != OK:
		push_warning("見たエンディングの記録を保存できなかった: %d" % err)
