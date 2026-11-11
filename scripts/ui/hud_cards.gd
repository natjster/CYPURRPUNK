class_name HudCards
extends Control
## CYPURRPUNK — the ocean-blue BOXES behind the HUD's big middle-of-the-screen text, so it sits in
## the same kind of panel as the weapon box, talk box and arrow label instead of floating loose
## over the game:
##   Banner  ("TUTORIAL COMPLETE!", big news)
##   Popup   ("EXTRACTED / 4 LOOT HOME ($150)": a reward card on the RIGHT, clear of the arrow and your cat)
##   Message ("MAINFRAME +25% -> 100%", short notes)
## Lives at scenes/ui/hud.tscn > HUD > Frame > Middle > Cards (FIRST child of Middle, so the boxes
## are drawn BEHIND the words). Each box is sized to its text every frame and fades with it.
## The look itself (colours, edge, corner brackets) is HudStyle: ui/hud_style.tres.
## Want one of them without a box? Take its name out of Labels below (Inspector).

## Which labels (siblings under Middle, by node name) get a box.
@export var labels: Array[String] = ["Banner", "Popup", "Message"]
## Room between the words and the box edge (HUD units: the screen is 720 tall).
@export var padding: Vector2 = Vector2(22, 10)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for label_name in labels:
		var label := get_parent().get_node_or_null(label_name) as Label
		if label == null or not label.visible or label.text == "" or label.modulate.a <= 0.01:
			continue
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		# How big the words really are (wrapped to the label's width if it wraps).
		var wrap := label.size.x if label.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
		var words := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, wrap, font_size)
		words.y = maxf(words.y, label.get_line_count() * label.get_line_height())
		# Line the box up with the words: centred, or hugging the right / left edge of the label.
		var spare := label.size.x - words.x
		var shift := spare * 0.5
		if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			shift = spare
		elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
			shift = 0.0
		var at := label.position + Vector2(shift, 0.0)
		var box := Rect2(at - padding, words + padding * 2.0)
		# The box fades out together with its words.
		HudStyle.draw_panel(self, box, false, Color(0, 0, 0, 0), label.modulate.a)
