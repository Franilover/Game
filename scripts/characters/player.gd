extends Entity
class_name Player


signal stamina_changed(current: float, maximum: float)
signal fisiologia_changed(vida_eterium_compartidos: bool)


@export_category("Movimiento")
@export var move_speed: float = 90.0
@export var run_multiplier: float = 1.5


@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regeneration: float = 22.0
@export var stamina_regeneration_delay: float = 0.8


@export_category("Eterium")
## Las reglas de Eterium vienen de Supabase.
## Estos valores no son balance local: solo reflejan el estado cargado.


@export_category("Salto")
@export var jump_distance: float = 28.0
@export var jump_duration: float = 0.28
@export var jump_cooldown: float = 0.55
@export var jump_stamina_cost: float = 15.0


@export_category("Dash")
@export var dash_distance: float = 64.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 0.8
@export var dash_stamina_cost: float = 25.0


@export_category("Correr")
@export var run_stamina_cost: float = 10.0


enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	DASH
}


var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN


var stamina: float = 0.0
var stamina_controller := PlayerStaminaController.new()
var eterium_runtime := PlayerEteriumRuntime.new()
var eterium := PlayerEteriumCoordinator.new()
var input_gate := GameplayInputGate.new()
var exploration_controller := PlayerExplorationController.new()
var locomotion := PlayerLocomotionCoordinator.new()
var movement_controller := PlayerMovementController.new()
var action_controller := PlayerActionController.new()

var _world_context_ref: WorldContext = null
var _game_state_ref: GameStateService = null
var _inventory_ref: GarliaInventory = null
var _exploration_check_timer: float = 0.0




var _action_direction: Vector2 = Vector2.DOWN
var _base_visual_position: Vector2 = Vector2.ZERO
var personaje_nombre: String = ""
var personaje_genero: String = ""
var personaje_especie: Dictionary = {}
var personaje_skin: String = ""


@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var visual: Node2D = $Visual

@onready var facing_marker: ColorRect = $Visual/FacingMarker


func configurar_dependencias(
	inventory: GarliaInventory = null,
	world_context: WorldContext = null,
	ium_manager: IUMManager = null,
	entity_manager: WorldEntityManager = null,
	supabase_client: GarliaSupabaseClient = null,
	game_state: GameStateService = null
) -> void:
	_inventory_ref = inventory
	_world_context_ref = world_context
	_ium_manager_ref = ium_manager
	_entity_manager_ref = entity_manager
	_supabase_client_ref = supabase_client
	_game_state_ref = game_state
	_configurar_eterium_desde_supabase()
	_configurar_especie_eterium_game_desde_supabase()


func _ready() -> void:
	super._ready()

	add_to_group("player")

	add_child(input_gate)
	eterium.configurar(eterium_runtime, stamina_controller)
	eterium.configurar_vital(vital_state)
	exploration_controller.terreno_descubierto.connect(_al_terreno_descubierto)
	locomotion.configurar(movement_controller, action_controller, stamina_controller)
	stamina_controller.configurar(max_stamina)
	stamina_controller.establecer_regeneracion(stamina_regeneration, stamina_regeneration_delay)
	stamina_controller.stamina_changed.connect(_al_cambio_stamina)

	_base_visual_position = visual.position

	_aplicar_configuracion_personaje()
	_update_dir_marker()
	_update_visual()

	stamina_changed.emit(
		stamina,
		max_stamina
	)


func _procesar_curacion_eterium(delta: float) -> void:
	var resultado := eterium.calcular_curacion(delta)
	if resultado.is_empty():
		return

	var curacion := int(resultado.get("curacion", 0))
	var costo := int(resultado.get("costo_eterium", 0))
	if not eterium.aplicar_curacion(curacion, costo):
		return

	# El runtime trabaja sobre el VitalState compartido con Entity.
	# Sincronizamos las propiedades públicas y notificamos a la presentación.
	_sync_desde_vital()
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)


func _actualizar_recuperacion_eterium(delta: float) -> void:
	var recuperadas := eterium.actualizar_recuperacion(delta, true)
	if recuperadas <= 0:
		return
	_sync_desde_vital()
	mana_changed.emit(mana, max_mana)
	if eterium.vida_eterium_compartidos():
		health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		return

	locomotion.actualizar_cooldowns(delta)
	_exploration_check_timer -= delta
	if _exploration_check_timer <= 0.0:
		_exploration_check_timer = 0.08
		_registrar_terreno_explorado()

	# Si una interfaz está bloqueando el gameplay,
	# no procesamos ningún input del jugador.
	if _esta_bloqueado_por_interfaz():
		velocity = Vector2.ZERO
		if state != State.IDLE:
			state = State.IDLE
			locomotion.reiniciar()
			_update_visual()
		return

	# El coordinador administra la ventana temporal de la acción.
	locomotion.avanzar_accion(delta)

	if state == State.JUMP:
		_procesar_jump(delta)
		return

	if state == State.DASH:
		_procesar_dash(delta)
		return

	# Curación con Eterium mientras se mantiene Q.
	if Input.is_action_pressed("focus") and not eterium.vida_eterium_compartidos():
		_procesar_curacion_eterium(delta)
		return


	# Shift tiene dos funciones:
	# pulsarlo = dash inmediato
	# mantenerlo = correr después del dash
	var shift_pressed := Input.is_action_pressed("run")

	if Input.is_action_just_pressed("run"):
		if _puede_hacer_dash():
			_iniciar_dash()
			return

	# Movimiento normal.
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var eterium_sprint := false
	if Input.is_action_pressed("eterium_sprint") and direction != Vector2.ZERO:
		eterium_sprint = eterium.procesar_carrera(delta)

	var is_running := (
		shift_pressed
		and direction != Vector2.ZERO
		and stamina > 0.0
		and not eterium_sprint
	)

	# La recuperación natural ocurre únicamente mientras el jugador espera.
	if direction == Vector2.ZERO and state == State.IDLE:
		_actualizar_recuperacion_eterium(delta)

	# Consumo de stamina al correr normalmente.
	if is_running:
		_gastar_stamina(run_stamina_cost * delta)

	# Movimiento.
	var speed: float

	if eterium_sprint:
		speed = move_speed * run_multiplier * eterium.multiplicador_carrera()
	elif is_running:
		speed = move_speed * run_multiplier
	else:
		speed = move_speed

	velocity = direction * speed

	move_and_slide()

	# Dirección.
	if direction != Vector2.ZERO:
		facing = direction.normalized()
		_update_dir_marker()

	# Estado visual.
	var new_state: State

	if direction == Vector2.ZERO:
		new_state = State.IDLE
	elif is_running:
		new_state = State.RUN
	else:
		new_state = State.WALK

	if new_state != state:
		state = new_state
		_update_visual()

	_actualizar_regeneracion_stamina(
		delta,
		is_running
	)


func _registrar_terreno_explorado() -> void:
	if not is_instance_valid(_world_context_ref):
		return
	exploration_controller.revisar(global_position, _world_context_ref)

func _al_terreno_descubierto(tile: Vector2i, descubrimiento: Dictionary) -> void:
	if _game_state_ref == null:
		return
	_game_state_ref.registrar_terreno_explorado(tile)
	var bioma: Variant = descubrimiento.get("bioma", {})
	var ecosistema: Variant = descubrimiento.get("ecosistema", {})
	var habitats: Variant = descubrimiento.get("habitats", [])
	var criaturas: Variant = descubrimiento.get("criaturas", [])
	if bioma is Dictionary and ecosistema is Dictionary:
		_game_state_ref.registrar_descubrimiento_mundo(
			bioma as Dictionary,
			ecosistema as Dictionary,
			habitats as Array if habitats is Array else [],
			criaturas as Array if criaturas is Array else []
		)


func _esta_bloqueado_por_interfaz() -> bool:
	return input_gate.esta_bloqueado()


func _actualizar_regeneracion_stamina(delta: float, esta_corriendo: bool) -> void:
	if esta_corriendo:
		return
	stamina_controller.actualizar(delta, true)

func _gastar_stamina(cantidad: float) -> bool:
	return stamina_controller.gastar(cantidad)

func _tiene_stamina(cantidad: float) -> bool:
	return stamina_controller.tiene(cantidad)


func restaurar_stamina(cantidad: float) -> bool:
	return stamina_controller.restaurar(cantidad)

func restaurar_eterium(cantidad: float) -> bool:
	var antes: int = mana
	mana = mini(maxi(mana + roundi(cantidad), 0), max_mana)
	if mana == antes:
		return false
	mana_changed.emit(mana, max_mana)
	return true

func _al_cambio_stamina(current: float, maximum: float) -> void:
	stamina = current
	stamina_changed.emit(current, maximum)


# ============================================================
# ETERIUM
# ============================================================

func _configurar_especie_eterium_game_desde_supabase() -> void:
	if _supabase_client_ref == null or _supabase_especie_configurada:
		return
	_supabase_especie_configurada = true
	if not _supabase_client_ref.especie_eterium_game_cargado.is_connected(_al_especie_eterium_game_cargado):
		_supabase_client_ref.especie_eterium_game_cargado.connect(_al_especie_eterium_game_cargado)
	if _supabase_client_ref.tiene_especie_eterium_game():
		_aplicar_especie_eterium_game(_supabase_client_ref.obtener_especie_eterium_game())


func _al_especie_eterium_game_cargado(reglas: Array) -> void:
	_aplicar_especie_eterium_game(reglas)


func _configurar_eterium_desde_supabase() -> void:
	if _supabase_client_ref == null or _supabase_runtime_configurado:
		return
	_supabase_runtime_configurado = true
	if not _supabase_client_ref.eterium_runtime_cargado.is_connected(
		_al_eterium_runtime_cargado
	):
		_supabase_client_ref.eterium_runtime_cargado.connect(
			_al_eterium_runtime_cargado
		)

	if _supabase_client_ref.tiene_eterium_runtime():
		_aplicar_eterium_runtime(
			_supabase_client_ref.obtener_eterium_reglas(),
			_supabase_client_ref.obtener_eterium_organismos()
		)
	else:
		_supabase_client_ref.cargar_eterium_runtime()


func _al_eterium_runtime_cargado(
	datos: Dictionary
) -> void:
	var reglas_variant: Variant = datos.get(
		"reglas",
		{}
	)
	var organismos_variant: Variant = datos.get(
		"organismos",
		[]
	)

	if not reglas_variant is Dictionary:
		return

	if not organismos_variant is Array:
		return

	_aplicar_eterium_runtime(
		reglas_variant as Dictionary,
		organismos_variant as Array
	)


func _aplicar_eterium_runtime(reglas: Dictionary, organismos: Array) -> void:
	eterium.aplicar_runtime(reglas, organismos)
	_sync_vital_desde_eterium()


func _aplicar_especie_eterium_game(reglas: Array) -> void:
	var especie_id := str(personaje_especie.get("id", "")).strip_edges()
	if especie_id.is_empty():
		return

	for regla_variant in reglas:
		if not regla_variant is Dictionary:
			continue
		var regla := regla_variant as Dictionary
		var padre_variant: Variant = regla.get("especie_eterium_v1", {})
		if not padre_variant is Dictionary:
			continue
		var padre := padre_variant as Dictionary
		if str(padre.get("especie_id", "")) != especie_id:
			continue

		if eterium.aplicar_especie(regla, especie_id):
			_sync_vital_desde_eterium()
			fisiologia_changed.emit(eterium.vida_eterium_compartidos())
		return


func _eterium_vida_compartida() -> bool:
	return eterium.vida_eterium_compartidos()


func absorber_eterium_de_criatura(criatura: Node) -> int:
	if not eterium.esta_listo():
		return 0
	if criatura == null or not is_instance_valid(criatura):
		return 0
	if not criatura is Creature:
		return 0
	if criatura.has_meta("eterium_absorbido"):
		return 0

	var datos_variant: Variant = (criatura as Creature).get_datos()
	if not datos_variant is Dictionary:
		return 0

	var cantidad := eterium.calcular_absorcion(datos_variant as Dictionary)
	criatura.set_meta("eterium_absorbido", true)

	if cantidad <= 0:
		return 0

	var absorbido := eterium.absorber(cantidad)
	if absorbido <= 0:
		return 0

	mana_changed.emit(mana, max_mana)
	if eterium.vida_eterium_compartidos():
		health_changed.emit(health, max_health)

	print(
		"Player: Eterium absorbido de ",
		str(criatura.get("criatura_nombre")),
		" → ",
		absorbido,
		" unidades runtime."
	)
	return absorbido

# ============================================================
# JUMP
# ============================================================

func _puede_hacer_jump() -> bool:
	return locomotion.puede_saltar(jump_stamina_cost)


func _iniciar_jump() -> void:
	if not locomotion.iniciar_salto(_obtener_direccion_accion(), jump_duration, jump_cooldown, jump_stamina_cost):
		return
	_action_direction = locomotion.obtener_direccion_accion(_obtener_direccion_accion())
	state = State.JUMP
	_update_visual()


func _procesar_jump(delta: float) -> void:
	var duracion := maxf(jump_duration, 0.001)
	var progreso := locomotion.obtener_progreso_salto(duracion)
	var velocidad := locomotion.obtener_velocidad_accion(duracion, jump_distance)
	velocity = _action_direction * velocidad
	move_and_slide()
	var altura := sin(progreso * PI) * 16.0
	visual.position = _base_visual_position + Vector2(0.0, -altura)
	if not locomotion.procesando_salto():
		velocity = Vector2.ZERO
		visual.position = _base_visual_position
		state = State.IDLE
		_update_visual()


# ============================================================
# DASH
# ============================================================

func _puede_hacer_dash() -> bool:
	return locomotion.puede_hacer_dash(dash_stamina_cost)


func _iniciar_dash() -> void:
	if not locomotion.iniciar_dash(_obtener_direccion_accion(), dash_duration, dash_cooldown, dash_stamina_cost):
		return
	_action_direction = locomotion.obtener_direccion_accion(_obtener_direccion_accion())
	state = State.DASH
	_update_visual()


func _procesar_dash(delta: float) -> void:
	var velocidad := locomotion.obtener_velocidad_accion(dash_duration, dash_distance)
	velocity = _action_direction * velocidad
	move_and_slide()
	if not locomotion.procesando_dash():
		velocity = Vector2.ZERO
		state = State.IDLE
		_update_visual()


func _obtener_direccion_accion() -> Vector2:
	if facing.length_squared() > 0.01:
		return facing.normalized()

	return Vector2.DOWN


# ============================================================
# COMBATE / DAÑO
# ============================================================

func take_damage(cantidad: int, origen: String = "desconocido") -> void:
	if not is_alive or state == State.DASH:
		return

	var dano_recibido := maxi(cantidad, 0)
	var inventario: GarliaInventory = _inventory_ref
	if inventario != null:
		var equipo_variant: Dictionary = inventario.obtener_equipamiento()
		if equipo_variant is Dictionary:
			dano_recibido = CombatDefense.aplicar(
				dano_recibido,
				CombatDefense.obtener_defensa(equipo_variant as Dictionary)
			)

	if _eterium_vida_compartida():
		mana = maxi(mana - dano_recibido, 0)
		health = mana
		mana_changed.emit(mana, max_mana)
		health_changed.emit(health, max_health)
		print(name, " recibió ", dano_recibido, " de daño. Reserva compartida: ", mana, "/", max_mana)
		if health <= 0:
			_die()
	else:
		super.take_damage(dano_recibido, origen)

	if not is_alive:
		_morir_jugador()
	elif dano_recibido > 0:
		_recibir_golpe_visual()


func _recibir_golpe_visual() -> void:
	if visual == null:
		return

	var tween := create_tween()

	tween.tween_property(
		visual,
		"modulate",
		Color(
			1.0,
			0.35,
			0.35
		),
		0.06
	)

	tween.tween_property(
		visual,
		"modulate",
		Color.WHITE,
		0.12
	)


func _morir_jugador() -> void:
	velocity = Vector2.ZERO

	set_physics_process(false)

	if visual == null:
		return

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		visual,
		"modulate:a",
		0.0,
		0.35
	)

	tween.tween_property(
		visual,
		"scale",
		Vector2(
			0.75,
			0.75
		),
		0.35
	)


func reaparecer() -> void:
	is_alive = true

	health = max_health
	mana = max_mana
	stamina_controller.reiniciar()

	velocity = Vector2.ZERO
	state = State.IDLE

	locomotion.reiniciar()

	var world_gen: Node = _world_context_ref
	if world_gen != null:
		set_spawn_from_world(world_gen)

	if visual != null:
		visual.position = _base_visual_position
		visual.modulate = Color.WHITE
		visual.scale = Vector2.ONE

	set_physics_process(true)

	_update_dir_marker()
	_update_visual()

	health_changed.emit(
		health,
		max_health
	)

	mana_changed.emit(
		mana,
		max_mana
	)

	stamina_changed.emit(
		stamina,
		max_stamina
	)


# ============================================================
# VISUAL / ANIMACIONES
# ============================================================

func _aplicar_configuracion_personaje() -> void:
	if _game_state_ref == null or not is_instance_valid(_game_state_ref):
		return

	var personaje_variant: Variant = _game_state_ref.obtener_configuracion_personaje()
	if not personaje_variant is Dictionary:
		return

	var personaje := personaje_variant as Dictionary
	personaje_nombre = str(personaje.get("nombre", "")).strip_edges()
	personaje_genero = str(personaje.get("genero", "")).strip_edges()
	personaje_skin = str(personaje.get("skin", "")).strip_edges()

	var especie_variant: Variant = personaje.get("especie", {})
	if especie_variant is Dictionary:
		personaje_especie = (especie_variant as Dictionary).duplicate(true)

	if personaje_skin.is_empty():
		return

	var textura := load(personaje_skin)
	if textura is Texture2D:
		var sprite := get_node_or_null("Visual/Sprite2D")
		if sprite is Sprite2D:
			(sprite as Sprite2D).texture = textura as Texture2D

	print(
		"Player: personaje aplicado → ",
		personaje_nombre,
		" | especie=",
		str(personaje_especie.get("nombre", "—")),
		" | skin=",
		personaje_skin
	)



func admin_obtener_configuracion() -> Dictionary:
	return {
		"nombre": personaje_nombre,
		"especie": personaje_especie.duplicate(true),
		"vida_maxima": max_health,
		"eterium_maximo": max_mana,
		"energia_maxima": max_stamina
	}


func admin_cambiar_nombre(nuevo_nombre: String) -> bool:
	var nombre := nuevo_nombre.strip_edges()
	if nombre.is_empty():
		return false

	personaje_nombre = nombre
	var personaje_variant: Variant = _game_state_ref.obtener_configuracion_personaje()
	var personaje: Dictionary = {}
	if personaje_variant is Dictionary:
		personaje = (personaje_variant as Dictionary).duplicate(true)

	personaje["nombre"] = nombre
	personaje["especie"] = personaje_especie.duplicate(true)
	personaje["skin"] = personaje_skin
	_game_state_ref.establecer_configuracion_personaje(personaje)
	return true


func admin_cambiar_especie(nueva_especie: Dictionary) -> bool:
	var especie_id := str(nueva_especie.get("id", "")).strip_edges()
	if especie_id.is_empty():
		return false

	personaje_especie = nueva_especie.duplicate(true)

	var personaje_variant: Variant = _game_state_ref.obtener_configuracion_personaje()
	var personaje: Dictionary = {}
	if personaje_variant is Dictionary:
		personaje = (personaje_variant as Dictionary).duplicate(true)

	personaje["nombre"] = personaje_nombre
	personaje["genero"] = personaje_genero
	personaje["especie"] = personaje_especie.duplicate(true)
	personaje["skin"] = personaje_skin
	_game_state_ref.establecer_configuracion_personaje(personaje)

	var reglas: Array = _supabase_client_ref.obtener_especie_eterium_game()
	if not reglas.is_empty():
		_aplicar_especie_eterium_game(reglas)

	return true


func admin_establecer_maximos(
	vida: int,
	eterium: int,
	energia: float
) -> bool:
	max_health = maxi(1, vida)
	max_mana = maxi(1, eterium)
	max_stamina = maxf(1.0, energia)

	health = mini(health, max_health)
	mana = mini(mana, max_mana)
	stamina = minf(stamina, max_stamina)

	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	stamina_changed.emit(stamina, max_stamina)
	return true


func admin_restaurar_defaults() -> bool:
	var reglas: Array = _supabase_client_ref.obtener_especie_eterium_game()
	var especie_id := str(personaje_especie.get("id", ""))
	var eterium_default := 100
	var vida_default := 100

	for regla_variant in reglas:
		if not regla_variant is Dictionary:
			continue
		var regla := regla_variant as Dictionary
		var padre_variant: Variant = regla.get("especie_eterium_v1", {})
		if not padre_variant is Dictionary:
			continue
		var padre := padre_variant as Dictionary
		if str(padre.get("especie_id", "")) != especie_id:
			continue
		eterium_default = maxi(1, roundi(float(padre.get("capacidad_base", 100))))
		if bool(regla.get("vida_eterium_compartidos", false)):
			vida_default = eterium_default
		break

	admin_establecer_maximos(
		vida_default,
		eterium_default,
		100.0
	)
	return true


func admin_guardar_estado() -> void:
	_game_state_ref.establecer_configuracion_personaje_admin({
		"rol": "admin" if bool(_game_state_ref.obtener_configuracion_personaje_admin().get("rol", "") == "admin") else "jugador",
		"capacidades": _game_state_ref.obtener_configuracion_personaje_admin().get("capacidades", []).duplicate(true),
		"maximos": {
			"vida": max_health,
			"eterium": max_mana,
			"energia": max_stamina
		}
	})
	_game_state_ref.guardar_partida()

func _update_visual() -> void:
	if anim == null:
		return

	var dir_name := _facing_name()
	var anim_name := ""

	match state:
		State.IDLE:
			anim_name = (
				"idle_"
				+ dir_name
			)

		State.WALK:
			anim_name = (
				"walk_"
				+ dir_name
			)

		State.RUN:
			anim_name = (
				"run_"
				+ dir_name
			)

		State.JUMP:
			anim_name = (
				"jump_"
				+ dir_name
			)

		State.DASH:
			anim_name = (
				"dash_"
				+ dir_name
			)

	if anim.has_animation(anim_name):
		anim.play(anim_name)


func _update_dir_marker() -> void:
	if facing_marker == null:
		return

	var center := Vector2(
		0,
		-24
	)

	var offset := (
		facing.normalized()
		* 14.0
	)

	facing_marker.position = (
		center
		+ offset
		- Vector2(
			2,
			2
		)
	)


func _facing_name() -> String:
	if abs(facing.y) >= abs(facing.x):
		return (
			"down"
			if facing.y > 0.0
			else "up"
		)

	return "side"


# ============================================================
# MAGIA IUM
# ============================================================

var _proceso_ium_equipado: Dictionary = {}
var _ium_manager_ref: IUMManager = null
var _entity_manager_ref: WorldEntityManager = null
var _supabase_client_ref: GarliaSupabaseClient = null
var _supabase_runtime_configurado: bool = false
var _supabase_especie_configurada: bool = false


func equipar_proceso_ium(proceso: Dictionary) -> void:
	_proceso_ium_equipado = proceso

func obtener_estado_ium() -> Dictionary:
	return _proceso_ium_equipado.duplicate(true)


func cargar_estado_ium(proceso: Dictionary) -> void:
	_proceso_ium_equipado = proceso.duplicate(true)




func _usar_proceso_ium() -> void:
	if _proceso_ium_equipado.is_empty():
		return

	if _ium_manager_ref == null:
		return

	var objetivo: Node = _buscar_objetivo_cercano()

	_ium_manager_ref.usar_proceso_equipado(objetivo)


func _buscar_objetivo_cercano() -> Node:
	var criaturas: Array = []
	if _entity_manager_ref != null:
		for entidad in _entity_manager_ref.obtener_entidades_activas():
			if entidad is Node and entidad.is_in_group("creatures"):
				criaturas.append(entidad)
	var mas_cercana: Node = null
	var dist_min := 160.0

	for criatura in criaturas:
		if not is_instance_valid(criatura):
			continue

		var dist := global_position.distance_to(
			criatura.global_position
		)

		if dist < dist_min:
			dist_min = dist
			mas_cercana = criatura

	return mas_cercana


func aplicar_efecto_slow(duracion: float) -> void:
	var speed_original := move_speed

	move_speed = move_speed * 0.4

	await get_tree().create_timer(duracion).timeout

	if is_instance_valid(self):
		move_speed = speed_original


# ============================================================
# SPAWN
# ============================================================

func set_spawn_from_world(
	world_gen: WorldGenerator
) -> void:
	if world_gen == null:
		return

	global_position = world_gen.get_spawn_position()


func _sync_vital_desde_eterium() -> void:
	if eterium_runtime == null:
		return
	health = vital_state.health
	mana = vital_state.mana
	max_health = vital_state.max_health
	max_mana = vital_state.max_mana
	is_alive = vital_state.is_alive
