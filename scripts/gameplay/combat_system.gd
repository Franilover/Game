extends Node
class_name CombatSystem


signal ataque_realizado(atacante: Node, objetivo: Entity, danio: int)
signal ataque_sin_objetivo(atacante: Node)
signal accion_contextual_solicitada(objeto: Dictionary, usuario: Node)


const COMBAT_ATTACK_AREA_SCRIPT: Script = preload(
	"res://scripts/gameplay/combat/combat_attack_area.gd"
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
var inventory: GarliaInventory = null
var world_context: WorldContext = null
var projectile_root: Node = null
var game_state: GameStateService = null
var _inventory_equipment_slot: String = "mano_secundaria"
var combat_controller := CombatController.new()
var _tiempo_desde_ataque: float = 0.0


func configurar(nuevo_player: Player, nuevo_inventory: GarliaInventory = null, nuevo_world_context: WorldContext = null, nuevo_projectile_root: Node = null, nuevo_game_state: GameStateService = null) -> void:
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
	var objeto_equipado := _obtener_objeto_equipado_para_accion()
	var modo := "arma_equipada" if _es_objeto_ataque(objeto_equipado) else "desarmado"

	return combat_controller.solicitar_ataque(
		_obtener_direccion_ataque(),
		objeto_equipado,
		modo
	)


func procesar_accion_secundaria() -> bool:
	if player == null or not player.is_alive:
		return false

	var arma := _obtener_arma_equipada()
	if arma.is_empty():
		return false

	return combat_controller.solicitar_ataque(
		_obtener_direccion_ataque(),
		arma,
		"mano_secundaria"
	)


func _al_ataque_solicitado(
	_direccion: Vector2,
	objeto: Dictionary,
	modo: String
) -> void:
	if player == null or _tiempo_desde_ataque > 0.0:
		return

	if modo == "desarmado":
		_atacar_desarmado()
		return

	if modo == "arma_equipada":
		if not _es_objeto_ataque(objeto):
			return
		_atacar_con_objeto(objeto)
		return

	if modo == "mano_secundaria":
		if not _es_arma(objeto):
			return
		_atacar_con_arma(objeto)


func _es_herramienta(objeto: Dictionary) -> bool:
	var tipo: String = str(objeto.get("tipo", "")).strip_edges().to_lower()
	return tipo == "herramienta"


func _es_objeto_ataque(objeto: Dictionary) -> bool:
	return _es_arma(objeto) or _es_herramienta(objeto)


func _atacar_con_objeto(objeto: Dictionary) -> void:
	if objeto.is_empty():
		return

	var tipo: String = str(objeto.get("tipo", "")).strip_edges().to_lower()
	if tipo == "herramienta":
		_atacar_con_herramienta(objeto)
		return

	_atacar_con_arma(objeto)


func _atacar_con_herramienta(herramienta: Dictionary) -> void:
	var propiedades_variant: Variant = herramienta.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant as Dictionary if propiedades_variant is Dictionary else {}
	var recoleccion_variant: Variant = propiedades.get("herramienta_recoleccion", {})
	var recoleccion: Dictionary = recoleccion_variant as Dictionary if recoleccion_variant is Dictionary else {}
	var tipo_herramienta := str(recoleccion.get("tipo", "")).strip_edges().to_lower()

	if tipo_herramienta == "pala":
		if _usar_pala():
			_consumir_durabilidad_herramienta()
		return

	var direccion: Vector2 = _obtener_direccion_ataque()
	var alcance: float = _obtener_alcance_arma(herramienta)
	var ancho: float = _obtener_ancho_arma(herramienta)

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


func _consumir_durabilidad_herramienta() -> void:
	if inventory == null:
		return
	inventory.consumir_durabilidad_equipo(_inventory_equipment_slot)


func _crear_ataque_melee(
	direccion: Vector2,
	alcance: float,
	ancho: float,
	objeto: Dictionary,
	danio_directo: int = -1
) -> void:
	if player == null:
		return

	var ataque := CombatAttackArea.new()
	ataque.configurar(
		player,
		direccion,
		alcance,
		ancho,
		objeto,
		duracion_ataque,
		color_ataque
	)

	if danio_directo >= 0:
		var objeto_ataque_variant: Variant = ataque.get("objeto_ataque")
		if objeto_ataque_variant is Dictionary:
			var objeto_ataque: Dictionary = objeto_ataque_variant as Dictionary
			objeto_ataque["_damage_override"] = danio_directo
			ataque.set("objeto_ataque", objeto_ataque)

	ataque.connect(
		"objetivo_detectado",
		_al_recibir_objetivo_de_ataque.bind(ataque)
	)

	player.add_child(ataque)
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

	# Compatibilidad para llamadas internas: este método representa
	# exclusivamente el objeto seleccionado en la hotbar.
	var objeto_activo := _obtener_objeto_equipado_para_accion()

	if objeto_activo.is_empty():
		return

	if not _es_objeto_ataque(objeto_activo):
		return

	_atacar_con_objeto(objeto_activo)


func _obtener_objeto_equipado_para_accion() -> Dictionary:
	if inventory == null:
		return {}

	var equipo_variant: Variant = inventory.obtener_equipamiento()
	if not equipo_variant is Dictionary:
		return {}
	var equipo := equipo_variant as Dictionary

	for clave_variant in ["mano_principal", "mano_secundaria"]:
		var clave := str(clave_variant)
		var candidato_variant: Variant = equipo.get(clave, {})
		if candidato_variant is Dictionary and _es_objeto_ataque(candidato_variant as Dictionary):
			_inventory_equipment_slot = clave
			return (candidato_variant as Dictionary).duplicate(true)

	for clave_variant in equipo.keys():
		var clave := str(clave_variant)
		var candidato_variant: Variant = equipo.get(clave, {})
		if candidato_variant is Dictionary and _es_objeto_ataque(candidato_variant as Dictionary):
			_inventory_equipment_slot = clave
			return (candidato_variant as Dictionary).duplicate(true)

	return {}


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


func _es_arma(
	objeto: Dictionary
) -> bool:
	var tipo: String = str(
		objeto.get(
			"tipo",
			""
		)
	).strip_edges().to_lower()

	if tipo == "arma":
		return true

	# Compatibilidad con partidas antiguas.
	if bool(objeto.get("es_arma", false)):
		return true

	var categoria: String = str(
		objeto.get(
			"categoria",
			""
		)
	).strip_edges().to_lower()

	return "arma" in categoria


func _atacar_desarmado() -> void:
	var direccion: Vector2 = _obtener_direccion_ataque()
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
	arma: Dictionary
) -> void:
	var direccion: Vector2 = (
		_obtener_direccion_ataque()
	)

	var modo: String = (
		_obtener_modo_ataque(arma)
	)

	_tiempo_desde_ataque = enfriamiento_arma

	if modo == "distancia":
		_disparar_proyectil(
			arma,
			direccion
		)
		return

	var alcance: float = _obtener_alcance_arma(
		arma
	)

	var ancho: float = _obtener_ancho_arma(
		arma
	)

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

	var raiz_proyectiles: Node = projectile_root
	if raiz_proyectiles == null or not is_instance_valid(raiz_proyectiles):
		return

	var velocidad: float = _obtener_float_propiedad(
		arma,
		"velocidad_proyectil",
		velocidad_proyectil
	)
	var vida: float = _obtener_float_propiedad(
		arma,
		"vida_proyectil",
		vida_proyectil
	)
	var radio: float = _obtener_float_propiedad(
		arma,
		"radio_impacto",
		radio_impacto_proyectil
	)
	var danio: int = _obtener_danio_arma(arma)

	var ataque := CombatAttack.new()
	ataque.configurar(
		player,
		direccion,
		arma,
		"distancia",
		danio,
		"Jugador/Proyectil:" + str(arma.get("nombre", "Proyectil"))
	)

	var proyectil := CombatProjectile.new()
	raiz_proyectiles.add_child(proyectil)
	proyectil.global_position = player.global_position + direccion * 14.0

	proyectil.configurar(
		ataque,
		direccion,
		velocidad,
		vida,
		radio
	)

	if proyectil.has_signal("objetivo_impactado"):
		proyectil.connect(
			"objetivo_impactado",
			_al_recibir_impacto_proyectil
		)

	print(
		"CombatSystem: proyectil disparado → ",
		str(arma.get("nombre", "Arma"))
	)

func _al_recibir_impacto_proyectil(
	objetivo: Entity,
	ataque: CombatAttack
) -> void:
	if objetivo == null or ataque == null:
		return

	var arma := ataque.object_data

	if (
		not arma.is_empty()
		and objetivo.is_in_group("creatures")
		and not objetivo.is_alive
		and ataque.attacker != null
		and ataque.attacker.is_in_group("player")
	):
		_registrar_criatura_derrotada(objetivo)

	if (
		not arma.is_empty()
		and objetivo.is_in_group("creatures")
		and objetivo.is_alive
		and _obtener_ai_controller(objetivo) != null
	):
		var ai: CreatureAI = _obtener_ai_controller(objetivo)
		if ai != null:
			ai.al_recibir_ataque_con_arma(arma)

	CombatFeedback.impacto(objetivo, ataque.damage)
	ataque_realizado.emit(ataque.attacker, objetivo, ataque.damage)


func _obtener_ai_controller(objetivo: Node) -> CreatureAI:
	if objetivo == null or not is_instance_valid(objetivo):
		return null
	return objetivo.get_node_or_null("AIController") as CreatureAI


func _obtener_modo_ataque(
	arma: Dictionary
) -> String:
	var tipo_objeto_variant: Variant = arma.get(
		"tipo_objeto",
		{}
	)

	if not tipo_objeto_variant is Dictionary:
		return "cuerpo"

	var tipo_objeto := tipo_objeto_variant as Dictionary

	var plantilla_variant: Variant = tipo_objeto.get(
		"plantilla",
		{}
	)

	if not plantilla_variant is Dictionary:
		return "cuerpo"

	var plantilla := plantilla_variant as Dictionary
	var categoria_item: String = str(
		plantilla.get(
			"categoria",
			""
		)
	).strip_edges().to_lower()

	if categoria_item == "arma_distancia":
		return "distancia"

	if categoria_item.begins_with("arma_"):
		return "cuerpo"

	return "cuerpo"


func atacar_objetivo_con_arma(
	atacante: Node,
	objetivo: Entity,
	arma: Dictionary
) -> bool:
	if atacante == null or not is_instance_valid(atacante):
		return false

	if objetivo == null or not is_instance_valid(objetivo):
		return false

	if arma.is_empty() or not _es_arma(arma):
		return false

	var danio: int = _obtener_danio_arma(arma)

	_aplicar_danio(
		objetivo,
		danio,
		str(arma.get("nombre", "Arma")),
		atacante,
		arma
	)

	return true


func obtener_alcance_arma(
	arma: Dictionary
) -> float:
	return _obtener_alcance_arma(arma)


func _obtener_danio_arma(
	arma: Dictionary
) -> int:
	var propiedades: Dictionary = (
		_obtener_propiedades_game(
			arma
		)
	)

	var danio_variant: Variant = propiedades.get(
		"danio",
		null
	)

	if danio_variant is int or danio_variant is float:
		return maxi(
			0,
			int(danio_variant)
		)

	return maxi(
		0,
		danio_arma_defecto
	)


func _obtener_alcance_arma(
	arma: Dictionary
) -> float:
	return _obtener_float_propiedad(
		arma,
		"alcance",
		alcance_arma
	)


func _obtener_ancho_arma(
	arma: Dictionary
) -> float:
	return _obtener_float_propiedad(
		arma,
		"ancho_ataque",
		ancho_arma
	)


func _obtener_float_propiedad(
	arma: Dictionary,
	nombre: String,
	valor_por_defecto: float
) -> float:
	var propiedades: Dictionary = (
		_obtener_propiedades_game(
			arma
		)
	)

	var valor: Variant = (
		propiedades.get(
			nombre,
			valor_por_defecto
		)
	)

	if valor is int or valor is float:
		return maxf(
			0.0,
			float(valor)
		)

	return valor_por_defecto


func _obtener_propiedades_game(
	objeto: Dictionary
) -> Dictionary:
	var propiedades_variant: Variant = (
		objeto.get(
			"propiedades_game",
			{}
		)
	)

	if propiedades_variant is Dictionary:
		return (
			propiedades_variant as Dictionary
		)

	return {}


func _aplicar_danio(
	objetivo: Entity,
	danio: int,
	origen: String,
	atacante: Node = null,
	arma: Dictionary = {}
) -> void:
	if not is_instance_valid(objetivo):
		return

	var vivo_antes: bool = objetivo.is_alive

	var aplicado := CombatDamage.aplicar(
		objetivo,
		danio,
		"Jugador/CombatSystem:" + origen
	)
	if not aplicado:
		return

	if (
		vivo_antes
		and not objetivo.is_alive
		and objetivo.is_in_group("creatures")
	):
		_registrar_criatura_derrotada(objetivo)

		var actor_eterium: Player = atacante as Player
		if actor_eterium == null:
			actor_eterium = player

		if actor_eterium != null and is_instance_valid(actor_eterium):
			actor_eterium.absorber_eterium_de_criatura(objetivo)

	if (
		not arma.is_empty()
		and objetivo.is_in_group("creatures")
		and objetivo.is_alive
		and objetivo.has_node("AIController")
	):
		var ai: CreatureAI = _obtener_ai_controller(objetivo)

		if ai != null:
			ai.al_recibir_ataque_con_arma(arma)

	CombatFeedback.impacto(objetivo, danio)

	var actor: Node = atacante

	if actor == null:
		actor = player

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


func _registrar_criatura_derrotada(objetivo: Entity) -> void:
	if game_state == null or not is_instance_valid(game_state):
		return
	game_state.registrar_criatura_derrotada(objetivo)


func _obtener_direccion_ataque() -> Vector2:
	if player == null:
		return Vector2.DOWN

	var direccion: Vector2 = player.facing
	if direccion.length_squared() > 0.01:
		return direccion.normalized()

	return Vector2.DOWN


