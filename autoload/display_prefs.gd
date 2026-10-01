extends Node
## 画面の大きさと、動きを減らす設定に合わせて表示を調整する（オートロード DisplayPrefs）。
## - スマホ横向きなど小さい画面では基準の大きさを 1024×576 にして、文字とボタンを実寸で大きくする
## - ブラウザで「視差効果を減らす」（prefers-reduced-motion）が有効なら reduced_motion = true

signal changed

var compact := false
var reduced_motion := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reduced_motion = _query_reduced_motion()
	get_tree().root.size_changed.connect(_fit)
	_fit()


## 画面の高さを CSS px 相当（端末の拡大率で割った値）で見て判定する
func _fit() -> void:
	var win := get_tree().root
	var scale := maxf(DisplayServer.screen_get_scale(), 1.0)
	var short_side := minf(win.size.x, win.size.y) / scale
	var want := short_side < UiTokens.COMPACT_SCREEN_HEIGHT
	if want == compact and win.content_scale_size != Vector2i.ZERO:
		return
	compact = want
	win.content_scale_size = UiTokens.COMPACT_BASE_SIZE if compact else UiTokens.BASE_SIZE
	changed.emit()


func _query_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	var v = JavaScriptBridge.eval("(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) ? 1 : 0", true)
	# ブラウザによって数値や真偽値で返るので、どちらでも判定できるようにする
	return typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL] and bool(v)
