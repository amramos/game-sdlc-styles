extends Control
## Port of loud-ink-cast-quiet-stage/demo.html?frame=key-scene (night palette).
## The stage and the cast are the entry's generated images; the engine draws only the interface.
## 1280x720 base, stretch canvas_items; every coordinate is the demo's.

const PAL := InkTheme.NIGHT
const LINE := "Eight coins. That bowl is half steam."
const CHIPS := [["↺", "Regular", 1]]
const OPTIONS := [["Hold firm", "Stay at the price", "12"], ["Meet them", "Split the difference", "10"],
	["Sweeten", "Add a skewer", "12"]]
const FOCUSED := 1

var ink := Color(PAL.ink)
var paper := Color(PAL.paper)
var cards: Array[Control] = []
var bubble: SpeechBubble
var chips: HBoxContainer
var focus_mark: FocusBrackets

func _ready() -> void:
	theme = InkTheme.build(PAL)
	_build_stage()
	var ui := Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(PRESET_FULL_RECT)
	ui.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(ui)
	_build_offer(ui)
	_build_line(ui)
	var options := _build_options(ui)
	_build_action(ui)
	focus_mark = FocusBrackets.new()
	focus_mark.paper = paper
	focus_mark.ink = ink
	focus_mark.mouse_filter = MOUSE_FILTER_IGNORE
	ui.add_child(focus_mark)
	await get_tree().process_frame           # containers have laid out
	await _layout_options(options)
	_place_chips()
	set_focus(FOCUSED, false)

# ---------------------------------------------------------------- stage: images only, quiet
func _build_stage() -> void:
	var stage := Control.new()
	stage.name = "Stage"
	stage.set_anchors_preset(PRESET_FULL_RECT)
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage)
	var back := TextureRect.new()
	back.name = "Backdrop"
	back.texture = load("res://cast/stage-stall-night.png")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED   # CSS object-fit: cover
	back.position = Vector2(-20, -70)
	back.size = Vector2(1320, 880)
	stage.add_child(back)
	var actor := TextureRect.new()
	actor.name = "Customer"
	actor.texture = load("res://cast/customer-haggling.png")
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor.stretch_mode = TextureRect.STRETCH_SCALE
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # shown at 0.57x; mipmaps measured softer than the browser
	var h := 500.0
	actor.size = Vector2(h * actor.texture.get_width() / actor.texture.get_height(), h)
	actor.position = Vector2(150, 118)
	actor.pivot_offset = Vector2(actor.size.x / 2.0, h)   # idle bob scales from the feet
	stage.add_child(actor)
	var counter := Panel.new()
	counter.name = "Counter"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAL.counter)
	sb.border_color = ink
	sb.border_width_top = 4
	counter.add_theme_stylebox_override("panel", sb)
	counter.position = Vector2(0, 536)
	counter.size = Vector2(1280, 184)
	stage.add_child(counter)

# ---------------------------------------------------------------- helpers
func label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if variation.ends_with("Caption") or variation in ["Who", "ChipWord"]:
		l.uppercase = true
	return l

## Tilted labels live in a plain slot: containers reset rotation, the slot doesn't.
func tilt(node: Control, degrees: float) -> void:
	var centre := func(): node.pivot_offset = node.size / 2.0   # rotate about the centre, like CSS
	node.resized.connect(centre)
	centre.call_deferred()
	node.rotation_degrees = degrees

# ---------------------------------------------------------------- their offer: a tilted tag
func _build_offer(ui: Control) -> void:
	var tag := PanelContainer.new()
	tag.name = "Offer"
	tag.theme_type_variation = "TagPanel"
	tag.position = Vector2(36, 30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	tag.add_child(col)
	var cap := label("Their offer", "Caption")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var num := PriceLabel.new()
	num.number = "8"
	num.number_size = 58
	num.unit_size = 26
	num.line_height = 52.2
	num.centred = true
	num.color = ink
	col.add_child(num)
	ui.add_child(tag)
	tilt(tag, -3.0)

# ---------------------------------------------------------------- the line, pointing at the speaker
func _build_line(ui: Control) -> void:
	var box := Control.new()
	box.name = "Line"
	box.position = Vector2(600, 110)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	ui.add_child(box)
	var shadow := ColorRect.new()                 # halftone shadow: under the panel, over the stage
	shadow.name = "HalftoneShadow"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://halftone.gdshader")
	mat.set_shader_parameter("dot_color", Color(PAL.shadow))
	shadow.material = mat
	box.add_child(shadow)
	bubble = SpeechBubble.new()
	bubble.paper = paper
	bubble.ink = ink
	bubble.custom_minimum_size.x = 600
	bubble.add_theme_stylebox_override("panel", InkTheme.panel(paper, ink, 4, Vector4(12, 18, 12, 12)))
	var text := label(LINE, "Line")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_child(text)
	box.add_child(bubble)
	bubble.resized.connect(func():
		# the shadow box is the panel's padding box moved 8 px down-right and grown 12 px (CSS ::before)
		shadow.position = Vector2(12, 12)
		shadow.size = bubble.size - Vector2(4, 4)
		mat.set_shader_parameter("rect_size", shadow.size)
		_place_chips())
	var who := PanelContainer.new()
	who.name = "Who"
	who.theme_type_variation = "WhoPanel"
	who.position = Vector2(-6, -22)                # CSS left:-10px top:-26px from the padding edge
	who.add_child(label("Pell", "Who"))
	box.add_child(who)
	tilt(who, -3.0)
	chips = HBoxContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override("separation", 10)
	for c in CHIPS:
		chips.add_child(_chip(c[0], c[1], c[2]))
	ui.add_child(chips)

## A signal chip: its own fill, ink text, and the kind in a word plus a mark (never colour alone).
func _chip(mark: String, word: String, kind: int) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "Chip%d" % kind
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	chip.add_child(row)
	var m := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ink
	m.add_theme_stylebox_override("panel", sb)
	m.custom_minimum_size = Vector2(24, 24)
	m.size_flags_vertical = SIZE_SHRINK_CENTER
	var ml := label(mark, "Mark")
	ml.set_anchors_preset(PRESET_FULL_RECT)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.add_child(ml)
	row.add_child(m)
	var wl := label(word, "ChipWord")
	wl.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(wl)
	return chip

func _place_chips() -> void:
	if chips and bubble:
		chips.position = Vector2(600, 110 + bubble.size.y + 20)   # under the line, wherever its text ends

# ---------------------------------------------------------------- the player's options on the counter
func _build_options(ui: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Options"
	row.add_theme_constant_override("separation", 22)
	ui.add_child(row)
	for o in OPTIONS:
		var slot := Control.new()                 # the container lays out the slot; the card lifts inside it
		slot.size_flags_vertical = SIZE_SHRINK_END
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.focus_mode = FOCUS_ALL
		card.custom_minimum_size = Vector2(190, 118)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		card.add_child(col)
		var cap := label(o[0], "CardCaption")
		cap.modulate.a = 0.9
		col.add_child(cap)
		col.add_child(_gap(4))
		var txt := label(o[1], "CardText")
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.custom_minimum_size.x = 158
		col.add_child(txt)
		col.add_child(_gap(6))
		var num := PriceLabel.new()
		num.number = o[2]
		num.line_height = 39.0                    # the number's line box, with the body face's strut
		                                          # (containers lay out in whole px: 2 x 23 + 39 = the web's 45.6 + 39.4)
		num.baseline_shift = -1.0
		num.color = ink
		col.add_child(num)
		slot.add_child(card)
		row.add_child(slot)
		cards.append(card)
		var i := cards.size() - 1
		card.mouse_entered.connect(func(): set_focus(i))
		card.focus_entered.connect(func(): set_focus(i))
	return row

## Each card keeps its own height (min 118); the row sits 26 px above the bottom, cards bottom-aligned.
func _layout_options(row: HBoxContainer) -> void:
	for c in cards:
		c.size = c.get_combined_minimum_size()
		c.get_parent().custom_minimum_size = c.size
		c.pivot_offset = c.size / 2.0
	await get_tree().process_frame
	row.size = row.get_combined_minimum_size()
	row.position = Vector2(28, 720 - 26 - row.size.y).round()

func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = h
	return g

## The focused card lifts (12 px up, x1.06) and the brackets close in around it.
func set_focus(i: int, animate := true) -> void:
	for j in cards.size():
		var lifted := j == i
		var face := cards[j]
		if animate:
			var tw := face.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(face, "position:y", -12.0 if lifted else 0.0, 0.08)
			tw.tween_property(face, "scale", Vector2.ONE * (1.06 if lifted else 1.0), 0.08)
		else:
			face.position.y = -12.0 if lifted else 0.0
			face.scale = Vector2.ONE * (1.06 if lifted else 1.0)
	var c := cards[i]
	var slot := c.get_parent() as Control
	var sz := c.size * 1.06
	var centre := slot.global_position + c.size / 2.0 + Vector2(0, -12)
	focus_mark.show_around(Rect2(centre - sz / 2.0, sz), animate)

# ---------------------------------------------------------------- the primary action
func _build_action(ui: Control) -> void:
	var act := Button.new()
	act.name = "Act"
	act.text = "OFFER"
	act.focus_mode = FOCUS_NONE
	var shade := ColorRect.new()                  # hard offset shadow in the accent, no blur
	shade.color = Color(PAL.accent)
	shade.show_behind_parent = true
	shade.position = Vector2(6, 6)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	act.add_child(shade)
	ui.add_child(act)
	await get_tree().process_frame
	act.size = act.get_combined_minimum_size()
	shade.size = act.size
	act.position = Vector2(1280 - 40, 720 - 44) - act.size
