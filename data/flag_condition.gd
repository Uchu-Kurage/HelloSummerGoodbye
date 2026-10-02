class_name FlagCondition
extends Resource
## フラグの条件。NPC の出る・出ない、日の場面の差し替え、エンディングの選び方に使う。
## require_all のフラグが全部立っていて、forbid_any のフラグがどれも立っていないときに成り立つ。

@export var require_all: Array[StringName] = []
@export var forbid_any: Array[StringName] = []


func is_met() -> bool:
	for f in require_all:
		if not GameState.has_flag(f):
			return false
	for f in forbid_any:
		if GameState.has_flag(f):
			return false
	return true


## 条件が空（null）なら、いつでも成り立つ
static func met(c: FlagCondition) -> bool:
	return c == null or c.is_met()
