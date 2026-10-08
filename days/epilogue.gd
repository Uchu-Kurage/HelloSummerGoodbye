extends DayBase
## エピローグ「それから」（8/31。タイトルの「それから」から、この1日だけを遊ぶ）。
## 左から：バス停 → 村の通り → 公民館 → 神社 → 秘密基地 → 祖父母の家。アイテムは置かない（DayData の items が空）。
## 1. 祠の前を通ると、ポケットの鈴が一度だけ鳴る（既存の鈴の音 suzu）
## 4. 神社：近づくと、お面の子と麦わら帽子の男の子が石段を駆け上がり、鳥居のむこうで消える（EpilogueKids）
## 5. 秘密基地：背中を向けてしゃがむ男が「……おそいぞ、とかいもん。」（近づくと自動。主人公は答えずに通り過ぎる）
## 6. 祖父母の家：おばあちゃんの会話のあと、主人公の「……ただいま」。会話の @event epilogue_box で、最後の宝箱へ
## 4・5・6 は近づくと自動で始まり、決定キー・タップで早送りできる。

## 鈴が鳴る位置（祠の前）
@export var bell_x := 590.0
## 神社の二人が駆け上がりはじめる、主人公の位置
@export var kids_from_x := 1950.0

var bell_rang := false
var _player: Node2D
@onready var _kids: Node2D = $Props/Kids


func _process(_delta: float) -> void:
	if preview:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var x := _player.global_position.x - global_position.x
	if not bell_rang and x >= bell_x:
		bell_rang = true
		SfxPlayer.play("suzu")
	if x >= kids_from_x and not _kids.started:
		_kids.start()


func _unhandled_input(event: InputEvent) -> void:
	# 神社の二人の演出は、決定キー・タップで早送り
	if _kids.started and not _kids.done and NatsumiScreen.is_tap(event):
		_kids.speed = UiTokens.SKIP_SPEED


func on_talk_event(event_name: String) -> void:
	super(event_name)
	if event_name == "epilogue_box":
		var main := get_tree().current_scene
		if main and main.has_method("finish_epilogue"):
			main.finish_epilogue()
