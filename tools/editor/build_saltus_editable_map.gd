@tool
extends EditorScript
## Convierte la expedición completa en una escena editable.
## Abrir expedicion_saltus.tscn antes de ejecutar este EditorScript.

const SCENE_PATH := "res://scenes/world/expedicion_saltus.tscn"

const CATEGORIES := [
	"Mapa",
	"Vegetacion",
	"Criaturas",
	"Mecanismos",
	"PuntosDeControl",
	"Fondos",
	"Ambiente",
	"ElementosTutorial",
	"ElementosEscena"
]


func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if not (root is SaltusExpedition):
		push_error("Saltus: abre scenes/world/expedicion_saltus.tscn antes de ejecutar este script.")
		return
	if root.get("contenido_escena_preconstruido"):
		push_warning("Saltus: la escena ya está convertida. No vuelvas a ejecutar el constructor porque podrías duplicar contenido.")
		return

	# Construye una sola vez los nodos iniciales dentro de la escena abierta.
	root.call("_crear_relleno_fondo")
	root.call("_crear_terreno")
	root.call("_crear_puntos_sector")
	root.call("_crear_fondo_y_parallax")
	root.call("_crear_arboleda")
	root.call("_crear_criaturas")
	root.call("_crear_ambiente")
	root.call("_crear_mecanicas_ambientales")

	_organizar_nodos(root)
	root.set("contenido_escena_preconstruido", true)
	root.scene_file_path = SCENE_PATH

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("Saltus: no se pudo empaquetar la expedición completa: " + error_string(pack_error))
		root.set("contenido_escena_preconstruido", false)
		return

	var save_error := ResourceSaver.save(packed, SCENE_PATH)
	if save_error != OK:
		push_error("Saltus: no se pudo guardar expedicion_saltus.tscn: " + error_string(save_error))
		root.set("contenido_escena_preconstruido", false)
		return

	print("Saltus: expedicion_saltus.tscn ahora contiene terreno, colisiones, fondos, plantas, criaturas, mecanismos, checkpoints y zona del primer jefe.")
	print("Guarda/recarga la escena en el editor y modifica sus nodos desde el árbol de escenas.")


func _organizar_nodos(root: Node) -> void:
	var grupos: Dictionary = {}
	for nombre in CATEGORIES:
		var grupo := Node2D.new()
		grupo.name = nombre
		root.add_child(grupo)
		grupo.owner = root
		grupos[nombre] = grupo

	var nodos := root.get_children().duplicate()
	for nodo: Node in nodos:
		if nodo is not Node2D or CATEGORIES.has(nodo.name) or nodo.name == "Player":
			continue
		var categoria := _categoria_para(nodo)
		var destino: Node2D = grupos[categoria]
		var transformacion := (nodo as Node2D).global_transform
		nodo.reparent(destino)
		(nodo as Node2D).global_transform = transformacion
		_asignar_owner_recursivo(nodo, root)


func _categoria_para(nodo: Node) -> String:
	var nombre := nodo.name
	if nombre == "TerrenoSaltusV2" or nombre.begins_with("Terreno_") or nombre.begins_with("Plataforma_"):
		return "Mapa"
	if nombre.begins_with("Zlish_") or nombre.begins_with("Flaxis_"):
		return "Criaturas"
	if nombre.begins_with("PuntoDescanso"):
		return "PuntosDeControl"
	if nombre.begins_with("Parallax") or nombre == "RellenoVerdeFondo":
		return "Fondos"
	if nombre.begins_with("HojasEnElAire"):
		return "Ambiente"
	if nombre.begins_with("FloraImpulsora") or nombre.begins_with("FlorDetectora"):
		return "Vegetacion"
	if nombre.begins_with("Puerta") or nombre.begins_with("CorrienteAerea"):
		return "Mecanismos"
	if nombre.begins_with("Indicacion_") or nombre == "ZonaPrimerJefe":
		return "ElementosTutorial"
	return "ElementosEscena"


func _asignar_owner_recursivo(nodo: Node, root: Node) -> void:
	nodo.owner = root
	for hijo: Node in nodo.get_children():
		_asignar_owner_recursivo(hijo, root)
