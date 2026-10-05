extends Node2D
class_name ZoneManager
## ZoneManager — autoridad de las zonas del runtime.
##
## Cada zona puede ser una escena independiente, pero comparte Player, HUD,
## inventario, input y sistemas del Main. Sólo una zona está cargada a la vez.
## El mundo procedural existe únicamente dentro de MundoAbierto.

signal zona_cambiada(tipo: String, zona: Node)

const REINO_TORRES_PATH := "res://scenes/kingdom/reino_torres.tscn"
const MUNDO_ABIERTO_PATH := "res://scenes/world/mundo_abierto.tscn"

const TIPO_REINO_TORRES := "reino_torres"
const TIPO_MUNDO_ABIERTO := "mundo_abierto"

var tipo_actual: String = ""
var zona_actual: Node = null
var _transicionando: bool = false


func iniciar() -> void:
	if GameState.debe_iniciar_en_reino_torres():
		entrar_reino_torres()
	else:
		entrar_mundo_abierto()


func entrar_reino_torres() -> void:
	_cambiar_zona(REINO_TORRES_PATH, TIPO_REINO_TORRES)


func entrar_mundo_abierto() -> void:
	_cambiar_zona(MUNDO_ABIERTO_PATH, TIPO_MUNDO_ABIERTO)


func salir_de_reino_torres() -> void:
	if _transicionando:
		return

	GameState.marcar_reino_torres_visitado()
	entrar_mundo_abierto()


func obtener_tipo_actual() -> String:
	return tipo_actual


func obtener_zona_actual() -> Node:
	return zona_actual


func obtener_world_generator() -> WorldGenerator:
	if tipo_actual != TIPO_MUNDO_ABIERTO:
		return null
	if zona_actual == null or not is_instance_valid(zona_actual):
		return null
	return zona_actual.get_node_or_null("WorldGenerator") as WorldGenerator


func _cambiar_zona(path: String, tipo: String) -> void:
	if _transicionando:
		return
	if tipo_actual == tipo and is_instance_valid(zona_actual):
		return

	_transicionando = true

	if is_instance_valid(zona_actual):
		zona_actual.queue_free()
		await zona_actual.tree_exited

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("ZoneManager: no se pudo cargar la zona '%s'." % path)
		_transicionando = false
		return

	zona_actual = packed.instantiate()
	zona_actual.name = "ZonaActiva"
	add_child(zona_actual)

	tipo_actual = tipo
	_transicionando = false

	print("ZoneManager: zona activa → ", tipo_actual)
	zona_cambiada.emit(tipo_actual, zona_actual)
