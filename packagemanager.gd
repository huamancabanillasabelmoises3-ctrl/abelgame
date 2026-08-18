@icon("res://packagemanager.svg")
extends Node
class_name PackageManager


enum PackageAction {
	NONE,
	SEARCH,
	INSTALL,
	UPDATE,
	UPGRADE
}


var actual_action: PackageAction = PackageAction.NONE

@onready var hr: HTTPRequest = $HR

@export var package_url: Dictionary = {
	"foo": "https://raw.githubusercontent.com/huamancabanillasabelmoises3-ctrl/abconsolefoo/main/package.json"
}


func output(value: Variant) -> void:
	# Ya ahorita implemento la señal.
	print(value)


func get_url_package(pkg: String) -> String:
	var url = package_url.get(pkg)

	if url == null:
		return ""

	return str(url)


func search_package(pkg: String) -> void:
	var url := get_url_package(pkg)

	if url.is_empty():
		output("Paquete no encontrado: " + pkg)
		return

	var error := hr.request(url)

	if error != OK:
		actual_action = PackageAction.NONE
		output("No se pudo conectar con el paquete: " + pkg)
		return

	actual_action = PackageAction.SEARCH
	output("Conexión con paquete establecida. Esperando datos...")

func test_save_package() -> void:
	var dir := "user://packages/foo"

	var error := DirAccess.make_dir_recursive_absolute(dir)

	if error != OK:
		output("No se pudo crear la carpeta: " + dir)
		return

	var file := FileAccess.open(
		dir + "/dontdelete.txt",
		FileAccess.WRITE
	)

	if file == null:
		output("No se pudo crear dontdelete.txt")
		return

	file.store_string(
		"Archivo de prueba este txt se genera para comprobar que el sistema de guardado funciona PORFAVOR no elimine esto en ejecución si no quieres que tu juego crashee o trate de reiniciar pensando que el sistema fallo"
	)

	file.close()

	output("Paquete guardado correctamente en: " + dir)

func _on_hr_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if actual_action == PackageAction.NONE:
		return

	if actual_action == PackageAction.SEARCH:
		_handle_search_result(result, response_code, body)
		return


func _handle_search_result(
	result: int,
	response_code: int,
	body: PackedByteArray
) -> void:
	actual_action = PackageAction.NONE

	if result != HTTPRequest.RESULT_SUCCESS:
		output("No se pudo obtener el paquete. Error de conexión.")
		return

	if response_code < 200 or response_code >= 300:
		output("El servidor respondió con HTTP " + str(response_code))
		return

	var text := body.get_string_from_utf8()
	var data = JSON.parse_string(text)

	if data == null:
		output("El package.json no contiene JSON válido.")
		return

	if not data is Dictionary:
		output("El package.json debe contener un objeto JSON.")
		return

	output(data)


func _ready() -> void:
	test_save_package()
	search_package("foo")
