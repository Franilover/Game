extends Node2D
class_name WorldProp

signal interactuar(prop: Node2D)

var tipo = ""
var bioma = ""
var variante = 0
var semilla = 0
var interactuable = false
var datos = {}
var _world_context: WorldContext = null
var _inventory: GarliaInventory = null
var _world_items: GarliaWorldItems = null
var _replica_red_cliente := false


func configurar_dependencias(
	nuevo_world_context: WorldContext,
	nuevo_inventory: GarliaInventory,
	nuevo_world_items: GarliaWorldItems = null
) -> void:
	_world_context = nuevo_world_context
	_inventory = nuevo_inventory
	_world_items = nuevo_world_items



func configurar(nuevo_tipo: String, nuevo_bioma: String, nueva_variante: int, nueva_semilla: int, nuevos_datos: Dictionary = {}) -> void:
	tipo = nuevo_tipo
	bioma = nuevo_bioma
	variante = nueva_variante
	semilla = nueva_semilla
	datos = nuevos_datos.duplicate(true)

	interactuable = (
		tipo == "recurso"
		or tipo == "planta"
		or tipo == "flor"
		or tipo == "cueva"
		or tipo == "estructura"
	)

	remove_from_group("interactable")
	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")

	if interactuable:
		add_to_group("interactable")

	if tipo == "recurso" or tipo == "planta":
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
	return _tiene_recoleccion_canonica()


func get_interaction_distance() -> float:
	return 58.0


func get_interaction_priority() -> int:
	match tipo:
		"recurso", "planta", "flor":
			return 30
		"cueva", "estructura":
			return 20
		_:
			return 0


func get_interaction_text() -> String:
	if _tiene_recoleccion_canonica():
		if _replica_red_cliente or (GarliaMultiplayer.es_servidor_dedicado() and _inventory == null):
			return "Recolección no sincronizada"
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

	var contexto_provider := _world_context
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
	if not item_id.is_empty():
		var item := _world_items.buscar_item_por_id(
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
	if not can_interact(persona):
		return false

	if _tiene_recoleccion_canonica():
		if _replica_red_cliente or (GarliaMultiplayer.es_servidor_dedicado() and _inventory == null):
			Events.notification_pushed.emit("La recolección multijugador aún no está disponible.")
			return true
		if not _puede_recolectar(persona):
			var requisito := _obtener_requisito_herramienta()
			var tipo_herramienta: String = str(requisito.get("tipo", "herramienta"))
			var nivel_requerido: int = maxi(1, int(requisito.get("nivel", 1)))
			Events.notification_pushed.emit(
				"Necesitas " + tipo_herramienta + " nivel " + str(nivel_requerido)
			)
			print(
				"WorldProp: recolección bloqueada por herramienta → ",
				tipo_herramienta,
				" nivel ",
				nivel_requerido
			)
			return true

		if _recolectar(persona):
			return true

		# La interacción fue reconocida, pero la recolección falló.
		# No dejamos que este caso caiga silenciosamente en combate.
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

	Events.notification_pushed.emit(
		mensaje
	)

	print(
		"WorldProp: interacción → ",
		accion,
		" | tipo=",
		tipo,
		" | bioma=",
		bioma
	)

	return true


func _tiene_recoleccion_canonica() -> bool:
	var item_id := _obtener_item_id_recoleccion()
	if item_id.is_empty():
		return false

	# Supabase manda: un prop puede ser "decoracion" visualmente y aun así
	# ser recolectable. La propiedad canónica es propiedades.recolectable.
	var propiedades_variant: Variant = datos.get("propiedades", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		if propiedades.has("recolectable"):
			return bool(propiedades.get("recolectable", false))

	# Compatibilidad con snapshots donde la propiedad aún no viene incluida:
	# si existe un item_id canónico, el vínculo prop → item sigue siendo válido.
	return true


func _obtener_requisito_herramienta() -> Dictionary:
	var requisito_variant: Variant = datos.get("herramienta_recoleccion", {})
	if requisito_variant is Dictionary:
		return (requisito_variant as Dictionary).duplicate(true)

	var propiedades_variant: Variant = datos.get("propiedades", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		requisito_variant = propiedades.get("herramienta_recoleccion", {})
		if requisito_variant is Dictionary:
			return (requisito_variant as Dictionary).duplicate(true)

	return {}


func _puede_recolectar(persona: Node) -> bool:
	var requisito := _obtener_requisito_herramienta()
	if requisito.is_empty():
		return true

	var inventario: Node = _inventory
	if inventario == null or not inventario.has_method("obtener_objeto_equipado"):
		return false

	var herramienta_variant: Variant = inventario.call(
		"obtener_objeto_equipado",
		"mano_secundaria"
	)

	if not herramienta_variant is Dictionary:
		return false

	var herramienta := herramienta_variant as Dictionary
	var propiedades_variant: Variant = herramienta.get("propiedades_game", {})
	if not propiedades_variant is Dictionary:
		return false

	var propiedades := propiedades_variant as Dictionary
	var herramienta_recoleccion_variant: Variant = propiedades.get(
		"herramienta_recoleccion",
		{}
	)
	if not herramienta_recoleccion_variant is Dictionary:
		return false

	var herramienta_recoleccion := herramienta_recoleccion_variant as Dictionary
	var tipo_requerido := str(requisito.get("tipo", "")).strip_edges().to_lower()
	var tipo_actual := str(herramienta_recoleccion.get("tipo", "")).strip_edges().to_lower()
	var nivel_requerido: int = maxi(1, int(requisito.get("nivel", 1)))
	var nivel_actual: int = int(herramienta_recoleccion.get("nivel", 0))

	return (
		not tipo_requerido.is_empty()
		and tipo_actual == tipo_requerido
		and nivel_actual >= nivel_requerido
	)


func _obtener_item_id_recoleccion() -> String:
	var item_id := str(datos.get("item_id", "")).strip_edges()
	if not item_id.is_empty():
		return item_id

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
	var recoleccion_variant: Variant = datos.get(
		"recoleccion",
		{}
	)

	if recoleccion_variant is Dictionary:
		cantidad = maxi(
			1,
			int(
				(recoleccion_variant as Dictionary).get(
					"cantidad",
					1
				)
			)
		)

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
			"WorldProp: no se puede recolectar → prop sin item_id canónico. ",
			"datos=",
			datos
		)
		return false

	var item := _world_items.buscar_item_por_id(
		item_id
	)
	if item.is_empty():
		print(
			"WorldProp: el item canónico no está cargado → ",
			item_id
		)
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
		Events.notification_pushed.emit("No tienes espacio en el inventario.")
		return false

	Events.notification_pushed.emit(
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
	set_process(false)
	remove_from_group("interactable")
	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")
	visible = false


func configurar_desde_game_data(datos_game: Dictionary) -> void:
	add_to_group("world_props")
	datos = datos_game.duplicate(true)
	tipo = str(datos.get("tipo", "decoracion"))
	bioma = ""
	var asset_path := str(datos.get("asset_path", "")).strip_edges()
	_actualizar_estado_interaccion()

	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")

	if tipo == "recurso" or tipo == "planta":
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
	if tipo == "recurso" or tipo == "planta":
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
	if tipo == "recurso" or tipo == "planta":
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
	var anterior := get_node_or_null("Sprite")
	if anterior != null and is_instance_valid(anterior):
		anterior.free()

	if asset_path.is_empty():
		return

	var textura: Texture2D = load(asset_path)
	if textura == null:
		push_warning(
			"WorldProp: no se pudo cargar asset_path → " + asset_path
		)
		return

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * maxf(float(datos.get("escala", 1.0)), 0.01)
	sprite.position = Vector2(
		float(datos.get("offset_x", 0.0)),
		float(datos.get("offset_y", 0.0))
	)
	add_child(sprite)


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
	if not _world_items.catalogo_cargado.is_connected(_al_cargar_catalogo_items):
		_world_items.catalogo_cargado.connect(_al_cargar_catalogo_items)
	_actualizar_profundidad()


func _process(_delta: float) -> void:
	_actualizar_profundidad()


func _al_cargar_catalogo_items(_items: Array) -> void:
	_actualizar_estado_interaccion()


func _actualizar_estado_interaccion() -> void:
	interactuable = _tiene_recoleccion_canonica() or tipo != "decoracion"
	if interactuable:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")


func _draw() -> void:
	# Los props del mundo ya no se dibujan con geometría generada.
	# Su representación visual viene exclusivamente de asset_path,
	# definido por Supabase en props_game.
	pass
