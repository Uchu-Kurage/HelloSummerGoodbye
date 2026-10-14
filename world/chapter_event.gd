class_name ChapterEvent
extends Node2D
## 章「あの夏へ」の会話の @event を受けて、場面を動かす。日のシーンの Props の下に置く。
## NEXT_DAY：次の日へ（暗転）／ TITLE_CALL：白くなってタイトルコールへ／ SET_FLAG：フラグを立てる（出る条件のある人が現れる）／
## REVEAL：target の小物をそっと出す／ SFX：音を鳴らす。sfx を指定すれば、どの動作でも鳴らす。

enum Action { NEXT_DAY, TITLE_CALL, SET_FLAG, REVEAL, SFX }

@export var event_name := ""
@export var action: Action = Action.NEXT_DAY
@export var flag: StringName
@export var target: NodePath
@export var sfx := ""


func on_talk_event(n: String) -> void:
	if n != event_name:
		return
	if sfx != "":
		SfxPlayer.play(sfx)
	match action:
		Action.NEXT_DAY:
			_main_call(&"advance_day")
		Action.TITLE_CALL:
			_main_call(&"start_title_call")
		Action.SET_FLAG:
			GameState.set_flag(flag)
		Action.REVEAL:
			var t := get_node_or_null(target) as CanvasItem
			if t:
				t.modulate.a = 0.0
				t.visible = true
				UiAnim.fade(t, 1.0, UiTokens.TIME_PANEL)


func _main_call(method: StringName) -> void:
	var main := get_tree().current_scene
	if main and main.has_method(method):
		main.call(method)
