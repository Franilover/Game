extends Node3D
class_name FirstPerson3DItemController

## Renderiza las dos manos usando los objetos reales del inventario compartido.
## Las acciones 3D se entregan a objetivos mediante una interfaz explícita.

const COMBAT_ITEM_RESOLVER = preload("res://scripts/gameplay/combat/combat_item_resolver.gd")

@export var distancia_interaccion: float = 2.8
@export var enfriamiento_uso: float = 0.32

var inventario: Node = null
var jugador: Node = null
var resolvedor_visual: Object = null
var world_items: Node = null

var _sprites: Dictionary = {}
var _datos_manos: Dictionary = {"izquierda": {}, "derecha": {}}
var _cooldown: float = 0.0
var _camara: Camera3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	_camara = get_parent() as Camera3D
	_crear_sprite_mano("izquierda", Vector3(-0.34, -0.30, -0.72))
	_crear_sprite_mano("derecha", Vector3(0.34, -0.30, -0.72))


func configurar_contexto(nuevo_inventario: Node, nuevo_jugador: Node, nuevo_resolvedor_visual: Object, nuevos_world_items: Node = null) -> void:
	inventario = nuevo_inventario
	jugador = nuevo_jugador
	resolvedor_visual = nuevo_resolvedor_visual
	world_items = nuevos_world_items
	if is_instance_valid(inventario):
		if inventario.has_signal("hand_item_changed"):
			var callback := Callable(self, "_al_cambiar_objeto_mano")
			if not inventario.is_connected("hand_item_changed", callback):
				inventario.connect("hand_item_changed", callback)
		if inventario.has_signal("inventory_changed"):
			var callback_inventario := Callable(self, "_al_cambiar_inventario")
			if not inventario.is_connected("inventory_changed", callback_inventario):
				inventario.connect("inventory_changed", callback_inventario)
	_actualizar_ambas_manos()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func _crear_sprite_mano(mano: String, posicion: Vector3) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "ObjetoPrimeraPersona_" + mano
	sprite.centered = true
	sprite.texture_filter = SpriteBase3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = 0.01
	sprite.position = posicion
	sprite.scale = Vector3.ONE * 1.15
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.visible = false
	add_child(sprite)
	_sprites[mano] = sprite


func _al_cambiar_objeto_mano(mano: String, _slot_index: int, _datos: Dictionary) -> void:
	_actualizar_mano(mano)


func _al_cambiar_inventario() -> void:
	_actualizar_ambas_manos()


func _actualizar_ambas_manos() -> void:
	_actualizar_mano("izquierda")
	_actualizar_mano("derecha")


func _actualizar_mano(mano: String) -> void:
	if not is_instance_valid(inventario) or not inventario.has_method("obtener_objeto_mano_activa"):
		return
	var objeto: Dictionary = inventario.call("obtener_objeto_mano_activa", mano)
	objeto = _enriquecer_objeto(objeto)
	_datos_manos[mano] = objeto.duplicate(true)
	var sprite := _sprites.get(mano) as Sprite3D
	if not is_instance_valid(sprite):
		return
	if objeto.is_empty():
		sprite.texture = null
		sprite.visible = false
		return
	var textura := _obtener_textura(objeto)
	sprite.texture = textura
	sprite.visible = textura != null


func _enriquecer_objeto(objeto: Dictionary) -> Dictionary:
	var resultado := objeto.duplicate(true)
	if resultado.is_empty() or not is_instance_valid(world_items):
		return resultado
	var item_id := str(resultado.get("item_id", resultado.get("id", ""))).strip_edges()
	var canonico: Dictionary = {}
	if not item_id.is_empty() and world_items.has_method("buscar_item_por_id"):
		canonico = world_items.call("buscar_item_por_id", item_id)
	if canonico.is_empty() and world_items.has_method("buscar_item_por_nombre"):
		canonico = world_items.call("buscar_item_por_nombre", str(resultado.get("nombre", "")))
	if canonico.is_empty():
		return resultado
	for clave in ["nombre", "tipo", "tipo_objeto", "categoria", "categoria_clave", "propiedades_game", "sprite_ruta", "ruta_sprite", "sprite_path", "textura_ruta", "ruta_textura", "texture_path", "imagen_ruta", "ruta_imagen", "icono_ruta"]:
		if not canonico.has(clave):
			continue
		var actual: Variant = resultado.get(clave, null)
		var canonico_valor: Variant = canonico[clave]
		if clave == "propiedades_game" and canonico_valor is Dictionary:
			var combinadas := (canonico_valor as Dictionary).duplicate(true)
			if actual is Dictionary:
				for propiedad in (actual as Dictionary).keys():
					if not combinadas.has(propiedad):
						combinadas[propiedad] = (actual as Dictionary)[propiedad]
			resultado[clave] = combinadas
		elif actual == null or (actual is String and (str(actual).strip_edges().is_empty() or (clave in ["nombre", "tipo"] and str(actual).strip_edges().to_lower() in ["objeto", "item", "desconocido"]))) or (actual is Dictionary and (actual as Dictionary).is_empty()):
			resultado[clave] = canonico_valor.duplicate(true) if canonico_valor is Dictionary or canonico_valor is Array else canonico_valor
	return resultado


func _obtener_textura(objeto: Dictionary) -> Texture2D:
	if is_instance_valid(resolvedor_visual) and resolvedor_visual.has_method("_obtener_textura_equipo"):
		var textura_variant: Variant = resolvedor_visual.call("_obtener_textura_equipo", objeto)
		if textura_variant is Texture2D:
			return textura_variant as Texture2D
	for clave in ["sprite", "textura", "texture", "imagen", "icono"]:
		var valor: Variant = objeto.get(clave, null)
		if valor is Texture2D:
			return valor as Texture2D
	return null


func usar_mano(mano: String) -> bool:
	if mano not in ["izquierda", "derecha"] or _cooldown > 0.0:
		return false
	if not is_instance_valid(inventario) or not is_instance_valid(_camara):
		return false
	var objeto: Dictionary = _datos_manos.get(mano, {}).duplicate(true)
	if objeto.is_empty():
		return false
	_cooldown = enfriamiento_uso
	_animar_uso(mano)
	var impacto := _consultar_objetivo()
	if impacto.is_empty():
		return false
	var objetivo_variant: Variant = impacto.get("collider")
	if not objetivo_variant is Node:
		return false
	var objetivo := objetivo_variant as Node
	var es_herramienta := COMBAT_ITEM_RESOLVER.es_herramienta(objeto)
	var es_arma := COMBAT_ITEM_RESOLVER.es_arma(objeto)
	var aceptado := false
	if es_herramienta:
		if objetivo.has_method("usar_herramienta_3d"):
			aceptado = bool(objetivo.call("usar_herramienta_3d", objeto.duplicate(true), mano, jugador, impacto.get("position", Vector3.ZERO)))
		elif objetivo.has_method("interactuar_herramienta_3d"):
			aceptado = bool(objetivo.call("interactuar_herramienta_3d", objeto.duplicate(true), mano, jugador, impacto.get("position", Vector3.ZERO)))
	elif es_arma:
		if objetivo.has_method("recibir_ataque_3d"):
			aceptado = bool(objetivo.call("recibir_ataque_3d", objeto.duplicate(true), jugador, impacto.get("position", Vector3.ZERO)))
	if aceptado and inventario.has_method("consumir_durabilidad_mano_activa"):
		inventario.call("consumir_durabilidad_mano_activa", mano)
	return aceptado


func _consultar_objetivo() -> Dictionary:
	if not is_instance_valid(_camara):
		return {}
	var espacio := _camara.get_world_3d().direct_space_state
	var inicio := _camara.global_position
	var fin := inicio + (-_camara.global_basis.z) * distancia_interaccion
	var consulta := PhysicsRayQueryParameters3D.create(inicio, fin)
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = true
	var exclusion: Array[RID] = []
	var jugador_3d := get_parent().get_parent() if is_instance_valid(get_parent()) else null
	if jugador_3d is CollisionObject3D:
		exclusion.append((jugador_3d as CollisionObject3D).get_rid())
	consulta.exclude = exclusion
	return espacio.intersect_ray(consulta)


func _animar_uso(mano: String) -> void:
	var sprite := _sprites.get(mano) as Sprite3D
	if not is_instance_valid(sprite) or not sprite.visible:
		return
	var posicion_inicial := sprite.position
	var rotacion_inicial := sprite.rotation
	var desplazamiento := Vector3(0.0, 0.0, 0.16)
	if mano == "izquierda":
		desplazamiento.x = 0.08
	else:
		desplazamiento.x = -0.08
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", posicion_inicial + desplazamiento, 0.09)
	tween.parallel().tween_property(sprite, "rotation", rotacion_inicial + Vector3(-0.42, 0.0, 0.16 if mano == "derecha" else -0.16), 0.09)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position", posicion_inicial, 0.16)
	tween.parallel().tween_property(sprite, "rotation", rotacion_inicial, 0.16)
