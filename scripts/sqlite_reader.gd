extends RefCounted
## Minimální čtečka SQLite souborů (jen čtení tabulek, bez SQL).
## Stačí na Anki kolekce (`collection.anki2` / `collection.anki21`).
## Algoritmus je ověřený proti sqlite3 na reálných .apkg balíčcích.

var data := PackedByteArray()
var page_size := 0
var usable := 0


func open_buffer(buf: PackedByteArray) -> bool:
	if buf.size() < 100:
		return false
	if buf.slice(0, 15).get_string_from_ascii() != "SQLite format 3":
		return false
	data = buf
	page_size = (data[16] << 8) | data[17]
	if page_size == 1:
		page_size = 65536
	usable = page_size - data[20]
	return true


## Vrátí řádky tabulky jako pole { rowid, vals }. Prázdné pole, když tabulka neexistuje.
func table_rows(table_name: String) -> Array:
	var root := _root_page(table_name)
	var out: Array = []
	if root > 0:
		_walk(root, out)
	return out


func _root_page(table_name: String) -> int:
	var schema: Array = []
	_walk(1, schema)
	for row in schema:
		var v: Array = row.vals
		if v.size() >= 4 and v[0] == "table" and v[1] == table_name:
			return int(v[3])
	return 0


func _u16(o: int) -> int:
	return (data[o] << 8) | data[o + 1]


func _u32(o: int) -> int:
	return (data[o] << 24) | (data[o + 1] << 16) | (data[o + 2] << 8) | data[o + 3]


## Vrací [hodnota, nová pozice].
func _varint(buf: PackedByteArray, p: int) -> Array:
	var v := 0
	for i in range(8):
		var b: int = buf[p]
		p += 1
		v = (v << 7) | (b & 0x7f)
		if b < 0x80:
			return [v, p]
	v = (v << 8) | buf[p]
	return [v, p + 1]


func _walk(pgno: int, out: Array) -> void:
	var base := (pgno - 1) * page_size
	var hdr := base + (100 if pgno == 1 else 0)
	var kind: int = data[hdr]
	var n := _u16(hdr + 3)
	if kind == 0x05:  # vnitřní uzel tabulky
		var right := _u32(hdr + 8)
		for i in range(n):
			var cell := base + _u16(hdr + 12 + 2 * i)
			_walk(_u32(cell), out)
		_walk(right, out)
	elif kind == 0x0d:  # list tabulky
		for i in range(n):
			var cell := base + _u16(hdr + 8 + 2 * i)
			var r := _varint(data, cell)
			var psize: int = r[0]
			r = _varint(data, r[1])
			var rowid: int = r[0]
			var payload := _payload(r[1], psize)
			out.append({"rowid": rowid, "vals": _record(payload)})


func _payload(p: int, size: int) -> PackedByteArray:
	var x := usable - 35
	if size <= x:
		return data.slice(p, p + size)
	var m := ((usable - 12) * 32) / 255 - 23
	var k := m + ((size - m) % (usable - 4))
	var local := k if k <= x else m
	var buf := data.slice(p, p + local)
	var overflow := _u32(p + local)
	var remaining := size - local
	while remaining > 0 and overflow != 0:
		var ob := (overflow - 1) * page_size
		var next := _u32(ob)
		var chunk := mini(remaining, usable - 4)
		buf.append_array(data.slice(ob + 4, ob + 4 + chunk))
		remaining -= chunk
		overflow = next
	return buf


func _record(b: PackedByteArray) -> Array:
	var r := _varint(b, 0)
	var header_size: int = r[0]
	var p: int = r[1]
	var types: Array = []
	while p < header_size:
		r = _varint(b, p)
		types.append(r[0])
		p = r[1]
	var q := header_size
	var vals: Array = []
	var int_sizes := {1: 1, 2: 2, 3: 3, 4: 4, 5: 6, 6: 8}
	for t_any in types:
		var t: int = t_any
		if t == 0:
			vals.append(null)
		elif int_sizes.has(t):
			var n: int = int_sizes[t]
			var v := 0
			for j in range(n):
				v = (v << 8) | b[q + j]
			if n < 8 and v >= (1 << (8 * n - 1)):
				v -= 1 << (8 * n)
			vals.append(v)
			q += n
		elif t == 7:
			var raw := b.slice(q, q + 8)
			raw.reverse()
			vals.append(raw.decode_double(0))
			q += 8
		elif t == 8:
			vals.append(0)
		elif t == 9:
			vals.append(1)
		elif t % 2 == 0:
			var n2: int = (t - 12) / 2
			vals.append(b.slice(q, q + n2))
			q += n2
		else:
			var n3: int = (t - 13) / 2
			vals.append(b.slice(q, q + n3).get_string_from_utf8())
			q += n3
	return vals
