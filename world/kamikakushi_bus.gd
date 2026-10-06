extends "res://world/bus_departure.gd"
## 帰る日のバス（神隠しルート）。足もと（バス停の前の道）が原点。祖父母の見送りまではほかのルートと同じ。
## 走り出してしばらくすると、ゆっくり走りながら、鈴を振る（@game suzu_furu）。鈴は一度だけ鳴る。
## そのあとはエンディングまで走る。追いかけてくる人はいない。

## 鈴を振る場面（会話の書き方は NpcData と同じ）
@export var bell_lines: Array[String] = ["@game suzu_furu", "ぼく：……"]


## 走り出して BELL_AFTER 進んだところ（親友ルートでは自転車のベルが鳴るところ）で、鈴を振る
func _start_chase() -> void:
	state = State.CATCH
	var me := NpcData.new()
	me.id = &"bus_bell"
	me.display_name = Strings.ME
	me.placeholder_color = WorldPalette.PLAYER_HAT
	await _hud.run_talk(me, bell_lines)
	state = State.AWAY
