extends Node2D
class_name CreaturePlacement

## Punto de colocación reutilizable para escenas diseñadas a mano.
## La identidad y los datos de la especie se resuelven desde WorldData (Supabase/cache),
## nunca se copian al Inspector.

@export_category("Criatura")
@export var criatura_id: String = ""
@export_range(1, 20, 1) var cantidad: int = 1
@export var separacion: float = 28.0
@export var desplazamiento_inicial: Vector2 = Vector2.ZERO
@export var nombre_individual: String = ""

var _generado: bool = false
var _world_data: WorldDataService = null


func _ready() -> void:
	_world_data = get_node_or_null("/root/WorldData") as WorldDataService
	if _world_data == null:
		push_error("CreaturePlacement: no se encontró el autoload /root/WorldData.")
		return

	if _world_data.esta_cargado():
		_generar_criaturas()
	elif not _world_data.mundo_listo.is_connected(_al_catalogo_listo):
		_world_data.mundo_listo.connect(_al_catalogo_listo, CONNECT_ONE_SHOT)


func _al_catalogo_listo() -> void:
	_generar_criaturas()


func _generar_criaturas() -> void:
	if _generado:
		return
	_generado = true

	var id := criatura_id.strip_edges()
	if id.is_empty():
		push_warning("CreaturePlacement (%s): asigna criatura_id en el Inspector." % name)
		return

	var datos := _world_data.obtener_criatura(id)
	if datos.is_empty():
		push_error("CreaturePlacement (%s): la criatura '%s' no existe en el catálogo sincronizado." % [name, id])
		return

	var escena := load("res://scenes/creatures/creature.tscn") as PackedScene
	if escena == null:
		push_error("CreaturePlacement: no se pudo cargar scenes/creatures/creature.tscn.")
		return

	var total := clampi(cantidad, 1, 20)
	for indice in range(total):
		var criatura := escena.instantiate() as Creature
		if criatura == null:
			push_error("CreaturePlacement: la escena base no contiene una Creature.")
			continue

		add_child(criatura)
		criatura.position = desplazamiento_inicial + Vector2(separacion * indice, 0.0)
		criatura.configurar_dependencias(null, null, null, null, _world_data)
		criatura.configurar_dependencias_ia(null, null, null, null, null)
		var datos_instancia := datos.duplicate(true)
		if not nombre_individual.strip_edges().is_empty():
			datos_instancia["nombre_individual"] = nombre_individual if total == 1 else "%s %d" % [nombre_individual, indice + 1]
		criatura.configurar(datos_instancia)
		criatura.activar_como_proxy()
