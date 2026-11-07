class_name PriceLabel
extends Control
## A number players decide by, in the display face, with its unit small after it on the same
## baseline ("12 coins"). The number sits centred in a `line_height` px line box, like CSS.

@export var number := "0"
@export var unit := " coins"
@export var number_size := 40
@export var unit_size := 20
@export var line_height := 36.0
@export var baseline_shift := 0.0   # extra px down, when the line box holds a taller strut
@export var centred := false
var color := Color.BLACK
var font: Font

func _ready() -> void:
	if font == null:
		font = InkTheme.display_base
	custom_minimum_size = Vector2(_width(), line_height)

func _width() -> float:
	return font.get_string_size(number, 0, -1, number_size).x + font.get_string_size(unit, 0, -1, unit_size).x

func _draw() -> void:
	var a := font.get_ascent(number_size)
	var d := font.get_descent(number_size)
	var x := (size.x - _width()) / 2.0 if centred else 0.0
	var y := (line_height - (a + d)) / 2.0 + a + baseline_shift
	draw_string(font, Vector2(x, y), number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, color)
	x += font.get_string_size(number, 0, -1, number_size).x
	draw_string(font, Vector2(x, y), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, unit_size, color)
