extends Entity
class_name Creature


@export var move_speed: float = 20.0
@export var min_move_time: float = 1.0
@export var max_move_time: float = 3.0

@export var mostrar_nombre_debug: bool = true
@export var nombre_font_size: int = 10
@export var nombre_outline_size: int = 2


var criatura_id: String = ""
var criatura_nombre: String = ""
var nombre_individual: String = ""

var datos: Dictionary = {}

var comportamiento: String = ""
var biologia: String = ""
var pensamiento: String = ""
var alma: String = ""
var relacion: String = ""
var magia: String = ""

var stats_dnd: Dictionary = {}

var chunk_coord: Vector2i = Vector2i.ZERO
var limites_chunk: Rect2 = Rect2()

var entorno: String = "tierra"

var _movimiento: CreatureMovement = null
var _dialogue_system_dependency: DialogueSystem = null
var _mission_manager_dependency: MissionManagerService = null
var _effects_root: Node = null
var _world_items_dependency: GarliaWorldItems = null
var _world_data_dependency: WorldDataService = null

var _rng := RandomNumberGenerator.new()
var _siguiendo_jugador: bool = false
var _jugador_seguimiento: Node = null
var _distancia_seguimiento: float = 24.0
var _muerte_procesada: bool = false
var _atacante_actual_danio: Node = null

var _sprite_textura_base: Texture2D = null
var _sprite_hframes_base: int = 1
var _sprite_vframes_base: int = 1
var _sprite_frame_base: int = 0
var _ataque_animando: bool = false
var _ataque_frame_actual: int = 0
var _ataque_frames_totales: int = 1
var _ataque_tiempo: float = 0.0
var _ataque_fps: float = 10.0

var _caminando_animando: bool = false
var _caminando_textura_base: Texture2D = null
var _caminando_hframes_base: int = 1
var _caminando_vframes_base: int = 1
var _caminando_frame_base: int = 0
var _caminando_frame_actual: int = 0
var _caminando_frames_totales: int = 1
var _caminando_tiempo: float = 0.0
var _caminando_fps: float = 8.0


func configurar_dependencias(
	dialogue_system: DialogueSystem,
	mission_manager: MissionManagerService,
	effects_root: Node,
	world_items: GarliaWorldItems,
	world_data: WorldDataService,
	relaciones_ecologicas: Array = []
) -> void:
	_dialogue_system_dependency = dialogue_system
	_mission_manager_dependency = mission_manager
	_effects_root = effects_root
	_world_items_dependency = world_items
	_world_data_dependency = world_data



func _ready() -> void:
	super._ready()

	# Las capas de TileMapDual pueden renderizar sus nodos Display internos
	# fuera del orden visual del contenedor. Fijamos la criatura en una capa
	# absoluta por encima del terreno y ordenamos entidades por el punto de apoyo.
	z_as_relative = false
	_actualizar_profundidad()

	add_to_group("interactable")
	add_to_group("creatures")

	_rng.seed = abs(
		hash(str(get_instance_id()))
	) + 1

	_crear_movimiento()

	queue_redraw()


func _crear_movimiento() -> void:
	_movimiento = get_node_or_null(
		"CreatureMovement"
	) as CreatureMovement

	if _movimiento == null:
		_movimiento = CreatureMovement.new()
		_movimiento.name = "CreatureMovement"
		add_child(_movimiento)

	_movimiento.configurar(
		self,
		move_speed,
		min_move_time,
		max_move_time,
		abs(
			hash(str(get_instance_id()))
		) + 1
	)


func configurar(
	datos_criatura: Dictionary
) -> void:
	_muerte_procesada = false
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	velocity = Vector2.ZERO
	datos = datos_criatura

	criatura_id = str(
		datos_criatura.get(
			"id",
			""
		)
	)

	criatura_nombre = str(
		datos_criatura.get(
			"nombre",
			"Criatura"
		)
	)

	nombre_individual = _obtener_nombre_individual()

	comportamiento = str(
		datos_criatura.get(
			"comportamiento",
			""
		)
	)

	biologia = str(
		datos_criatura.get(
			"biologia",
			""
		)
	)

	pensamiento = str(
		datos_criatura.get(
			"pensamiento",
			""
		)
	)

	alma = str(
		datos_criatura.get(
			"alma",
			""
		)
	)

	relacion = str(
		datos_criatura.get(
			"relacion",
			""
		)
	)

	magia = str(
		datos_criatura.get(
			"magia",
			""
		)
	)

	var stats_variant: Variant = datos_criatura.get(
		"stats_dnd",
		{}
	)

	if stats_variant is Dictionary:
		stats_dnd = stats_variant
	else:
		stats_dnd = {}

	var hp_variant: Variant = stats_dnd.get(
		"hp_max",
		null
	)

	if hp_variant != null:
		max_health = maxi(
			1,
			int(hp_variant)
		)

	health = max_health
	mana = max_mana
	is_alive = true

	_rng.seed = abs(
		hash(
			criatura_id
			+ criatura_nombre
		)
	) + 1

	if _movimiento == null:
		_crear_movimiento()

	if _movimiento != null:
		_movimiento.configurar(
			self,
			move_speed,
			min_move_time,
			max_move_time,
			abs(
				hash(
					criatura_id
					+ criatura_nombre
				)
			) + 1
		)

	_cargar_sprite()

	var ai := get_node_or_null("AIController") as CreatureAI
	if ai != null:
		ai.configurar_criatura()

	queue_redraw()


func _cargar_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var rutas: Array[String] = []

	# Los Garumis tienen un catálogo visual independiente. No reutilizamos por
	# accidente el sprite de una criatura normal con el mismo nombre.
	if str(datos.get("categoria_entidad", "")).strip_edges().to_lower() == "garumi":
		var asset_key := str(datos.get("asset_key", criatura_nombre)).strip_edges()
		if asset_key.is_empty() or asset_key.contains("/") or asset_key.contains("\\"):
			asset_key = criatura_nombre
		var rutas_garumi: Array[String] = [
			"res://assets/art/garumis/" + asset_key + ".png",
			"res://assets/art/garumis/" + asset_key + ".PNG",
			"res://assets/art/garumis/" + asset_key + ".svg",
			"res://assets/art/garumis/" + asset_key + ".SVG"
		]
		var textura_garumi: Texture2D = null
		for ruta_garumi in rutas_garumi:
			if not ResourceLoader.exists(ruta_garumi):
				continue
			textura_garumi = load(ruta_garumi) as Texture2D
			if textura_garumi != null:
				break
		var sprite_garumi := get_node_or_null("Sprite2D") as Sprite2D
		if sprite_garumi != null:
			sprite_garumi.texture = textura_garumi
		set_meta("garumi_sprite_missing", textura_garumi == null)
		queue_redraw()
		return


	if _es_humano() and not nombre_individual.is_empty():
		rutas.append(
			"res://assets/art/characters/"
			+ nombre_individual
			+ ".png"
		)
		rutas.append(
			"res://assets/art/characters/"
			+ nombre_individual
			+ ".PNG"
		)

	# Las criaturas pueden tener su sprite canónico en una carpeta propia
	# o en la raíz de creatures. Ambos formatos son compatibles.
	var nombre := criatura_nombre.strip_edges()
	if not nombre.is_empty():
		rutas.append(
			"res://assets/art/creatures/"
			+ nombre
			+ "/"
			+ nombre
			+ ".png"
		)
		rutas.append(
			"res://assets/art/creatures/"
			+ nombre
			+ "/"
			+ nombre
			+ ".PNG"
		)
	rutas.append(
		"res://assets/art/creatures/"
		+ nombre
		+ ".png"
	)
	rutas.append(
		"res://assets/art/creatures/"
		+ nombre
		+ ".PNG"
	)

	for ruta in rutas:
		if not ResourceLoader.exists(ruta):
			continue

		var textura := load(ruta) as Texture2D
		if textura == null:
			continue

		sprite.texture = textura
		return

	sprite.texture = null


func configurar_chunk(
	nuevo_chunk: Vector2i,
	nuevos_limites: Rect2
) -> void:
	chunk_coord = nuevo_chunk
	limites_chunk = nuevos_limites

	if _movimiento != null:
		_movimiento.configurar_chunk(
			nuevos_limites
		)


func configurar_entorno(
	habitat_clave: String
) -> void:
	match habitat_clave:
		"pelagico", "bentonico", "litoral":
			entorno = "agua"

		_:
			entorno = "tierra"


func get_nombre() -> String:
	return criatura_nombre


func get_nombre_visual() -> String:
	if not nombre_individual.is_empty():
		return nombre_individual

	return criatura_nombre


func get_id() -> String:
	return criatura_id


func activar_como_proxy() -> void:
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	set_process(true)
	set_physics_process(true)
	var ai := get_node_or_null("AIController")
	if ai != null:
		ai.set_process(true)
		ai.set_physics_process(true)
	establecer_colision(true)
	add_to_group("interactable")
	add_to_group("creatures")
	if is_alive:
		add_to_group("damageable")
	_actualizar_profundidad()
	queue_redraw()


func desactivar_como_proxy() -> void:
	if _movimiento != null:
		_movimiento.detener()
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)
	var ai := get_node_or_null("AIController")
	if ai != null:
		ai.set_process(false)
		ai.set_physics_process(false)
	establecer_colision(false)
	remove_from_group("interactable")
	remove_from_group("creatures")
	remove_from_group("damageable")
	visible = false


func get_personaje_game_id() -> String:
	return str(datos.get("personaje_game_id", "")).strip_edges()


func get_datos() -> Dictionary:
	return datos


func configurar_dependencias_ia(
	jugador: Node,
	entity_manager: WorldEntityManager,
	inventario: GarliaInventory,
	combat_system: CombatSystem,
	world_items: GarliaWorldItems,
	relaciones_ecologicas: Array = [],
	world_atmosphere: WorldAtmosphere = null
) -> void:
	var ai := get_node_or_null("AIController") as CreatureAI
	if ai == null:
		return

	ai.configurar_dependencias(
		jugador,
		entity_manager,
		inventario,
		combat_system,
		world_items,
		relaciones_ecologicas,
		world_atmosphere
	)


func configurar_relaciones_ecologicas(relaciones_ecologicas: Array) -> void:
	var ai := get_node_or_null("AIController") as CreatureAI
	if ai != null:
		ai.configurar_relaciones_ecologicas(relaciones_ecologicas)


func obtener_config_ia() -> Dictionary:
	var valor: Variant = datos.get(
		"ia_config",
		{}
	)

	if valor is Dictionary:
		return (valor as Dictionary).duplicate(true)

	return {}


func crear_senuelo_ilusorio_azulado(duracion: float = 0.75) -> bool:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return false

	var raiz: Node = _effects_root if _effects_root != null and is_instance_valid(_effects_root) else get_parent()
	if raiz == null:
		return false

	var senuelo := Sprite2D.new()
	senuelo.texture = sprite.texture
	senuelo.hframes = sprite.hframes
	senuelo.vframes = sprite.vframes
	senuelo.frame = sprite.frame
	senuelo.global_position = sprite.global_position
	senuelo.global_rotation = sprite.global_rotation
	senuelo.global_scale = sprite.global_scale
	senuelo.flip_h = sprite.flip_h
	senuelo.flip_v = sprite.flip_v
	senuelo.modulate = Color(0.42, 0.72, 1.0, 0.78)
	senuelo.z_index = z_index
	raiz.add_child(senuelo)
	var tween := senuelo.create_tween()
	tween.tween_property(senuelo, "modulate:a", 0.0, maxf(duracion, 0.1))
	tween.tween_callback(senuelo.queue_free)
	return true


func ejecutar_muerte_simulada_visual(duracion: float = 1.0) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	# La criatura permanece viva y dañable; sólo se atenúa su apariencia.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.42, 0.72, 1.0, 0.12), 0.16)
	tween.tween_interval(maxf(duracion, 0.1))
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.22)


func take_damage_desde(atacante: Node, cantidad: int, origen: String = "desconocido") -> void:
	_atacante_actual_danio = atacante if is_instance_valid(atacante) else null
	take_damage(cantidad, origen)
	_atacante_actual_danio = null


func take_damage(
	cantidad: int,
	origen: String = "desconocido"
) -> void:
	if not is_alive:
		return

	var salud_anterior := health

	super.take_damage(cantidad, origen)

	if health < salud_anterior:
		# El evento de ataque también debe llegar a la IA cuando el golpe es
		# letal: un Ligniano libera su defensa al ser atacado, no al sobrevivir.
		var ai := get_node_or_null("AIController") as CreatureAI

		if ai != null:
			ai.al_recibir_danio(salud_anterior - health, _atacante_actual_danio)


func establecer_colision(activa: bool) -> void:
	var collision := get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D

	if collision == null:
		return

	collision.set_deferred(
		"disabled",
		not activa
	)


func get_skin_visual() -> Sprite2D:
	return get_node_or_null(
		"Sprite2D"
	) as Sprite2D


func ocultar_nombre_debug() -> void:
	mostrar_nombre_debug = false
	queue_redraw()


func copiar_skin_de(origen: Node) -> bool:
	if origen == null or not is_instance_valid(origen):
		return false

	var sprite_origen: Sprite2D = null

	if origen is Creature:
		sprite_origen = (
			(origen as Creature).get_skin_visual()
		)
	else:
		sprite_origen = origen.get_node_or_null(			"Visual/Sprite2D"
		) as Sprite2D

	if sprite_origen == null or sprite_origen.texture == null:
		return false

	var sprite_destino := get_node_or_null(
		"Sprite2D"
	) as Sprite2D

	if sprite_destino == null:
		return false

	sprite_destino.texture = sprite_origen.texture
	sprite_destino.position = sprite_origen.position
	sprite_destino.scale = sprite_origen.scale
	sprite_destino.rotation = sprite_origen.rotation
	sprite_destino.flip_h = sprite_origen.flip_h
	sprite_destino.flip_v = sprite_origen.flip_v

	queue_redraw()

	return true


func crear_rastro_teleport(
	origen: Vector2,
	destino: Vector2,
	duracion: float,
	puntos: int
) -> void:
	var raiz_efectos := _effects_root
	if raiz_efectos == null or not is_instance_valid(raiz_efectos):
		return

	var rastro := CreatureTeleportTrail.new()
	raiz_efectos.add_child(rastro)
	rastro.configurar(
		self,
		origen,
		destino,
		duracion,
		puntos
	)


func iniciar_animacion_ataque() -> bool:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return false

	var textura_base := sprite.texture
	if textura_base == null:
		return false

	var rutas: Array[String] = []
	var nombre := criatura_nombre.strip_edges()
	if nombre.is_empty():
		return false

	# Formato principal: una carpeta propia por criatura.
	rutas.append("res://assets/art/creatures/" + nombre + "/" + nombre + "_ataque.png")
	rutas.append("res://assets/art/creatures/" + nombre + "/" + nombre + "_ataque.PNG")
	# Compatibilidad con el formato plano que ya usa el sistema de skins.
	rutas.append("res://assets/art/creatures/" + nombre + "_ataque.png")
	rutas.append("res://assets/art/creatures/" + nombre + "_ataque.PNG")

	var textura_ataque: Texture2D = null
	for ruta in rutas:
		if ResourceLoader.exists(ruta):
			textura_ataque = load(ruta) as Texture2D
			if textura_ataque != null:
				break

	if textura_ataque == null:
		return false

	_sprite_textura_base = textura_base
	_sprite_hframes_base = maxi(sprite.hframes, 1)
	_sprite_vframes_base = maxi(sprite.vframes, 1)
	_sprite_frame_base = sprite.frame

	var ancho_frame := maxi(
		int(textura_base.get_width()) / _sprite_hframes_base,
		1
	)
	var alto_frame := maxi(
		int(textura_base.get_height()) / _sprite_vframes_base,
		1
	)

	var hframes := 1
	var vframes := 1
	if textura_ataque.get_width() >= ancho_frame and textura_ataque.get_height() >= alto_frame:
		hframes = maxi(int(textura_ataque.get_width()) / ancho_frame, 1)
		vframes = maxi(int(textura_ataque.get_height()) / alto_frame, 1)

	_ataque_frames_totales = maxi(hframes * vframes, 1)
	_ataque_frame_actual = 0
	_ataque_fps = 10.0
	_ataque_tiempo = 0.0
	_ataque_animando = true

	sprite.texture = textura_ataque
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = 0

	return true


func _actualizar_animacion_ataque(delta: float) -> void:
	if not _ataque_animando:
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		_detener_animacion_ataque()
		return

	_ataque_tiempo += delta
	var intervalo := 1.0 / maxf(_ataque_fps, 1.0)
	while _ataque_tiempo >= intervalo:
		_ataque_tiempo -= intervalo
		_ataque_frame_actual += 1
		if _ataque_frame_actual >= _ataque_frames_totales:
			_detener_animacion_ataque()
			return
		sprite.frame = _ataque_frame_actual


func _detener_animacion_ataque() -> void:
	if not _ataque_animando and _sprite_textura_base == null:
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and _sprite_textura_base != null:
		sprite.texture = _sprite_textura_base
		sprite.hframes = _sprite_hframes_base
		sprite.vframes = _sprite_vframes_base
		sprite.frame = clampi(
			_sprite_frame_base,
			0,
			maxi(sprite.hframes * sprite.vframes - 1, 0)
		)

	_ataque_animando = false
	_ataque_frame_actual = 0
	_ataque_frames_totales = 1
	_ataque_tiempo = 0.0
	_sprite_textura_base = null


func _actualizar_animacion_caminando(delta: float) -> void:
	# La animación de movimiento se resuelve por el asset disponible,
	# no por una lista fija de criaturas.
	var nombre_normalizado := criatura_nombre.strip_edges()
	if nombre_normalizado.is_empty():
		return

	if _ataque_animando:
		_detener_animacion_caminando()
		return

	# La misma animación de Flaxis sirve para caminar, perseguir y huir.
	# El ataque tiene prioridad y usa su propia animación cuando existe.
	var esta_moviendo := velocity.length_squared() > 0.25
	if not esta_moviendo:
		_detener_animacion_caminando()
		return

	if not _caminando_animando:
		if not _iniciar_animacion_caminando():
			return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		_detener_animacion_caminando()
		return

	_caminando_tiempo += delta
	var intervalo := 1.0 / maxf(_caminando_fps, 1.0)
	while _caminando_tiempo >= intervalo:
		_caminando_tiempo -= intervalo
		_caminando_frame_actual = (
			(_caminando_frame_actual + 1) % _caminando_frames_totales
		)
		sprite.frame = _caminando_frame_actual


func iniciar_animacion_caminando() -> bool:
	if criatura_nombre.strip_edges().is_empty():
		return false
	return _iniciar_animacion_caminando()


func _iniciar_animacion_caminando() -> bool:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return false

	var nombre := criatura_nombre.strip_edges()
	var rutas: Array[String] = [
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_Walking.png",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_Walking.PNG",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_walking.png",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_walking.PNG",
		# Compatibilidad temporal con assets anteriores.
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_caminando.png",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_caminando.PNG"
	]

	var textura: Texture2D = null
	for ruta in rutas:
		if ResourceLoader.exists(ruta):
			textura = load(ruta) as Texture2D
			if textura != null:
				break

	if textura == null:
		return false

	_caminando_textura_base = sprite.texture
	_caminando_hframes_base = maxi(sprite.hframes, 1)
	_caminando_vframes_base = maxi(sprite.vframes, 1)
	_caminando_frame_base = sprite.frame

	var ancho_frame := maxi(
		int(_caminando_textura_base.get_width()) / _caminando_hframes_base,
		1
	)
	var alto_frame := maxi(
		int(_caminando_textura_base.get_height()) / _caminando_vframes_base,
		1
	)

	var hframes := maxi(int(textura.get_width()) / ancho_frame, 1)
	var vframes := maxi(int(textura.get_height()) / alto_frame, 1)
	_caminando_frames_totales = maxi(hframes * vframes, 1)
	_caminando_frame_actual = 0
	_caminando_tiempo = 0.0
	_caminando_animando = true

	sprite.texture = textura
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = 0

	return true


func _detener_animacion_caminando() -> void:
	if not _caminando_animando:
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and _caminando_textura_base != null:
		sprite.texture = _caminando_textura_base
		sprite.hframes = _caminando_hframes_base
		sprite.vframes = _caminando_vframes_base
		sprite.frame = clampi(
			_caminando_frame_base,
			0,
			maxi(sprite.hframes * sprite.vframes - 1, 0)
		)

	_caminando_animando = false
	_caminando_frame_actual = 0
	_caminando_frames_totales = 1
	_caminando_tiempo = 0.0
	_caminando_textura_base = null


func _es_humano() -> bool:
	return criatura_nombre.strip_edges().to_lower() == "humano"


func _obtener_nombre_individual() -> String:
	var claves: Array[String] = [
		"nombre_individual",
		"nombre_personaje",
		"nombre_npc",
		"identidad"
	]

	for clave in claves:
		var valor: String = str(
			datos.get(
				clave,
				""
			)
		).strip_edges()

		if not valor.is_empty():
			return valor

	return ""


func get_stats_dnd() -> Dictionary:
	return stats_dnd


func _actualizar_profundidad() -> void:
	z_as_relative = false
	var profundidad_y := global_position.y
	var sprite := get_node_or_null("Sprite2D") as Sprite2D

	if sprite != null and sprite.texture != null:
		profundidad_y += sprite.position.y
		profundidad_y += (
			float(sprite.texture.get_height())
			* 0.5
			* absf(sprite.scale.y)
		)

	z_index = clampi(1000 + int(profundidad_y), 1, 4096)


func _physics_process(delta: float) -> void:
	_actualizar_animacion_ataque(delta)
	_actualizar_profundidad()
	if _siguiendo_jugador:
		_procesar_seguimiento()

	if not is_alive:
		if _movimiento != null:
			_movimiento.detener()
		else:
			velocity = Vector2.ZERO

		return

	if _movimiento != null:
		_movimiento.procesar(delta)
	else:
		velocity = Vector2.ZERO

	_actualizar_animacion_caminando(delta)


func iniciar_seguimiento_jugador(nuevo_jugador: Node) -> bool:
	if nuevo_jugador == null or not is_instance_valid(nuevo_jugador):
		return false

	_jugador_seguimiento = nuevo_jugador
	_siguiendo_jugador = true

	if _movimiento != null:
		_movimiento.tomar_control()

	return true


func detener_seguimiento_jugador() -> void:
	_siguiendo_jugador = false
	_jugador_seguimiento = null

	if _movimiento != null:
		_movimiento.liberar_control()


func esta_siguiendo_jugador() -> bool:
	return (
		_siguiendo_jugador
		and is_instance_valid(_jugador_seguimiento)
	)


func _procesar_seguimiento() -> void:
	if not esta_siguiendo_jugador():
		_siguiendo_jugador = false
		return

	var distancia := global_position.distance_to(
		_jugador_seguimiento.global_position
	)

	if distancia <= _distancia_seguimiento:
		_movimiento.establecer_direccion(Vector2.ZERO)
		return

	var direccion := global_position.direction_to(
		_jugador_seguimiento.global_position
	)
	_movimiento.establecer_direccion(direccion)
	_movimiento.tomar_control()


func tomar_control_movimiento() -> void:
	if _movimiento == null:
		return

	_movimiento.tomar_control()


func liberar_control_movimiento() -> void:
	if _movimiento == null:
		return

	_movimiento.liberar_control()


func establecer_direccion_movimiento(
	direccion: Vector2
) -> void:
	if _movimiento == null:
		return

	_movimiento.establecer_direccion(
		direccion
	)


func detener_movimiento() -> void:
	if _movimiento == null:
		return

	_movimiento.detener()


func can_interact(
	_actor: Node
) -> bool:
	return is_alive


func es_dialogable() -> bool:
	return not get_dialogue_data().is_empty()


func get_dialogue_data() -> Dictionary:
	var personaje_id := get_personaje_game_id()

	# El diálogo de un personaje siempre se resuelve por su ID canónico.
	# El snapshot de la criatura solo sirve como respaldo para evitar
	# que una instancia quede muda si todavía no tiene el registro anidado.
	if not personaje_id.is_empty():
		var dialogo_canonico: Dictionary = {}
		if _world_data_dependency != null and is_instance_valid(_world_data_dependency):
			dialogo_canonico = _world_data_dependency.obtener_dialogo_game(
			personaje_id
		)
		if not dialogo_canonico.is_empty():
			return dialogo_canonico

	var dialogo_variant: Variant = datos.get("dialogo", {})

	if dialogo_variant is Dictionary:
		return (dialogo_variant as Dictionary).duplicate(true)

	if dialogo_variant is Array:
		return {"lineas": (dialogo_variant as Array).duplicate(true)}

	# Compatibilidad para criaturas que todavía no usan personajes_game.
	var ia_variant: Variant = datos.get("ia_config", {})
	if ia_variant is Dictionary:
		var ia_config := ia_variant as Dictionary
		var ia_dialogo_variant: Variant = ia_config.get("dialogo", {})

		if ia_dialogo_variant is Dictionary:
			return (ia_dialogo_variant as Dictionary).duplicate(true)

		if ia_dialogo_variant is Array:
			return {"lineas": (ia_dialogo_variant as Array).duplicate(true)}

	return {}


func get_interaction_priority() -> int:
	if es_dialogable():
		return 60

	return 0


func get_interaction_distance() -> float:
	if es_dialogable():
		return 64.0

	return 48.0


func get_interaction_text() -> String:
	if es_dialogable():
		return "Hablar"

	return "Examinar"


func interact(
	_actor: Node
) -> void:
	if not es_dialogable():
		return

	var dialogue_system := _dialogue_system_dependency
	if dialogue_system == null or not is_instance_valid(dialogue_system):
		return
	if dialogue_system != null:
		dialogue_system.abrir_desde(self)


func _die() -> void:
	_detener_animacion_ataque()
	_detener_animacion_caminando()

	if _muerte_procesada:
		return

	_muerte_procesada = true
	is_alive = false

	if not criatura_id.is_empty():
		var mission_manager := _mission_manager_dependency
		if mission_manager != null and is_instance_valid(mission_manager):
			mission_manager.registrar_muerte(criatura_id, 1)
		if _world_items_dependency != null and is_instance_valid(_world_items_dependency):
			_world_items_dependency.generar_drops_criatura(
					criatura_id,
					global_position
				)

	died.emit()

	if _movimiento != null:
		_movimiento.detener()

	velocity = Vector2.ZERO

	set_physics_process(false)
	set_process(false)

	var ai_controller := get_node_or_null("AIController")
	if ai_controller != null:
		ai_controller.set_physics_process(false)
		ai_controller.set_process(false)

	remove_from_group("damageable")
	remove_from_group("interactable")

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.18
	)

	tween.tween_property(
		self,
		"scale",
		Vector2(0.7, 0.7),
		0.18
	)

	tween.chain().tween_callback(
		_ocultar_muerto
	)


func _ocultar_muerto() -> void:
	visible = false


func _draw() -> void:
	var brillo_horario := bool(
		get_meta("brillo_horario", false)
	)

	if brillo_horario:
		_dibujar_brillo_horario()

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	# Con arte disponible, el mundo muestra únicamente el sprite.
	# El nombre queda reservado para el respaldo visual cuando falta el arte.
	if sprite != null and sprite.texture != null:
		return

	if str(datos.get("categoria_entidad", "")).strip_edges().to_lower() == "garumi":
		_dibujar_garumi_sin_sprite()
		if mostrar_nombre_debug:
			_dibujar_nombre()
		return

	var color: Color = (
		_obtener_color()
	)

	draw_circle(
		Vector2.ZERO,
		8.0,
		Color(
			0.08,
			0.08,
			0.10
		)
	)

	draw_circle(
		Vector2.ZERO,
		6.5,
		color
	)

	draw_circle(
		Vector2.ZERO,
		4.5,
		color.lightened(0.12)
	)

	draw_circle(
		Vector2(
			-2.2,
			-1.5
		),
		1.0,
		Color.WHITE
	)

	draw_circle(
		Vector2(
			2.2,
			-1.5
		),
		1.0,
		Color.WHITE
	)

	draw_circle(
		Vector2(
			-2.2,
			-1.5
		),
		0.45,
		Color(
			0.05,
			0.05,
			0.05
		)
	)

	draw_circle(
		Vector2(			2.2,
			-1.5
		),
		0.45,
		Color(
			0.05,
			0.05,
			0.05
		)
	)

	# Las criaturas sin sprite usan la figura de respaldo y conservan el nombre.
	if mostrar_nombre_debug:
		_dibujar_nombre()



## Proyección geométrica temporal de desarrollo. El arte final debe ser un
## sprite propio en assets/art/garumis; esta figura no define el canon visual.
func _dibujar_garumi_sin_sprite() -> void:
	var color := _obtener_color()
	var silueta := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(7.0, -3.0),
		Vector2(5.0, 5.0),
		Vector2(0.0, 9.0),
		Vector2(-6.0, 4.0),
		Vector2(-8.0, -3.0)
	])
	draw_colored_polygon(silueta, Color(0.06, 0.07, 0.10, 0.95))
	var nucleo := PackedVector2Array([
		Vector2(0.0, -6.0),
		Vector2(4.0, -2.0),
		Vector2(2.0, 4.0),
		Vector2(-1.0, 6.0),
		Vector2(-4.0, 1.0),
		Vector2(-4.0, -2.0)
	])
	draw_colored_polygon(nucleo, color)
	draw_circle(Vector2(0.0, -1.0), 1.5, color.lightened(0.35))


func _dibujar_brillo_horario() -> void:
	var pulso := 0.82 + 0.18 * sin(
		float(Time.get_ticks_msec()) / 260.0
	)

	draw_circle(
		Vector2(0, -10),
		22.0 * pulso,
		Color(1.0, 0.88, 0.45, 0.10)
	)
	draw_circle(
		Vector2(0, -10),
		14.0 * pulso,
		Color(1.0, 0.94, 0.62, 0.18)
	)

func _dibujar_nombre() -> void:
	var nombre_visual := get_nombre_visual()

	if nombre_visual.is_empty():
		return

	var font: Font = (
		ThemeDB.fallback_font
	)

	var ancho: float = float(
		font.get_string_size(
			nombre_visual,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			nombre_font_size
		).x
	)

	var posicion := Vector2(
		-ancho * 0.5,
		-12.0
	)

	font.draw_string_outline(
		get_canvas_item(),
		posicion,
		nombre_visual,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		nombre_font_size,
		nombre_outline_size,
		Color(
			0.03,
			0.03,
			0.04
		)
	)

	font.draw_string(
		get_canvas_item(),
		posicion,
		nombre_visual,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		nombre_font_size,
		Color.WHITE
	)


func _obtener_color() -> Color:
	if criatura_id.is_empty():
		return Color(
			0.72,
			0.55,
			0.35
		)

	var valor: int = abs(
		hash(criatura_id)
	)

	var tono: float = (
		float(valor % 360)
		/ 360.0
	)

	return Color.from_hsv(
		tono,
		0.55,
		0.90
	)