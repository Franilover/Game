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

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()

	add_to_group("interactable")

	_rng.seed = abs(
		hash(str(get_instance_id()))
	) + 1

	_crear_movimiento()

	queue_redraw()


func _crear_movimiento() -> void:
	# Usamos el nodo que existe físicamente en creature.tscn.
	_movimiento = get_node_or_null(
		"CreatureMovement"
	) as CreatureMovement

	# Respaldo por si alguna criatura se crea desde otra escena
	# que todavía no tenga el nodo.
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

	var stats_variant: Variant = (
		datos_criatura.get(
			"stats_dnd",
			{}
		)
	)

	if stats_variant is Dictionary:
		stats_dnd = stats_variant
	else:
		stats_dnd = {}

	var hp_variant: Variant = (
		stats_dnd.get(
			"hp_max",
			null
		)
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
	queue_redraw()


func _cargar_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var ruta := "res://assets/art/creatures/" + criatura_nombre + ".png"

	if ResourceLoader.exists(ruta):
		sprite.texture = load(ruta)
	else:
		sprite.texture = null
		# Sin sprite → _draw() mostrará los círculos de debug


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


func get_id() -> String:
	return criatura_id


func get_datos() -> Dictionary:
	return datos


func get_stats_dnd() -> Dictionary:
	return stats_dnd


# ============================================================
# MOVIMIENTO
# ============================================================

func _physics_process(delta: float) -> void:
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


# ============================================================
# INTERACCIÓN
# ============================================================

func can_interact(
	_actor: Node
) -> bool:
	return is_alive


func get_interaction_text() -> String:
	return "Examinar"


func interact(
	_actor: Node
) -> void:
	print(
		"Interacción con criatura: ",
		criatura_nombre,
		" | id=",
		criatura_id
	)


# ============================================================
# MUERTE
# ============================================================

func _die() -> void:
	if not is_alive:
		return

	is_alive = false

	# Los drops se calculan usando criatura_drops de Supabase.
	# La posición se captura antes de ocultar/eliminar la criatura.
	if not criatura_id.is_empty():
		GarliaWorldItems.generar_drops_criatura(
			criatura_id,
			global_position
		)

	died.emit()

	if _movimiento != null:
		_movimiento.detener()

	velocity = Vector2.ZERO

	set_physics_process(false)
	set_process(false)

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


# ============================================================
# DEBUG VISUAL
# ============================================================

func _draw() -> void:
	# Si hay un Sprite2D asignado, no dibujamos el placeholder.
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture != null:
		if mostrar_nombre_debug:
			_dibujar_nombre()
		return

	# Placeholder de debug (círculos) cuando no hay sprite.
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
		Vector2(
			2.2,
			-1.5
		),
		0.45,
		Color(
			0.05,
			0.05,
			0.05
		)
	)

	if mostrar_nombre_debug:
		_dibujar_nombre()


func _dibujar_nombre() -> void:
	if criatura_nombre.is_empty():
		return

	var font: Font = (
		ThemeDB.fallback_font
	)

	var ancho: float = float(
		font.get_string_size(
			criatura_nombre,
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
		criatura_nombre,
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
		criatura_nombre,
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
