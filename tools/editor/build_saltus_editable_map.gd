@tool
extends EditorScript
## Convierte la expedición completa en una escena editable.
## Abrir expedicion_saltus.tscn antes de ejecutar este EditorScript.

const SCENE_PATH := "res://scenes/world/expedicion_saltus.tscn"
const EXPEDITION_SCRIPT_PATH := "res://scripts/world/saltus_expedition.gd"

const CATEGORIES := [
	"Mapa", "Vegetacion", "Criaturas", "Mecanismos", "PuntosDeControl",
	"Fondos", "Ambiente", "ElementosTutorial", "ElementosEscena"
]


func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.scene_file_path != SCENE_PATH:
		push_error("Saltus: abre scenes/world/expedicion_saltus.tscn antes de ejecutar este script.")
		return
	if bool(root.get("contenido_escena_preconstruido")):
		push_warning("Saltus: la escena ya está convertida. No vuelvas a ejecutar el constructor.")
		return

	# La raíz abierta puede ser un PlaceholderScriptInstance aunque el script
	# tenga @tool. Instanciamos una fábrica real desde el recurso GDScript.
	var expedition_script := load(EXPEDITION_SCRIPT_PATH) as GDScript
	if expedition_script == null or not expedition_script.can_instantiate():
		push_error("Saltus: no se pudo compilar/instanciar saltus_expedition.gd. Revisa los errores de GDScript.")
		return

	var factory := expedition_script.new() as Node2D
	if factory == null:
		push_error("Saltus: no se pudo crear la fábrica temporal del escenario.")
		return
	factory.name = "SaltusSceneFactory_TEMP"
	root.add_child(factory)

	factory.call("_crear_relleno_fondo")
	factory.call("_crear_terreno")
	factory.call("_crear_puntos_sector")
	factory.call("_crear_fondo_y_parallax")
	factory.call("_crear_arboleda")
	factory.call("_crear_criaturas")
	factory.call("_crear_ambiente")
	factory.call("_crear_mecanicas_ambientales")
	_materializar_componentes_visuales(factory)

	# EditorScript no hereda Node y no dispone de get_tree().
	# Esperamos desde el SceneTree principal para que se ejecuten los call_deferred del terreno.
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree != null:
		await scene_tree.process_frame
		await scene_tree.process_frame

	var generados := factory.get_children().duplicate()
	for nodo: Node in generados:
		var transformacion := (nodo as Node2D).global_transform if nodo is Node2D else Transform2D.IDENTITY
		factory.remove_child(nodo)
		root.add_child(nodo)
		if nodo is Node2D:
			(nodo as Node2D).global_transform = transformacion
	root.remove_child(factory)
	factory.free()

	_organizar_nodos(root)
	# Garantiza que todos los nodos del escenario pertenezcan a esta escena.
	# Sin owner, Godot los muestra pero no permite editarlos como parte del .tscn.
	for hijo: Node in root.get_children():
		_asignar_owner_recursivo(hijo, root)
	root.set("contenido_escena_preconstruido", true)

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		root.set("contenido_escena_preconstruido", false)
		push_error("Saltus: no se pudo empaquetar la expedición completa: " + error_string(pack_error))
		return

	var save_error := ResourceSaver.save(packed, SCENE_PATH)
	if save_error != OK:
		root.set("contenido_escena_preconstruido", false)
		push_error("Saltus: no se pudo guardar expedicion_saltus.tscn: " + error_string(save_error))
		return

	print("Saltus: expedicion_saltus.tscn ahora contiene terreno, colisiones, fondos, plantas, criaturas, mecanismos, checkpoints y zona del primer jefe.")
	print("Saltus: la escena completa quedó guardada y sus nodos son editables desde el árbol.")


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


func _materializar_componentes_visuales(root: Node) -> void:
	for nodo: Node in root.get_children():
		if nodo.name.begins_with("FloraImpulsora"):
			_agregar_circulo(nodo, 22.0, Vector2(0.0, -12.0))
			_agregar_sprite(nodo, "FlorSaltarinaSprite", "res://assets/art/kingdom/Saltus/2D Section/Flor Saltarina.png")
		elif nodo.name.begins_with("FlorDetectora"):
			_agregar_circulo(nodo, 28.0, Vector2(0.0, -16.0))
			_agregar_sprite(nodo, "Sprite2D", "res://assets/art/kingdom/Saltus/2D Section/Flor Detectora.png")
		elif nodo.name == "PuertaFlorDetectora":
			var tamano: Vector2 = nodo.get("gate_size")
			var colision := CollisionShape2D.new()
			var rectangulo := RectangleShape2D.new()
			rectangulo.size = tamano
			colision.shape = rectangulo
			nodo.add_child(colision)
			var visual := Polygon2D.new()
			visual.name = "Visual"
			visual.polygon = PackedVector2Array([
				Vector2(-tamano.x * 0.5, -tamano.y * 0.5),
				Vector2(tamano.x * 0.5, -tamano.y * 0.5),
				Vector2(tamano.x * 0.5, tamano.y * 0.5),
				Vector2(-tamano.x * 0.5, tamano.y * 0.5)
			])
			visual.color = nodo.get("gate_color")
			nodo.add_child(visual)
		elif nodo.name.begins_with("CorrienteAerea"):
			var colision := CollisionShape2D.new()
			var rectangulo := RectangleShape2D.new()
			rectangulo.size = Vector2(280.0, 190.0)
			colision.shape = rectangulo
			nodo.add_child(colision)
			var indicador := Node2D.new()
			indicador.name = "IndicadorCorriente"
			nodo.add_child(indicador)
			for indice in range(3):
				var linea := Line2D.new()
				linea.width = 3.0
				linea.default_color = Color(0.78, 0.88, 0.66, 0.52)
				linea.points = PackedVector2Array([
					Vector2(-72.0, 30.0 + indice * 22.0),
					Vector2(-24.0, 8.0 + indice * 22.0),
					Vector2(24.0, 14.0 + indice * 22.0),
					Vector2(72.0, -8.0 + indice * 22.0)
				])
				linea.z_index = 3
				indicador.add_child(linea)


func _agregar_circulo(parent: Node, radio: float, posicion: Vector2) -> void:
	var colision := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = radio
	colision.shape = circulo
	colision.position = posicion
	parent.add_child(colision)


func _agregar_sprite(parent: Node, nombre: String, ruta: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = load(ruta) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0, 2.0)
	if sprite.texture != null:
		sprite.position.y = -sprite.texture.get_height() * sprite.scale.y * 0.5
	parent.add_child(sprite)
