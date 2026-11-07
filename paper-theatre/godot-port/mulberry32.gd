extends RefCounted
## mulberry32, bit for bit as the web demo's: the same seed tears the same paper edges.

var _a := 0

func _init(seed: int) -> void:
	_a = seed & 0xFFFFFFFF

static func _imul(x: int, y: int) -> int:
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF

func next() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := _imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
