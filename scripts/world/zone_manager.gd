extends Node2D
## ZoneManager — autoridad de las zonas del runtime.
##
## Cada zona puede ser una escena independiente, pero comparte Player, HUD,
## inventario, input y sistemas del Main. Sólo una zona está cargada a la vez.
## El mundo procedural existe únicamente dentro de MundoAbierto.

signal zona_cambiada(tipo: String, zona: Node)

const MUNDO_ABIERTO_PATH := "res://scenes/world/mundo_abierto.tscn"

const TIPO_REINO_TORRES := "reino_torres"
const TIPO_MUNDO_ABIERTO := "mundo_abierto"

var tipo_actual: String = ""
var zona_actual: Node = null
var _transicionando: bool = false
var _salida_reino_pendiente: bool = false
var _supabase_client: GarliaSupabaseClient = null


func configurar_dependencias(supabase_client: GarliaSupabaseClient) -> void:
	_supabase_client = supabase_client


func iniciar() -> void:
	if _supabase_client == null:
		push_error("ZoneManager: falta SupabaseClient.")
		return

	if GameState.debe_iniciar_en_reino_torres():
		var regla := _supabase_client.obtener_reino_game("torres")
		if regla.is_empty():
			push_error("ZoneManager: Supabase no tiene un reino activo con clave 'torres'.")
			return
		entrar_reino_torres(regla)
	else:
		entrar_mundo_abierto()


func entrar_reino_torres(regla: Dictionary = {}) -> void:
	var regla_canonica := regla
	if regla_canonica.is_empty() and _supabase_client != null:
		regla_canonica = _supabase_client.obtener_reino_game("torres")

	var propiedades_variant: Variant = regla_canonica.get("propiedades", {})
	if not propiedades_variant is Dictionary:
		push_error("ZoneManager: las propiedades de Torres no son un objeto JSON.")
		return

	var propiedades := propiedades_variant as Dictionary
	if str(propiedades.get("tipo_zona", "")) != "escena_fija":
		push_error("ZoneManager: Torres no está configurado como escena_fija en Supabase.")
		return
	if not bool(propiedades.get("usa_world_generator", false)) and not bool(propiedades.get("generacion_procedural", false)):
		var escena := str(propiedades.get("escena", "")).strip_edges()
		if escena.is_empty():
			push_error("ZoneManager: Torres no tiene escena configurada en Supabase.")
			return
		_cambiar_zona(escena, TIPO_REINO_TORRES)
		return

	push_error("ZoneManager: Supabase exige WorldGenerator para Torres, pero esta zona está definida como fija.")


func entrar_mundo_abierto() -> void:
	_cambiar_zona(MUNDO_ABIERTO_PATH, TIPO_MUNDO_ABIERTO)


func salir_de_reino_torres() -> void:
	if _transicionando:
		return

	GameState.marcar_reino_torres_visitado()
	_salida_reino_pendiente = true
	entrar_mundo_abierto()


func consumir_salida_reino_pendiente() -> bool:
	var pendiente := _salida_reino_pendiente
	_salida_reino_pendiente = false
	return pendiente


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

	if tipo == TIPO_REINO_TORRES and zona_actual.has_signal("salida_solicitada"):
		var callback := Callable(self, "salir_de_reino_torres")
		if not zona_actual.salida_solicitada.is_connected(callback):
			zona_actual.salida_solicitada.connect(callback)

	tipo_actual = tipo
	_transicionando = false

	print("ZoneManager: zona activa → ", tipo_actual)
	zona_cambiada.emit(tipo_actual, zona_actual)
