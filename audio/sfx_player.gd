extends Node
## 効果音・環境音を鳴らす枠（スキル「7. 効果音」）。
## res://audio/sfx/<名前>.ogg（または .wav）があれば鳴らし、なければ無音で通る。

const SFX_DIR := "res://audio/sfx/"
const AMBIENT_DIR := "res://audio/ambient/"
const EXTS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 6
## text_tick を鳴らす間隔（文字数）
const TICK_EVERY := 3

## ブラウザでは最初の操作のあとでないと音が出ないので、タイトルの操作で true にする
var enabled := false
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _ambient: AudioStreamPlayer
var _ambient_name := ""
var _tick_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)


func unlock() -> void:
	enabled = true
	if _ambient_name != "":
		var n := _ambient_name
		_ambient_name = ""
		set_ambient(n)


## cursor / accept / cancel / pickup / box_open / box_close / day_change / text_tick
func play(sfx_name: String) -> void:
	if not enabled:
		return
	var stream := _find(SFX_DIR, sfx_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return


## 文字送りの音。数文字おきに小さく鳴らす
func tick() -> void:
	_tick_count += 1
	if _tick_count % TICK_EVERY == 0:
		play("text_tick")


## 環境音（蝉の声など）を切り替える。空文字で止める
func set_ambient(ambient_name: String) -> void:
	if ambient_name == _ambient_name:
		return
	_ambient_name = ambient_name
	_ambient.stop()
	if not enabled or ambient_name == "":
		return
	var stream := _find(AMBIENT_DIR, ambient_name)
	if stream:
		_ambient.stream = stream
		_ambient.play()


func _find(dir: String, base: String) -> AudioStream:
	var key := dir + base
	if _cache.has(key):
		return _cache[key]
	var found: AudioStream = null
	for ext in EXTS:
		var path := "%s%s.%s" % [dir, base, ext]
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_cache[key] = found
	return found
