extends Entity
class_name Creature

const PIXELGRAFIA_FONT = preload("res://assets/fonts/Pixelgrafia.ttf")
const SHOP_UI_PATH := "res://scripts/ui/shop_ui.gd"
const COMBAT_DEFENSE_SCRIPT: Script = preload("res://scripts/gameplay/combat/combat_defense.gd")
const SHARED_ASSET_LIBRARY: Script = preload("res://scripts/shared/assets/shared_asset_library.gd")
const CHARACTER_APPEARANCE_SCRIPT: Script = preload("res://scripts/characters/character_appearance.gd")
const SHARED_SPRITE_ANIMATOR_SCRIPT: Script = preload("res://scripts/shared/animation/shared_sprite_animation_controller.gd")

signal configuracion_actualizada
signal danio_recibido(cantidad: int, atacante: Node)


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
# Node evita una dependencia circular: DialogueSystem usa Creature como fuente
# de diálogo, mientras Creature sólo necesita invocar su API pública.
var _dialogue_system_dependency: Node = null
var _mission_manager_dependency: MissionManagerService = null
var _effects_root: Node = null
var _world_items_dependency: GarliaWorldItems = null
var _world_data_dependency: WorldDataService = null

var _rng := RandomNumberGenerator.new()
var _siguiendo_jugador: bool = false
var _jugador_seguimiento: Node = null
var _distancia_seguimiento: float = 24.0
var _muerte_procesada: bool = false
var _control_remoto_cliente: bool = false
var _red_posicion_objetivo: Vector2 = Vector2.ZERO
var _red_velocidad_objetivo: Vector2 = Vector2.ZERO
var _red_ataque_activo_previo := false
var _sprite_animator: SharedSpriteAnimationController = SHARED_SPRITE_ANIMATOR_SCRIPT.new()
var _zlish_idle_animando: bool = false

var _sprite_textura_base: Texture2D = null
var _sprite_hframes_base: int = 1
var _sprite_vframes_base: int = 1
var _sprite_frame_base: int = 0
var _ataque_animando: bool = false
var _ataque_frames_totales: int = 1
var _ataque_fps: float = 10.0

var _caminando_animando: bool = false
var _caminando_textura_base: Texture2D = null
var _caminando_hframes_base: int = 1
var _caminando_vframes_base: int = 1
var _caminando_frame_base: int = 0
var _caminando_frames_totales: int = 1
var _caminando_fps: float = 8.0
var _zlish_idle_fps: float = 5.0

var _sprite_npc_base: Texture2D = null
var _sprite_npc_lateral: Texture2D = null
var _sprite_npc_espalda: Texture2D = null
var _npc_direccion_anterior := Vector2.DOWN


func configurar_dependencias(
	dialogue_system: Node,
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
	_sprite_animator.configurar(get_node_or_null("Sprite2D") as Sprite2D)

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
	# Una instancia reciclada debe liberar la animación anterior antes de
	# recibir otra criatura, para no heredar textura, cuadro ni temporizador.
	_detener_animacion_ataque()
	_detener_animacion_caminando()
	_sprite_animator.detener(0)
	_zlish_idle_animando = false
	_muerte_procesada = false
	_ataque_animando = false
	_caminando_animando = false
	_zlish_idle_animando = false
	_sprite_textura_base = null
	_caminando_textura_base = null
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

	# Reconfigurar el dominio vital completo, no solo los campos espejo de Entity.
	_configurar_estado_vital()

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

	queue_redraw()
	configuracion_actualizada.emit()


func _cargar_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	_sprite_animator.configurar(sprite)
	# Cada configuración parte de la escala neutra para no heredar ajustes
	# de un habitante anterior cuando una instancia se reutiliza.
	sprite.scale = Vector2.ONE
	sprite.flip_h = false
	_sprite_npc_base = null
	_sprite_npc_lateral = null
	_sprite_npc_espalda = null
	_npc_direccion_anterior = Vector2.DOWN

	var rutas: Array[String] = []

	# Los Garumis tienen un catálogo visual independiente. No reutilizamos por
	# accidente el sprite de una criatura normal con el mismo nombre.
	if str(datos.get("categoria_entidad", "")).strip_edges().to_lower() == "garumi":
		var asset_key := str(datos.get("asset_key", criatura_nombre)).strip_edges()
		if asset_key.is_empty() or asset_key.contains("/") or asset_key.contains("\\"):
			asset_key = criatura_nombre
		# Primero se intenta la clave visual del catálogo. Si está vacía o
		# desactualizada, se usa el nombre visible; así Velki.png y Velkor.png
		# se cargan aunque el registro no tenga asset_key específico.
		var claves_asset: Array[String] = [asset_key]
		if criatura_nombre.strip_edges() != asset_key:
			claves_asset.append(criatura_nombre.strip_edges())
		var textura_garumi: Texture2D = null
		for clave_asset in claves_asset:
			if clave_asset.is_empty() or clave_asset.contains("/") or clave_asset.contains("\\"):
				continue
			var rutas_garumi: Array[String] = [
				"res://assets/art/creatures/criaturas/" + clave_asset + ".png",
				"res://assets/art/creatures/criaturas/" + clave_asset + ".PNG",
				"res://assets/art/creatures/criaturas/" + clave_asset + ".svg",
				"res://assets/art/creatures/criaturas/" + clave_asset + ".SVG"
			]
			for ruta_garumi in rutas_garumi:
				textura_garumi = SHARED_ASSET_LIBRARY.textura(ruta_garumi)
				if textura_garumi != null:
					break
			if textura_garumi != null:
				break
		var sprite_garumi := get_node_or_null("Sprite2D") as Sprite2D
		if sprite_garumi != null:
			sprite_garumi.texture = textura_garumi
		set_meta("garumi_sprite_missing", textura_garumi == null)
		queue_redraw()
		return

	# Los NPC de reinos locales pueden declarar una ruta propia para reutilizar
	# sprites del paquete artístico del reino sin copiarlos a la carpeta global.
	var sprite_path := str(datos.get("sprite_path", "")).strip_edges()
	if sprite_path.begins_with("res://assets/art/kingdom/") and sprite_path.contains("/Personajes/"):
		var textura_local: Texture2D = SHARED_ASSET_LIBRARY.textura(sprite_path)
		if textura_local != null:
			sprite.texture = textura_local
			_normalizar_escala_sprite_personaje(sprite)
			sprite.visible = true
			set_meta("sprite_key_cargado", sprite_path)
			return

	# Los habitantes locales pueden tener una clave visual explícita aunque
	# sus datos provengan de una plantilla de criatura. Priorizarla evita que
	# _es_humano() o el nombre del registro impidan cargar su arte propio.
	var sprite_key_local := str(datos.get("sprite_key", "")).strip_edges()
	if not sprite_key_local.is_empty() and not sprite_key_local.contains("/") and not sprite_key_local.contains("\\"):
		for extension in [".png", ".PNG"]:
			var ruta_personaje: String = "res://assets/art/kingdom/Torres/Personajes/" + sprite_key_local + str(extension)
			var textura_personaje: Texture2D = SHARED_ASSET_LIBRARY.textura(ruta_personaje)
			if textura_personaje != null:
				sprite.texture = textura_personaje
				_configurar_sprites_direccionales_npc(sprite_key_local, sprite)
				_normalizar_escala_sprite_personaje(sprite)
				sprite.visible = true
				remove_meta("sprite_placeholder_humano")
				remove_meta("sprite_key_no_encontrado")
				set_meta("sprite_key_cargado", sprite_key_local)
				return
		set_meta("sprite_key_no_encontrado", sprite_key_local)
		push_warning("Creature: no se pudo cargar el sprite local '%s'." % sprite_key_local)

	if _es_humano():
		var sprite_personaje := str(datos.get("sprite_key", nombre_individual)).strip_edges()
		if not sprite_personaje.is_empty():
			rutas.append(
				"res://assets/art/kingdom/Torres/Personajes/"
				+ sprite_personaje
				+ ".png"
			)
			rutas.append(
				"res://assets/art/kingdom/Torres/Personajes/"
				+ sprite_personaje
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
			+ "/"
			+ nombre
			+ "_Idle.png"
		)
		rutas.append(
			"res://assets/art/creatures/"
			+ nombre
			+ "/"
			+ nombre
			+ "_Idle.PNG"
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
		var textura: Texture2D = SHARED_ASSET_LIBRARY.textura(ruta)
		if textura == null:
			continue

		sprite.texture = textura
		if _es_humano() and ruta.begins_with("res://assets/art/kingdom/Torres/Personajes/"):
			_configurar_sprites_direccionales_npc(str(datos.get("sprite_key", nombre_individual)).strip_edges(), sprite)
			_normalizar_escala_sprite_personaje(sprite)
		return

	# Mientras cada NPC recibe su sprite propio, reutilizamos el cuerpo humano
	# base ya incluido en el proyecto. No generamos ni sustituimos arte del usuario.
	if _es_humano() and not get_personaje_game_id().is_empty():
		var textura_base: Texture2D = CHARACTER_APPEARANCE_SCRIPT.obtener_textura_sprite("idle_front")
		if textura_base != null:
			sprite.texture = textura_base
			_configurar_sprites_direccionales_npc(str(datos.get("sprite_key", nombre_individual)).strip_edges(), sprite)
			_normalizar_escala_sprite_personaje(sprite)
			set_meta("sprite_placeholder_humano", true)
			return

	sprite.texture = null


func _configurar_sprites_direccionales_npc(sprite_key: String, sprite: Sprite2D) -> void:
	_sprite_npc_base = sprite.texture
	_sprite_npc_lateral = null
	_sprite_npc_espalda = null
	_npc_direccion_anterior = Vector2.DOWN
	if sprite_key.is_empty() or sprite_key.contains("/") or sprite_key.contains("\\"):
		return

	var clave_lateral := sprite_key
	var clave_espalda := sprite_key
	match sprite_key.to_lower():
		"mara":
			clave_lateral = "Maral"
		"bruna":
			clave_espalda = "Brunal"
		"elian":
			clave_espalda = "Ellan"

	_sprite_npc_lateral = _cargar_sprite_direccional_personaje(clave_lateral + "_Walking_Left.png")
	_sprite_npc_espalda = _cargar_sprite_direccional_personaje(clave_espalda + "_Walking_Back.png")


func _cargar_sprite_direccional_personaje(nombre_archivo: String) -> Texture2D:
	var ruta := "res://assets/art/kingdom/Torres/Personajes/" + nombre_archivo
	return SHARED_ASSET_LIBRARY.textura(ruta)


func _actualizar_sprite_direccional_npc() -> void:
	if _sprite_npc_base == null or _ataque_animando or _caminando_animando:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	if velocity.length_squared() > 0.25:
		if absf(velocity.x) > absf(velocity.y):
			_npc_direccion_anterior = Vector2.RIGHT if velocity.x > 0.0 else Vector2.LEFT
		else:
			_npc_direccion_anterior = Vector2.DOWN if velocity.y > 0.0 else Vector2.UP

	var textura := _sprite_npc_base
	sprite.flip_h = false
	var postura := str(get_meta("postura_npc", ""))
	if postura == "dormir":
		if _sprite_npc_espalda != null:
			textura = _sprite_npc_espalda
	elif velocity.length_squared() > 0.25:
		if _npc_direccion_anterior == Vector2.UP and _sprite_npc_espalda != null:
			textura = _sprite_npc_espalda
		elif absf(_npc_direccion_anterior.x) > 0.0 and _sprite_npc_lateral != null:
			textura = _sprite_npc_lateral
			sprite.flip_h = _npc_direccion_anterior.x > 0.0

	if sprite.texture != textura:
		sprite.texture = textura
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
		_normalizar_escala_sprite_personaje(sprite)


func _normalizar_escala_sprite_personaje(sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null:
		return

	# Los sprites de habitantes usan una altura visual común de 48 px.
	# Así se admiten dibujos con más resolución sin reducir sus píxeles ni
	# alterar su proporción; los sprites clásicos de 32x48 conservan escala 1.
	var altura_textura := maxf(float(sprite.texture.get_height()), 1.0)
	var escala_uniforme := 48.0 / altura_textura
	sprite.scale = Vector2.ONE * escala_uniforme


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
	var personaje_id := str(datos.get("personaje_game_id", "")).strip_edges()
	if personaje_id.is_empty():
		personaje_id = str(get_meta("personaje_game_id", "")).strip_edges()
	return personaje_id


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


func tiene_movimiento_autonomo_permitido() -> bool:
	# CreatureMovement consulta esta condición en cada physics frame.
	# Leer sólo las tres claves necesarias evita duplicar recursivamente
	# toda la configuración de IA por cada criatura y cada frame.
	var configuracion_variant: Variant = datos.get("ia_config", {})
	if not configuracion_variant is Dictionary:
		return true
	var configuracion := configuracion_variant as Dictionary
	var movimiento_variant: Variant = configuracion.get("movimiento", {})
	var movimiento: Dictionary = movimiento_variant if movimiento_variant is Dictionary else {}
	var tipo := str(movimiento.get("tipo", "")).strip_edges().to_lower()
	return (
		tipo != "inmovil"
		and movimiento.get("desplazamiento_propio", true) != false
		and configuracion.get("movimiento_permitido", true) != false
	)


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


func configurar_replica_red_cliente() -> void:
	if _control_remoto_cliente:
		return
	_control_remoto_cliente = true
	if _movimiento != null:
		_movimiento.detener()
		_movimiento.set_physics_process(false)
		_movimiento.set_process(false)
	var ai := get_node_or_null("AIController")
	if ai != null:
		ai.set_physics_process(false)
		ai.set_process(false)


func reactivar_simulacion_local_red() -> void:
	_control_remoto_cliente = false
	set_process(true)
	set_physics_process(true)
	if _movimiento != null:
		_movimiento.set_process(true)
		_movimiento.set_physics_process(true)
	var ai := get_node_or_null("AIController")
	if ai != null:
		ai.set_process(true)
		ai.set_physics_process(true)
	visible = is_alive
	if is_alive:
		establecer_colision(true)
		add_to_group("creatures")
		add_to_group("interactable")
		add_to_group("damageable")
	else:
		establecer_colision(false)
		remove_from_group("interactable")
		remove_from_group("damageable")


func ocultar_replica_red_cliente() -> void:
	configurar_replica_red_cliente()
	var necesitaba_ocultar := visible or is_in_group("damageable") or is_in_group("interactable")
	visible = false
	remove_from_group("damageable")
	remove_from_group("interactable")
	if necesitaba_ocultar:
		establecer_colision(false)


func esta_animando_ataque() -> bool:
	return _ataque_animando


func aplicar_estado_red(
	posicion: Vector2,
	velocidad: Vector2,
	vida: int,
	vida_maxima: int,
	viva: bool,
	ataque_activo: bool = false
) -> void:
	configurar_replica_red_cliente()
	_red_posicion_objetivo = posicion
	_red_velocidad_objetivo = velocidad
	var visibilidad_previa := visible
	var vida_previa := is_alive
	vital_state.max_health = maxi(vida_maxima, 1)
	vital_state.health = clampi(vida, 0, vital_state.max_health)
	vital_state.is_alive = viva and vital_state.health > 0
	_sync_desde_vital()
	visible = is_alive
	if is_alive:
		if not visibilidad_previa or not vida_previa:
			establecer_colision(true)
			add_to_group("interactable")
			add_to_group("creatures")
			add_to_group("damageable")
		if ataque_activo and not _red_ataque_activo_previo:
			iniciar_animacion_ataque()
		_red_ataque_activo_previo = ataque_activo
	else:
		if visibilidad_previa or vida_previa:
			remove_from_group("damageable")
			remove_from_group("interactable")
			establecer_colision(false)
			velocity = Vector2.ZERO
			_detener_animacion_ataque()
			_detener_animacion_caminando()
		_red_ataque_activo_previo = false


func take_damage_desde(
	atacante: Node,
	cantidad: int,
	origen: String = "desconocido"
) -> int:
	return _aplicar_danio_recibido(cantidad, origen, atacante)


func take_damage(
	cantidad: int,
	origen: String = "desconocido"
) -> int:
	return _aplicar_danio_recibido(cantidad, origen, null)


func _aplicar_danio_recibido(
	cantidad: int,
	origen: String,
	atacante: Node
) -> int:
	if not is_alive:
		return 0

	# La defensa propia de la criatura se aplica en el mismo punto para todos
	# los atacantes. La armadura equipada del jugador sigue resolviéndose en
	# Player; aquí solo se consume stats_dnd.defensa cuando es numérica.
	var defensa_variant: Variant = stats_dnd.get("defensa", 0)
	var defensa_propia := float(defensa_variant) if defensa_variant is int or defensa_variant is float else 0.0
	cantidad = COMBAT_DEFENSE_SCRIPT.aplicar(cantidad, defensa_propia)
	if cantidad <= 0:
		return 0

	# Los sparrings del Cuartel nunca pueden morir: conservan 1 HP y
	# recuperan su estado original al cerrar la sesión.
	if bool(get_meta("barracks_training_target", false)):
		cantidad = mini(cantidad, maxi(health - 1, 0))
		if cantidad <= 0:
			return 0

	var atacante_evento := atacante if is_instance_valid(atacante) else null
	var danio_real := super.take_damage(cantidad, origen)
	if danio_real > 0:
		# Se informa el daño de esta invocación, sin incluir golpes anidados
		# que puedan ejecutarse desde health_changed.
		danio_recibido.emit(danio_real, atacante_evento)

	return danio_real


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
	_detener_animacion_caminando()
	_zlish_idle_animando = false
	var textura_base := sprite.texture
	if textura_base == null:
		return false

	var nombre := criatura_nombre.strip_edges()
	if nombre.is_empty():
		return false
	var rutas: Array[String] = [
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_ataque.png",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_ataque.PNG",
		"res://assets/art/creatures/" + nombre + "_ataque.png",
		"res://assets/art/creatures/" + nombre + "_ataque.PNG"
	]
	var textura_ataque: Texture2D = null
	for ruta in rutas:
		textura_ataque = SHARED_ASSET_LIBRARY.textura(ruta)
		if textura_ataque != null:
			break
	if textura_ataque == null:
		return false

	_sprite_textura_base = textura_base
	_sprite_hframes_base = maxi(sprite.hframes, 1)
	_sprite_vframes_base = maxi(sprite.vframes, 1)
	_sprite_frame_base = sprite.frame
	var ancho_frame := maxi(int(floor(float(textura_base.get_width()) / float(_sprite_hframes_base))), 1)
	var alto_frame := maxi(int(floor(float(textura_base.get_height()) / float(_sprite_vframes_base))), 1)
	var hframes := 1
	var vframes := 1
	if textura_ataque.get_width() >= ancho_frame and textura_ataque.get_height() >= alto_frame:
		hframes = maxi(int(floor(float(textura_ataque.get_width()) / float(ancho_frame))), 1)
		vframes = maxi(int(floor(float(textura_ataque.get_height()) / float(alto_frame))), 1)

	_ataque_frames_totales = maxi(hframes * vframes, 1)
	_ataque_fps = 10.0
	_ataque_animando = true
	sprite.texture = textura_ataque
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = 0
	_sprite_animator.configurar(sprite)
	_sprite_animator.reproducir(_ataque_fps, 0, _ataque_frames_totales, false)
	return true


func _actualizar_animacion_ataque(delta: float) -> void:
	if not _ataque_animando:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		_detener_animacion_ataque()
		return
	_sprite_animator.actualizar(delta)
	if not _sprite_animator.reproduciendo:
		_detener_animacion_ataque()


func _detener_animacion_ataque() -> void:
	if not _ataque_animando and _sprite_textura_base == null:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and _sprite_textura_base != null:
		sprite.texture = _sprite_textura_base
		sprite.hframes = _sprite_hframes_base
		sprite.vframes = _sprite_vframes_base
		sprite.frame = clampi(_sprite_frame_base, 0, maxi(sprite.hframes * sprite.vframes - 1, 0))
		_sprite_animator.detener(sprite.frame)
	_ataque_animando = false
	_ataque_frames_totales = 1
	_sprite_textura_base = null


func _actualizar_animacion_caminando(delta: float) -> void:
	if criatura_nombre.strip_edges().is_empty():
		return
	if _ataque_animando or velocity.length_squared() <= 0.25:
		_detener_animacion_caminando()
		return
	if not _caminando_animando and not _iniciar_animacion_caminando():
		return

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		_detener_animacion_caminando()
		return
	if criatura_nombre.strip_edges().to_lower() == "zlish":
		sprite.flip_h = velocity.x > 0.0
	_sprite_animator.actualizar(delta)


func iniciar_animacion_caminando() -> bool:
	if criatura_nombre.strip_edges().is_empty():
		return false
	return _iniciar_animacion_caminando()


func _iniciar_animacion_caminando() -> bool:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return false
	var nombre := criatura_nombre.strip_edges()
	var rutas: Array[String] = []
	if nombre.to_lower() == "zlish":
		rutas.append("res://assets/art/creatures/Zlish/Zlish Izquierda.png")
	rutas.append_array([
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_Walking.png",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_Walking.PNG",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_walking.png",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_walking.PNG",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_caminando.png",
		"res://assets/art/creatures/" + nombre + "/" + nombre + "_caminando.PNG"
	])
	var textura: Texture2D = null
	for ruta in rutas:
		textura = SHARED_ASSET_LIBRARY.textura(ruta)
		if textura != null:
			break
	if textura == null:
		return false

	_caminando_textura_base = sprite.texture
	_caminando_hframes_base = maxi(sprite.hframes, 1)
	_caminando_vframes_base = maxi(sprite.vframes, 1)
	_caminando_frame_base = sprite.frame
	var ancho_frame := maxi(int(floor(float(_caminando_textura_base.get_width()) / float(_caminando_hframes_base))), 1)
	var alto_frame := maxi(int(floor(float(_caminando_textura_base.get_height()) / float(_caminando_vframes_base))), 1)
	var hframes := maxi(int(floor(float(textura.get_width()) / float(ancho_frame))), 1)
	var vframes := maxi(int(floor(float(textura.get_height()) / float(alto_frame))), 1)
	_caminando_frames_totales = maxi(hframes * vframes, 1)
	_caminando_animando = true
	_zlish_idle_animando = false
	sprite.texture = textura
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = 0
	if nombre.to_lower() == "zlish":
		sprite.flip_h = velocity.x > 0.0
	_sprite_animator.configurar(sprite)
	_sprite_animator.reproducir(_caminando_fps, 0, _caminando_frames_totales, true)
	return true


func _detener_animacion_caminando() -> void:
	if not _caminando_animando:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and _caminando_textura_base != null:
		sprite.texture = _caminando_textura_base
		sprite.hframes = _caminando_hframes_base
		sprite.vframes = _caminando_vframes_base
		sprite.frame = clampi(_caminando_frame_base, 0, maxi(sprite.hframes * sprite.vframes - 1, 0))
		_sprite_animator.detener(sprite.frame)
	_caminando_animando = false
	_caminando_frames_totales = 1
	_caminando_textura_base = null
	_zlish_idle_animando = false
	if criatura_nombre.strip_edges().to_lower() == "zlish" and sprite != null:
		sprite.flip_h = false


func _actualizar_animacion_idle_zlish(delta: float) -> void:
	if criatura_nombre.strip_edges().to_lower() != "zlish" or _ataque_animando or _caminando_animando:
		return
	if velocity.length_squared() > 0.25:
		if _zlish_idle_animando:
			_sprite_animator.detener(0)
			_zlish_idle_animando = false
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	if sprite.hframes != 11 or sprite.vframes != 1:
		sprite.hframes = 11
		sprite.vframes = 1
	if not _zlish_idle_animando:
		_sprite_animator.configurar(sprite)
		_sprite_animator.reproducir(_zlish_idle_fps, 0, 11, true)
		_zlish_idle_animando = true
	_sprite_animator.actualizar(delta)


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
	if _control_remoto_cliente:
		if not is_alive:
			velocity = Vector2.ZERO
			return
		var factor := 1.0 - exp(-14.0 * delta)
		global_position = global_position.lerp(_red_posicion_objetivo, factor)
		velocity = _red_velocidad_objetivo
		_actualizar_animacion_caminando(delta)
		_actualizar_animacion_idle_zlish(delta)
		_actualizar_sprite_direccional_npc()
		return
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
	_actualizar_animacion_idle_zlish(delta)
	_actualizar_sprite_direccional_npc()


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


func pausar_movimiento_temporal() -> void:
	if _movimiento != null:
		_movimiento.pausar_temporalmente()


func reanudar_movimiento_temporal() -> void:
	if _movimiento != null:
		_movimiento.reanudar_temporalmente()


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
	# Una criatura oculta (por ejemplo, un aldeano que quedó fuera de la
	# habitación activa) no debe conservar un objetivo de interacción.
	return is_alive and is_visible_in_tree()


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
		# Dentro de los edificios se usa el mismo alcance corto que en el
		# exterior. El aviso aparece al acercarse al personaje, no desde el
		# otro extremo de la habitación.
		if bool(get_meta("rutina_en_edificio", false)):
			return 64.0
		return 64.0

	return 48.0


func _obtener_tienda_npc() -> Dictionary:
	var shop_script := SHARED_ASSET_LIBRARY.obtener_recurso(SHOP_UI_PATH) as Script
	if shop_script == null:
		return {}
	var tienda_variant: Variant = shop_script.call("tienda_para_npc", self)
	return tienda_variant as Dictionary if tienda_variant is Dictionary else {}


func get_interaction_text() -> String:
	if not _obtener_tienda_npc().is_empty():
		return "Comprar"
	if es_dialogable():
		return "Hablar"
	return "Examinar"


func interact(
	_actor: Node
) -> void:
	if not es_dialogable():
		return

	var tienda := _obtener_tienda_npc()
	if not tienda.is_empty() and is_instance_valid(_world_items_dependency):
		var shop_script := SHARED_ASSET_LIBRARY.obtener_recurso(SHOP_UI_PATH) as Script
		var inventario := get_tree().get_first_node_in_group("inventory") as GarliaInventory
		var interfaz: CanvasLayer = null
		if shop_script != null:
			interfaz = shop_script.new() as CanvasLayer
		if is_instance_valid(inventario) and is_instance_valid(interfaz):
			interfaz.configurar(self, inventario, _world_items_dependency, _actor)
			var padre := get_tree().current_scene
			if not is_instance_valid(padre):
				padre = get_tree().root
			padre.add_child(interfaz)
			return

	# Si este NPC está conversando con otro habitante, la interacción
	# permite presenciar ese intercambio en vez de abrir un diálogo individual.
	var sistema_conversacion := get_tree().get_first_node_in_group("npc_conversation_system")
	if is_instance_valid(sistema_conversacion) and sistema_conversacion.has_method("intentar_observar_conversacion"):
		var jugador := _actor as Node2D
		if sistema_conversacion.call("intentar_observar_conversacion", self, jugador, _mission_manager_dependency):
			return

	abrir_dialogo()


func abrir_dialogo() -> void:
	if not is_instance_valid(_dialogue_system_dependency):
		return
	if not _dialogue_system_dependency.has_method("abrir_desde"):
		return
	_dialogue_system_dependency.call("abrir_desde", self)


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

	# Entity conserva la autoridad de emisión idempotente de died.
	super._die()

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

	var font: Font = PIXELGRAFIA_FONT

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