extends "res://world/bus_departure.gd"
## 帰る日のバス（ノーマルルート）。足もと（バス停の前の道）が原点。祖父母の見送りまではほかのルートと同じ。
## 走り出してしばらくすると、ゆっくり走りながら、うしろの窓から手をふる祖父母が小さくなっていくのを見る（@game bus_window）。
## そのあと、おばあちゃんのおにぎりの包みを開く。追いかけてくる人はいない。そのままエンディングまで走る。

## 窓から見送る場面と、おにぎり（会話の書き方は NpcData と同じ）
@export var window_lines: Array[String] = ["@game bus_window", "@if_has onigiri_wrap onigiri", "@end", "#onigiri",
	"@show onigiri_wrap", "（おにぎりの つつみを ひらいた）", "……すこしだけ、しょっぱい。"]


## 走り出して BELL_AFTER 進んだところ（親友ルートでは自転車のベルが鳴るところ）で、うしろの窓をふりかえる
func _start_chase() -> void:
	state = State.CATCH
	var me := NpcData.new()
	me.id = &"bus_window"
	me.display_name = Strings.ME
	me.placeholder_color = WorldPalette.PLAYER_HAT
	await _hud.run_talk(me, window_lines)
	state = State.AWAY
