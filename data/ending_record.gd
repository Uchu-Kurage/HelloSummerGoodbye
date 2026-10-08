class_name EndingRecord
extends RefCounted
## 見たエンディングの記録（DESIGN.md「3. 作らないもの」の例外の、小さなセーブ）。
## user:// の ConfigFile に、ノーマル・親友・初恋・神隠しの4つを真偽値で持つ。それ以外（アイテム・好感度など）は保存しない。
## Web 版では user:// はブラウザ（IndexedDB）に残る。記録を消す操作はつけない。
## 4つすべて見ると、タイトル画面に「それから」が出る。

const PATH := "user://endings.cfg"
const SECTION := "seen"
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


## 4つすべて見たか（「それから」を出す）
static func all_seen() -> bool:
	return seen_count() == ROUTES.size()
