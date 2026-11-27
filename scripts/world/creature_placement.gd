@tool
extends Node2D
class_name CreaturePlacement

## Punto de colocación para escenas diseñadas a mano.
## El selector se alimenta del snapshot del catálogo sincronizado desde Supabase.
## Los datos de la criatura siempre se resuelven en WorldData al ejecutar el juego.

const CATALOGO_PATH := "res://data/world_initial.json"
const PROPERTY_CRITTER := "criatura_id"

@export_category("Aparición")
@export_range(1, 20, 1) var cantidad: int = 1
@export var separacion: float = 28.0
@export var desplazamiento_inicial: Vector2 = Vector2.ZERO
@export var nombre_individual: String = ""

var _criatura_id: String = ""
var _generado: bool = false
var _world_data: WorldDataService = null
var _opciones_por_etiqueta: Dictionary = {}
var _etiqueta_por_id: Dictionary = {}


func _get_property_list() -> Array[Dictionary]:
	_actualizar_opciones_selector()
	var etiquetas: Array[String] = ["— Seleccionar criatura —"]
	for etiqueta_variant in _opciones_por_etiqueta.keys():
		etiquetas.append(str(etiqueta_variant))
	return [{
		"name": PROPERTY_CRITTER,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(etiquetas),
		"usage": PROPERTY_USAGE_DEFAULT
	}]


func _get(property: StringName) -> Variant:
	if str(property) != PROPERTY_CRITTER:
		return null
	_actualizar_opciones_selector()
	return str(_etiqueta_por_id.get(_criatura_id, "— Seleccionar criatura —"))


func _set(property: StringName, value: Variant) -> bool:
	if str(property) != PROPERTY_CRITTER:
		return false
	_actualizar_opciones_selector()
	var seleccion := str(value)
	if seleccion == "— Seleccionar criatura —" or seleccion.is_empty():
		_criatura_id = ""
	elif _opciones_por_etiqueta.has(seleccion):
		_criatura_id = str(_opciones_por_etiqueta[seleccion])
	else:
		# Permite conservar IDs ya serializados aunque cambie la etiqueta visible.
		_criatura_id = seleccion
	notify_property_list_changed()
	return true


func _actualizar_opciones_selector() -> void:
	_opciones_por_etiqueta.clear()
	_etiqueta_por_id.clear()
	if not Engine.is_editor_hint():
		return
	if not FileAccess.file_exists(CATALOGO_PATH):
		return

	var texto := FileAccess.get_file_as_string(CATALOGO_PATH)
	var parseado: Variant = JSON.parse_string(texto)
	if not parseado is Dictionary:
		return

	var encontrados: Dictionary = {}
	_recopilar_criaturas(parseado, encontrados)
	var ids: Array = encontrados.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(encontrados[a].get("nombre", "")).naturalcasecmp_to(str(encontrados[b].get("nombre", ""))) < 0
	)
	for id_variant in ids:
		var id := str(id_variant)
		var datos: Dictionary = encontrados[id]
		var nombre := str(datos.get("nombre", "Criatura")).strip_edges()
		var etiqueta := "%s · %s" % [nombre, id.left(8)]
		_opciones_por_etiqueta[etiqueta] = id
		_etiqueta_por_id[id] = etiqueta


func _recopilar_criaturas(valor: Variant, resultado: Dictionary) -> void:
	if valor is Dictionary:
		var diccionario := valor as Dictionary
		if diccionario.has("criaturas") and diccionario["criaturas"] is Array:
			for criatura_variant in diccionario["criaturas"]:
				if not criatura_variant is Dictionary:
					continue
				var criatura := criatura_variant as Dictionary
				var id := str(criatura.get("id", "")).strip_edges()
				if not id.is_empty():
					resultado[id] = criatura
		for hijo in diccionario.values():
			if hijo is Dictionary or hijo is Array:
				_recopilar_criaturas(hijo, resultado)
	elif valor is Array:
		for hijo in valor:
			if hijo is Dictionary or hijo is Array:
				_recopilar_criaturas(hijo, resultado)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_world_data = get_node_or_null("/root/WorldData") as WorldDataService
	if _world_data == null:
		push_error("CreaturePlacement: no se encontró el autoload /root/WorldData.")
		return
	if _world_data.esta_cargado():
		_generar_criaturas()
	elif not _world_data.mundo_listo.is_connected(_al_catalogo_listo):
		_world_data.mundo_listo.connect(_al_catalogo_listo, CONNECT_ONE_SHOT)


func _al_catalogo_listo() -> void:
	_generar_criaturas()


func _generar_criaturas() -> void:
	if _generado:
		return
	_generado = true
	var id := _criatura_id.strip_edges()
	if id.is_empty():
		push_warning("CreaturePlacement (%s): selecciona una criatura en el Inspector." % name)
		return
	var datos := _world_data.obtener_criatura(id)
	if datos.is_empty():
		push_error("CreaturePlacement (%s): la criatura '%s' no existe en el catálogo sincronizado." % [name, id])
		return
	var escena := load("res://scenes/creatures/creature.tscn") as PackedScene
	if escena == null:
		push_error("CreaturePlacement: no se pudo cargar scenes/creatures/creature.tscn.")
		return
	var total := clampi(cantidad, 1, 20)
	for indice in range(total):
		var criatura := escena.instantiate() as Creature
		if criatura == null:
			push_error("CreaturePlacement: la escena base no contiene una Creature.")
			continue
		add_child(criatura)
		criatura.position = desplazamiento_inicial + Vector2(separacion * indice, 0.0)
		criatura.configurar_dependencias(null, null, null, null, _world_data)
		var datos_instancia := datos.duplicate(true)
		if not nombre_individual.strip_edges().is_empty():
			datos_instancia["nombre_individual"] = nombre_individual if total == 1 else "%s %d" % [nombre_individual, indice + 1]
		criatura.configurar(datos_instancia)
		criatura.activar_como_proxy()
