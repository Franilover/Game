extends Node
class_name CombatSystem


signal ataque_realizado(atacante: Node, objetivo: Entity, danio: int)
signal contacto_efectivo(atacante: Node, objetivo: Entity, origen: String)
signal ataque_sin_objetivo(atacante: Node)
signal accion_contextual_solicitada(objeto: Dictionary, usuario: Node)


const COMBAT_ITEM_RESOLVER: Script = preload(
	"res://scripts/gameplay/combat/combat_item_resolver.gd"
)

const COMBAT_ATTACK_EXECUTOR: Script = preload(
	"res://scripts/gameplay/combat/combat_attack_executor.gd"
)

const COMBAT_WEAPON_ATTACK_VALIDATOR: Script = preload(
	"res://scripts/gameplay/combat/combat_weapon_attack_validator.gd"
)

const COMBAT_ATTACK_RESULT: Script = preload(
	"res://scripts/gameplay/combat/combat_attack_result.gd"
)

const COMBAT_IMPACT_EFFECTS: Script = preload(
	"res://scripts/gameplay/combat/combat_impact_effects.gd"
)

@export_category("Ataque")
@export var alcance_desarmado: float = 48.0
@export var ancho_ataque: float = 48.0
@export var danio_desarmado: int = 8

@export var alcance_arma: float = 64.0
@export var ancho_arma: float = 48.0
@export var danio_arma_defecto: int = 8
@export var enfriamiento_arma: float = 0.18

@export_category("Armas a distancia")
@export var velocidad_proyectil: float = 280.0
@export var vida_proyectil: float = 3.0
@export var radio_impacto_proyectil: float = 9.0

@export_category("Visual")
@export var duracion_ataque: float = 0.20
@export var color_ataque: Color = Color(0.86, 0.74, 0.52, 0.65)

var player: Entity = null
var inventory: InventoryController = null
var world_context: WorldContext = null
var world_items: GarliaWorldItems = null
var projectile_root: Node = null
var game_state: GameStateService = null
var _accion_en_mano_derecha: bool = false
var combat_controller := CombatController.new()
var _tiempo_desde_ataque: float = 0.0


func configurar(nuevo_player: Player, nuevo_inventory: InventoryController = null, nuevo_world_context: WorldContext = null, nuevo_projectile_root: Node = null, nuevo_game_state: GameStateService = null, nuevo_world_items: GarliaWorldItems = null) -> void:
	inventory = nuevo_inventory
	world_context = nuevo_world_context
	world_items = nuevo_world_items
	projectile_root = nuevo_projectile_root
	game_state = nuevo_game_state
	configurar_jugador_activo(nuevo_player, nuevo_player.input_gate)


## Cambia el actor que ejecuta el combate sin reemplazar inventario ni dependencias.
## Permite que expediciones con un CharacterBody2D especializado usen el mismo
## CombatSystem y la misma autoridad de entrada de Main.
func configurar_jugador_activo(
	nuevo_jugador: Entity,
	nuevo_input_gate: GameplayInputGate = null
) -> void:
	if nuevo_jugador == null or not is_instance_valid(nuevo_jugador):
		push_warning("CombatSystem: se rechazó un actor de combate inválido.")
		return
	player = nuevo_jugador
	if not is_instance_valid(combat_controller):
		combat_controller = CombatController.new()
	if not combat_controller.is_inside_tree():
		add_child(combat_controller)
	combat_controller.configurar_gate(nuevo_input_gate)

	print(
		"CombatSystem: configurado."
	)


func _process(delta: float) -> void:
	_tiempo_desde_ataque = maxf(
		_tiempo_desde_ataque - delta,
		0.0
	)


func _ready() -> void:

	if not combat_controller.is_inside_tree():
		add_child(combat_controller)
	if not combat_controller.ataque_solicitado.is_connected(_al_ataque_solicitado):
		combat_controller.ataque_solicitado.connect(_al_ataque_solicitado)


func procesar_accion_primaria() -> bool:
	if not CombatTargeting.es_atacante_valido(player) or _tiempo_desde_ataque > 0.0:
		return false

	# El router ya resolvió la prioridad de interacción.
	# Aquí solo se decide la acción primaria de combate.
	var objeto_activo: Dictionary = _enriquecer_objeto_combate(inventory.obtener_objeto_mano_activa("izquierda")) if inventory != null else {}
	_accion_en_mano_derecha = false
	var modo := "objeto_mano" if _es_objeto_ataque(objeto_activo) else "desarmado"

	return combat_controller.solicitar_ataque(
		_obtener_direccion_ataque(),
		objeto_activo,
		modo
	)


func procesar_accion_secundaria() -> bool:
	if not CombatTargeting.es_atacante_valido(player) or _tiempo_desde_ataque > 0.0:
		return false

	var objeto_mano := _enriquecer_objeto_combate(_obtener_objeto_mano_activa("derecha"))
	_accion_en_mano_derecha = true
	if objeto_mano.is_empty():
		return false

	var modo := "objeto_mano" if _es_objeto_ataque(objeto_mano) else "desarmado"
	return combat_controller.solicitar_ataque(
		_obtener_direccion_ataque(),
		objeto_mano,
		modo
	)


func _al_ataque_solicitado(
	direccion: Vector2,
	objeto: Dictionary,
	modo: String
) -> void:
	if not CombatTargeting.es_atacante_valido(player) or _tiempo_desde_ataque > 0.0:
		return
	var direccion_ataque := _normalizar_direccion_ataque(direccion)

	if modo == "desarmado":
		_atacar_desarmado(direccion_ataque)
		return

	if modo == "objeto_mano":
		if not _es_objeto_ataque(objeto):
			return
		_atacar_con_objeto(objeto, direccion_ataque)
		return


func _arma_bloqueada_por_licencia(objeto: Dictionary) -> bool:
	var nombre := str(objeto.get("nombre", "")).strip_edges().to_lower()
	if not nombre.contains("espada"):
		return false
	if bool(GameState.world_state.flags.get("licencia_espadas", false)):
		return false

	# La licencia se exige únicamente dentro de zonas que son reinos.
	# Mundo Abierto, Explorar Granja, expediciones y Hogar quedan libres.
	var zone_manager := get_tree().get_first_node_in_group("zone_manager")
	if not is_instance_valid(zone_manager) or not zone_manager.has_method("obtener_tipo_actual"):
		return false
	var tipo_zona := str(zone_manager.call("obtener_tipo_actual")).strip_edges().to_lower()
	return tipo_zona == "reino_torres" or tipo_zona.begins_with("reino:")


func _mostrar_aviso_licencia(objeto: Dictionary) -> void:
	var nombre := str(objeto.get("nombre", "arma")).strip_edges()
	if nombre.is_empty():
		nombre = "arma"
	Events.notification_pushed.emit('No puedes usar "%s" sin licencia' % nombre)


func _es_herramienta(objeto: Dictionary) -> bool:
	return COMBAT_ITEM_RESOLVER.es_herramienta(objeto)

func _es_objeto_ataque(objeto: Dictionary) -> bool:
	return COMBAT_ITEM_RESOLVER.es_objeto_ataque(objeto)

func _atacar_con_objeto(objeto: Dictionary, direccion: Vector2) -> void:
	if objeto.is_empty():
		return
	if _arma_bloqueada_por_licencia(objeto):
		_mostrar_aviso_licencia(objeto)
		return

	if _es_herramienta(objeto):
		_atacar_con_herramienta(objeto, direccion)
		return

	_atacar_con_arma(objeto, direccion)

func _atacar_con_herramienta(
	herramienta: Dictionary,
	direccion: Vector2
) -> void:
	var propiedades := _obtener_propiedades_game(herramienta)
	var recoleccion_variant: Variant = propiedades.get("herramienta_recoleccion", {})
	var recoleccion: Dictionary = recoleccion_variant as Dictionary if recoleccion_variant is Dictionary else {}
	var tipo_herramienta := str(recoleccion.get("tipo", "")).strip_edges().to_lower()

	if tipo_herramienta == "pala":
		if _usar_pala():
			_reproducir_animacion_equipo(herramienta, direccion)
			_consumir_durabilidad_herramienta()
		return

	# Las herramientas no son armas: hacha, pico, hoz, azada, etc.
	# sólo ejecutan su acción contextual desde InteractionSystem.
	# Si no hay un objetivo compatible, el clic no debe convertirse
	# accidentalmente en un ataque cuerpo a cuerpo.
	return

func _usar_pala() -> bool:
	if world_context == null or not is_instance_valid(world_context):
		return false

	var objetivo_posicion: Vector2 = player.global_position
	var tile: Vector2i = world_context.get_tile_at(objetivo_posicion)
	var zona: int = world_context.get_zona_at(tile)

	# La pala transforma únicamente Pradera en Tierra.
	if zona != 0:
		return false

	if world_context.cambiar_zona_at(tile, 1):
		_iniciar_cooldown_ataque()
		print("CombatSystem: pala → Pradera convertida en Tierra en ", tile)
		return true

	return false


func _consumir_durabilidad_herramienta() -> void:
	if inventory == null:
		return
	var mano := "derecha" if _accion_en_mano_derecha else "izquierda"
	inventory.consumir_durabilidad_mano_activa(mano)


func _crear_ataque_melee(
	direccion: Vector2,
	alcance: float,
	ancho: float,
	objeto: Dictionary,
	danio_directo: int = -1
) -> void:
	if not CombatTargeting.es_atacante_valido(player):
		return

	var ataque: CombatAttackArea = COMBAT_ATTACK_EXECUTOR.crear_ataque_melee(
		player,
		direccion,
		alcance,
		ancho,
		objeto,
		duracion_ataque,
		color_ataque,
		danio_directo,
		Callable(self, "_al_recibir_objetivo_de_ataque")
	)
	if ataque == null:
		return

	print(
		"CombatSystem: área de ataque creada | dirección=",
		direccion,
		" alcance=",
		alcance,
		" ancho=",
		ancho
	)

func _al_recibir_objetivo_de_ataque(
	objetivo: Node,
	ataque: CombatAttackArea
) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	if ataque == null or not is_instance_valid(ataque):
		return
	var atacante := ataque.atacante
	if not CombatTargeting.es_atacante_valido(atacante):
		return

	var objeto := ataque.objeto_ataque
	var entidad_objetivo := objetivo as Entity
	if entidad_objetivo == null:
		return
	if not CombatTargeting.es_objetivo_valido(atacante, entidad_objetivo):
		return
	contacto_efectivo.emit(
		atacante,
		entidad_objetivo,
		"Jugador/Combate:" + str(objeto.get("nombre", "Objeto"))
	)
	var danio := _obtener_danio_arma(objeto)

	var override_variant: Variant = objeto.get(
		"_damage_override",
		-1
	)
	if override_variant is int and int(override_variant) >= 0:
		danio = int(override_variant)

	if _es_herramienta(objeto) and danio <= 0:
		print(
			"CombatSystem: ataque de herramienta detectó → ",
			objetivo.name,
			" | sin daño configurado en Supabase."
		)
		return

	_aplicar_danio(
		objetivo,
		danio,
		str(objeto.get("nombre", "Objeto")),
		atacante,
		objeto
	)

func usar_objeto_activo() -> void:
	if not CombatTargeting.es_atacante_valido(player):
		return

	var objeto_activo := _enriquecer_objeto_combate(_obtener_objeto_mano_activa("derecha"))
	if objeto_activo.is_empty() or not _es_objeto_ataque(objeto_activo):
		return
	_atacar_con_objeto(objeto_activo, _obtener_direccion_ataque())


## Los snapshots de partidas antiguas pueden conservar sólo item_id/cantidad.
## Resolver aquí contra el catálogo evita que CombatSystem dependa de la UI
## y permite clasificar el arma y reproducir su animación con datos canónicos.
func _enriquecer_objeto_combate(objeto: Dictionary) -> Dictionary:
	var resultado := objeto.duplicate(true)
	if resultado.is_empty() or not is_instance_valid(world_items):
		return resultado
	var item_id := str(resultado.get("item_id", resultado.get("id", ""))).strip_edges()
	var canonico: Dictionary = {}
	if not item_id.is_empty():
		canonico = world_items.buscar_item_por_id(item_id)
	if canonico.is_empty():
		canonico = world_items.buscar_item_por_nombre(str(resultado.get("nombre", "")))
	if canonico.is_empty():
		return resultado
	for clave in ["nombre", "propiedades_game", "categoria", "categoria_clave", "tipo", "tipo_objeto"]:
		if not canonico.has(clave):
			continue
		var actual: Variant = resultado.get(clave, null)
		var valor_canonico: Variant = canonico[clave]
		if clave == "propiedades_game" and valor_canonico is Dictionary:
			var combinadas := (valor_canonico as Dictionary).duplicate(true)
			if actual is Dictionary:
				for propiedad in (actual as Dictionary).keys():
					if not combinadas.has(propiedad):
						combinadas[propiedad] = (actual as Dictionary)[propiedad]
			resultado[clave] = combinadas
			continue
		var vacio := actual == null
		if actual is String:
			var texto_actual := str(actual).strip_edges().to_lower()
			vacio = texto_actual.is_empty() or (clave in ["nombre", "tipo"] and texto_actual in ["objeto", "item", "desconocido"])
		elif actual is Dictionary:
			vacio = (actual as Dictionary).is_empty()
		elif actual is Array:
			vacio = (actual as Array).is_empty()
		if vacio:
			resultado[clave] = valor_canonico.duplicate(true) if valor_canonico is Dictionary or valor_canonico is Array else valor_canonico
	return resultado


func _obtener_objeto_mano_activa(mano: String) -> Dictionary:
	if inventory == null:
		return {}
	return inventory.obtener_objeto_mano_activa(mano)


func _atacar_desarmado(direccion: Vector2) -> void:
	# El hitbox es la única resolución del ataque melee.
	# CombatAttackArea detecta el objetivo y CombatDamage aplica el daño.
	_crear_ataque_melee(
		direccion,
		alcance_desarmado,
		ancho_ataque,
		{},
		danio_desarmado
	)

	_iniciar_cooldown_ataque()

func _atacar_con_arma(
	arma: Dictionary,
	direccion: Vector2
) -> void:
	var modo := _obtener_modo_ataque(arma)
	_iniciar_cooldown_ataque()

	_reproducir_animacion_equipo(arma, direccion)
	if modo == "distancia":
		_disparar_proyectil(arma, direccion)
		return
	var alcance := _obtener_alcance_arma(arma)
	var ancho := _obtener_ancho_arma(arma)
	_crear_ataque_melee(
		direccion,
		alcance,
		ancho,
		arma
	)

func _reproducir_animacion_equipo(objeto: Dictionary, direccion: Vector2) -> void:
	if not is_instance_valid(player) or not player.has_method("reproducir_animacion_herramienta"):
		return
	var destino := player.global_position + direccion.normalized() * 28.0
	player.call("reproducir_animacion_herramienta", objeto, destino)


func _disparar_proyectil(
	arma: Dictionary,
	direccion: Vector2
) -> void:
	if not CombatTargeting.es_atacante_valido(player):
		return

	var velocidad := _obtener_float_propiedad(
		arma,
		"velocidad_proyectil",
		velocidad_proyectil
	)
	var vida := _obtener_float_propiedad(
		arma,
		"vida_proyectil",
		vida_proyectil
	)
	var radio := _obtener_float_propiedad(
		arma,
		"radio_impacto",
		radio_impacto_proyectil
	)
	var danio := _obtener_danio_arma(arma)

	var proyectil: CombatProjectile = COMBAT_ATTACK_EXECUTOR.disparar_proyectil(
		player,
		projectile_root,
		direccion,
		arma,
		velocidad,
		vida,
		radio,
		danio,
		Callable(self, "_al_detectar_contacto_proyectil"),
		Callable(self, "_al_recibir_impacto_proyectil")
	)
	if proyectil == null:
		return

	print(
		"CombatSystem: proyectil disparado → ",
		str(arma.get("nombre", "Arma"))
	)

func _al_detectar_contacto_proyectil(
	objetivo: Entity,
	ataque: CombatAttack
) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	if ataque == null or not CombatTargeting.es_objetivo_valido(ataque.attacker, objetivo):
		return
	contacto_efectivo.emit(
		ataque.attacker,
		objetivo,
		ataque.origin
	)


func _al_recibir_impacto_proyectil(
	objetivo: Entity,
	ataque: CombatAttack
) -> void:
	if objetivo == null or not is_instance_valid(objetivo) or ataque == null:
		return
	# El atacante pudo morir durante las señales síncronas del daño. Eso no
	# invalida un impacto que ya se aplicó: todavía hay que registrar derrota,
	# absorción y feedback. Solo se omite si la instancia ya salió del mundo.
	if (
		not is_instance_valid(ataque.attacker)
		or not ataque.attacker.is_inside_tree()
		or ataque.attacker.is_queued_for_deletion()
	):
		return

	var arma := ataque.object_data
	COMBAT_IMPACT_EFFECTS.procesar_impacto_confirmado(
		game_state,
		player,
		ataque.attacker,
		objetivo,
		ataque.damage,
		arma
	)
	ataque_realizado.emit(ataque.attacker, objetivo, ataque.damage)


func _obtener_modo_ataque(arma: Dictionary) -> String:
	return COMBAT_ITEM_RESOLVER.obtener_modo_ataque(arma)

func solicitar_ataque_con_arma(
	atacante: Node,
	objetivo: Entity,
	arma: Dictionary
) -> CombatAttackResult:
	if atacante == player and _arma_bloqueada_por_licencia(arma):
		_mostrar_aviso_licencia(arma)
		return COMBAT_ATTACK_RESULT.rechazado(&"licencia_requerida")
	var motivo_rechazo: StringName = COMBAT_WEAPON_ATTACK_VALIDATOR.validar(
		atacante,
		objetivo,
		arma
	)
	if not motivo_rechazo.is_empty():
		return COMBAT_ATTACK_RESULT.rechazado(motivo_rechazo)

	var danio: int = _obtener_danio_arma(arma)
	contacto_efectivo.emit(
		atacante,
		objetivo,
		"Entidad/Arma:" + str(arma.get("nombre", "Arma"))
	)

	var danio_aplicado := _aplicar_danio(
		objetivo,
		danio,
		str(arma.get("nombre", "Arma")),
		atacante,
		arma
	)

	return COMBAT_ATTACK_RESULT.aceptado(true, danio_aplicado)


## Compatibilidad para consumidores antiguos: true significa solicitud aceptada,
## no necesariamente que la salud del objetivo haya disminuido.
func atacar_objetivo_con_arma(
	atacante: Node,
	objetivo: Entity,
	arma: Dictionary
) -> bool:
	return solicitar_ataque_con_arma(atacante, objetivo, arma).solicitud_aceptada


func obtener_alcance_arma(
	arma: Dictionary
) -> float:
	return _obtener_alcance_arma(arma)


func _obtener_danio_arma(arma: Dictionary) -> int:
	return COMBAT_ITEM_RESOLVER.obtener_danio_arma(
		arma,
		danio_arma_defecto
	)

func _obtener_alcance_arma(arma: Dictionary) -> float:
	return COMBAT_ITEM_RESOLVER.obtener_alcance_arma(
		arma,
		alcance_arma
	)

func _obtener_ancho_arma(arma: Dictionary) -> float:
	return COMBAT_ITEM_RESOLVER.obtener_ancho_ataque(
		arma,
		ancho_arma
	)

func _obtener_float_propiedad(
	arma: Dictionary,
	nombre: String,
	valor_por_defecto: float
) -> float:
	return COMBAT_ITEM_RESOLVER.obtener_float_propiedad(
		arma,
		nombre,
		valor_por_defecto
	)

func _obtener_propiedades_game(objeto: Dictionary) -> Dictionary:
	return COMBAT_ITEM_RESOLVER.obtener_propiedades_game(objeto)

func _aplicar_danio(
	objetivo: Entity,
	danio: int,
	origen: String,
	atacante: Node = null,
	arma: Dictionary = {}
) -> bool:
	var actor: Node = atacante
	if actor == null:
		actor = player
	if not CombatTargeting.es_objetivo_valido(actor, objetivo):
		return false

	var danio_real := CombatDamage.aplicar_y_obtener_danio(
		objetivo,
		danio,
		"Jugador/CombatSystem:" + origen,
		Callable(),
		actor
	)
	if danio_real <= 0:
		return false

	COMBAT_IMPACT_EFFECTS.procesar_impacto_confirmado(
		game_state,
		player,
		actor,
		objetivo,
		danio_real,
		arma
	)

	if is_instance_valid(actor) and not actor.is_queued_for_deletion():
		ataque_realizado.emit(
			actor,
			objetivo,
			danio_real
		)
		print(
			"CombatSystem: ",
			actor.name,
			" atacó a ",
			objetivo.name,
			" con ",
			origen,
			" por ",
			danio_real,
			" de daño efectivo (base: ",
			danio,
			")."
		)
	return true


## Daño solicitado por sistemas de gameplay
##
## API de coordinación para IA e IUM. CombatDamage sigue siendo el único
## resolver autorizado que aplica daño a Entity; los proyectiles usan ese
## mismo resolver desde su ejecución de impacto.
func solicitar_danio_desde_entidad(
	atacante: Node,
	objetivo: Entity,
	danio: int,
	origen: String = "CombatSystem/Entidad"
) -> CombatAttackResult:
	if not CombatTargeting.es_atacante_valido(atacante):
		return COMBAT_ATTACK_RESULT.rechazado(&"atacante_invalido")
	if (
		objetivo == null
		or not is_instance_valid(objetivo)
		or not objetivo.is_inside_tree()
		or objetivo.is_queued_for_deletion()
	):
		return COMBAT_ATTACK_RESULT.rechazado(&"objetivo_invalido")
	if not objetivo.is_in_group("damageable"):
		return COMBAT_ATTACK_RESULT.rechazado(&"objetivo_no_daniable")
	if not objetivo.is_alive:
		return COMBAT_ATTACK_RESULT.rechazado(&"objetivo_derrotado")
	if not CombatTargeting.es_objetivo_valido(atacante, objetivo):
		return COMBAT_ATTACK_RESULT.rechazado(&"objetivo_no_daniable")

	# La IA llama esta API después de confirmar su contacto. El evento se
	# registra incluso si el daño resultante es cero.
	contacto_efectivo.emit(atacante, objetivo, origen)

	# El contacto emite señales síncronas: sus listeners pueden derrotar al
	# atacante o al objetivo antes de que esta solicitud aplique daño.
	if not CombatTargeting.es_objetivo_valido(atacante, objetivo):
		return COMBAT_ATTACK_RESULT.aceptado(true, false)
	if danio <= 0:
		return COMBAT_ATTACK_RESULT.aceptado(true, false)

	var danio_real := CombatDamage.aplicar_y_obtener_danio(
		objetivo,
		danio,
		origen,
		Callable(),
		atacante
	)
	if danio_real <= 0:
		return COMBAT_ATTACK_RESULT.aceptado(true, false)

	COMBAT_IMPACT_EFFECTS.procesar_impacto_confirmado(
		game_state,
		player,
		atacante,
		objetivo,
		danio_real
	)

	# Robo de vida: usa el daño efectivo devuelto por esta invocación,
	# no la diferencia global de salud, que puede incluir daño reentrante.
	if is_instance_valid(atacante) and not atacante.is_queued_for_deletion() and atacante is Creature:
		var criatura_atacante := atacante as Creature
		if criatura_atacante.get_nombre().strip_edges().to_lower() == "vampiro":
			var config_ia := criatura_atacante.obtener_config_ia()
			var combate_variant: Variant = config_ia.get("combate", {})
			if combate_variant is Dictionary:
				var robo_variant: Variant = (combate_variant as Dictionary).get("robo_vida", {})
				if robo_variant is Dictionary and bool((robo_variant as Dictionary).get("activo", false)):
					var fraccion: float = float((robo_variant as Dictionary).get("fraccion_curacion", 0.5))
					if fraccion > 0.0:
						var curacion := maxi(1, int(ceil(float(danio_real) * clampf(fraccion, 0.0, 1.0))))
						criatura_atacante.heal(curacion)

	if is_instance_valid(atacante) and not atacante.is_queued_for_deletion():
		ataque_realizado.emit(atacante, objetivo, danio_real)
	return COMBAT_ATTACK_RESULT.aceptado(true, true)


## Compatibilidad: el booleano histórico indica que hubo reducción real de salud.
func aplicar_danio_desde_entidad(
	atacante: Node,
	objetivo: Entity,
	danio: int,
	origen: String = "CombatSystem/Entidad"
) -> bool:
	var resultado := solicitar_danio_desde_entidad(
		atacante,
		objetivo,
		danio,
		origen
	)
	return resultado.danio_aplicado


func _iniciar_cooldown_ataque() -> void:
	_tiempo_desde_ataque = maxf(enfriamiento_arma, 0.0)


func _normalizar_direccion_ataque(direccion: Vector2) -> Vector2:
	if direccion.length_squared() > 0.01:
		return direccion.normalized()
	return _obtener_direccion_ataque()


func _obtener_direccion_ataque() -> Vector2:
	if player == null:
		return Vector2.DOWN

	var facing_variant: Variant = player.get("facing")
	if facing_variant is Vector2:
		var direccion: Vector2 = facing_variant
		if direccion.length_squared() > 0.01:
			return direccion.normalized()

	return Vector2.DOWN
