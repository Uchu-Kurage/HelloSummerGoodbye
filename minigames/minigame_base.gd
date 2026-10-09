class_name MinigameBase
extends NatsumiScreen
## すべてのミニゲーム（16種類）の共通の土台（ルート分岐表「ミニゲームの共通の決まり」）。
## - 始める前：1行の説明（intro_text）と操作の絵。決定・タップで始まる（MinigameFrame）
## - 入力は左右と決定だけ（押し続け・スワイプは使わない）。継承した画面は _left / _right / _accept を書く。
##   タッチは、画面のどこかをタップ＝決定。arrows = true のミニゲームは、下の左右の矢印＝左右キー。
##   選択肢の枠（make_choice）を並べるミニゲームは、枠をタップ・矢印キーと決定で選ぶ（GUI のフォーカス）
## - Esc／「もどる」でいつでもやめられる。やめたら「ふつう」（それまでにおわった回があれば、その結果）
## - おわったら end_game(よくできたか)。「つぎへ」「もういちど」。何度やり直しても、記録するのは最初の1回（grade）
## - 「よくできた」の条件は、継承した画面の GOOD_ で始まる定数（仮の値。遊んでみて調整する）
## - 30秒〜1分で終わるようにする
## 継承した画面の書き方：_setup()（部品を作る。1回だけ）→ _begin()（1回ぶんを始める。もういちどでも呼ばれる）→
## _process_game(delta)（遊んでいるあいだ）→ end_game()。

enum State { INTRO, PLAY, RESULT }

var state := State.INTRO
## 始める前の1行の説明
var intro_text := ""
## タッチのとき、左右の矢印を出すか
var arrows := false
## 遊んだ回数（もういちど で増える）
var round_count := 0
## 最初の回の結果（まだなら -1）
var first_grade := -1
## 記録する値（石切りの跳ねた回数など。最初の回のもの。なければ -1）
var grade_value := -1
## 途中でやめたか
var quit_by_player := false
var frame: MinigameFrame


func _build() -> void:
	_setup()
	frame = MinigameFrame.new()
	add_child(frame)
	frame.start_requested.connect(start)
	frame.quit_requested.connect(quit)
	frame.left_pressed.connect(func(): if state == State.PLAY: _left())
	frame.right_pressed.connect(func(): if state == State.PLAY: _right())
	frame.next_requested.connect(func(): finish())
	frame.retry_requested.connect(retry)
	frame.set_arrows(false)
	_show_intro.call_deferred()


## 始める前の説明を出す（並べ終わってから。もう始まっていたら出さない）
func _show_intro() -> void:
	if state == State.INTRO and not done:
		frame.show_intro(intro_text)


## 部品を作る（1回だけ）
func _setup() -> void:
	pass


## 1回ぶんを始める（もういちど でも呼ばれる。状態をもどす）
func _begin() -> void:
	pass


func _left() -> void:
	pass


func _right() -> void:
	pass


## 決定（キーボードの Space／決定、タッチのタップ）。pos はタップした位置（キーボードなら null）
func _accept(_pos: Variant = null) -> void:
	pass


## 遊んでいるあいだ（state == PLAY）の毎フレーム
func _process_game(_delta: float) -> void:
	pass


## 途中でやめたとき（記録の値を「ふつう」にそろえるなど）
func _on_quit() -> void:
	pass


## 始める（始める前の説明を閉じる）
func start() -> void:
	if state != State.INTRO:
		return
	frame.hide_intro()
	_play()


func _play() -> void:
	state = State.PLAY
	speed = 1.0
	round_count += 1
	frame.set_arrows(arrows)
	_begin()


## もういちど（記録は最初の回のまま）
func retry() -> void:
	if state != State.RESULT:
		return
	frame.hide_result()
	hush()
	_play()


## おわり。最初の回だけ結果を記録する
func end_game(good: bool, value := -1) -> void:
	if state != State.PLAY:
		return
	state = State.RESULT
	frame.set_arrows(false)
	hide_hint()
	if first_grade < 0:
		first_grade = GameState.Grade.GOOD if good else GameState.Grade.NORMAL
		grade = first_grade
		grade_value = value
	frame.show_result.call_deferred()


## やめる（Esc／「もどる」）。それまでにおわった回がなければ「ふつう」
func quit() -> void:
	if done:
		return
	if state != State.RESULT and first_grade < 0:
		quit_by_player = true
		grade = GameState.Grade.NORMAL
		_on_quit()
	finish()


func _process(delta: float) -> void:
	if state == State.PLAY and not done:
		_process_game(delta * speed)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		quit()
		get_viewport().set_input_as_handled()
		return
	match state:
		State.INTRO:
			if is_tap(event) and not _on_button(event):
				# 説明が出てすぐの押し（会話を送った押しの続き）では始めない
				if frame.intro_ready():
					start()
				get_viewport().set_input_as_handled()
		State.PLAY:
			if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
				_left()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
				_right()
				get_viewport().set_input_as_handled()
			elif is_tap(event) and not _on_button(event):
				var pos: Variant = event.position if (event is InputEventScreenTouch or event is InputEventMouseButton) else null
				_accept(pos)
				get_viewport().set_input_as_handled()


## タップした場所が、ボタン（もどる・矢印・選択肢の枠）の上か
func _on_button(event: InputEvent) -> bool:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return false
	var pos: Vector2 = event.position
	if frame.over_button(pos):
		return true
	return _over_choice(self, pos)


func _over_choice(n: Node, pos: Vector2) -> bool:
	for c in n.get_children():
		if c is BaseButton and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(pos):
			return true
		if c is Control and c != frame and _over_choice(c, pos):
			return true
	return false


# --- 共通の部品 -------------------------------------------------------------------

## 往復するゲージの位置（0〜1）。t は経過秒、period は片道の秒数
static func swing(t: float, period: float) -> float:
	var k := fposmod(t / period, 2.0)
	return k if k <= 1.0 else 2.0 - k


## ゲージを描く（横向き）。r の中に、good_from〜good_to（0〜1）の範囲を ACCENT で、いまの位置 at を INK の印で
func draw_gauge(r: Rect2, at: float, good_from: float, good_to: float, vertical := false) -> void:
	draw_rect(r, UiTokens.PAPER)
	draw_rect(r, UiTokens.INK_SOFT, false, 2.0)
	if vertical:
		draw_rect(Rect2(r.position.x, r.end.y - r.size.y * good_to, r.size.x, r.size.y * (good_to - good_from)), Color(UiTokens.ACCENT, 0.55))
		var y := r.end.y - r.size.y * at
		draw_rect(Rect2(r.position.x - 6, y - 3, r.size.x + 12, 6), UiTokens.INK)
	else:
		draw_rect(Rect2(r.position.x + r.size.x * good_from, r.position.y, r.size.x * (good_to - good_from), r.size.y), Color(UiTokens.ACCENT, 0.55))
		var x := r.position.x + r.size.x * at
		draw_rect(Rect2(x - 3, r.position.y - 6, 6, r.size.y + 12), UiTokens.INK)


## 絵を、足もと foot・高さ h で描く（flip で左右反転）
func draw_sprite(tex: Texture2D, foot: Vector2, h: float, flip := false, alpha := 1.0) -> void:
	var w := tex.get_width() * h / tex.get_height()
	if flip:
		draw_set_transform(foot, 0.0, Vector2(-1, 1))
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -h), Vector2(w, h)), false, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, Rect2(foot + Vector2(-w / 2.0, -h), Vector2(w, h)), false, Color(1, 1, 1, alpha))


## 自動の動作確認用：いま押すとよい（good）／わるい入力。{"key": KEY_SPACE など, "tap": 画面の位置} か、待つなら {}
func bot(_good: bool) -> Dictionary:
	return {}


## 画面のまん中あたり（タップで決定するときの位置）
func center_tap() -> Vector2:
	return get_global_rect().get_center() + Vector2(0, -size.y * 0.1)
