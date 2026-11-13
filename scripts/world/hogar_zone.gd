extends Node2D
class_name HogarZone
## Parcela privada asociada al guardado local activo.
## El terreno se dibuja en coordenadas de mundo; los datos editables se serializan
## en GameState.world_state.flags mediante ZoneManager.

const ANCHO := 2400.0
const ALTO := 1600.0
const TAMANO_CUADRICULA := 32.0
const COLOR_HIERBA := Color(0.34, 0.48, 0.27, 1.0)
const COLOR_HIERBA_CLARA := Color(0.39, 0.53, 0.30, 1.0)
const COLOR_CAMINO := Color(0.55, 0.43, 0.29, 1.0)
const COLOR_TIERRA := Color(0.39, 0.29, 0.20, 1.0)
const COLOR_BORDE := Color(0.20, 0.29, 0.18, 1.0)

var _decoraciones: Array[Dictionary] = []
var _version_estado := 1


func _ready() -> void:
	call_deferred("_inicializar_terreno_dual")


func _inicializar_terreno_dual() -> void:
	var terreno := get_node_or_null("WorldTerrain") as WorldTerrain
	if not is_instance_valid(terreno):
		push_error("HogarZone: falta WorldTerrain.")
		return

	# Hogar usa exactamente el renderer Dual de las demás zonas, pero con
	# una extensión fija y sin WorldGenerator ni streaming compartido.
	terreno.position = Vector2(-ANCHO * 0.5, -ALTO * 0.5)
	terreno.configurar(20261113, 32, 32, WorldData)
	await get_tree().process_frame
	if not is_instance_valid(terreno) or not is_instance_valid(terreno.visual):
		return

	terreno.visual.finalizar_preparacion_renderer()
	terreno.visual.comenzar_lote()

	var ancho_celdas := int(ANCHO / 32.0)
	var alto_celdas := int(ALTO / 32.0)
	for y in range(alto_celdas):
		for x in range(ancho_celdas):
			terreno.visual.set_zone(Vector2i(x, y), WorldTerrain.Zone.GRASS, 0, "Pradera")

	# Camino de tierra desde la casa hasta la entrada de la parcela.
	for y in range(19, 46):
		for x in range(35, 40):
			terreno.visual.set_zone(Vector2i(x, y), WorldTerrain.Zone.DIRT, 0, "Pradera")

	# Suelo de cultivo inicial, separado del camino.
	for y in range(30, 39):
		for x in range(45, 58):
			terreno.visual.set_zone(Vector2i(x, y), WorldTerrain.Zone.DIRT, 0, "Pradera")

	terreno.visual.terminar_lote()
	# Una sola invalidación para la parcela fija completa; el renderer Dual
	# resuelve las esquinas y bordes entre Pradera y Tierra.
	var orden: Array = []
	orden.resize(ancho_celdas * alto_celdas)
	for indice in range(orden.size()):
		orden[indice] = indice
	terreno.visual.marcar_region_generada_dirty(Vector2i.ZERO, orden, ancho_celdas, 0, orden.size())
	terreno.visual.flush()


func obtener_estado_guardado() -> Dictionary:
	return {
		"version": _version_estado,
		"decoraciones": _decoraciones.duplicate(true)
	}


func cargar_estado_guardado(estado: Dictionary) -> void:
	_version_estado = maxi(1, int(estado.get("version", 1)))
	var datos: Variant = estado.get("decoraciones", [])
	_decoraciones.clear()
	if datos is Array:
		for entrada in datos:
			if not entrada is Dictionary:
				continue
			var item := (entrada as Dictionary).duplicate(true)
			_decoraciones.append({
					"tipo": str(item.get("tipo", "decoracion")),
					"x": clampf(float(item.get("x", 0.0)), -ANCHO * 0.5, ANCHO * 0.5),
					"y": clampf(float(item.get("y", 0.0)), -ALTO * 0.5, ALTO * 0.5),
					"giro": float(item.get("giro", 0.0))
				})


func establecer_decoraciones(decoraciones: Array) -> void:
	cargar_estado_guardado({"version": _version_estado, "decoraciones": decoraciones})


func agregar_decoracion(tipo: String, posicion: Vector2, giro: float = 0.0) -> bool:
	if tipo.strip_edges().is_empty() or not obtener_limites().has_point(posicion):
		return false
	_decoraciones.append({
		"tipo": tipo.strip_edges(),
		"x": posicion.x,
		"y": posicion.y,
		"giro": giro
	})
	return true


func mover_decoracion(indice: int, posicion: Vector2) -> bool:
	if indice < 0 or indice >= _decoraciones.size() or not obtener_limites().has_point(posicion):
		return false
	_decoraciones[indice]["x"] = posicion.x
	_decoraciones[indice]["y"] = posicion.y
	queue_redraw()
	return true


func quitar_decoracion(indice: int) -> bool:
	if indice < 0 or indice >= _decoraciones.size():
		return false
	_decoraciones.remove_at(indice)
	queue_redraw()
	return true


func obtener_decoraciones() -> Array[Dictionary]:
	return _decoraciones.duplicate(true)


func obtener_limites() -> Rect2:
	return Rect2(-ANCHO * 0.5, -ALTO * 0.5, ANCHO, ALTO)
