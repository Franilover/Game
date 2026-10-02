extends Node


signal ataque_realizado(atacante: Node, objetivo: Node, danio: int)
signal ataque_sin_objetivo(atacante: Node)
signal accion_contextual_solicitada(objeto: Dictionary, usuario: Node)


const PROJECTILE_SCRIPT: Script = preload(
	"res://scripts/systems/combat_projectile.gd"
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
@export var duracion_ataque: float = 0.12
@export var color_ataque: Color = Color(0.86, 0.74, 0.52, 0.65)

var player: Node = null
var _tiempo_desde_ataque: float = 0.0


func configurar(nuevo_player: Node) -> void:
	player = nuevo_player

	print(
		"CombatSystem: configurado."
	)


func _process(delta: float) -> void:
	_tiempo_desde_ataque = maxf(
		_tiempo_desde_ataque - delta,
		0.0
	)


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return

	if not event.is_action_pressed("primary_action"):
		return

	if _tiempo_desde_ataque > 0.0:
		return

	usar_objeto_activo()

	get_viewport().set_input_as_handled()


func usar_objeto_activo() -> void:
	if player == null:
		return

	var objeto_activo: Dictionary = (
		_obtener_objeto_activo()
	)

	if objeto_activo.is_empty():
		_atacar_desarmado()
		return

	if _es_arma(objeto_activo):
		_atacar_con_arma(objeto_activo)
		return

	accion_contextual_solicitada.emit(
		objeto_activo,
		player
	)

	print(
		"CombatSystem: usar objeto → ",
		str(
			objeto_activo.get(
				"nombre",
				"Objeto"
			)
		)
	)


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


func _obtener_objeto_activo() -> Dictionary:
	var inventario := get_tree().get_first_node_in_group(
		"inventory"
	)

	if inventario == null:
		return {}

	if not inventario.has_method(
		"obtener_objeto_activo"
	):
		return {}

	var objeto: Variant = inventario.call(
		"obtener_objeto_activo"
	)

	if objeto is Dictionary:
		return objeto as Dictionary

	return {}


func _atacar_desarmado() -> void:
	var direccion: Vector2 = (
		_obtener_direccion_ataque()
	)

	var objetivo: Node = _buscar_objetivo(
		direccion,
		alcance_desarmado,
		ancho_ataque
	)

	_mostrar_area_ataque(
		direccion,
		alcance_desarmado,
		ancho_ataque
	)

	_tiempo_desde_ataque = enfriamiento_arma

	if objetivo == null:
		ataque_sin_objetivo.emit(
			player
		)
		return

	_aplicar_danio(
		objetivo,
		danio_desarmado,
		"desarmado"
	)


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

	var objetivo: Node = _buscar_objetivo(
		direccion,
		alcance,
		ancho
	)

	_mostrar_area_ataque(
		direccion,
		alcance,
		ancho
	)

	if objetivo == null:
		ataque_sin_objetivo.emit(
			player
		)

		print(
			"CombatSystem: ataque sin objetivo → ",
			str(
				arma.get(
					"nombre",
					"Arma"
				)
			)
		)

		return

	var danio: int = _obtener_danio_arma(
		arma
	)

	_aplicar_danio(
		objetivo,
		danio,
		str(
			arma.get(
				"nombre",
				"Arma"
			)
		)
	)


func _disparar_proyectil(
	arma: Dictionary,
	direccion: Vector2
) -> void:
	if player == null:
		return

	var escena_actual := get_tree().current_scene

	if escena_actual == null:
		return

	var proyectil := Node2D.new()

	proyectil.set_script(
		PROJECTILE_SCRIPT
	)

	escena_actual.add_child(
		proyectil
	)

	proyectil.global_position = (
		player.global_position
		+ direccion * 14.0
	)

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

	var danio: int = _obtener_danio_arma(
		arma
	)

	proyectil.call(
		"configurar",
		direccion,
		velocidad,
		vida,
		radio,
		danio,
		player
	)

	print(
		"CombatSystem: proyectil disparado → ",
		str(
			arma.get(
				"nombre",
				"Arma"
			)
		)
	)


func _obtener_modo_ataque(
	arma: Dictionary
) -> String:
	var propiedades: Dictionary = (
		_obtener_propiedades_game(
			arma
		)
	)

	var modo_variant: Variant = (
		propiedades.get(
			"modo_ataque",
			propiedades.get(
				"tipo_ataque",
				""
			)
		)
	)

	if modo_variant is String:
		var modo: String = (
			modo_variant as String
		).strip_edges().to_lower()

		if (
			modo == "distancia"
			or modo == "rango"
			or modo == "proyectil"
			or modo == "a distancia"
		):
			return "distancia"

		if modo == "cuerpo" or modo == "melee":
			return "cuerpo"

	var nombre: String = str(
		arma.get(
			"nombre",
			""
		)
	).to_lower()

	var descripcion: String = str(
		arma.get(
			"descripcion",
			""
		)
	).to_lower()

	var geometria: String = ""

	var geometria_variant: Variant = (
		arma.get(
			"geometria_fisica",
			{}
		)
	)

	if geometria_variant is Dictionary:
		geometria = str(
			(geometria_variant as Dictionary).get(
				"forma",
				""
			)
		).to_lower()

	var texto: String = (
		nombre
		+ " "
		+ descripcion
		+ " "
		+ geometria
	)

	# La clasificación se deriva del propio objeto canónico.
	# No existe una lista de armas específica en el código.
	if (
		"proyectil" in texto
		or "flecha" in texto
		or "dispar" in texto
		or "a distancia" in texto
		or "arco" in texto
	):
		return "distancia"

	return "cuerpo"


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
	objetivo: Node,
	danio: int,
	origen: String
) -> void:
	if not is_instance_valid(objetivo):
		return

	if not objetivo.has_method(
		"take_damage"
	):
		return

	objetivo.call(
		"take_damage",
		danio
	)

	_animar_objetivo(
		objetivo
	)

	ataque_realizado.emit(
		player,
		objetivo,
		danio
	)

	print(
		"CombatSystem: ",
		player.name,
		" atacó a ",
		objetivo.name,
		" con ",
		origen,
		" por ",
		danio,
		" de daño."
	)


func _obtener_direccion_ataque() -> Vector2:
	if player == null:
		return Vector2.DOWN

	if "facing" in player:
		var direccion: Vector2 = player.facing

		if direccion.length_squared() > 0.01:
			return direccion.normalized()

	return Vector2.DOWN


func _buscar_objetivo(
	direccion: Vector2,
	alcance: float,
	ancho: float
) -> Node:
	var mejor_objetivo: Node = null
	var mejor_distancia: float = INF

	var candidatos: Array[Node] = (
		get_tree().get_nodes_in_group(
			"damageable"
		)
	)

	var lado_medio: float = (
		ancho * 0.5
	)

	for candidato in candidatos:
		if not is_instance_valid(candidato):
			continue

		if candidato == player:
			continue

		if not candidato is Node2D:
			continue

		if not candidato.is_inside_tree():
			continue

		if "is_alive" in candidato:
			if not bool(candidato.is_alive):
				continue

		var candidato_2d: Node2D = (
			candidato as Node2D
		)

		var relativo: Vector2 = (
			candidato_2d.global_position
			- player.global_position
		)

		var frente: float = (
			relativo.dot(direccion)
		)

		var lateral: float = abs(
			relativo.cross(direccion)
		)

		var inicio: float = 8.0
		var final: float = (
			inicio
			+ alcance
		)

		if frente < inicio:
			continue

		if frente > final:
			continue

		if lateral > lado_medio:
			continue

		var distancia: float = (
			relativo.length()
		)

		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor_objetivo = candidato

	return mejor_objetivo


func _mostrar_area_ataque(
	direccion: Vector2,
	alcance: float,
	ancho: float
) -> void:
	if player == null:
		return

	var area_visual := Polygon2D.new()

	var mitad: float = (
		ancho * 0.5
	)

	var inicio: float = 8.0

	var final: float = (
		inicio
		+ alcance
	)

	area_visual.polygon = PackedVector2Array([
		Vector2(
			inicio,
			-mitad
		),
		Vector2(
			final,
			-mitad
		),
		Vector2(
			final,
			mitad
		),
		Vector2(
			inicio,
			mitad
		)
	])

	area_visual.color = color_ataque
	area_visual.z_index = 100

	var escena_actual := (
		get_tree().current_scene
	)

	if escena_actual == null:
		area_visual.queue_free()
		return

	escena_actual.add_child(
		area_visual
	)

	area_visual.global_position = (
		player.global_position
	)

	area_visual.rotation = (
		direccion.angle()
	)

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		area_visual,
		"modulate:a",
		0.0,
		duracion_ataque
	)

	tween.tween_property(
		area_visual,
		"scale",
		Vector2(
			1.08,
			1.08
		),
		duracion_ataque
	)

	tween.chain().tween_callback(
		area_visual.queue_free
	)


func _animar_objetivo(
	objetivo: Node
) -> void:
	if not objetivo is CanvasItem:
		return

	var objetivo_visual := (
		objetivo as CanvasItem
	)

	var modulate_original: Color = (
		objetivo_visual.modulate
	)

	var tween := create_tween()

	tween.tween_property(
		objetivo_visual,
		"modulate",
		Color(
			1.0,
			0.45,
			0.45,
			modulate_original.a
		),
		0.04
	)

	tween.tween_property(
		objetivo_visual,
		"modulate",
		modulate_original,
		0.08
	)
