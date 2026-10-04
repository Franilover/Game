extends Node
class_name SupabaseClient

signal request_completed(request_id: int, resultado: int, codigo_http: int, cabeceras: PackedStringArray, cuerpo: PackedByteArray)

@export var base_url: String = "https://ftdxthnizdosaaavjhah.supabase.co"
@export var publishable_key: String = "sb_publishable_dZowBcHCW7PJ5tV8aDnAPQ_1URMyPbV8"

var _next_request_id: int = 1

func rpc(nombre: String, payload: Dictionary = {}) -> int:
	return _request("/rest/v1/rpc/" + nombre, HTTPClient.METHOD_POST, JSON.stringify(payload))

func get_rest(recurso: String, query: String = "") -> int:
	var path := "/rest/v1/" + recurso
	if not query.is_empty():
		path += "?" + query
	return _request(path, HTTPClient.METHOD_GET, "")

func _request(path: String, method: HTTPClient.Method, body: String) -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	http.request_completed.connect(func(resultado: int, codigo_http: int, cabeceras: PackedStringArray, cuerpo: PackedByteArray) -> void:
		request_completed.emit(request_id, resultado, codigo_http, cabeceras, cuerpo)
		http.queue_free(), CONNECT_ONE_SHOT)
	var resultado := http.request(base_url + path, PackedStringArray([
		"apikey: " + publishable_key,
		"Content-Type: application/json",
		"Accept: application/json"
	]), method, body)
	if resultado != OK:
		http.queue_free()
		request_completed.emit(request_id, HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
	return request_id


func _emit_request_failed(request_id: int) -> void:
	request_completed.emit(
		request_id,
		HTTPRequest.RESULT_REQUEST_FAILED,
		0,
		PackedStringArray(),
		PackedByteArray()
	)
