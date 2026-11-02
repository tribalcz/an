extends Control
## Anki Reader – tmavé rozhraní: balíčky | seznam karet | detail karty.

const Loader := preload("res://scripts/anki_loader.gd")

const C_BG := Color("#0e1015")
const C_PANEL := Color("#14171e")
const C_RAISED := Color("#1b1f29")
const C_LINE := Color("#252a36")
const C_FG := Color("#e6e9f0")
const C_MUTED := Color("#8a92a6")
const C_FAINT := Color("#5b6275")
const C_ACCENT := Color("#8aa4ff")
const C_ACCENT_BG := Color("#1e2745")

var cards: Array = []
var filtered: Array = []
var cur := -1
var shown := false
var deck_filter := ""

var path_lbl: Label
var tree: Tree
var search: LineEdit
var status_lbl: Label
var list: ItemList
var crumb_lbl: Label
var tags_lbl: Label
var side_lbl: Label
var front_rtl: RichTextLabel
var show_btn: Button
var answer_box: VBoxContainer
var back_rtl: RichTextLabel
var sound_btn: Button
var player: AudioStreamPlayer
var textures := {}


func _ready() -> void:
	theme = _make_theme()
	_build_ui()
	_reload()


# ---------------------------------------------------------------- téma

func _sb(color: Color, radius := 6, border := 0, border_color := Color.TRANSPARENT, pad_h := -1, pad_v := -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	if pad_h >= 0:
		s.content_margin_left = pad_h
		s.content_margin_right = pad_h
	if pad_v >= 0:
		s.content_margin_top = pad_v
		s.content_margin_bottom = pad_v
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Instrument Sans", "Segoe UI", "Noto Sans", "Noto Sans CJK JP", "Yu Gothic", "Meiryo", "sans-serif"])
	t.default_font = sf
	t.default_font_size = 15

	var bold := FontVariation.new()
	bold.base_font = sf
	bold.variation_embolden = 0.8
	t.set_font("bold_font", "RichTextLabel", bold)

	t.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, 10, 1, C_LINE))

	t.set_color("font_color", "Label", C_FG)
	t.set_color("default_color", "RichTextLabel", C_FG)

	# Tlačítka
	t.set_stylebox("normal", "Button", _sb(C_RAISED, 6, 1, C_LINE, 14, 7))
	t.set_stylebox("hover", "Button", _sb(C_ACCENT_BG, 6, 1, C_ACCENT, 14, 7))
	t.set_stylebox("pressed", "Button", _sb(C_ACCENT_BG, 6, 1, C_ACCENT, 14, 7))
	t.set_stylebox("focus", "Button", _sb(Color.TRANSPARENT, 6, 2, C_ACCENT, 14, 7))
	t.set_color("font_color", "Button", C_MUTED)
	t.set_color("font_hover_color", "Button", C_FG)
	t.set_color("font_pressed_color", "Button", C_FG)

	# Vyhledávání
	t.set_stylebox("normal", "LineEdit", _sb(C_RAISED, 6, 1, C_RAISED, 10, 8))
	t.set_stylebox("focus", "LineEdit", _sb(C_RAISED, 6, 1, C_ACCENT, 10, 8))
	t.set_color("font_color", "LineEdit", C_FG)
	t.set_color("font_placeholder_color", "LineEdit", C_FAINT)
	t.set_color("caret_color", "LineEdit", C_ACCENT)
	t.set_color("selection_color", "LineEdit", C_ACCENT_BG)

	# Seznam karet
	t.set_stylebox("panel", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", _sb(C_ACCENT_BG, 6))
	t.set_stylebox("selected_focus", "ItemList", _sb(C_ACCENT_BG, 6))
	t.set_stylebox("hovered", "ItemList", _sb(C_RAISED, 6))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", C_MUTED)
	t.set_color("font_hovered_color", "ItemList", C_FG)
	t.set_color("font_selected_color", "ItemList", C_FG)
	t.set_constant("v_separation", "ItemList", 8)

	# Strom balíčků
	t.set_stylebox("panel", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", _sb(C_ACCENT_BG, 6))
	t.set_stylebox("selected_focus", "Tree", _sb(C_ACCENT_BG, 6))
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_color("font_color", "Tree", C_MUTED)
	t.set_color("font_selected_color", "Tree", C_FG)
	t.set_constant("v_separation", "Tree", 6)

	var line := StyleBoxLine.new()
	line.color = C_LINE
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	return t


# ---------------------------------------------------------------- UI

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rtl(size: int, center: bool) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	return r


func _make_panel(parent: Control, min_w: int, expand: bool) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = min_w
	if expand:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Horní lišta
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	top.add_child(_label("Anki Reader", 22, C_FG))
	path_lbl = _label("", 13, C_MUTED)
	path_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(path_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var reload := Button.new()
	reload.text = "Znovu načíst (F5)"
	reload.focus_mode = Control.FOCUS_NONE
	reload.pressed.connect(_reload)
	top.add_child(reload)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	# Balíčky
	var left := _make_panel(body, 240, false)
	left.add_child(_label("BALÍČKY", 11, C_FAINT))
	tree = Tree.new()
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_on_deck_selected)
	left.add_child(tree)

	# Seznam karet
	var mid := _make_panel(body, 340, false)
	search = LineEdit.new()
	search.placeholder_text = "Hledat v kartách…"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_t): _apply_filter())
	mid.add_child(search)
	status_lbl = _label("", 12, C_FAINT)
	mid.add_child(status_lbl)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.max_text_lines = 1
	list.item_selected.connect(_select)
	list.item_activated.connect(func(_i): _toggle())
	mid.add_child(list)

	# Detail
	var right := _make_panel(body, 0, true)
	var head := HBoxContainer.new()
	right.add_child(head)
	crumb_lbl = _label("", 13, C_MUTED)
	head.add_child(crumb_lbl)
	var hs := Control.new()
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hs)
	tags_lbl = _label("", 13, C_ACCENT)
	head.add_child(tags_lbl)
	right.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)

	var stage := VBoxContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 18)
	scroll.add_child(stage)

	side_lbl = _label("PŘEDNÍ STRANA", 11, C_FAINT)
	side_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(side_lbl)

	front_rtl = _rtl(48, true)
	stage.add_child(front_rtl)

	show_btn = Button.new()
	show_btn.text = "Ukázat odpověď"
	show_btn.focus_mode = Control.FOCUS_NONE
	show_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed"]:
		show_btn.add_theme_stylebox_override(state, _sb(C_ACCENT, 6, 0, Color.TRANSPARENT, 22, 9))
	for col in ["font_color", "font_hover_color", "font_pressed_color"]:
		show_btn.add_theme_color_override(col, C_BG)
	show_btn.pressed.connect(_toggle)
	stage.add_child(show_btn)

	answer_box = VBoxContainer.new()
	answer_box.add_theme_constant_override("separation", 14)
	answer_box.visible = false
	stage.add_child(answer_box)
	answer_box.add_child(HSeparator.new())
	var back_side := _label("ZADNÍ STRANA", 11, C_FAINT)
	back_side.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer_box.add_child(back_side)
	back_rtl = _rtl(22, true)
	back_rtl.add_theme_color_override("default_color", C_MUTED)
	answer_box.add_child(back_rtl)

	sound_btn = Button.new()
	sound_btn.text = "▶  Přehrát zvuk (P)"
	sound_btn.focus_mode = Control.FOCUS_NONE
	sound_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sound_btn.visible = false
	sound_btn.pressed.connect(_play_sound)
	stage.add_child(sound_btn)

	player = AudioStreamPlayer.new()
	add_child(player)

	var hint := _label("Mezerník otočit   ·   ↑ ↓ další karta   ·   P zvuk   ·   F5 znovu načíst", 12, C_FAINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(hint)


# ---------------------------------------------------------------- data

func _reload() -> void:
	textures.clear()
	cards = Loader.load_all()
	path_lbl.text = Loader.anki_dir()
	_build_deck_tree()
	deck_filter = ""
	_apply_filter()


func _build_deck_tree() -> void:
	tree.clear()
	var counts := {}
	for c in cards:
		var parts: PackedStringArray = c.deck.split("::")
		var path := ""
		for p in parts:
			path = p if path == "" else path + "::" + p
			counts[path] = int(counts.get(path, 0)) + 1

	var root := tree.create_item()
	var all_item := tree.create_item(root)
	all_item.set_text(0, "Všechny karty   %d" % cards.size())
	all_item.set_metadata(0, "")

	var items := {}
	var paths := counts.keys()
	paths.sort()  # rodič je vždy kratší prefix, tedy dřív
	for path in paths:
		var parts: PackedStringArray = path.split("::")
		var parent_item: TreeItem = all_item
		if parts.size() > 1:
			parent_item = items[path.substr(0, path.length() - parts[-1].length() - 2)]
		var it := tree.create_item(parent_item)
		it.set_text(0, "%s   %d" % [parts[-1], counts[path]])
		it.set_metadata(0, path)
		items[path] = it
	all_item.select(0)


func _on_deck_selected() -> void:
	var it := tree.get_selected()
	if it == null:
		return
	deck_filter = str(it.get_metadata(0))
	_apply_filter()


func _apply_filter() -> void:
	var q := search.text.strip_edges().to_lower()
	filtered.clear()
	list.clear()
	for c in cards:
		if deck_filter != "" and not (c.deck == deck_filter or c.deck.begins_with(deck_filter + "::")):
			continue
		if q != "" and not c.search.contains(q):
			continue
		filtered.append(c)
		list.add_item(c.title)
	status_lbl.text = "%d z %d karet" % [filtered.size(), cards.size()]
	if not Loader.warnings.is_empty():
		status_lbl.text += "   ⚠ " + " ".join(Loader.warnings)
	if filtered.is_empty():
		cur = -1
		_render()
	else:
		_select(0)


# ---------------------------------------------------------------- karta

func _select(i: int) -> void:
	if filtered.is_empty():
		return
	cur = clampi(i, 0, filtered.size() - 1)
	shown = false
	list.select(cur)
	list.ensure_current_is_visible()
	_render()


func _toggle() -> void:
	if cur < 0:
		return
	shown = not shown
	_render()


func _render() -> void:
	if cur < 0:
		crumb_lbl.text = ""
		tags_lbl.text = ""
		side_lbl.visible = false
		show_btn.visible = false
		answer_box.visible = false
		sound_btn.visible = false
		if cards.is_empty():
			front_rtl.text = "[color=#8a92a6]V adresáři anki/ nejsou žádné karty.\nVlož sem balíček .apkg nebo textový export z Anki (.txt, .tsv, .csv).[/color]"
		else:
			front_rtl.text = "[color=#8a92a6]Nic nenalezeno.[/color]"
		front_rtl.add_theme_font_size_override("normal_font_size", 18)
		return

	front_rtl.add_theme_font_size_override("normal_font_size", 48)
	var c: Dictionary = filtered[cur]
	crumb_lbl.text = str(c.deck).replace("::", "  ›  ")
	tags_lbl.text = "   ".join(c.tags)
	side_lbl.visible = true
	front_rtl.clear()
	front_rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	_append_bb(front_rtl, Loader.to_bbcode(c.front, c.html), c, 160)
	front_rtl.pop()

	back_rtl.clear()
	back_rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	var first := true
	for b in c.backs:
		var bb: String = Loader.to_bbcode(b.text, c.html)
		if bb == "":
			continue
		if not first:
			back_rtl.add_text("\n\n")
		first = false
		if b.name != "":
			back_rtl.push_color(C_FAINT)
			back_rtl.push_font_size(12)
			back_rtl.add_text(str(b.name).to_upper())
			back_rtl.pop()
			back_rtl.pop()
			back_rtl.add_text("\n")
		_append_bb(back_rtl, bb, c, 320)
	back_rtl.pop()

	answer_box.visible = shown
	show_btn.visible = not shown
	sound_btn.visible = not c.sounds.is_empty()


## Přidá BBCode text; značky \u0001jméno\u0002 nahradí obrázkem z balíčku.
func _append_bb(rtl: RichTextLabel, bb: String, card: Dictionary, max_h: int) -> void:
	var parts := bb.split("\u0001")
	rtl.append_text(parts[0])
	for i in range(1, parts.size()):
		var seg: String = parts[i]
		var k := seg.find("\u0002")
		if k < 0:
			rtl.append_text(seg)
			continue
		var tex := _texture(card, seg.substr(0, k))
		if tex != null:
			var h := mini(tex.get_height(), max_h)
			var w := int(round(float(tex.get_width()) * h / tex.get_height()))
			rtl.add_image(tex, w, h)
		else:
			rtl.append_text("[color=#5b6275][obrázek chybí][/color]")
		rtl.append_text(seg.substr(k + 1))


func _texture(card: Dictionary, file_name: String) -> Texture2D:
	var key := str(card.pkg) + "|" + file_name
	if textures.has(key):
		return textures[key]
	var tex: Texture2D = null
	var bytes := Loader.media_bytes(card.pkg, file_name)
	if not bytes.is_empty():
		var img := Image.new()
		var err := ERR_FILE_UNRECOGNIZED
		match file_name.get_extension().to_lower():
			"png":
				err = img.load_png_from_buffer(bytes)
			"jpg", "jpeg":
				err = img.load_jpg_from_buffer(bytes)
			"webp":
				err = img.load_webp_from_buffer(bytes)
			"svg":
				err = img.load_svg_from_buffer(bytes)
		if err == OK:
			tex = ImageTexture.create_from_image(img)
	textures[key] = tex
	return tex


func _play_sound() -> void:
	if cur < 0:
		return
	var c: Dictionary = filtered[cur]
	for sound_name in c.sounds:
		var bytes := Loader.media_bytes(c.pkg, sound_name)
		if bytes.is_empty():
			continue
		match str(sound_name).get_extension().to_lower():
			"mp3":
				var st := AudioStreamMP3.new()
				st.data = bytes
				player.stream = st
				player.play()
				return
			"ogg":
				player.stream = AudioStreamOggVorbis.load_from_buffer(bytes)
				player.play()
				return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		_reload()
		get_viewport().set_input_as_handled()
		return
	if filtered.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_play_sound()
	elif event.is_action_pressed("ui_accept"):
		_toggle()
	elif event.is_action_pressed("ui_down"):
		_select(cur + 1)
	elif event.is_action_pressed("ui_up"):
		_select(cur - 1)
	else:
		return
	get_viewport().set_input_as_handled()
