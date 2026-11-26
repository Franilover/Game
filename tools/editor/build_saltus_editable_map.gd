@tool
extends EditorScript
## Convierte la expedición completa en una escena editable.
## Abrir expedicion_saltus.tscn antes de ejecutar este EditorScript.

const SCENE_PATH := "res://scenes/world/expedicion_saltus.tscn"
const EXPEDITION_SCRIPT_PATH := "res://scripts/world/saltus_expedition.gd"

# Nombres de los contenedores usados por versiones anteriores del constructor.
const CATEGORIES := [
	"Mapa", "Vegetacion", "Criaturas", "Mecanismos", "PuntosDeControl",
	"Fondos", "Ambiente", "ElementosTutorial", "ElementosEscena"
]


func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.scene_file_path != SCENE_PATH:
		push_error("Saltus: abre scenes/world/expedicion_saltus.tscn antes de ejecutar este script.")
		return
	print("Saltus: comprobando contenido materializado de la escena...")
	if bool(root.get("contenido_escena_preconstruido")) and _escena_tiene_contenido_editable(root):
		# Migra escenas anteriores: elimina contenedores de categoría y deja cada
		# elemento del mundo como hijo directo e independiente de la raíz.
		_desagrupar_categorias(root)
		for hijo: Node in root.get_children():
			_asignar_owner_recursivo(hijo, root)
		var escena_existente := PackedScene.new()
		var error_pack := escena_existente.pack(root)
		if error_pack != OK:
			push_error("Saltus: no se pudo preparar la escena para edición: " + error_string(error_pack))
			return
		var error_guardado := ResourceSaver.save(escena_existente, SCENE_PATH)
		if error_guardado != OK:
			push_error("Saltus: no se pudo guardar la escena editable: " + error_string(error_guardado))
			return
		# Actualiza también el documento que mantiene abierto el editor.
		# Así el árbol de Scene y el archivo .tscn quedan sincronizados.
		get_editor_interface().save_scene()
		print("Saltus: escena editable verificada, guardada y sincronizada con el editor.")
		return

	# Si el indicador quedó activado en una ejecución parcial pero el árbol solo
	# contiene Player, reconstruimos. Nunca usamos el booleano como única prueba.
	_limpiar_contenido_generado(root)

	# El nodo raíz ya tiene SaltusExpedition como script @tool. Generamos
	# directamente sobre él: así cada objeto nace dentro de la escena abierta
	# y no depende de una fábrica temporal ni de una coroutine de EditorScript.
	var metodos_generacion := [
		"_crear_relleno_fondo",
		"_crear_terreno",
		"_crear_puntos_sector",
		"_crear_fondo_y_parallax",
		"_crear_arboleda",
		"_crear_criaturas",
		"_crear_ambiente",
		"_crear_mecanicas_ambientales"
	]
	for metodo: String in metodos_generacion:
		if not root.has_method(metodo):
			push_error("Saltus: la raíz no expone " + metodo + ". Comprueba el script SaltusExpedition.")
			return

	print("Saltus: generando directamente dentro de ExpedicionSaltus...")
	for metodo: String in metodos_generacion:
		root.call(metodo)
	_materializar_componentes_visuales(root)

	# El constructor crea los nodos como hijos directos de la raíz. Se asigna
	# owner a todo el subárbol para que Godot los serialice en el .tscn.
	for hijo: Node in root.get_children():
		_asignar_owner_recursivo(hijo, root)

	var cantidad_hijos := root.get_child_count()
	if cantidad_hijos <= 1 or not _escena_tiene_contenido_editable(root):
		root.set("contenido_escena_preconstruido", false)
		push_error("Saltus: generación incompleta. Hijos raíz=" + str(cantidad_hijos) + ". No se guardó la escena.")
		return

	root.set("contenido_escena_preconstruido", true)
	print("Saltus: verificación previa al guardado | hijos raíz=", cantidad_hijos)
	for hijo: Node in root.get_children():
		print("Saltus: nodo raíz | ", hijo.name, " | owner=", hijo.owner == root)

	# Guardamos el documento que está abierto en el editor. No empaquetamos con
	# ResourceSaver en paralelo: eso podía sobrescribir el estado del Scene dock.
	var error_guardado := get_editor_interface().save_scene()
	if error_guardado != OK:
		root.set("contenido_escena_preconstruido", false)
		push_error("Saltus: el editor no pudo guardar expedicion_saltus.tscn: " + error_string(error_guardado))
		return

	print("Saltus: escena guardada. Los objetos deben figurar como nodos independientes bajo ExpedicionSaltus.")



func _desagrupar_categorias(root: Node) -> void:
	for grupo: Node in root.get_children().duplicate():
		if not CATEGORIES.has(grupo.name):
			continue
		for elemento: Node in grupo.get_children().duplicate():
			var transformacion := (elemento as Node2D).global_transform if elemento is Node2D else Transform2D.IDENTITY
			grupo.remove_child(elemento)
			root.add_child(elemento)
			if elemento is Node2D:
				(elemento as Node2D).global_transform = transformacion
		grupo.owner = null
		root.remove_child(grupo)
		grupo.free()


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


func _escena_tiene_contenido_editable(root: Node) -> bool:
	return (
		_contiene_nombre(root, "TerrenoSaltusV2")
		and _contiene_prefijo(root, "FloraImpulsora_")
		and _contiene_prefijo(root, "FlorDetectora_")
		and _contiene_prefijo(root, "Zlish_")
		and _contiene_prefijo(root, "Flaxis_")
		and _contiene_nombre(root, "PuertaFlorDetectora")
		and _contiene_prefijo(root, "CorrienteAerea")
		and _contiene_nombre(root, "PuntoDescanso")
		and _contiene_prefijo(root, "Parallax")
	)


func _contiene_nombre(nodo: Node, nombre: String) -> bool:
	if nodo.name == nombre:
		return true
	for hijo: Node in nodo.get_children():
		if _contiene_nombre(hijo, nombre):
			return true
	return false


func _contiene_prefijo(nodo: Node, prefijo: String) -> bool:
	if nodo.name.begins_with(prefijo):
		return true
	for hijo: Node in nodo.get_children():
		if _contiene_prefijo(hijo, prefijo):
			return true
	return false


func _limpiar_contenido_generado(root: Node) -> void:
	for hijo: Node in root.get_children().duplicate():
		if hijo.name == "Player":
			continue
		root.remove_child(hijo)
		hijo.free()
	root.set("contenido_escena_preconstruido", false)
	print("Saltus: árbol incompleto detectado; se reconstruirá desde cero conservando Player.")
