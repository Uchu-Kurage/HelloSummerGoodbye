@tool
class_name ChapterProp
extends Node2D
## 章「あの夏へ」の仮素材の小物を1つ置く（ChapterArt の絵）。足もとが原点。

@export var kind: ChapterArt.Kind = ChapterArt.Kind.BED:
	set(v):
		kind = v
		queue_redraw()
## 横に広がるもの（住宅地・フェンス・石段）の幅
@export var width := 160.0:
	set(v):
		width = v
		queue_redraw()


func _draw() -> void:
	ChapterArt.draw(self, kind, width)
