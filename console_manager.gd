extends Node
class_name ConsoleManager


signal output(out: String)

@onready var node_route: Node = self
var route_stack: Array = []
var resource_path: String = ""
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

	if route is Object:
		var route_node := route as Object
		var local = route_node.get_node_or_null(target)

		if local != null:
			return local

	return get_node_or_null(target)


func _has_property(obj: Object, property_name: String) -> bool:
	for p in obj.get_property_list():
		if p.has("name") and str(p["name"]) == property_name:
			return true

	return false

func _push_route_state() -> void:
	route_stack.append({
		"route": route,
		"node_route": node_route,
		"resource_path": resource_path
	})


func _pop_route_state() -> bool:
	if route_stack.is_empty():
		return false

	var state: Dictionary = route_stack.pop_back()

	route = state.get("route", self)
	node_route = state.get("node_route", self)
	resource_path = str(state.get("resource_path", ""))

	return true


func _strip_surrounding_quotes(text: String) -> String:
	text = text.strip_edges()

	if text.begins_with("\"") and text.ends_with("\"") and text.length() >= 2:
		return text.substr(1, text.length() - 2)

	return text


func _get_member(container: Variant, member: String) -> Variant:
	if member == "self":
		return container

	if container is Dictionary:
		if not container.has(member):
			return NoResult.new()
		return container[member]

	if container is Array:
		if not member.is_valid_int():
			return NoResult.new()

		var idx := int(member)
		var arr: Array = container

		if idx < 0 or idx >= arr.size():
			return NoResult.new()

		return arr[idx]

	if container is Object:
		var obj: Object = container

		if not _has_property(obj, member):
			return NoResult.new()

		return obj.get(member)

	return NoResult.new()


func _resolve_property_chain(base: Variant, chain: String) -> Variant:
	var current: Variant = base

	for part in chain.split("."):
		part = part.strip_edges()

		if part.is_empty():
			continue

		if part == "@":
			current = last_value
			continue

		if part == "~":
			current = route
			continue

		current = _get_member(current, part)

		if current is NoResult:
			return current

	return current


func _resolve_reference(text: String) -> Variant:
	var direct := resolve_route(text)

	if direct != null:
		return direct

	if text.find(".") != -1:
		var chained = _resolve_property_chain(route, text)

		if not (chained is NoResult):
			return chained

	return null


func _resolve_property_parent(base: Variant, chain: String) -> Dictionary:
	var parts := chain.split(".")

	if parts.is_empty():
		return {"error": true}

	var current: Variant = base

	for i in range(parts.size() - 1):
		var part := parts[i].strip_edges()

		if part.is_empty():
			continue

		if part == "@":
			current = last_value
			continue

		if part == "~":
			current = route
			continue

		current = _get_member(current, part)

		if current is NoResult:
			return {"error": true}

	return {
		"parent": current,
		"leaf": parts[parts.size() - 1].strip_edges()
	}


func _set_member(container: Variant, member: String, value: Variant) -> bool:
	if container is Dictionary:
		var dict: Dictionary = container
		dict[member] = value
		return true

	if container is Array:
		if not member.is_valid_int():
			return false

		var idx := int(member)
		var arr: Array = container

		if idx < 0 or idx >= arr.size():
			return false

		arr[idx] = value
		return true

	if container is Object:
		var obj: Object = container

		if not _has_property(obj, member):
			return false

		obj.set(member, value)
		return true

	return false

func cmd_vget(args: Array) -> Variant:
	if args.size() != 1:
		console_output("[ERROR] Uso: vget [name]")
		return NoResult.new()

	var tname := str(args[0])

	if not variables.has(tname):
		console_output("[ERROR] Variable no encontrada: " + tname)
		return NoResult.new()

	return variables[tname]

func cmd_vset(args: Array) -> Variant:
	if args.size() != 2:
		console_output("[ERROR] Uso: vset [name] [value]")
		return NoResult.new()

	var tname := str(args[0])
	var value: Variant = args[1]

	variables[tname] = value
	return NoResult.new()

func cmd_load(args: Array) -> Variant:
	if args.size() != 1:
		console_output("[ERROR] Uso: load [path]")
		return NoResult.new()

	var path := _strip_surrounding_quotes(str(args[0]))
	var resource := ResourceLoader.load(path)

	if resource == null:
		console_output("[ERROR] No se pudo cargar: " + path)
		return NoResult.new()

	_push_route_state()
	route = resource
	resource_path = path

	console_output(path)
	return resource


func cmd_go(args: Array) -> Variant:
	if args.size() != 1:
		console_output("[ERROR] Uso: go [property|exit]")
		return NoResult.new()

	var chain := _strip_surrounding_quotes(str(args[0]))

	if chain == "exit" or chain == "..":
		if not _pop_route_state():
			console_output("[ERROR] No hay ruta previa")
			return NoResult.new()

		if route is Node:
			console_output((route as Node).get_path())
		elif resource_path != "":
			console_output(resource_path)
		else:
			console_output(str(route))

		return route

	var base := route
	var resolved = _resolve_property_chain(base, chain)

	if resolved is NoResult or resolved == null:
		console_output("[ERROR] Propiedad/ruta no encontrada: " + chain)
		return NoResult.new()

	_push_route_state()
	route = resolved

	if resource_path.is_empty():
		resource_path = chain
	else:
		resource_path = resource_path + "." + chain

	console_output(resource_path)
	return route

func cmd_log(args: Array) -> Variant:
	if args.size() > 0:
		console_output(args[0])

	return NoResult.new()


func cmd_new(args: Array) -> Variant:
	if args.is_empty():
		console_output("[ERROR] Uso: new [expression]")
		return NoResult.new()

	var expression := " ".join(args)
	var result = evaluate_raw_expression(expression)

	if not (result is NoResult):
		return result

	var type_name := str(args[0])

	if ClassDB.class_exists(type_name):
		if not ClassDB.can_instantiate(type_name):
			console_output(
				"[ERROR] La clase no puede ser instanciada: " + type_name
			)
			return NoResult.new()

		return ClassDB.instantiate(type_name)

	console_output("[ERROR] No se pudo crear: " + expression)
	return NoResult.new()


func cmd_repeat(args: Array) -> Variant:
	if args.size() != 2:
		console_output("[ERROR] Uso: repeat [amount] [command]")
		return NoResult.new()

	var amount = args[0]

	if not (amount is int):
		console_output("[ERROR] La cantidad debe ser un entero")
		return NoResult.new()

	if amount < 0:
		console_output("[ERROR] La cantidad no puede ser negativa")
		return NoResult.new()

	var command := str(args[1])

	if command.strip_edges() == "":
		console_output("[ERROR] Comando vacío")
		return NoResult.new()

	var final_result: Variant = NoResult.new()

	for i in range(amount):
		var tokens := tokenize(command)

		if tokens.is_empty():
			continue

		var result = parse_command(tokens)

		if not (result is NoResult):
			last_value = result
			final_result = result

	return final_result


func cmd_ls(args: Array) -> Variant:
	if not (route is Node):
		console_output("[ERROR] Route actual no es un Node")
		return NoResult.new()

	var node := route as Node

	if args.is_empty():
		var children := node.get_children()

		for child in children:
			console_output(child.name)

		return children

	if str(args[0]) == "props":
		var list := []

		for p in node.get_property_list():
			list.append(p["name"])
			console_output(p["name"])

		return list

	return NoResult.new()

func cmd_cd(args: Array) -> Variant:
	if args.is_empty():
		return route

	var target_text := _strip_surrounding_quotes(str(args[0]))

	var target: Object
	if target_text == "self":
		target = node_route
	else:
		target = resolve_route(target_text)

	if target == null or not (target is Node):
		console_output("[ERROR] Nodo no encontrado")
		return NoResult.new()

	_push_route_state()
	node_route = target
	route = target
	resource_path = ""

	console_output((target as Node).get_path())
	return target

func cmd_pwd(_args: Array) -> Variant:
	if route is Node:
		var r := (route as Node).get_path()

		console_output(r)
		return r

	console_output("[ERROR] Route actual no es un Node")
	return NoResult.new()

func cmd_get(args: Array) -> Variant:
	var target: Variant
	var property: String

	if args.size() == 1:
		target = route
		property = str(args[0])

	elif args.size() == 2:
		target = _resolve_reference(str(args[0]))
		property = str(args[1])

	else:
		console_output("[ERROR] Uso: get [route] [value]")
		return NoResult.new()

	if target == null or target is NoResult:
		console_output("[ERROR] Route inválido")
		return NoResult.new()

	var result = _resolve_property_chain(target, property)

	if result is NoResult:
		console_output("[ERROR] Propiedad no encontrada: " + property)
		return NoResult.new()

	return result


func cmd_set(args: Array) -> Variant:
	var target: Variant
	var property: String
	var value: Variant

	if args.size() == 2:
		target = route
		property = str(args[0])
		value = args[1]

	elif args.size() == 3:
		target = _resolve_reference(str(args[0]))
		property = str(args[1])
		value = args[2]

	else:
		console_output("[ERROR] Uso: set [route] [value] [data]")
		return NoResult.new()

	if target == null or target is NoResult:
		console_output("[ERROR] Route inválido")
		return NoResult.new()

	var endpoint := _resolve_property_parent(target, property)

	if endpoint.has("error"):
		console_output("[ERROR] Propiedad no encontrada: " + property)
		return NoResult.new()

	var parent = endpoint["parent"]
	var leaf: String = str(endpoint["leaf"])

	if not _set_member(parent, leaf, value):
		console_output("[ERROR] No se pudo asignar: " + property)
		return NoResult.new()

	return NoResult.new()


func cmd_call(args: Array) -> Variant:
	if args.size() < 1:
		console_output("[ERROR] Uso: call [route] [method] [parameters]")
		return NoResult.new()

	var target: Object = route
	var method_index := 0

	if args.size() >= 2:
		var first := str(args[0])

		if route != null and route.has_method(first):
			target = route
			method_index = 0
		else:
			var resolved = _resolve_reference(first)
			if resolved != null and resolved is Object:
				target = resolved
				method_index = 1
			else:
				target = route
				method_index = 0

	var method := str(args[method_index])

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

		if route != null and route.has_signal(first):
			target = route
			signal_index = 0
		else:
			var resolved = _resolve_reference(first)
			if resolved != null and resolved is Object:
				target = resolved
				signal_index = 1
			else:
				target = route
				signal_index = 0

	var signal_name := str(args[signal_index])

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
		"args": 2,
		"raw": [0]
	},
	"set": {
		"func": cmd_set,
		"args": 3,
		"raw": [0]
	},
	"call": {
		"func": cmd_call,
		"args": -1,
		"raw": [0, 1]
	},
	"emit": {
		"func": cmd_emit,
		"args": -1,
		"raw": [0, 1]
	},
	"pwd": {
		"func": cmd_pwd,
		"args": 0
	},
	"cd": {
		"func": cmd_cd,
		"args": 1,
		"raw": [0]
	},
	"ls": {
		"func": cmd_ls,
		"args": -1
	},
	"vget": {
		"func": cmd_vget,
		"args": 1,
		"raw": [0]
	},
	"vset": {
		"func": cmd_vset,
		"args": 2,
		"raw": [0]
	},
	"new": {
		"func": cmd_new,
		"args": -1
	},
	"load": {
		"func": cmd_load,
		"args": 1,
		"raw": [0]
	},
	"go": {
		"func": cmd_go,
		"args": 1,
		"raw": [0]
	},
	"repeat": {
		"func" : cmd_repeat,
		"args" : 2,
		"raw" : []
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

	for ch in [
		"+",
		"-",
		"*",
		"/",
		"%",
		"(",
		")",
		".",
		",",
		"[",
		"]",
		"{",
		"}"
	]:
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


func evaluate_raw_expression(text: String) -> Variant:
	var expression := Expression.new()

	var error := expression.parse(text)

	if error != OK:
		return NoResult.new()

	var result = expression.execute(
		[],
		ConsoleContext.new(
			last_value,
			route,
			variables
		)
	)

	if expression.has_execute_failed():
		return NoResult.new()

	return result

func parse_command(tokens: PackedStringArray, index := 0) -> Variant:
	if index >= tokens.size():
		return NoResult.new()

	var token := tokens[index]

	if token in commands:
		var command_data: Dictionary = commands[token]
		var args: Array = []

		var amount: int = command_data["args"]
		var raw: Array = command_data.get("raw", [])

		if amount == -1:
			for i in range(index + 1, tokens.size()):
				var argument_index := i - index - 1

				if argument_index in raw:
					args.append(tokens[i])
				else:
					args.append(parse_value(tokens[i]))

		else:
			for i in range(amount):
				var arg_index := index + 1 + i

				if arg_index >= tokens.size():
					break

				if i in raw:
					args.append(tokens[arg_index])
				else:
					var result = parse_command(tokens, arg_index)

					if not (result is NoResult):
						args.append(result)

					index += count_tokens(tokens, arg_index)

		return command_data["func"].call(args)

	return parse_value(token)


func count_tokens(tokens: PackedStringArray, index: int) -> int:
	if index >= tokens.size():
		return 1

	var token := tokens[index]

	if token in commands:
		var command_data: Dictionary = commands[token]
		var amount: int = command_data["args"]
		var raw: Array = command_data.get("raw", [])

		if amount == -1:
			return tokens.size() - index

		var consumed := 1

		for i in range(amount):
			var arg_index := index + consumed

			if arg_index >= tokens.size():
				break

			if i in raw:
				consumed += 1
			else:
				consumed += count_tokens(tokens, arg_index)

		return consumed

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
				if (
					not quote
					and parentheses == 0
					and brackets == 0
					and braces == 0
				):
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
	command = command.replace(";", "\n")

	var commands_text := command.split("\n")

	if commands_text.is_empty():
		return 1

	for line in commands_text:
		var text := line.strip_edges()

		if text.is_empty():
			continue

		var tokens := tokenize(text)

		if tokens.is_empty():
			continue

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
		variables = _variables

class NoResult:
	pass
