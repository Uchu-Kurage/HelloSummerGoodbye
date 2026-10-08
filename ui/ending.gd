extends Control
## エンディング。宝箱が開き、拾ったアイテムが1つずつ順に現れる。「もういちど」で最初から。
## 入った時点で、見たエンディングを記録する（EndingRecord）。
## エピローグ「それから」のときは、全ルートのアイテムをそろった状態で並べ（ページ送り）、「タイトルへ」でもどる。

const MAIN_SCENE := "res://world/main.tscn"
const ENDING_MUSIC := "ending"
const TITLE_SCENE := "res://ui/title.tscn"

@onready var _box: TreasureBox = $TreasureBox
var _list: MenuList


func _ready() -> void:
	$Paper.color = UiTokens.PAPER_DARK
	# 夏の音を静かに閉じて、エンディングの曲に入れかえる
	SfxPlayer.set_ambient("")
	SfxPlayer.play_music(ENDING_MUSIC)
	_list = MenuList.new()
	_list.vertical = false
	_list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_box.footer.add_child(_list)
	_box.header_caption.theme_type_variation = &"EndingTitleLabel"
	if GameState.epilogue:
		_box.header_caption.text = Strings.EPILOGUE_TITLE
		_box.show_all(GameState.every_item())
		_add_item(Strings.EPILOGUE_TO_TITLE, _on_title)
	else:
		# 見たエンディングを記録する（初恋は高・中・低のどれでも）
		EndingRecord.mark(GameState.current_route())
		var ending := GameState.current_ending()
		_box.header_caption.text = ending.title if ending and ending.title != "" else Strings.ENDING_TITLE
		_box.ending_message = ending.message if ending else ""
		_add_item(Strings.ENDING_RETRY, _on_retry)
	_list.modulate.a = 0.0
	_box.reveal_finished.connect(_on_revealed)
	await get_tree().process_frame
	_box.open()


func _add_item(text: String, cb: Callable) -> void:
	var b: MenuItem = preload("res://ui/components/menu_item.tscn").instantiate()
	b.text = text
	b.pressed.connect(cb)
	_list.add_child(b)


func _on_revealed() -> void:
	UiAnim.fade(_list, 1.0, UiTokens.TIME_PANEL)
	_list.activate()
	# 「もういちど」は缶の右上。下へ移動すると宝箱の枠に入れる
	var items := _list.items()
	var slot := _box.first_slot()
	if slot and items.size() > 0:
		items[0].focus_neighbor_bottom = items[0].get_path_to(slot)


func _on_title() -> void:
	if Transition.is_busy():
		return
	GameState.reset()
	SfxPlayer.stop_music()
	Transition.change_scene(TITLE_SCENE)


func _on_retry() -> void:
	if Transition.is_busy():
		return
	GameState.reset()
	SfxPlayer.stop_music()
	Transition.change_scene(MAIN_SCENE)
