extends Entity


signal stamina_changed(current: float, maximum: float)


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
var _stamina_regeneration_timer: float = 0.0

var _eterium_reglas: Dictionary = {}
var _eterium_organismos: Dictionary = {}
var _eterium_runtime_ready: bool = false
var _eterium_heal_timer: float = 0.0
var _eterium_recovery_accumulator: float = 0.0


var _jump_time: float = 0.0
var _jump_cooldown_timer: float = 0.0

var _dash_time: float = 0.0
var _dash_cooldown_timer: float = 0.0

var _action_direction: Vector2 = Vector2.DOWN
var _base_visual_position: Vector2 = Vector2.ZERO
var _ultima_exploracion_tile: Vector2i = Vector2i(2147483647, 2147483647)


@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var visual: Node2D = $Visual

@onready var body_visual: ColorRect = $Visual/Body
@onready var head_visual: ColorRect = $Visual/Head
@onready var facing_marker: ColorRect = $Visual/FacingMarker


func _ready() -> void:
	super._ready()

	add_to_group("player")

	stamina = max_stamina

	_configurar_eterium_desde_supabase()

	_base_visual_position = visual.position

	_update_dir_marker()
	_update_visual()

	stamina_changed.emit(
		stamina,
		max_stamina
	)


func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		return

	_actualizar_cooldowns(delta)
	_registrar_terreno_explorado()

	# Si una interfaz está bloqueando el gameplay,
	# no procesamos ningún input del jugador.
	if _esta_bloqueado_por_interfaz():
		velocity = Vector2.ZERO

		if state != State.IDLE:
			state = State.IDLE
			_update_visual()

		return

	# Mientras hacemos una acción especial,
	# esa acción toma el control del movimiento.
	if state == State.JUMP:
		_procesar_jump(delta)
		return

	if state == State.DASH:
		_procesar_dash(delta)
		return

	# Curación con Eterium mientras se mantiene Q.
	if Input.is_action_pressed("focus"):
		_procesar_curacion_eterium(delta)
		return

	_eterium_heal_timer = 0.0

	# Magia IUM.
	if Input.is_action_just_pressed("use_ium"):
		_usar_proceso_ium()

	# Esquiva.
	# Reutilizamos el DASH existente porque ya proporciona
	# movimiento rápido e invulnerabilidad durante la acción.
	if Input.is_action_just_pressed("dodge"):
		if _puede_hacer_dash():
			_iniciar_dash()
			return

	# Dash alternativo.
	if Input.is_action_just_pressed("dash"):
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

	var is_running := (
		Input.is_action_pressed("run")
		and direction != Vector2.ZERO
		and stamina > 0.0
	)

	# La recuperación natural ocurre únicamente mientras el jugador espera.
	if direction == Vector2.ZERO and state == State.IDLE:
		_actualizar_recuperacion_eterium(delta)
	else:
		_eterium_recovery_accumulator = 0.0

	# Consumo de stamina al correr.
	if is_running:
		_gastar_stamina(
			run_stamina_cost * delta
		)

		_stamina_regeneration_timer = (
			stamina_regeneration_delay
		)

	# Movimiento.
	var speed: float

	if is_running:
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
	var world_gen: Node = get_tree().get_first_node_in_group(
		"world_generator"
	)

	if world_gen == null or not is_instance_valid(world_gen):
		return

	if not world_gen.has_method("get_tile_at"):
		return

	var tile_variant: Variant = world_gen.call(
		"get_tile_at",
		global_position
	)

	if not tile_variant is Vector2i:
		return

	var tile: Vector2i = tile_variant as Vector2i

	if tile == _ultima_exploracion_tile:
		return

	_ultima_exploracion_tile = tile
	GameState.registrar_terreno_explorado(tile)

	if not world_gen.has_method("get_bioma_at"):
		return

	var bioma_variant: Variant = world_gen.call(
		"get_bioma_at",
		tile
	)
	var ecosistema_variant: Variant = world_gen.call(
		"get_ecosistema_at",
		tile
	)
	var habitats_variant: Variant = world_gen.call(
		"get_habitats_at",
		tile
	)
	var criaturas_variant: Variant = world_gen.call(
		"get_criaturas_at",
		tile
	)

	if not bioma_variant is Dictionary:
		return

	if not ecosistema_variant is Dictionary:
		return

	var habitats: Array = []
	if habitats_variant is Array:
		habitats = habitats_variant as Array

	var criaturas: Array = []
	if criaturas_variant is Array:
		criaturas = criaturas_variant as Array

	GameState.registrar_descubrimiento_mundo(
		bioma_variant as Dictionary,
		ecosistema_variant as Dictionary,
		habitats,
		criaturas
	)


func _esta_bloqueado_por_interfaz() -> bool:
	var consola := get_tree().get_first_node_in_group(
		"admin_console"
	)

	if consola != null:
		if bool(consola.get("_abierto")):
			return true

	return get_tree().paused


func _actualizar_cooldowns(delta: float) -> void:
	_jump_cooldown_timer = maxf(
		_jump_cooldown_timer - delta,
		0.0
	)

	_dash_cooldown_timer = maxf(
		_dash_cooldown_timer - delta,
		0.0
	)


func _actualizar_regeneracion_stamina(
	delta: float,
	esta_corriendo: bool
) -> void:
	if esta_corriendo:
		return

	if _stamina_regeneration_timer > 0.0:
		_stamina_regeneration_timer = maxf(
			_stamina_regeneration_timer - delta,
			0.0
		)

		return

	if stamina >= max_stamina:
		return

	stamina = minf(
		stamina + stamina_regeneration * delta,
		max_stamina
	)

	stamina_changed.emit(
		stamina,
		max_stamina
	)


func _gastar_stamina(cantidad: float) -> bool:
	if cantidad <= 0.0:
		return true

	if stamina < cantidad:
		return false

	stamina = maxf(
		stamina - cantidad,
		0.0
	)

	_stamina_regeneration_timer = (
		stamina_regeneration_delay
	)

	stamina_changed.emit(
		stamina,
		max_stamina
	)

	return true


func _tiene_stamina(cantidad: float) -> bool:
	return stamina >= cantidad


# ============================================================
# ETERIUM
# ============================================================

func _configurar_eterium_desde_supabase() -> void:
	if not SupabaseClient.eterium_runtime_cargado.is_connected(
		_al_eterium_runtime_cargado
	):
		SupabaseClient.eterium_runtime_cargado.connect(
			_al_eterium_runtime_cargado
		)

	if SupabaseClient.tiene_eterium_runtime():
		_aplicar_eterium_runtime(
			SupabaseClient.obtener_eterium_reglas(),
			SupabaseClient.obtener_eterium_organismos()
		)
	else:
		SupabaseClient.cargar_eterium_runtime()


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


func _aplicar_eterium_runtime(
	reglas: Dictionary,
	organismos: Array
) -> void:
	if reglas.is_empty():
		return

	_eterium_reglas = reglas.duplicate(true)
	_eterium_organismos.clear()

	for organismo_variant in organismos:
		if not organismo_variant is Dictionary:
			continue

		var organismo := organismo_variant as Dictionary
		var organismo_id := str(
			organismo.get("organismo_id", "")
		)

		if organismo_id.is_empty():
			continue

		_eterium_organismos[organismo_id] = (
			organismo.duplicate(true)
		)

	var escala := _eterium_escala_runtime()
	var limite_s := float(
		_eterium_reglas.get(
			"limite_estable_s",
			0.0
		)
	)
	var nuevo_max_mana := maxi(
		1,
		roundi(limite_s * escala)
	)

	max_mana = nuevo_max_mana
	mana = clampi(
		mana,
		0,
		max_mana
	)

	_eterium_runtime_ready = true
	mana_changed.emit(
		mana,
		max_mana
	)

	print(
		"Player: Eterium canónico cargado → límite S=",
		limite_s,
		" | escala=",
		escala,
		" | runtime=",
		max_mana
	)


func _eterium_escala_runtime() -> float:
	return maxf(
		float(
			_eterium_reglas.get(
				"escala_runtime",
				0.0
			)
		),
		0.001
	)


func _actualizar_recuperacion_eterium(delta: float) -> void:
	if not _eterium_runtime_ready:
		return

	if mana >= max_mana:
		_eterium_recovery_accumulator = 0.0
		return

	var recuperacion_s := maxf(
		float(
			_eterium_reglas.get(
				"recuperacion_pasiva_s_por_segundo",
				0.0
			)
		),
		0.0
	)

	if recuperacion_s <= 0.0:
		return

	_eterium_recovery_accumulator += (
		recuperacion_s
		* _eterium_escala_runtime()
		* delta
	)

	var unidades := floori(
		_eterium_recovery_accumulator
	)

	if unidades <= 0:
		return

	var espacio := max_mana - mana
	var recuperadas := mini(
		unidades,
		espacio
	)

	if recuperadas <= 0:
		_eterium_recovery_accumulator = 0.0
		return

	mana += recuperadas
	_eterium_recovery_accumulator -= recuperadas

	mana_changed.emit(
		mana,
		max_mana
	)


func _procesar_curacion_eterium(delta: float) -> void:
	velocity = Vector2.ZERO

	if state != State.IDLE:
		state = State.IDLE
		_update_visual()

	if not _eterium_runtime_ready:
		_eterium_heal_timer = 0.0
		return

	if health >= max_health:
		_eterium_heal_timer = 0.0
		return

	var escala := _eterium_escala_runtime()
	var costo_s := maxf(
		float(
			_eterium_reglas.get(
				"curacion_costo_s_por_tick",
				0.0
			)
		),
		0.0
	)
	var intervalo_s := maxf(
		float(
			_eterium_reglas.get(
				"curacion_intervalo_s",
				0.0
			)
		),
		0.01
	)
	var curacion_por_s := maxf(
		float(
			_eterium_reglas.get(
				"curacion_vida_por_s",
				0.0
			)
		),
		0.0
	)

	var costo_runtime := maxi(
		1,
		roundi(costo_s * escala)
	)

	if mana < costo_runtime:
		_eterium_heal_timer = 0.0
		return

	_eterium_recovery_accumulator = 0.0
	_eterium_heal_timer -= delta

	if _eterium_heal_timer > 0.0:
		return

	_eterium_heal_timer = intervalo_s

	var curacion := maxi(
		1,
		roundi(costo_s * curacion_por_s)
	)
	curacion = mini(
		curacion,
		max_health - health
	)

	if curacion <= 0:
		return

	heal(curacion)
	mana = maxi(
		mana - costo_runtime,
		0
	)
	mana_changed.emit(
		mana,
		max_mana
	)


func absorber_eterium_de_criatura(criatura: Node) -> int:
	if not _eterium_runtime_ready:
		return 0

	if criatura == null or not is_instance_valid(criatura):
		return 0

	if not criatura.has_method("get_datos"):
		return 0

	if criatura.has_meta("eterium_absorbido"):
		return 0

	var datos_variant: Variant = criatura.call("get_datos")
	if not datos_variant is Dictionary:
		return 0

	var datos := datos_variant as Dictionary
	var biologia_variant: Variant = datos.get(
		"biologia_calculada",
		{}
	)

	if not biologia_variant is Dictionary:
		return 0

	var biologia := biologia_variant as Dictionary
	var organismo_id := str(
		biologia.get(
			"organismo_id",
			""
		)
	)

	if organismo_id.is_empty():
		return 0

	var organismo_variant: Variant = _eterium_organismos.get(
		organismo_id,
		{}
	)
	if not organismo_variant is Dictionary:
		return 0

	var organismo := organismo_variant as Dictionary
	if not bool(organismo.get("posee_eterium", false)):
		return 0

	var base := str(
		organismo.get(
			"base_eterium",
			""
		)
	).strip_edges().to_lower()

	if base.is_empty():
		return 0

	var rendimientos_variant: Variant = _eterium_reglas.get(
		"rendimiento_por_base_s",
		{}
	)
	if not rendimientos_variant is Dictionary:
		return 0

	var rendimiento_s := maxf(
		float(
			(rendimientos_variant as Dictionary).get(
				base,
				0.0
			)
		),
		0.0
	)
	var eficiencia := clampf(
		float(
			_eterium_reglas.get(
				"absorcion_eficiencia",
				0.0
			)
		),
		0.0,
		1.0
	)

	var cantidad_runtime := roundi(
		rendimiento_s
		* eficiencia
		* _eterium_escala_runtime()
	)
	var espacio := max_mana - mana
	cantidad_runtime = clampi(
		cantidad_runtime,
		0,
		espacio
	)

	criatura.set_meta(
		"eterium_absorbido",
		true
	)

	if cantidad_runtime <= 0:
		return 0

	mana += cantidad_runtime
	_eterium_recovery_accumulator = 0.0

	mana_changed.emit(
		mana,
		max_mana
	)

	print(
		"Player: Eterium absorbido de ",
		str(criatura.get("criatura_nombre")),
		" → ",
		cantidad_runtime,
		" unidades runtime (",
		rendimiento_s,
		" S)."
	)

	return cantidad_runtime




# ============================================================
# JUMP
# ============================================================