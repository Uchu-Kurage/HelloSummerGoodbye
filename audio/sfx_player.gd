extends Node
## 効果音・環境音・BGM を鳴らす（スキル「7. 効果音」）。
## res://audio/sfx/<名前>.ogg（または .wav）があれば鳴らし、なければ無音で通る。環境音・BGM も同じ（ambient/・music/）。
## 環境音と BGM はくり返し鳴らし、切り替えるときはゆっくり入れかえる（クロスフェード）。
## 素材の出典とライセンスは res://CREDITS.md。

const SFX_DIR := "res://audio/sfx/"
const AMBIENT_DIR := "res://audio/ambient/"
const MUSIC_DIR := "res://audio/music/"
## 環境音・BGM の入れかえにかける秒数
const AMBIENT_FADE := 1.2
const MUSIC_FADE := 1.5
## 聞こえない大きさ（フェードの始まりと終わり）
const SILENT_DB := -40.0
## 環境音・BGM の音量のバス（res://default_bus_layout.tres。set_ambient_volume は環境音のバス全体を動かす）
const AMBIENT_BUS := &"Ambient"
const MUSIC_BUS := &"Music"
## BGM のふだんの大きさ（環境音より少し控えめに）
const MUSIC_DB := -6.0
const EXTS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 6
## text_tick を鳴らす間隔（文字数）
const TICK_EVERY := 3

## ブラウザでは最初の操作のあとでないと音が出ないので、タイトルの操作で true にする
var enabled := false
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
## 環境音は2つの再生機を交互に使い、入れかえるときに重ねる
var _ambient: AudioStreamPlayer
var _ambient_old: AudioStreamPlayer
var _ambient_name := ""
var _music: AudioStreamPlayer
var _music_name := ""
var _tick_count := 0
var _volume_tween: Tween
var _ambient_db := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambient = _make_loop_player(AMBIENT_BUS)
	_ambient_old = _make_loop_player(AMBIENT_BUS)
	_music = _make_loop_player(MUSIC_BUS)


func _make_loop_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func unlock() -> void:
	enabled = true
	if _ambient_name != "":
		var n := _ambient_name
		_ambient_name = ""
		set_ambient(n)
	if _music_name != "":
		var m := _music_name
		_music_name = ""
		play_music(m)


## cursor / accept / cancel / pickup / box_open / box_close / day_change / text_tick /
## item_show（縁側の場面でアイテムを見せる）/ whistle（祖父・お面の子の口笛。素材がなければ「♪」の吹き出しだけ）など
## volume_db で大きさを変えられる（カブトムシとりの心臓の音など）
func play(sfx_name: String, volume_db := 0.0) -> void:
	if not enabled:
		return
	var stream := _find(SFX_DIR, sfx_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return


## 文字送りの音。数文字おきに小さく鳴らす
func tick() -> void:
	_tick_count += 1
	if _tick_count % TICK_EVERY == 0:
		play("text_tick")


## いま鳴らしている環境音の名前（縁側の場面が、終わったときにもとの音へもどすため）
func ambient_name() -> String:
	return _ambient_name


## 環境音（蝉の声、縁側の場面の engawa_night など）を切り替える。前の音とゆっくり入れかえる。空文字で止める
func set_ambient(ambient_name: String) -> void:
	if ambient_name == _ambient_name:
		return
	_ambient_name = ambient_name
	# いま鳴っている音を、もう1つの再生機にうつしてフェードアウトする
	var swap := _ambient_old
	_ambient_old = _ambient
	_ambient = swap
	_fade(_ambient_old, SILENT_DB, AMBIENT_FADE, true)
	if not enabled or ambient_name == "":
		return
	var stream := _find(AMBIENT_DIR, ambient_name, true)
	if stream:
		_ambient.stream = stream
		_ambient.volume_db = SILENT_DB
		_ambient.play()
		_fade(_ambient, 0.0, AMBIENT_FADE)


## 環境音の大きさ（dB）。型抜きで削っているあいだ、まわりの音を少し下げるなど。time 秒かけて変える
func set_ambient_volume(db: float, time := 0.0) -> void:
	if _volume_tween:
		_volume_tween.kill()
	if time <= 0.0:
		_set_ambient_bus(db)
		return
	_volume_tween = create_tween()
	_volume_tween.tween_method(_set_ambient_bus, _ambient_db, db, time)


func _set_ambient_bus(db: float) -> void:
	_ambient_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(AMBIENT_BUS), db)


## BGM を鳴らす（タイトル・エンディング）。前の曲とゆっくり入れかえる。空文字で止める
func play_music(music_name: String) -> void:
	if music_name == _music_name and _music.playing:
		return
	_music_name = music_name
	if music_name == "":
		_fade(_music, SILENT_DB, MUSIC_FADE, true)
		return
	if not enabled:
		return
	var stream := _find(MUSIC_DIR, music_name, true)
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = SILENT_DB
	_music.play()
	_fade(_music, MUSIC_DB, MUSIC_FADE)


func stop_music() -> void:
	play_music("")


func music_name() -> String:
	return _music_name


func _fade(p: AudioStreamPlayer, db: float, time: float, stop_after := false) -> void:
	if p.has_meta("tween"):
		var old: Tween = p.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, time)
	if stop_after:
		tw.tween_callback(p.stop)
	p.set_meta("tween", tw)


## looped：環境音・BGM はくり返す
func _find(dir: String, base: String, looped := false) -> AudioStream:
	var key := dir + base
	if _cache.has(key):
		return _cache[key]
	var found: AudioStream = null
	for ext in EXTS:
		var path := "%s%s.%s" % [dir, base, ext]
		if ResourceLoader.exists(path):
			found = load(path)
			break
	if looped and found and "loop" in found:
		found.loop = true
	_cache[key] = found
	return found
