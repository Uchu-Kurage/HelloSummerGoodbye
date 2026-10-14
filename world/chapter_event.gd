class_name ChapterEvent
extends Node2D
## 章「あの夏へ」の会話の @event を受けて、場面を動かす。日のシーンの Props の下に置く。
## NEXT_DAY：次の日へ（暗転）／ TITLE_CALL：白くなってタイトルコールへ／ SET_FLAG：フラグを立てる（出る条件のある人が現れる）／
## REVEAL：target の小物をそっと出す／ SFX：音を鳴らす／ TAKERU_PHOTO：タケルが写真を撮る／ WHITE_OUT：白くなって next_scene へ。sfx を指定すれば、どの動作でも鳴らす。

enum Action { NEXT_DAY, TITLE_CALL, SET_FLAG, REVEAL, SFX, TAKERU_PHOTO, WHITE_OUT }

@export var event_name := ""
@export var action: Action = Action.NEXT_DAY
@export var flag: StringName
@export var target: NodePath
@export var sfx := ""
## TAKERU_PHOTO：タケルが撮る写真の ID（フィルムは減らさない）
@export var photo_id: StringName
## WHITE_OUT：白くなったあとに読み込む画面
@export_file("*.tscn") var next_scene := ""


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
		Action.TAKERU_PHOTO:
			GameState.take_takeru_photo(GameState.photo_data(photo_id))
		Action.WHITE_OUT:
			var main := get_tree().current_scene
			if main and main.has_method(&"start_white_out"):
				main.call(&"start_white_out", next_scene)
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
