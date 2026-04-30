extends RefCounted
class_name TsvIo


func write_rows(path: String, headers: Array, rows: Array) -> Dictionary:
	var normalized_path := _normalize_path(path)
	_ensure_parent_directory(normalized_path)
	var lines: Array[String] = []
	lines.append(_build_line(headers))
	for row in rows:
		lines.append(_build_row_line(headers, row))
	var file := FileAccess.open(normalized_path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"errors": ["Failed to open TSV output path: %s" % normalized_path],
		}
	file.store_string("\n".join(lines))
	return {
		"ok": true,
		"path": normalized_path,
		"errors": [],
	}


func read_rows(path: String) -> Dictionary:
	var normalized_path := _normalize_path(path)
	if not FileAccess.file_exists(normalized_path):
		return {
			"ok": false,
			"headers": [],
			"rows": [],
			"errors": ["TSV file does not exist: %s" % normalized_path],
		}
	var file := FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"headers": [],
			"rows": [],
			"errors": ["Failed to open TSV file: %s" % normalized_path],
		}
	return parse_tsv_text(file.get_as_text(), normalized_path)


func parse_tsv_text(text: String, source_label := "<memory>") -> Dictionary:
	var errors: Array[String] = []
	var normalized_text := text.replace("\r\n", "\n").replace("\r", "\n")
	var lines := normalized_text.split("\n", true)
	while not lines.is_empty() and str(lines[lines.size() - 1]).is_empty():
		lines.remove_at(lines.size() - 1)
	if lines.is_empty():
		return {
			"ok": false,
			"headers": [],
			"rows": [],
			"errors": ["TSV file is empty: %s" % source_label],
		}
	var headers := _parse_line(str(lines[0]))
	if headers.is_empty():
		errors.append("TSV header row is empty: %s" % source_label)
	var rows: Array[Dictionary] = []
	for index in range(1, lines.size()):
		var raw_line := str(lines[index])
		if raw_line.is_empty():
			continue
		var values := _parse_line(raw_line)
		if values.size() > headers.size():
			errors.append("%s row %d has more columns than the header." % [source_label, index + 1])
		while values.size() < headers.size():
			values.append("")
		var row: Dictionary = {
			"__row_number": index + 1,
		}
		for header_index in range(headers.size()):
			row[headers[header_index]] = values[header_index]
		rows.append(row)
	return {
		"ok": errors.is_empty(),
		"headers": headers,
		"rows": rows,
		"errors": errors,
	}


func _build_line(headers: Array) -> String:
	var escaped_headers: Array[String] = []
	for header in headers:
		escaped_headers.append(_escape_cell(header))
	return "\t".join(escaped_headers)


func _build_row_line(headers: Array, row: Dictionary) -> String:
	var cells: Array[String] = []
	for header in headers:
		cells.append(_escape_cell(row.get(header, "")))
	while not cells.is_empty() and cells[cells.size() - 1].is_empty():
		cells.remove_at(cells.size() - 1)
	return "\t".join(cells)


func _parse_line(line: String) -> Array[String]:
	var values: Array[String] = []
	for raw_value in line.split("\t"):
		values.append(_unescape_cell(str(raw_value)))
	return values


func _escape_cell(value: Variant) -> String:
	var text := str(value)
	text = text.replace("\\", "\\\\")
	text = text.replace("\t", "\\t")
	text = text.replace("\n", "\\n")
	text = text.replace("\r", "")
	return text


func _unescape_cell(value: String) -> String:
	var result := ""
	var escape_active := false
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if escape_active:
			match character:
				"t":
					result += "\t"
				"n":
					result += "\n"
				"\\":
					result += "\\"
				_:
					result += character
			escape_active = false
			continue
		if character == "\\":
			escape_active = true
			continue
		result += character
	if escape_active:
		result += "\\"
	return result


func _ensure_parent_directory(path: String) -> void:
	var base_dir := path.get_base_dir()
	if base_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(base_dir)


func _normalize_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
