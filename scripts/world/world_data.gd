extends Node

signal mundo_listo

var mundo: Dictionary = {}
var cargado := false

# Índices rápidos
var _biomas_por_id: Dictionary = {}
var _ecosistemas_por_id: Dictionary = {}
var _habitats_por_id: Dictionary = {}
var _criaturas_por_id: Dictionary = {}


func _ready() -> void:
	SupabaseClient.mundo_cargado.connect(_recibir_mundo)


func _recibir_mundo(datos: Dictionary) -> void:
	mundo = datos

	_construir_indices()

	cargado = true

	print("WorldData: mundo cargado correctamente.")
	print("WorldData: biomas = ", _biomas_por_id.size())
	print("WorldData: ecosistemas = ", _ecosistemas_por_id.size())
	print("WorldData: habitats = ", _habitats_por_id.size())
	print("WorldData: criaturas = ", _criaturas_por_id.size())

	mundo_listo.emit()


# =========================================================
# CONSTRUCCIÓN DE ÍNDICES
# =========================================================

func _construir_indices() -> void:
	_biomas_por_id.clear()
	_ecosistemas_por_id.clear()
	_habitats_por_id.clear()
	_criaturas_por_id.clear()

	for bioma in obtener_biomas():
		_indexar_bioma(bioma)

	for ecosistema in obtener_ecosistemas_sin_bioma():
		_indexar_ecosistema(ecosistema)


func _indexar_bioma(bioma: Dictionary) -> void:
	var bioma_id: String = str(bioma.get("id", ""))

	if bioma_id.is_empty():
		return

	_biomas_por_id[bioma_id] = bioma

	var ecosistemas: Array = bioma.get("ecosistemas", [])

	for ecosistema in ecosistemas:
		_indexar_ecosistema(ecosistema)


func _indexar_ecosistema(ecosistema: Dictionary) -> void:
	var ecosistema_id: String = str(ecosistema.get("id", ""))

	if ecosistema_id.is_empty():
		return

	_ecosistemas_por_id[ecosistema_id] = ecosistema

	var habitats: Array = ecosistema.get("habitats", [])

	for habitat in habitats:
		_indexar_habitat(habitat)


func _indexar_habitat(habitat: Dictionary) -> void:
	var habitat_id: String = str(habitat.get("id", ""))

	if habitat_id.is_empty():
		return

	_habitats_por_id[habitat_id] = habitat

	var criaturas: Array = habitat.get("criaturas", [])

	for criatura in criaturas:
		_indexar_criatura(criatura)


func _indexar_criatura(criatura: Dictionary) -> void:
	var criatura_id: String = str(criatura.get("id", ""))

	if criatura_id.is_empty():
		return

	_criaturas_por_id[criatura_id] = criatura


# =========================================================
# CONSULTAS
# =========================================================

func obtener_biomas() -> Array:
	return mundo.get("biomas", [])


func obtener_ecosistemas_sin_bioma() -> Array:
	return mundo.get("ecosistemas_sin_bioma", [])


func obtener_bioma(bioma_id: String) -> Dictionary:
	return _biomas_por_id.get(bioma_id, {})


func obtener_ecosistema(ecosistema_id: String) -> Dictionary:
	return _ecosistemas_por_id.get(ecosistema_id, {})


func obtener_habitat(habitat_id: String) -> Dictionary:
	return _habitats_por_id.get(habitat_id, {})


func obtener_criatura(criatura_id: String) -> Dictionary:
	return _criaturas_por_id.get(criatura_id, {})


func obtener_ecosistemas_de_bioma(bioma_id: String) -> Array:
	var bioma := obtener_bioma(bioma_id)

	if bioma.is_empty():
		return []

	return bioma.get("ecosistemas", [])


func obtener_habitats_de_ecosistema(ecosistema_id: String) -> Array:
	var ecosistema := obtener_ecosistema(ecosistema_id)

	if ecosistema.is_empty():
		return []

	return ecosistema.get("habitats", [])


func obtener_criaturas_de_habitat(habitat_id: String) -> Array:
	var habitat := obtener_habitat(habitat_id)

	if habitat.is_empty():
		return []

	return habitat.get("criaturas", [])


func esta_cargado() -> bool:
	return cargado
