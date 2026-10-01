extends SceneTree
## DESIGN.md「11. 10日分の仮データ」から data/ 以下の .tres を作るツール（初回の生成用）。
## 使い方: godot --headless --script res://tools/build_data.gd
## 生成後は .tres をエディタで直接編集して良い（このツールを再実行すると上書きされる）。

const ROWS := [
	[1, 7, 21, "到着の日", "bus_ticket", "バスの切符", "ここまで のった バスの きっぷ。", "#C98F5A"],
	[2, 7, 23, "村を知る日", "marble", "ビー玉", "ぴかぴかの ビー玉。たからもの。", "#7FB6C9"],
	[3, 7, 27, "川の日", "river_stone", "川のきれいな石", "つめたくて、すべすべ。", "#9AA59B"],
	[4, 8, 1, "夕立の日", "cicada_shell", "セミの抜け殻", "木に しがみついた ままだった。", "#B8894E"],
	[5, 8, 6, "夏祭りの日", "festival_mask", "お祭りのお面", "よみせで かってもらった。", "#E0A5A0"],
	[6, 8, 13, "お盆（迎え火）", "senko_hanabi", "線香花火", "さいごまで おちなかった。", "#E3B85A"],
	[7, 8, 16, "お盆（送り火）", "hozuki", "ほおずき", "あかくて、ちょうちんみたい。", "#D9763F"],
	[8, 8, 20, "静かな日", "friend_letter", "友達の置き手紙", "「また らいねん」って かいてあった。", "#E9E1C9"],
	[9, 8, 30, "最後の夜", "straw_hat", "祖父の麦わら帽子", "ちょっと おおきい。", "#D8BC7A"],
	[10, 8, 31, "帰る日", "onigiri_wrap", "おにぎりの包み", "おばあちゃんが にぎってくれた。", "#A9B88E"],
]


func _initialize() -> void:
	var list := DayList.new()
	for r in ROWS:
		var item := ItemData.new()
		item.id = StringName(r[4])
		item.display_name = r[5]
		item.description = r[6]
		item.day_number = r[0]
		item.placeholder_color = Color(r[7])
		var item_path := "res://data/items/%s.tres" % r[4]
		ResourceSaver.save(item, item_path)
		item = load(item_path)

		var day := DayData.new()
		day.day_number = r[0]
		day.month = r[1]
		day.day = r[2]
		day.title = r[3]
		day.scene_path = "res://days/day_%02d.tscn" % r[0]
		day.items = [item]
		var day_path := "res://data/days/day_%02d.tres" % r[0]
		ResourceSaver.save(day, day_path)
		list.days.append(load(day_path))
	print("saved day_list: ", ResourceSaver.save(list, "res://data/day_list.tres"))
	quit()
