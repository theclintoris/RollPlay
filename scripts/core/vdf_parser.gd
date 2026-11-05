class_name VdfParser
extends RefCounted
## A small, dependency-free parser for Valve's KeyValues text format.
## Handles nested objects, quoted and bare tokens, escapes, and // comments.

static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return {}
	return parse(source)


static func parse(source: String) -> Dictionary:
	var parser := _Parser.new(source.trim_prefix("\ufeff"))
	return parser.parse_root()


class _Parser:
	var text: String
	var index := 0
	var length: int

	func _init(source: String) -> void:
		text = source
		length = source.length()

	func parse_root() -> Dictionary:
		var root: Dictionary = {}
		while true:
			_skip_ignored()
			if _at_end():
				break
			if _peek() == "}":
				index += 1
				continue
			var key := _read_token()
			if key.is_empty():
				if not _at_end():
					index += 1
				continue
			_skip_ignored()
			if _peek() == "{":
				index += 1
				root[key] = _parse_object()
			else:
				root[key] = _read_token()
		return root

	func _parse_object() -> Dictionary:
		var node: Dictionary = {}
		while true:
			_skip_ignored()
			if _at_end():
				break
			if _peek() == "}":
				index += 1
				break
			var key := _read_token()
			if key.is_empty():
				if not _at_end():
					index += 1
				continue
			_skip_ignored()
			if _peek() == "{":
				index += 1
				node[key] = _parse_object()
			else:
				node[key] = _read_token()
		return node

	func _read_token() -> String:
		_skip_ignored()
		if _at_end():
			return ""
		var first := _peek()
		if first == "{" or first == "}":
			return first
		if first == "\"":
			index += 1
			return _read_quoted()
		var start := index
		while not _at_end():
			var character := _peek()
			if _is_space(character) or character == "{" or character == "}" or character == "\"":
				break
			index += 1
		return text.substr(start, index - start)

	func _read_quoted() -> String:
		var output := ""
		while not _at_end():
			var character := _peek()
			index += 1
			if character == "\"":
				break
			if character == "\\" and not _at_end():
				var escaped := _peek()
				index += 1
				match escaped:
					"n":
						output += "\n"
					"t":
						output += "\t"
					"r":
						output += "\r"
					"\\":
						output += "\\"
					"\"":
						output += "\""
					_:
						output += escaped
			else:
				output += character
		return output

	func _skip_ignored() -> void:
		while not _at_end():
			var character := _peek()
			if _is_space(character):
				index += 1
				continue
			if character == "/" and index + 1 < length and text[index + 1] == "/":
				index += 2
				while not _at_end() and _peek() != "\n":
					index += 1
				continue
			if character == "[" and text.substr(index).begins_with("[$"):
				# Conditional platform token; the manifest data we need is unconditional.
				var close := text.find("]", index)
				index = close + 1 if close >= 0 else length
				continue
			break

	func _peek() -> String:
		return text[index] if index < length else ""

	func _at_end() -> bool:
		return index >= length

	static func _is_space(character: String) -> bool:
		return character == " " or character == "\t" or character == "\r" or character == "\n"
