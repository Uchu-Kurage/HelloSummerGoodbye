class_name EngawaReply
extends Resource
## 縁側の場面の返事（DESIGN.md「5. ワールドと日の構成」）。res://data/engawa/*.tres に置くと、それだけで縁側の場面に出る。
## 探す順番：同じ item_id で route が一致するもの → route が空のもの → 見つからなければ「なんにも」の返事（item_id が空のもの）

const DIR := "res://data/engawa/"

## 対象のアイテム。空なら「なんにも」のときの返事
@export var item_id: StringName
## 対象のルート（&"normal"／&"shinyu"／&"hatsukoi"／&"kamikakushi"。GameState.current_route）。空なら全ルート共通
@export var route: StringName
## 表示する行。話し手は行の頭に書く（例：「おじいちゃん：いい いしだ。」「ぼく：うん」）
@export var lines: Array[String] = []

static var _all: Array[EngawaReply] = []
static var _loaded := false


## res://data/engawa/ の返事をぜんぶ読む（Web 書き出しでは .tres が .tres.remap になるので、その名前も読む）
static func all() -> Array[EngawaReply]:
	if _loaded:
		return _all
	_loaded = true
	var files := DirAccess.get_files_at(DIR)
	files.sort()
	for f in files:
		var name := f.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var r := load(DIR + name) as EngawaReply
		if r and not _all.has(r):
			_all.append(r)
	return _all


## アイテム（null なら「なんにも」）とルートに合う返事
static func find(item_id: StringName, route: StringName) -> EngawaReply:
	var list := all()
	if item_id != &"":
		for r in list:
			if r.item_id == item_id and r.route == route:
				return r
		for r in list:
			if r.item_id == item_id and r.route == &"":
				return r
	for r in list:
		if r.item_id == &"" and (r.route == route or r.route == &""):
			return r
	return null
