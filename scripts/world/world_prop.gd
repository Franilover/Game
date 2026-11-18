extends Node2D
class_name WorldProp

signal interactuar(prop: Node2D)

var tipo = ""
var bioma = ""
var variante = 0
var semilla = 0
var interactuable = false
var datos = {}
var _world_context = null
var _inventory = null
var _world_items = null
var _replica_red_cliente := false
var _recoleccion_en_curso := false
var _recoleccion_token: int = 0
const TIEMPO_RECOLECCION_HERRAMIENTA: float = 1.25
var _progreso_recoleccion: float = 0.0


func _es_servidor_dedicado() -> bool:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or arbol.root == null:
		return false
	var multiplayer := arbol.root.get_node_or_null("GarliaMultiplayer")
	return is_instance_valid(multiplayer) and multiplayer.has_method("es_servidor_dedicado") and bool(multiplayer.call("es_servidor_dedicado"))


func _emitir_notificacion(mensaje: String) -> void:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or arbol.root == null:
		return
	var events := arbol.root.get_node_or_null("Events")
	if is_instance_valid(events) and events.has_signal("notification_pushed"):
		events.emit_signal("notification_pushed", mensaje)




func configurar_dependencias(
	nuevo_world_context,
	nuevo_inventory,
	nuevo_world_items = null
) -> void:
	_world_context = nuevo_world_context
	_inventory = nuevo_inventory
	_world_items = nuevo_world_items
	_conectar_catalogo_items()
	_actualizar_estado_interaccion()



func _normalizar_tipo_prop(valor: String) -> String:
	var tipo_normalizado := valor.strip_edges().to_lower()
	if tipo_normalizado in ["árbol", "arboles", "árboles", "tree", "trees"]:
		return "arbol"
	return tipo_normalizado


func _es_arbol() -> bool:
	var tipo_dato := _normalizar_tipo_prop(str(datos.get("tipo", tipo)))
	var clave := _normalizar_tipo_prop(str(datos.get("clave", datos.get("prop_id", ""))))
	var nombre := _normalizar_tipo_prop(str(datos.get("nombre", "")))
	return tipo_dato == "arbol" or clave == "arbol" or nombre == "arbol"


func configurar(nuevo_tipo: String, nuevo_bioma: String, nueva_variante: int, nueva_semilla: int, nuevos_datos: Dictionary = {}) -> void:
	tipo = _normalizar_tipo_prop(nuevo_tipo)
	bioma = nuevo_bioma
	variante = nueva_variante
	semilla = nueva_semilla
	datos = nuevos_datos.duplicate(true)
	set_meta("atractor_refugio", bool(datos.get("atractor_refugio", false)))
	if datos.has("refugio_clave"):
		set_meta("refugio_clave", str(datos.get("refugio_clave", "")).strip_edges())

	interactuable = (
		tipo == "recurso"
		or tipo == "planta"
		or tipo == "flor"
		or tipo == "arbol"
		or tipo == "cueva"
		or tipo == "estructura"
	)

	remove_from_group("interactable")
	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")

	if interactuable:
		add_to_group("interactable")

	if tipo in ["recurso", "planta", "arbol"]:
		add_to_group("world_resource")
	elif tipo == "cueva":
		add_to_group("world_cave")
	elif tipo == "estructura":
		add_to_group("world_structure")

	queue_redraw()

func obtener_tipo() -> String:
	return tipo

func obtener_datos() -> Dictionary:
	return datos.duplicate(true)


func es_recolectable() -> bool:
	# La identidad del árbol es suficiente para seleccionarlo como objetivo.
	# El item de salida se resuelve al completar la acción, no al buscar objetivo.
	return _es_arbol() or _tiene_recoleccion_canonica()


func get_interaction_distance() -> float:
	return 58.0


func get_interaction_priority() -> int:
	if _es_arbol():
		return 35
	match tipo:
		"recurso", "planta", "flor", "arbol":
			return 30
		"cueva", "estructura":
			return 20
		_:
			return 0


func get_interaction_text() -> String:
	if _tiene_recoleccion_canonica():
		if _replica_red_cliente or (_es_servidor_dedicado() and _inventory == null):
			return "Recolección no sincronizada"
		var requisito := _obtener_requisito_herramienta()
		match str(requisito.get("tipo", "")).strip_edges().to_lower():
			"hacha", "axe":
				return "Cortar"
			"pico", "pickaxe":
				return "Minar"
		return "Recolectar"

	match tipo:
		"recurso", "planta", "flor":
			return "Investigar"
		"cueva":
			return "Explorar"
		"estructura":
			return "Examinar"
		_:
			return "Examinar"


func can_interact(persona: Node) -> bool:
	if not interactuable:
		return false

	if not persona is Node2D:
		return false

	if not is_instance_valid(persona):
		return false

	var persona_2d := persona as Node2D
	var distancia := global_position.distance_to(
		persona_2d.global_position
	)

	return distancia <= get_interaction_distance()


func get_interaction_details() -> Dictionary:
	var detalles: Dictionary = {
		"titulo": tipo.capitalize(),
		"accion": get_interaction_text(),
		"bioma": bioma
	}

	var contexto_provider: Variant = _world_context
	if contexto_provider != null and is_instance_valid(contexto_provider):
		var contexto_variant: Variant = contexto_provider.get_contexto_at(global_position)

		if contexto_variant is Dictionary:
			var contexto := contexto_variant as Dictionary
			var ecosistema_variant: Variant = contexto.get(
				"ecosistema",
				""
			)
			var habitat_variant: Variant = contexto.get(
				"habitat",
				""
			)

			if ecosistema_variant is String:
				detalles["ecosistema"] = ecosistema_variant
			elif ecosistema_variant is Dictionary:
				detalles["ecosistema"] = str(
					(ecosistema_variant as Dictionary).get(
						"nombre",
						""
					)
				)

			if habitat_variant is String:
				detalles["habitat"] = habitat_variant
			elif habitat_variant is Dictionary:
				detalles["habitat"] = str(
					(habitat_variant as Dictionary).get(
						"nombre",
						""
					)
				)

	var item_id := _obtener_item_id_recoleccion()
	if not item_id.is_empty() and is_instance_valid(_world_items):
		var item: Dictionary = _world_items.buscar_item_por_id(
			item_id
		)

		if not item.is_empty():
			detalles["item_nombre"] = str(
				item.get(
					"nombre",
					""
				)
			)
			detalles["descripcion"] = str(
				item.get(
					"descripcion",
					""
				)
			)

	return detalles


func interact(persona: Node) -> bool:
	return interactuar_con_herramienta(persona, "mano_secundaria")


func interactuar_con_herramienta(persona: Node, mano: String) -> bool:
	if not can_interact(persona):
		return false

	if _tiene_recoleccion_canonica():
		if _replica_red_cliente or (_es_servidor_dedicado() and _inventory == null):
			_emitir_notificacion("La recolección multijugador aún no está disponible.")
			return true

		var requisito := _obtener_requisito_herramienta()
		if not requisito.is_empty():
			# El clic puede venir de cualquiera de las dos manos. Si la mano
			# pulsada no lleva la herramienta, aceptar la otra mano equipada.
			var mano_herramienta := mano
			if not _puede_recolectar(persona, mano_herramienta):
				var mano_alternativa := "derecha" if mano == "izquierda" else "izquierda"
				if _puede_recolectar(persona, mano_alternativa):
					mano_herramienta = mano_alternativa
				else:
					var tipo_herramienta := str(requisito.get("tipo", "herramienta"))
					var nivel_requerido := maxi(1, int(requisito.get("nivel", 1)))
					_emitir_notificacion("Necesitas " + tipo_herramienta + " nivel " + str(nivel_requerido))
					return true
			if _recoleccion_en_curso:
				return true
			_recoleccion_en_curso = true
			_progreso_recoleccion = 0.0
			queue_redraw()
			_recoleccion_token += 1
			call_deferred("_ejecutar_recoleccion_con_herramienta", persona, mano_herramienta, _recoleccion_token)
			return true

		_recolectar(persona)
		return true

	var accion := get_interaction_text()
	var categoria: String = tipo.capitalize()
	if tipo == "cueva":
		categoria = "Entrada"
	elif tipo == "recurso":
		categoria = "Recurso"
	var mensaje := accion + " " + categoria
	if not bioma.is_empty():
		mensaje += " · " + bioma
	_emitir_notificacion(mensaje)
	print("WorldProp: interacción → ", accion, " | tipo=", tipo, " | bioma=", bioma)
	return true


func _ejecutar_recoleccion_con_herramienta(persona: Node, mano: String, token: int) -> void:
	var herramienta: Dictionary = _inventory.obtener_objeto_mano_activa(mano).duplicate(true)
	if persona.has_method("reproducir_animacion_herramienta"):
		persona.call("reproducir_animacion_herramienta", herramienta, global_position)

	var sprite := get_node_or_null("Sprite") as Sprite2D
	if is_instance_valid(sprite):
		var posicion_inicial := sprite.position
		var sacudida := create_tween()
		sacudida.tween_property(sprite, "position", posicion_inicial + Vector2(2.0, 0.0), 0.07)
		sacudida.tween_property(sprite, "position", posicion_inicial + Vector2(-2.0, 0.0), 0.07)
		sacudida.tween_property(sprite, "position", posicion_inicial, 0.07)

	var tiempo_transcurrido := 0.0
	while tiempo_transcurrido < TIEMPO_RECOLECCION_HERRAMIENTA:
		if not is_instance_valid(self) or token != _recoleccion_token:
			return
		var paso := minf(0.05, TIEMPO_RECOLECCION_HERRAMIENTA - tiempo_transcurrido)
		await get_tree().create_timer(paso).timeout
		tiempo_transcurrido += paso
		_progreso_recoleccion = clampf(tiempo_transcurrido / TIEMPO_RECOLECCION_HERRAMIENTA, 0.0, 1.0)
		queue_redraw()
	if not is_instance_valid(self) or token != _recoleccion_token:
		return
	_recoleccion_en_curso = false
	_progreso_recoleccion = 0.0
	queue_redraw()

	if not is_instance_valid(persona) or not can_interact(persona):
		return
	if not _puede_recolectar(persona, mano):
		return

	# El recurso sólo se entrega al completar la animación y si el inventario
	# todavía puede recibirlo. _recolectar conserva el vínculo canónico prop → item.
	_recolectar(persona)


func _tiene_recoleccion_canonica() -> bool:
	# Supabase manda: respetar una declaración explícita, incluso si desactiva
	# la recolección. Los árboles antiguos se reconocen por identidad mientras
	# llega el snapshot actualizado con item_id y propiedades.
	var propiedades_variant: Variant = datos.get("propiedades", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		if propiedades.has("recolectable"):
			return bool(propiedades.get("recolectable", false))

	if _es_arbol():
		return true

	return not _obtener_item_id_recoleccion().is_empty()


func _obtener_requisito_herramienta() -> Dictionary:
	var requisito_variant: Variant = datos.get("herramienta_recoleccion", {})
	if requisito_variant is Dictionary and not (requisito_variant as Dictionary).is_empty():
		return (requisito_variant as Dictionary).duplicate(true)

	var propiedades_variant: Variant = datos.get("propiedades", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		requisito_variant = propiedades.get("herramienta_recoleccion", {})
		if requisito_variant is Dictionary and not (requisito_variant as Dictionary).is_empty():
			return (requisito_variant as Dictionary).duplicate(true)

	# Los árboles actuales de props_game no tienen requisito explícito todavía.
	# Su interacción de tala usa el hacha básica como herramienta mínima.
	if _es_arbol():
		return {"tipo": "hacha", "nivel": 1}
	return {}


func _puede_recolectar(persona: Node, mano: String) -> bool:
	var requisito := _obtener_requisito_herramienta()
	if requisito.is_empty():
		return true
	if not is_instance_valid(persona):
		return false

	var inventario: Node = _inventory
	if inventario == null or not inventario.has_method("obtener_objeto_mano_activa"):
		return false
	if mano not in ["izquierda", "derecha", "mano_secundaria"]:
		return false

	var mano_inventario := "derecha" if mano == "mano_secundaria" else mano
	var herramienta_variant: Variant = inventario.call("obtener_objeto_mano_activa", mano_inventario)
	if not herramienta_variant is Dictionary:
		return false

	var herramienta := herramienta_variant as Dictionary
	var propiedades_variant: Variant = herramienta.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant as Dictionary if propiedades_variant is Dictionary else {}
	var herramienta_recoleccion_variant: Variant = propiedades.get("herramienta_recoleccion", {})
	var herramienta_recoleccion: Dictionary = herramienta_recoleccion_variant as Dictionary if herramienta_recoleccion_variant is Dictionary else {}

	var tipo_requerido := str(requisito.get("tipo", "")).strip_edges().to_lower()
	var tipo_actual := str(herramienta_recoleccion.get("tipo", "")).strip_edges().to_lower()
	var nivel_actual := int(herramienta_recoleccion.get("nivel", 0))

	# Compatibilidad con las hachas ya registradas en items_game, cuyas
	# propiedades todavía están vacías. El nombre del item determina tipo y nivel.
	if tipo_actual.is_empty():
		var nombre_herramienta := str(herramienta.get("nombre", "")).strip_edges().to_lower()
		if nombre_herramienta.contains("hacha"):
			tipo_actual = "hacha"
			nivel_actual = 2 if nombre_herramienta.contains("piedra") else 1
		elif nombre_herramienta.contains("pico"):
			tipo_actual = "pico"
			nivel_actual = 2 if nombre_herramienta.contains("piedra") else 1

	var nivel_requerido := maxi(1, int(requisito.get("nivel", 1)))
	return not tipo_requerido.is_empty() and tipo_actual == tipo_requerido and nivel_actual >= nivel_requerido


func _obtener_item_id_recoleccion() -> String:
	var item_id_variant: Variant = datos.get("item_id", null)
	var item_id := "" if item_id_variant == null else str(item_id_variant).strip_edges()
	if not item_id.is_empty():
		return item_id

	# Los árboles del catálogo actual no tienen item_id asociado. La tala
	# entrega el recurso canónico Madera desde el catálogo de items_game.
	if _es_arbol():
		if not is_instance_valid(_world_items):
			return ""
		var madera: Dictionary = _world_items.buscar_item_por_nombre("Madera")
		if madera.is_empty() and _world_items.has_method("obtener_catalogo"):
			for item_variant in _world_items.obtener_catalogo():
				if not item_variant is Dictionary:
					continue
				var item_catalogo := item_variant as Dictionary
				if str(item_catalogo.get("nombre", "")).strip_edges().to_lower() == "madera":
					madera = item_catalogo
					break
		return str(madera.get("item_id", madera.get("id", ""))).strip_edges()

	# El snapshot de props_game puede conservar el vínculo en
	# propiedades.item_id aunque item_id no haya sido proyectado al nodo.
	var propiedades_variant: Variant = datos.get("propiedades", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		item_id = str(propiedades.get("item_id", "")).strip_edges()
		if not item_id.is_empty():
			return item_id

	var recoleccion_variant: Variant = datos.get("recoleccion", {})
	if recoleccion_variant is Dictionary:
		item_id = str((recoleccion_variant as Dictionary).get("item_id", "")).strip_edges()
		if not item_id.is_empty():
			return item_id

	# props_game y items_game están relacionados en Supabase mediante
	# props_game.item_id; WorldData puede no incluir esa columna en su
	# consulta. En ese caso resolvemos el vínculo por propiedades_game.prop_id,
	# que también viene definido en el registro canónico de items_game.
	var prop_id := str(datos.get("id", "")).strip_edges()
	if prop_id.is_empty():
		prop_id = str(datos.get("prop_id", "")).strip_edges()
	if prop_id.is_empty():
		return ""

	if not is_instance_valid(_world_items):
		return ""
	for item_variant in _world_items.obtener_catalogo():
		if not item_variant is Dictionary:
			continue
		var item := item_variant as Dictionary
		var propiedades_item_variant: Variant = item.get("propiedades_game", {})
		if not propiedades_item_variant is Dictionary:
			continue
		var propiedades_item := propiedades_item_variant as Dictionary
		if str(propiedades_item.get("prop_id", "")).strip_edges() != prop_id:
			continue
		return str(item.get("item_id", item.get("id", ""))).strip_edges()

	return ""


func _obtener_cantidad_recoleccion() -> int:
	var cantidad: int = 1
	var recoleccion_variant: Variant = datos.get("recoleccion", {})
	if not recoleccion_variant is Dictionary:
		var propiedades_variant: Variant = datos.get("propiedades", {})
		if propiedades_variant is Dictionary:
			recoleccion_variant = (propiedades_variant as Dictionary).get("recoleccion", {})

	if recoleccion_variant is Dictionary:
		cantidad = maxi(1, int((recoleccion_variant as Dictionary).get("cantidad", 1)))

	return cantidad


func _recolectar(persona: Node) -> bool:
	var inventario: Node = _inventory
	if inventario == null or not is_instance_valid(inventario):
		print("WorldProp: no se puede recolectar → inventario inválido.")
		return false
	if not inventario.has_method("agregar_objeto"):
		print("WorldProp: no se puede recolectar → inventario sin agregar_objeto.")
		return false

	if _world_items == null or not is_instance_valid(_world_items):
		print("WorldProp: no se puede recolectar → GarliaWorldItems inválido.")
		return false

	var item_id := _obtener_item_id_recoleccion()
	if item_id.is_empty():
		print(
			"WorldProp: no se puede recolectar → item de salida no disponible. ",
			"datos=",
			datos
		)
		_emitir_notificacion("El catálogo de recursos aún no está disponible. Inténtalo de nuevo en un momento.")
		return false

	var item: Dictionary = _world_items.buscar_item_por_id(
		item_id
	)
	if item.is_empty():
		print(
			"WorldProp: el item canónico no está cargado → ",
			item_id
		)
		_emitir_notificacion("No se pudo cargar el recurso Madera. El árbol sigue intacto; inténtalo de nuevo.")
		return false

	item["cantidad"] = _obtener_cantidad_recoleccion()

	var agregado: bool = bool(
		inventario.call(
			"agregar_objeto",
			item
		)
	)
	if not agregado:
		print(
			"WorldProp: recolección rechazada por inventario → ",
			str(item.get("nombre", "Objeto")),
			" | item_id=",
			item_id,
			" | slots=",
			str(inventario.get("items").size() if inventario.get("items") is Array else -1)
		)
		_emitir_notificacion("No tienes espacio en el inventario.")
		return false

	_emitir_notificacion(
		"Recolectaste " + str(
			item.get(
				"nombre",
				"Objeto"
			)
		) + " x" + str(
			item.get(
				"cantidad",
				1
			)
		)
	)

	print(
		"WorldProp: recurso recolectado → ",
		str(item.get("nombre", "Objeto")),
		" x",
		str(item.get("cantidad", 1)),
		" | item_id=",
		item_id,
		" | bioma=",
		bioma
	)

	queue_free()
	return true



func activar_como_proxy() -> void:
	visible = true
	set_process(true)
	_actualizar_estado_interaccion()
	_actualizar_profundidad()
	queue_redraw()


func desactivar_como_proxy() -> void:
	_recoleccion_token += 1
	_recoleccion_en_curso = false
	set_process(false)
	remove_from_group("interactable")
	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")
	visible = false


func configurar_desde_game_data(datos_game: Dictionary) -> void:
	add_to_group("world_props")
	datos = datos_game.duplicate(true)
	tipo = _normalizar_tipo_prop(str(datos.get("tipo", "decoracion")))
	bioma = ""
	var asset_path := str(datos.get("asset_path", "")).strip_edges()
	_actualizar_estado_interaccion()

	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")

	if tipo in ["recurso", "planta", "arbol"]:
		add_to_group("world_resource")
	elif tipo == "cueva":
		add_to_group("world_cave")
	elif tipo == "estructura":
		add_to_group("world_structure")

	_actualizar_sprite(asset_path)
	queue_redraw()


func configurar_replica_red_cliente() -> void:
	_replica_red_cliente = true


func ocultar_replica_red_cliente() -> void:
	configurar_replica_red_cliente()
	visible = false
	remove_from_group("interactable")
	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")


func aplicar_estado_red(posicion: Vector2) -> void:
	configurar_replica_red_cliente()
	global_position = posicion
	visible = true
	if interactuable:
		add_to_group("interactable")
	if tipo in ["recurso", "planta", "arbol"]:
		add_to_group("world_resource")
	elif tipo == "cueva":
		add_to_group("world_cave")
	elif tipo == "estructura":
		add_to_group("world_structure")


func reactivar_simulacion_local_red() -> void:
	_replica_red_cliente = false
	visible = true
	remove_from_group("interactable")
	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")
	if interactuable:
		add_to_group("interactable")
	if tipo in ["recurso", "planta", "arbol"]:
		add_to_group("world_resource")
	elif tipo == "cueva":
		add_to_group("world_cave")
	elif tipo == "estructura":
		add_to_group("world_structure")


func configurar_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2
) -> void:
	datos["chunk"] = chunk_coord
	datos["limite_chunk"] = limite_chunk


func _actualizar_sprite(asset_path: String) -> void:
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		push_error("WorldProp: la escena world_prop.tscn no contiene el nodo Sprite.")
		return

	if asset_path.is_empty():
		sprite.texture = null
		sprite.visible = false
		return

	var textura: Texture2D = load(asset_path)
	if textura == null:
		push_warning(
			"WorldProp: no se pudo cargar asset_path → " + asset_path
		)
		sprite.texture = null
		sprite.visible = false
		return

	sprite.texture = textura
	sprite.visible = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * maxf(float(datos.get("escala", 1.0)), 0.01)
	sprite.position = Vector2(
		float(datos.get("offset_x", 0.0)),
		float(datos.get("offset_y", 0.0))
	)


func _actualizar_profundidad() -> void:
	# Los props viven bajo Entities, mientras el terreno usa capas
	# TileMapDual internas. Usar z relativo podía sumar la profundidad
	# al z del contenedor y dejar el resultado sujeto a la jerarquía.
	# La profundidad del prop se establece en coordenadas absolutas.
	z_as_relative = false

	# El punto de apoyo es la base del sprite, no su centro. Así los
	# objetos altos conservan una profundidad coherente con el jugador.
	var profundidad_y := global_position.y
	var sprite := get_node_or_null("Sprite") as Sprite2D

	if sprite != null and sprite.texture != null:
		profundidad_y += sprite.position.y
		profundidad_y += (
			float(sprite.texture.get_height())
			* 0.5
			* absf(sprite.scale.y)
		)

	profundidad_y += float(datos.get("profundidad_offset_y", 0.0))

	# El margen positivo mantiene los props por delante del terreno,
	# cuyas capas usan z_index negativo; el componente Y conserva
	# el orden entre props según su punto de apoyo.
	z_index = clampi(1000 + int(profundidad_y), 1, 4096)


func _ready() -> void:
	add_to_group("world_props")
	_conectar_catalogo_items()
	_actualizar_estado_interaccion()
	_actualizar_profundidad()


func _conectar_catalogo_items() -> void:
	if not is_instance_valid(_world_items):
		return
	if not _world_items.catalogo_cargado.is_connected(_al_cargar_catalogo_items):
		_world_items.catalogo_cargado.connect(_al_cargar_catalogo_items)


func _process(_delta: float) -> void:
	_actualizar_profundidad()
	if _recoleccion_en_curso:
		queue_redraw()


func _al_cargar_catalogo_items(_items: Array) -> void:
	_actualizar_estado_interaccion()


func _actualizar_estado_interaccion() -> void:
	interactuable = _tiene_recoleccion_canonica() or tipo != "decoracion"
	if interactuable:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")


func _draw() -> void:
	# La barra temporal representa el progreso de la acción sobre este prop;
	# el sprite principal sigue viniendo exclusivamente de asset_path.
	if not _recoleccion_en_curso:
		return
	var sprite := get_node_or_null("Sprite") as Sprite2D
	var alto_sprite := 24.0
	if is_instance_valid(sprite) and sprite.texture != null:
		alto_sprite = float(sprite.texture.get_height()) * absf(sprite.scale.y)
	var origen := Vector2(-18.0, -alto_sprite * 0.5 - 12.0)
	var fondo := Rect2(origen, Vector2(36.0, 5.0))
	draw_rect(fondo, Color(0.12, 0.10, 0.08, 0.95), true)
	draw_rect(Rect2(origen + Vector2.ONE, Vector2(34.0 * _progreso_recoleccion, 3.0)), Color(0.82, 0.68, 0.43, 1.0), true)
