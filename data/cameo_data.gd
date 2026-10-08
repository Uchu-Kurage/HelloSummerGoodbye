class_name CameoData
extends Resource
## 他ルートの人物の顔出し（ルート分岐表「他ルートの人物の顔出し」）。res://data/cameos/*.tres に置くと、それだけで出る。
## 背景に立っているだけか、話しかけると一言だけ返す。フラグ・好感度・話したかどうかの記録は、一切かえない。
## 日のシーンの土台（DayBase）が、その日の分を Props の下に置く（world/cameo.tscn）。

const DIR := "res://data/cameos/"

enum Kind {
	PERSON,   ## 人物。line があれば話しかけると一言だけ返す（なければ立っているだけ）
	GLIMPSE,  ## 一瞬見える姿（お面の子）。近づくと、ゆっくり消える。話しかけられない
	OBJECT,   ## 持ち物だけ（画板・自転車・段ボール箱など。world/scenery_prop.gd の絵）
}

@export var id: StringName
## 出すルート（&"normal"／&"shinyu"／&"hatsukoi"／&"kamikakushi"。GameState.current_route）
@export var route: StringName
## 出す日（DayData.day_number）
@export var day_number := 1
## その日の中の位置（足もとの x。道は y = 604）
@export var x := 0.0
@export var kind: Kind = Kind.PERSON
## 話しかけたときの一言（1行）。ほかの人が言うときは「タケル：…」のように名前を頭に書く。空なら話しかけられない
@export var line := ""
## 追加の条件（お面を選ぶ前だけ、など）。空ならいつでも
@export var appear_if: FlagCondition
@export_group("見た目")
## 人物の見た目（名前・絵・高さ・仮の色）は、各ルートの NpcData を使い回す
@export var npc: NpcData
## 絵だけ差し替える（絵を描いている なつみ、など）。空なら npc の絵（GLIMPSE は遠くのお面の子）
@export var sprite: Texture2D
## 高さ。0 なら npc の高さ
@export var height := 0.0
## 道から奥へずらす量（遠くにいる人・物）。奥ほど小さく、少しかすむ
@export var depth := 0.0
## かたむけて描く（寝ている、など。度）
@export var tilt := 0.0
## OBJECT のときの絵（world/scenery_prop.gd の Kind の番号）
@export var prop_kind := 0
## OBJECT のときの幅（ScenerySprop.width。段ボール箱の山など）
@export var prop_width := 0.0

static var _all: Array[CameoData] = []
static var _loaded := false


## res://data/cameos/ の顔出しをぜんぶ読む（Web 書き出しでは .tres が .tres.remap になるので、その名前も読む）
static func all() -> Array[CameoData]:
	if _loaded:
		return _all
	_loaded = true
	var files := DirAccess.get_files_at(DIR)
	files.sort()
	for f in files:
		var name := f.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var c := load(DIR + name) as CameoData
		if c and not _all.has(c):
			_all.append(c)
	return _all


## その日の顔出し（ルートは問わない。出すかどうかは Cameo が決める）
static func for_day(day_number: int) -> Array[CameoData]:
	var out: Array[CameoData] = []
	for c in all():
		if c.day_number == day_number:
			out.append(c)
	return out


## いまのルートとフラグで出すか
func is_shown() -> bool:
	return route == GameState.current_route() and FlagCondition.met(appear_if)
