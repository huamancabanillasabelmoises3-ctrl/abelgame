extends Node
class_name ConsoleManager


signal output(out: String)


var route: Object = self
var last_value: Variant = null
var variables: Dictionary = {}


func set_route(new_route: Object) -> void:
	route = new_route


func console_output(value: Variant) -> void:
	output.emit(str(value))


func resolve_route(target: String) -> Object:
	target = target.strip_edges()

	if target == "self":
		return route

	if variables.has(target):
		if variables[target] is Object:
			return variables[target]

	if route is Node:
		var route_node := route as Node
		var local := route_node.get_node_or_null(target)
		if local != null:
			return local

	return get_node_or_null(target)


func _has_property(obj: Object, property_name: String) -> bool:
	for p in obj.get_property_list():
		if p.has("name") and str(p["name"]) == property_name:
			return true
	return false


func cmd_log(args: Array) -> Variant:
	if args.size() > 0:
		console_output(args[0])
	return NoResult.new()


func cmd_get(args: Array) -> Variant:
	var target: Object
	var property: String

	if args.size() == 1:
		target = route
		property = str(args[0])

	elif args.size() == 2:
		target = resolve_route(str(args[0]))
		property = str(args[1])

	else:
		console_output("[ERROR] Uso: get [route] [value]")
		return NoResult.new()

	if target == null:
		console_output("[ERROR] Route inválido")
		return NoResult.new()

	if not _has_property(target, property):
		console_output("[ERROR] Propiedad no encontrada: " + property)
		return NoResult.new()

	return target.get(property)


func cmd_set(args: Array) -> Variant:
	var target: Object
	var property: String
	var value: Variant

	if args.size() == 2:
		target = route
		property = str(args[0])
		value = args[1]

	elif args.size() == 3:
		target = resolve_route(str(args[0]))
		property = str(args[1])
		value = args[2]

	else:
		console_output("[ERROR] Uso: set [route] [value] [data]")
		return NoResult.new()

	if target == null:
		console_output("[ERROR] Route inválido")
		return NoResult.new()

	if not _has_property(target, property):
		console_output("[ERROR] Propiedad no encontrada: " + property)
		return NoResult.new()

	target.set(property, value)
	return NoResult.new()


func cmd_call(args: Array) -> Variant:
	if args.size() < 1:
		console_output("[ERROR] Uso: call [route] [method] [parameters]")
		return NoResult.new()

	var target: Object = route
	var method_index := 0

	if args.size() >= 2:
		var first := str(args[0])

		# Atajo: call say "Hello"
		if route != null and route.has_method(first):
			target = route
			method_index = 0
		else:
			var resolved := resolve_route(first)
			if resolved != null:
				target = resolved
				method_index = 1
			else:
				target = route
				method_index = 0

	var method: String = str(args[method_index])

	if target == null:
		console_output("[ERROR] Route inválido")
		return NoResult.new()

	if not target.has_method(method):
		console_output("[ERROR] Método no encontrado: " + method)
		return NoResult.new()

	var parameters: Array = []
	for i in range(method_index + 1, args.size()):
		parameters.append(args[i])

	return target.callv(method, parameters)


func cmd_emit(args: Array) -> Variant:
	if args.size() < 1:
		console_output("[ERROR] Uso: emit [route] [signal] [parameters]")
		return NoResult.new()

	var target: Object = route
	var signal_index := 0

	if args.size() >= 2:
		var first := str(args[0])

		# Atajo: emit pressed
		if route != null and route.has_signal(first):
			target = route
			signal_index = 0
		else:
			var resolved := resolve_route(first)
			if resolved != null:
				target = resolved
				signal_index = 1
			else:
				target = route
				signal_index = 0

	var signal_name: String = str(args[signal_index])

	if target == null:
		console_output("[ERROR] Route inválido")
		return NoResult.new()

	if not target.has_signal(signal_name):
		console_output("[ERROR] Señal no encontrada: " + signal_name)
		return NoResult.new()

	var parameters: Array = []
	for i in range(signal_index + 1, args.size()):
		parameters.append(args[i])

	target.callv("emit_signal", [signal_name] + parameters)
	return NoResult.new()


var commands := {
	"log": {
		"func": cmd_log,
		"args": 1
	},
	"get": {
		"func": cmd_get,
		"args": 2
	},
	"set": {
		"func": cmd_set,
		"args": 3
	},
	"call": {
		"func": cmd_call,
		"args": -1
	},
	"emit": {
		"func": cmd_emit,
		"args": -1
	}
}


func preprocess_expression(text: String) -> String:
	text = text.replace("@", "last")
	text = text.replace("~", "current")
	return text


func _looks_like_expression(text: String) -> bool:
	if text == "":
		return false

	if text.begins_with("\"") and text.ends_with("\""):
		return false

	if text == "null" or text == "true" or text == "false":
		return false

	if text == "@" or text == "~":
		return false

	for ch in ["+", "-", "*", "/", "%", "(", ")", ".", ",", "[", "]", "{", "}"]:
		if text.find(ch) != -1:
			return true

	return false


func evaluate_expression(text: String) -> Variant:
	var expression := Expression.new()
	var parsed_text := preprocess_expression(text)

	var error := expression.parse(parsed_text)
	if error != OK:
		return NoResult.new()

	var context := ConsoleContext.new(
		last_value,
		route,
		variables
	)

	var result = expression.execute([], context)

	if expression.has_execute_failed():
		return NoResult.new()

	return result


func parse_value(value: String) -> Variant:
	value = value.strip_edges()

	if value == "@":
		return last_value

	if value == "~":
		return route

	if value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2)

	if value == "null":
		return null

	if value == "true":
		return true

	if value == "false":
		return false

	if value in variables:
		return variables[value]

	if value.is_valid_int():
		return int(value)

	if value.is_valid_float():
		return float(value)

	if _looks_like_expression(value):
		var expr_result = evaluate_expression(value)
		if not (expr_result is NoResult):
			return expr_result

	return value


func parse_command(tokens: PackedStringArray, index := 0) -> Variant:
	if index >= tokens.size():
		return NoResult.new()

	var token := tokens[index]

	if token in commands:
		var args: Array = []
		var amount: int = commands[token]["args"]

		if amount == -1:
			for i in range(index + 1, tokens.size()):
				args.append(parse_value(tokens[i]))
		else:
			for i in range(amount):
				var result = parse_command(tokens, index + 1)
				if not (result is NoResult):
					args.append(result)
				index += count_tokens(tokens, index + 1)

		return commands[token]["func"].call(args)

	return parse_value(token)


func count_tokens(tokens: PackedStringArray, index: int) -> int:
	if index >= tokens.size():
		return 1

	if tokens[index] in commands:
		var total := 1
		var amount: int = commands[tokens[index]]["args"]

		if amount == -1:
			return tokens.size() - index

		for i in range(amount):
			total += count_tokens(tokens, index + 1)

		return total

	return 1


func tokenize(text: String) -> PackedStringArray:
	var tokens: PackedStringArray = []

	var current := ""
	var quote := false
	var parentheses := 0
	var brackets := 0
	var braces := 0

	for c in text:
		match c:
			"\"":
				quote = not quote
				current += c

			"(":
				parentheses += 1
				current += c

			")":
				parentheses -= 1
				current += c

			"[":
				brackets += 1
				current += c

			"]":
				brackets -= 1
				current += c

			"{":
				braces += 1
				current += c

			"}":
				braces -= 1
				current += c

			" ":
				if not quote and parentheses == 0 and brackets == 0 and braces == 0:
					if current != "":
						tokens.append(current)
						current = ""
				else:
					current += c

			_:
				current += c

	if current != "":
		tokens.append(current)

	return tokens


func execute(command: String) -> int:
	var tokens := tokenize(command)

	if tokens.is_empty():
		return 1

	var result = parse_command(tokens)

	if not (result is NoResult):
		last_value = result

	return 0


class ConsoleContext:
	var last: Variant
	var current: Variant
	var variables: Dictionary

	func _init(_last, _current, _variables):
		last = _last
		current = _current

class NoResult:
	pass
