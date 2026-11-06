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

var player: Player = null
var inventory: InventoryController = null
var world_context: WorldContext = null
var projectile_root: Node = null
var game_state: GameStateService = null
var _inventory_equipment_slot: String = "mano_secundaria"
var _accion_en_mano_derecha: bool = false
var combat_controller := CombatController.new()
var _tiempo_desde_ataque: float = 0.0


func configurar(nuevo_player: Player, nuevo_inventory: InventoryController = null, nuevo_world_context: WorldContext = null, nuevo_projectile_root: Node = null, nuevo_game_state: GameStateService = null) -> void:
	player = nuevo_player
	inventory = nuevo_inventory
	world_context = nuevo_world_context
	projectile_root = nuevo_projectile_root
	game_state = nuevo_game_state
	if not is_instance_valid(combat_controller):
		combat_controller = CombatController.new()
	if not combat_controller.is_inside_tree():
		add_child(combat_controller)
	combat_controller.configurar_gate(player.input_gate)

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
	if player == null or not player.is_alive:
		return false

	# El router ya resolvió la prioridad de interacción.
	# Aquí solo se decide la acción primaria de combate.
	var objeto_activo: Dictionary = inventory.obtener_objeto_mano_activa("izquierda") if inventory != null else {}
	_accion_en_mano_derecha = false
	var modo := "arma_equipada" if _es_objeto_ataque(objeto_activo) else "desarmado"

	return combat_controller.solicitar_ataque(
		_obtener_direccion_ataque(),
		objeto_activo,
		modo
	)


func procesar_accion_secundaria() -> bool:
	if player == null or not player.is_alive:
		return false

	var objeto_equipado := _obtener_objeto_equipado_para_accion()
	_accion_en_mano_derecha = true
	if objeto_equipado.is_empty():
		return false

	var modo := "arma_equipada" if _es_objeto_ataque(objeto_equipado) else "desarmado"
	return combat_controller.solicitar_ataque(
		_obtener_direccion_ataque(),
		objeto_equipado,
		modo
	)


func _al_ataque_solicitado(
	direccion: Vector2,
	objeto: Dictionary,
	modo: String
) -> void:
	if player == null or _tiempo_desde_ataque > 0.0:
		return

	var direccion_ataque := _normalizar_direccion_ataque(direccion)

	if modo == "desarmado":
		_atacar_desarmado(direccion_ataque)
		return

	if modo == "arma_equipada":
		if not _es_objeto_ataque(objeto):
			return
		_atacar_con_objeto(objeto, direccion_ataque)
		return

	if modo == "mano_secundaria":
		if not _es_arma(objeto):
			return
		_atacar_con_arma(objeto, direccion_ataque)

func _es_herramienta(objeto: Dictionary) -> bool:
	return COMBAT_ITEM_RESOLVER.es_herramienta(objeto)

func _es_objeto_ataque(objeto: Dictionary) -> bool:
	return COMBAT_ITEM_RESOLVER.es_objeto_ataque(objeto)

func _atacar_con_objeto(objeto: Dictionary, direccion: Vector2) -> void:
	if objeto.is_empty():
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
			_consumir_durabilidad_herramienta()
		return

	var alcance := _obtener_alcance_arma(herramienta)
	var ancho := _obtener_ancho_arma(herramienta)
	_crear_ataque_melee(
		direccion,
		alcance,
		ancho,
		herramienta
	)
	_consumir_durabilidad_herramienta()

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
		_tiempo_desde_ataque = enfriamiento_arma
		print("CombatSystem: pala → Pradera convertida en Tierra en ", tile)
		return true

	return false


func _consumir_durabilidad_herramienta(en_equipo: bool = false) -> void:
	if inventory == null:
		return
	if en_equipo:
		inventory.consumir_durabilidad_equipo(_inventory_equipment_slot)
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
	if player == null:
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

	var objeto := ataque.objeto_ataque
	var entidad_objetivo := objetivo as Entity
	if entidad_objetivo == null:
		return
	contacto_efectivo.emit(
		player,
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
		player,
		objeto
	)

func usar_objeto_activo() -> void:
	if player == null:
		return

	var objeto_activo := _obtener_objeto_activo_para_accion()
	if objeto_activo.is_empty() or not _es_objeto_ataque(objeto_activo):
		return
	_atacar_con_objeto(objeto_activo, _obtener_direccion_ataque())


func _obtener_objeto_activo_para_accion() -> Dictionary:
	if inventory == null:
		return {}
	# El ataque primario usa el objeto activo de la mano derecha.
	return inventory.obtener_objeto_mano_activa("derecha")


func _obtener_objeto_equipado_para_accion() -> Dictionary:
	if inventory == null:
		return {}
	# El clic derecho usa el objeto activo de la mano derecha.
	return inventory.obtener_objeto_mano_activa("derecha")


func _obtener_arma_equipada(slot_preferido: String = "mano_principal") -> Dictionary:
	if inventory == null:
		return {}

	var equipo_variant: Variant = inventory.obtener_equipamiento()
	if not equipo_variant is Dictionary:
		return {}
	var equipo := equipo_variant as Dictionary

	var preferida_variant: Variant = equipo.get(slot_preferido, {})
	if preferida_variant is Dictionary and _es_arma(preferida_variant as Dictionary):
		_inventory_equipment_slot = slot_preferido
		return (preferida_variant as Dictionary).duplicate(true)

	for clave_variant in ["mano_principal", "mano_secundaria"]:
		var clave := str(clave_variant)
		var candidato_variant: Variant = equipo.get(clave, {})
		if candidato_variant is Dictionary and _es_arma(candidato_variant as Dictionary):
			_inventory_equipment_slot = clave
			return (candidato_variant as Dictionary).duplicate(true)

	for clave_variant in equipo.keys():
		var clave := str(clave_variant)
		var candidato_variant: Variant = equipo.get(clave, {})
		if candidato_variant is Dictionary and _es_arma(candidato_variant as Dictionary):
			_inventory_equipment_slot = clave
			return (candidato_variant as Dictionary).duplicate(true)

	return {}


func _es_arma(objeto: Dictionary) -> bool:
	return COMBAT_ITEM_RESOLVER.es_arma(objeto)

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

	_tiempo_desde_ataque = enfriamiento_arma

func _atacar_con_arma(
	arma: Dictionary,
	direccion: Vector2
) -> void:
	var modo := _obtener_modo_ataque(arma)
	_tiempo_desde_ataque = enfriamiento_arma

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

func _disparar_proyectil(
	arma: Dictionary,
	direccion: Vector2
) -> void:
	if player == null:
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
	if ataque == null:
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
	if objetivo == null or ataque == null:
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
	if objetivo == null or not is_instance_valid(objetivo):
		return false

	var aplicado := CombatDamage.aplicar(
		objetivo,
		danio,
		"Jugador/CombatSystem:" + origen,
		Callable(),
		atacante
	)
	if not aplicado:
		return false

	var actor: Node = atacante
	if actor == null:
		actor = player

	COMBAT_IMPACT_EFFECTS.procesar_impacto_confirmado(
		game_state,
		player,
		actor,
		objetivo,
		danio,
		arma
	)

	ataque_realizado.emit(
		actor,
		objetivo,
		danio
	)

	print(
		"CombatSystem: ",
		actor.name,
		" atacó a ",
		objetivo.name,
		" con ",
		origen,
		" por ",
		danio,
		" de daño."
	)
	return true


## Daño genérico de entidades
##
## CombatSystem es el único punto de aplicación de daño del gameplay.
## Las IA deciden cuándo atacar, pero no modifican directamente la salud.
func solicitar_danio_desde_entidad(
	atacante: Node,
	objetivo: Entity,
	danio: int,
	origen: String = "CombatSystem/Entidad"
) -> CombatAttackResult:
	if atacante == null or not is_instance_valid(atacante):
		return COMBAT_ATTACK_RESULT.rechazado(&"atacante_invalido")
	if objetivo == null or not is_instance_valid(objetivo):
		return COMBAT_ATTACK_RESULT.rechazado(&"objetivo_invalido")
	if not objetivo.is_alive:
		return COMBAT_ATTACK_RESULT.rechazado(&"objetivo_derrotado")

	# La IA llama esta API después de confirmar su contacto. El evento se
	# registra incluso si el daño resultante es cero.
	contacto_efectivo.emit(atacante, objetivo, origen)
	if danio <= 0:
		return COMBAT_ATTACK_RESULT.aceptado(true, false)

	var salud_objetivo_antes: int = objetivo.health
	var aplicado := CombatDamage.aplicar(
		objetivo,
		danio,
		origen,
		Callable(),
		atacante
	)
	if not aplicado:
		return COMBAT_ATTACK_RESULT.aceptado(true, false)

	COMBAT_IMPACT_EFFECTS.procesar_impacto_confirmado(
		game_state,
		player,
		atacante,
		objetivo,
		danio
	)

	# Robo de vida canónico: sólo cura al vampiro que acaba de infligir
	# daño real; CombatDamage ya confirmó que la salud del objetivo bajó.
	if atacante is Creature:
		var criatura_atacante := atacante as Creature
		if criatura_atacante.get_nombre().strip_edges().to_lower() == "vampiro":
			var config_ia := criatura_atacante.obtener_config_ia()
			var combate_variant: Variant = config_ia.get("combate", {})
			if combate_variant is Dictionary:
				var robo_variant: Variant = (combate_variant as Dictionary).get("robo_vida", {})
				if robo_variant is Dictionary and bool((robo_variant as Dictionary).get("activo", false)):
					var fraccion: float = float((robo_variant as Dictionary).get("fraccion_curacion", 0.5))
					var danio_real := maxi(salud_objetivo_antes - objetivo.health, 0)
					if fraccion > 0.0 and danio_real > 0:
						var curacion := maxi(1, int(ceil(float(danio_real) * clampf(fraccion, 0.0, 1.0))))
						criatura_atacante.heal(curacion)

	ataque_realizado.emit(atacante, objetivo, danio)
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


func _normalizar_direccion_ataque(direccion: Vector2) -> Vector2:
	if direccion.length_squared() > 0.01:
		return direccion.normalized()
	return _obtener_direccion_ataque()


func _obtener_direccion_ataque() -> Vector2:
	if player == null:
		return Vector2.DOWN

	var direccion: Vector2 = player.facing
	if direccion.length_squared() > 0.01:
		return direccion.normalized()

	return Vector2.DOWN
