extends RefCounted
## Načítá karty z textových exportů Anki ("Notes in Plain Text": .txt / .tsv / .csv)
## z adresáře `anki/` v kořeni projektu. Podadresáře tvoří hierarchii balíčků.
##
## Podporované hlavičky: #separator, #html, #tags column, #deck column.
## Pole v uvozovkách (včetně víceřádkových) jsou podporována.

const EXTENSIONS := ["txt", "tsv", "csv"]


static func anki_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://anki")
	return OS.get_executable_path().get_base_dir().path_join("anki")


## Vrátí pole karet: { front, backs: Array[String], deck, tags: Array, html, title, search }.
static func load_all() -> Array:
	var cards: Array = []
	_scan(anki_dir(), "", cards)
	return cards


static func _scan(dir_path: String, deck_prefix: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	var files: Array = []
	var dirs: Array = []
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			if d.current_is_dir():
				dirs.append(entry)
			else:
				files.append(entry)
		entry = d.get_next()
	d.list_dir_end()
	files.sort()
	dirs.sort()
	for f in files:
		if f.get_extension().to_lower() in EXTENSIONS:
			var base: String = f.get_basename()
			var deck := base if deck_prefix == "" else deck_prefix + "::" + base
			_parse_file(dir_path.path_join(f), deck, out)
	for sub in dirs:
		var sub_deck: String = sub if deck_prefix == "" else deck_prefix + "::" + sub
		_scan(dir_path.path_join(sub), sub_deck, out)


static func _parse_file(path: String, default_deck: String, out: Array) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	if text.begins_with("﻿"):
		text = text.substr(1)

	var sep := "\t"
	if path.get_extension().to_lower() == "csv":
		sep = ","
	var html := false
	var tags_col := -1
	var deck_col := -1

	# Hlavičky (#klíč:hodnota) se čtou před vlastními záznamy.
	var body_lines := PackedStringArray()
	var in_header := true
	for line in text.split("\n"):
		if in_header and line.begins_with("#"):
			var kv := line.substr(1).strip_edges().split(":", true, 1)
			if kv.size() == 2:
				var key := kv[0].strip_edges().to_lower()
				var val := kv[1].strip_edges()
				match key:
					"separator":
						sep = _separator(val)
					"html":
						html = val.to_lower() == "true"
					"tags column":
						tags_col = int(val) - 1
					"deck column":
						deck_col = int(val) - 1
			continue
		in_header = false
		body_lines.append(line)

	for rec in _records("\n".join(body_lines), sep):
		var fields: Array = Array(rec)
		var tags: Array = []
		var deck := default_deck
		# Sloupce tagů a balíčku se musí odebrat od většího indexu.
		var specials: Array = []
		if tags_col >= 0:
			specials.append([tags_col, "tags"])
		if deck_col >= 0:
			specials.append([deck_col, "deck"])
		specials.sort_custom(func(a, b): return a[0] > b[0])
		for s in specials:
			if s[0] < fields.size():
				var v: String = fields[s[0]]
				fields.remove_at(s[0])
				if s[1] == "tags":
					for tg in v.split(" ", false):
						tags.append(tg)
				elif v.strip_edges() != "":
					deck = v.strip_edges()
		if fields.is_empty() or str(fields[0]).strip_edges() == "":
			continue
		var front: String = fields[0]
		var backs: Array = []
		for i in range(1, fields.size()):
			if str(fields[i]).strip_edges() != "":
				backs.append(fields[i])
		var front_plain := plain(front)
		var back_plain := plain(" ".join(backs))
		out.append({
			"front": front,
			"backs": backs,
			"deck": deck,
			"tags": tags,
			"html": html,
			"title": (front_plain.substr(0, 40) + ("  —  " + back_plain.substr(0, 40) if back_plain != "" else "")),
			"search": (front_plain + " " + back_plain + " " + " ".join(tags) + " " + deck).to_lower(),
		})


static func _separator(name: String) -> String:
	match name.to_lower():
		"tab": return "\t"
		"comma": return ","
		"semicolon": return ";"
		"pipe": return "|"
		"space": return " "
		"colon": return ":"
	return name.substr(0, 1) if name.length() > 0 else "\t"


## Rozdělí text na záznamy a pole; respektuje pole v uvozovkách.
static func _records(text: String, sep: String) -> Array:
	var records: Array = []
	var rec := PackedStringArray()
	var field := ""
	var in_q := false
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if in_q:
			if c == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_q = false
			else:
				field += c
		elif c == "\"" and field == "":
			in_q = true
		elif c == sep:
			rec.append(field)
			field = ""
		elif c == "\n" or c == "\r":
			if c == "\r" and i + 1 < n and text[i + 1] == "\n":
				i += 1
			rec.append(field)
			field = ""
			if not (rec.size() == 1 and rec[0] == ""):
				records.append(rec)
			rec = PackedStringArray()
		else:
			field += c
		i += 1
	if field != "" or rec.size() > 0:
		rec.append(field)
		records.append(rec)
	return records


static func _sub(text: String, pattern: String, repl: String) -> String:
	var re := RegEx.create_from_string(pattern)
	return re.sub(text, repl, true)


static func _entities(t: String) -> String:
	return t.replace("&nbsp;", " ").replace("&lt;", "<").replace("&gt;", ">") \
		.replace("&quot;", "\"").replace("&#39;", "'").replace("&amp;", "&")


## Čistý text bez značek (pro seznam a vyhledávání).
static func plain(s: String) -> String:
	var t := _sub(s, "\\[sound:[^\\]]*\\]", "")
	t = _sub(t, "(?i)<br\\s*/?>", " ")
	t = _sub(t, "<[^>]*>", "")
	t = _sub(t, "\\{\\{c\\d+::(.*?)(::.*?)?\\}\\}", "$1")
	t = _entities(t)
	t = _sub(t, "\\s+", " ")
	return t.strip_edges()


## Převod HTML z Anki na BBCode pro RichTextLabel.
static func to_bbcode(s: String, html: bool) -> String:
	var t := _sub(s, "\\[sound:[^\\]]*\\]", "")
	t = t.replace("[", "[lb]")
	t = _sub(t, "\\{\\{c\\d+::(.*?)(::.*?)?\\}\\}", "[color=#8aa4ff]$1[/color]")
	if html:
		t = _sub(t, "(?i)<br\\s*/?>", "\n")
		t = _sub(t, "(?i)</(div|p|li|tr)>", "\n")
		t = _sub(t, "(?i)<(b|strong)>", "[b]")
		t = _sub(t, "(?i)</(b|strong)>", "[/b]")
		t = _sub(t, "(?i)<(i|em)>", "[i]")
		t = _sub(t, "(?i)</(i|em)>", "[/i]")
		t = _sub(t, "(?i)<u>", "[u]")
		t = _sub(t, "(?i)</u>", "[/u]")
		t = _sub(t, "<[^>]*>", "")
		t = _entities(t)
	return t.strip_edges()
