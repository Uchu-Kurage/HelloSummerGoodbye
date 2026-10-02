class_name Interactable
extends Area2D
## 近づくと吹き出しが出て、interact（E / タップ）で何かが起きるものの共通の土台。
## アイテム（ItemPickup）と NPC（Npc）がこれを継承する。
## プレイヤーが範囲に入る／出ると HUD（グループ interact_listener）に知らせる。

## 吹き出しを出す高さ（足もとからの距離）
@export var bubble_height := 110.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## いま話しかけられる／拾えるか
func can_interact() -> bool:
	return true


## プレイヤーが動けないとき（バスに乗っているなど）でも使えるか
func works_while_locked() -> bool:
	return false


## 吹き出しの文言（キーボード用・タッチ用）
func bubble_text(touch: bool) -> String:
	return ""


## interact が押されたときの処理。hud はメッセージの表示などに使う
func interact(_hud: Node) -> void:
	pass


## HUD が吹き出しを出す位置（画面座標）
func bubble_screen_position() -> Vector2:
	return get_global_transform_with_canvas() * Vector2(0, -bubble_height)


func notify_left() -> void:
	if is_inside_tree():
		get_tree().call_group("interact_listener", "on_interactable_exited", self)


func _on_body_entered(body: Node) -> void:
	if body is Player and can_interact():
		get_tree().call_group("interact_listener", "on_interactable_entered", self)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		notify_left()


func _exit_tree() -> void:
	notify_left()
