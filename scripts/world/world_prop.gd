extends Node2D
class_name WorldProp

signal interactuar(prop: Node2D)

var tipo = ""
var bioma = ""
var variante = 0
var semilla = 0
var interactuable = false
var datos = {}

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

	var generador := get_tree().get_first_node_in_group(
		"world_generator"
	)

	if generador != null and generador.has_method(
		"get_contexto_at"
	):
		var contexto_variant: Variant = generador.call(
			"get_contexto_at",
			global_position
		)

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
		var item := GarliaWorldItems.buscar_item_por_id(
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


func interact(persona: Node) -> void:
	if not can_interact(persona):
		return

	if _tiene_recoleccion_canonica():
		if _recolectar(persona):
			return

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


func _tiene_recoleccion_canonica() -> bool:
	if tipo != "recurso" and tipo != "planta" and tipo != "flor":
		return false

	var item_id := _obtener_item_id_recoleccion()
	return not item_id.is_empty()


func _obtener_item_id_recoleccion() -> String:
	var item_id := str(
		datos.get(
			"item_id",
			""
		)
	).strip_edges()

	if not item_id.is_empty():
		return item_id

	var recoleccion_variant: Variant = datos.get(
		"recoleccion",
		{}
	)

	if not recoleccion_variant is Dictionary:
		return ""

	return str(
		(recoleccion_variant as Dictionary).get(
			"item_id",
			""
		)
	).strip_edges()


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
	var inventario: Node = get_tree().get_first_node_in_group(
		"inventory"
	)
	if inventario == null or not inventario.has_method(
		"agregar_objeto"
	):
		return false

	var item_id := _obtener_item_id_recoleccion()
	if item_id.is_empty():
		return false

	var item := GarliaWorldItems.buscar_item_por_id(
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



func configurar_desde_game_data(datos_game: Dictionary) -> void:
	datos = datos_game.duplicate(true)
	tipo = str(datos.get("tipo", "decoracion"))
	bioma = ""
	var asset_path := str(datos.get("asset_path", "")).strip_edges()
	interactuable = tipo != "decoracion"

	if interactuable:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")

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


func configurar_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2
) -> void:
	datos["chunk"] = chunk_coord
	datos["limite_chunk"] = limite_chunk


func _actualizar_sprite(asset_path: String) -> void:
	var anterior := get_node_or_null("Sprite")
	if anterior != null:
		anterior.queue_free()

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

	z_index = clampi(
		int(global_position.y / 8.0),
		-4096,
		4096
	)


func _ready() -> void:
	z_index = clampi(
		int(global_position.y / 8.0),
		-4096,
		4096
	)


func _draw() -> void:
	# Los props del mundo ya no se dibujan con geometría generada.
	# Su representación visual viene exclusivamente de asset_path,
	# definido por Supabase en props_game.
	pass
