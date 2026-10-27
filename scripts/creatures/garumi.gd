extends Creature
class_name Garumi

signal vinculo_establecido(garumi: Garumi, jugador: Node, tipo: String)
signal salud_combate_cambiada(actual: int, maxima: int)
signal encuentro_iniciado(garumi: Garumi, jugador: Node)

const OPCION_OFRECER_VINCULO := 0
const OPCION_ENFRENTAR := 1
const OPCION_FORZAR_VINCULO := 2
const OPCION_RETIRARSE := 3

@export_category("Vínculo y combate")
@export_range(1, 1000, 1) var salud_combate_predeterminada: int = 40
@export_range(0.05, 0.75, 0.05) var umbral_vinculo_forzado: float = 0.25

var _enfrentamiento_activo: bool = false
var _vinculado: bool = false
var _tipo_vinculo: String = ""
var _jugador_del_encuentro: Node = null
var _menu_contextual: PopupMenu = null


func _ready() -> void:
	super._ready()
	_normalizar_grupos_garumi()


func configurar(datos_garumi: Dictionary) -> void:
	var datos_separados := datos_garumi.duplicate(true)
	datos_separados["categoria_entidad"] = "garumi"
	if not datos_separados.has("asset_key"):
		datos_separados["asset_key"] = str(datos_separados.get("nombre", ""))
	super.configurar(datos_separados)
	_vinculado = bool(datos_separados.get("vinculado", false))
	_tipo_vinculo = str(datos_separados.get("tipo_vinculo", ""))


func activar_como_proxy() -> void:
	super.activar_como_proxy()
	_normalizar_grupos_garumi()


func _normalizar_grupos_garumi() -> void:
	remove_from_group("creatures")
	remove_from_group("damageable")
	add_to_group("garumis")


func es_garumi() -> bool:
	return true


func es_dialogable() -> bool:
	return not _vinculado


func can_interact(_jugador: Node) -> bool:
	return is_inside_tree() and not _vinculado


func get_interaction_priority() -> int:
	return 20


func get_interaction_distance() -> float:
	return 48.0


func get_interaction_text() -> String:
	if _vinculado:
		return ""
	if _enfrentamiento_activo and puede_forzar_vinculo():
		return "Garumi debilitado: interactuar"
	if _enfrentamiento_activo:
		return "Enfrentamiento: interactuar"
	return "Interactuar con " + (criatura_nombre if not criatura_nombre.is_empty() else name)


## Se invoca desde InteractionSystem al acercarse y usar la acción contextual.
func interact(jugador: Node) -> void:
	if jugador == null or not is_instance_valid(jugador) or _vinculado:
		return
	_mostrar_menu_contextual(jugador)


func _mostrar_menu_contextual(jugador: Node) -> void:
	if is_instance_valid(_menu_contextual):
		_menu_contextual.queue_free()
	_menu_contextual = PopupMenu.new()
	_menu_contextual.name = "GarumiBondMenu"
	get_tree().root.add_child(_menu_contextual)
	_menu_contextual.id_pressed.connect(_al_seleccionar_opcion.bind(jugador))
	_menu_contextual.popup_hide.connect(_al_ocultar_menu)

	if _enfrentamiento_activo:
		if puede_forzar_vinculo():
			_menu_contextual.add_item("Forzar vínculo", OPCION_FORZAR_VINCULO)
		_menu_contextual.add_item("Retirarse del enfrentamiento", OPCION_RETIRARSE)
	else:
		_menu_contextual.add_item("Ofrecer vínculo", OPCION_OFRECER_VINCULO)
		_menu_contextual.add_item("Enfrentar", OPCION_ENFRENTAR)

	_menu_contextual.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))


func _al_seleccionar_opcion(opcion: int, jugador: Node) -> void:
	if is_instance_valid(_menu_contextual):
		_menu_contextual.queue_free()
	_menu_contextual = null
	match opcion:
		OPCION_OFRECER_VINCULO:
			ofrecer_vinculo(jugador)
		OPCION_ENFRENTAR:
			iniciar_enfrentamiento(jugador)
		OPCION_FORZAR_VINCULO:
			forzar_vinculo(jugador)
		OPCION_RETIRARSE:
			finalizar_enfrentamiento()


func _al_ocultar_menu() -> void:
	if is_instance_valid(_menu_contextual):
		_menu_contextual.queue_free()
	_menu_contextual = null


func ofrecer_vinculo(jugador: Node) -> bool:
	if _vinculado or _enfrentamiento_activo:
		return false
	_establecer_vinculo(jugador, "voluntario")
	return true


func iniciar_enfrentamiento(jugador: Node) -> bool:
	if _vinculado or _enfrentamiento_activo:
		return false
	if jugador == null or not is_instance_valid(jugador):
		return false

	_jugador_del_encuentro = jugador
	_enfrentamiento_activo = true
	max_health = maxi(1, int(datos.get("salud_combate", salud_combate_predeterminada)))
	vital_state.configurar(max_health, max_mana)
	restaurar_estado_vital(max_health, true)
	add_to_group("damageable")
	salud_combate_cambiada.emit(health, max_health)
	encuentro_iniciado.emit(self, jugador)
	return true


func puede_forzar_vinculo() -> bool:
	if _vinculado or not _enfrentamiento_activo or max_health <= 0:
		return false
	return float(health) / float(max_health) <= umbral_vinculo_forzado


## El daño común sigue sin afectar a los Garumis. Solo el daño durante un
## enfrentamiento explícito reduce su salud y nunca puede matarlos.
func take_damage(cantidad: int, origen: String = "desconocido") -> void:
	if not _enfrentamiento_activo or _vinculado or not is_alive:
		return
	if cantidad <= 0:
		return

	var salud_anterior := health
	var salud_minima := 1
	health = maxi(salud_minima, health - cantidad)
	vital_state.health = health
	vital_state.is_alive = true
	_sync_desde_vital()
	if health != salud_anterior:
		health_changed.emit(health, max_health)
		salud_combate_cambiada.emit(health, max_health)
		print("Garumi: ", criatura_nombre, " recibe ", salud_anterior - health, " de daño (", origen, ") | ", health, "/", max_health)


func forzar_vinculo(jugador: Node) -> bool:
	if not puede_forzar_vinculo():
		return false
	_establecer_vinculo(jugador, "forzado")
	return true


func _establecer_vinculo(jugador: Node, tipo: String) -> void:
	_vinculado = true
	_tipo_vinculo = tipo
	_enfrentamiento_activo = false
	_jugador_del_encuentro = null
	remove_from_group("damageable")
	datos["vinculado"] = true
	datos["tipo_vinculo"] = tipo
	set_meta("vinculado", true)
	set_meta("tipo_vinculo", tipo)
	vinculo_establecido.emit(self, jugador, tipo)
	print("Garumi: vínculo ", tipo, " establecido con ", jugador.name if jugador != null else "jugador desconocido")


func finalizar_enfrentamiento() -> void:
	_enfrentamiento_activo = false
	_jugador_del_encuentro = null
	remove_from_group("damageable")
	restaurar_estado_vital(max_health, true)


func esta_vinculado() -> bool:
	return _vinculado


func obtener_tipo_vinculo() -> String:
	return _tipo_vinculo


func esta_enfrentamiento() -> bool:
	return _enfrentamiento_activo
