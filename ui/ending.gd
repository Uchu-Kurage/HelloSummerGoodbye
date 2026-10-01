extends Control
## エンディング。宝箱が開き、拾ったアイテムが1つずつ順に現れる。「もういちど」で最初から。

const MAIN_SCENE := "res://world/main.tscn"

@onready var _box: TreasureBox = $TreasureBox
var _list: MenuList


func _ready() -> void:
	$Paper.color = UiTokens.PAPER_DARK
	_box.header_caption.text = Strings.ENDING_TITLE
	_list = MenuList.new()
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.footer.add_child(_list)
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
	var items := _list.items()
	var slot := _box.last_row_slot()
	if slot and items.size() > 0:
		items[0].focus_neighbor_top = items[0].get_path_to(slot)


func _on_retry() -> void:
	if Transition.is_busy():
		return
	GameState.reset()
	Transition.change_scene(MAIN_SCENE)
