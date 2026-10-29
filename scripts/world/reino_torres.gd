extends Node2D

signal salida_solicitada

const TORRES_ART_ROOT := "res://assets/art/kingdom/torres"

# Cada edificio intenta primero su sprite específico y después uno genérico.
# Si no existe ningún archivo válido, sus Polygon2D de placeholder quedan visibles.
const SPRITE_BUILDINGS: Array[Dictionary] = [
	{"key":"castillo", "paths":["castillo.png","edificios/castillo.png"], "position":Vector2(0,-205), "size":Vector2(230,190), "hide":["CastleKeep","CastleFacade","CastleRoof","CastleDoor","CastleWindow","CastleTower"]},
	{"key":"panaderia", "paths":["casas/panaderia.png","edificios/panaderia.png","casas/casa.png"], "position":Vector2(-245,-157), "size":Vector2(96,92), "hide":["HouseBaker"]},
	{"key":"posada", "paths":["casas/posada.png","edificios/posada.png","casas/casa.png"], "position":Vector2(-385,52), "size":Vector2(104,102), "hide":["HouseInn"]},
	{"key":"vivienda_mason", "paths":["casas/vivienda_mason.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-235,152), "size":Vector2(96,88), "hide":["HouseMason"]},
	{"key":"casa_oriente_a", "paths":["casas/casa_oriente_a.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(220,-158), "size":Vector2(96,90), "hide":["HouseEastA"]},
	{"key":"casa_oriente_b", "paths":["casas/casa_oriente_b.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(385,-148), "size":Vector2(96,90), "hide":["HouseEastB"]},
	{"key":"casa_oriente_c", "paths":["casas/casa_oriente_c.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(385,118), "size":Vector2(96,92), "hide":["HouseEastC"]},
	{"key":"forja", "paths":["edificios/forja.png","edificios/taller.png"], "position":Vector2(-360,-201), "size":Vector2(104,92), "hide":["ForgeBase","ForgeRoof","ForgeOpening","ForgeFire"]},
	{"key":"establos", "paths":["edificios/establos.png","edificios/establo.png"], "position":Vector2(382,177), "size":Vector2(112,88), "hide":["StableBase","StableRoof","StableDoor"]},
	{"key":"archivo_real", "paths":["edificios/archivo_real.png","edificios/archivo.png","edificios/edificio.png"], "position":Vector2(-170,-657), "size":Vector2(116,94), "hide":["RoyalArchive"]},
	{"key":"sala_consejo", "paths":["edificios/sala_consejo.png","edificios/consejo.png","edificios/edificio.png"], "position":Vector2(170,-658), "size":Vector2(132,104), "hide":["CouncilHall"]},
	{"key":"casa_estudio", "paths":["edificios/casa_estudio.png","edificios/estudio_oris.png","edificios/edificio.png"], "position":Vector2(-410,-564), "size":Vector2(122,98), "hide":["OrisStudy","StudyDome"]},
	{"key":"casa_comercio", "paths":["edificios/casa_comercio.png","edificios/comercio.png","edificios/edificio.png"], "position":Vector2(930,-358), "size":Vector2(122,100), "hide":["TradeHouse"]},
	{"key":"alojamiento", "paths":["edificios/alojamiento.png","edificios/posada.png","edificios/edificio.png"], "position":Vector2(930,-253), "size":Vector2(134,108), "hide":["Caravanserai"]},
	{"key":"cuartel", "paths":["edificios/cuartel.png","edificios/edificio.png"], "position":Vector2(730,-358), "size":Vector2(126,104), "hide":["GuardBarracks"]},
	{"key":"registro", "paths":["edificios/registro.png","edificios/edificio.png"], "position":Vector2(730,-250), "size":Vector2(108,90), "hide":["GateOffice"]},
	{"key":"reparaciones", "paths":["edificios/reparaciones.png","edificios/taller.png","edificios/edificio.png"], "position":Vector2(930,102), "size":Vector2(118,96), "hide":["RepairWorkshop"]},
	{"key":"almacen", "paths":["edificios/almacen.png","edificios/edificio.png"], "position":Vector2(730,102), "size":Vector2(116,96), "hide":["PublicStore"]},
	{"key":"carpinteria", "paths":["edificios/carpinteria.png","edificios/taller.png","edificios/edificio.png"], "position":Vector2(930,212), "size":Vector2(114,96), "hide":["Cartwright"]},
	{"key":"granero", "paths":["edificios/granero.png","edificios/almacen.png","edificios/edificio.png"], "position":Vector2(-450,257), "size":Vector2(124,102), "hide":["GrainStore"]},
	{"key":"molino", "paths":["edificios/molino.png","edificios/edificio.png"], "position":Vector2(-270,257), "size":Vector2(114,96), "hide":["MillHouse"]},
	{"key":"aguas", "paths":["edificios/aguas.png","edificios/estacion_agua.png","edificios/edificio.png"], "position":Vector2(250,257), "size":Vector2(124,102), "hide":["WaterWorks"]},
	{"key":"corrales", "paths":["edificios/corrales.png","edificios/establos.png","edificios/edificio.png"], "position":Vector2(450,257), "size":Vector2(122,100), "hide":["AnimalPens"]},
	{"key":"casa_granjeros", "paths":["edificios/casa_granjeros.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-850,602), "size":Vector2(126,102), "hide":["FarmersHall"]},
	{"key":"semillas", "paths":["edificios/semillas.png","edificios/almacen.png","edificios/edificio.png"], "position":Vector2(800,602), "size":Vector2(122,100), "hide":["SeedStore"]},
	{"key":"telar", "paths":["edificios/telares.png","casas/taller.png","casas/casa.png"], "position":Vector2(-760,-258), "size":Vector2(100,90), "hide":["WeaverHouse"]},
	{"key":"alfareria", "paths":["edificios/alfareria.png","casas/taller.png","casas/casa.png"], "position":Vector2(-760,102), "size":Vector2(100,90), "hide":["PotterHouse"]},
	{"key":"banos", "paths":["edificios/banos.png","edificios/edificio.png"], "position":Vector2(-760,211), "size":Vector2(108,98), "hide":["BathHouse"]},
	{"key":"vivienda_oeste_01", "paths":["casas/vivienda_oeste_01.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,-354), "size":Vector2(84,82), "hide":["WestHome1Wall","WestHome1Roof","WestHome1Door","WestHome1CollisionBody"]},
	{"key":"vivienda_oeste_02", "paths":["casas/vivienda_oeste_02.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,-354), "size":Vector2(84,82), "hide":["WestHome2Wall","WestHome2Roof","WestHome2Door","WestHome2CollisionBody"]},
	{"key":"vivienda_oeste_03", "paths":["casas/vivienda_oeste_03.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,-254), "size":Vector2(84,82), "hide":["WestHome3Wall","WestHome3Roof","WestHome3Door","WestHome3CollisionBody"]},
	{"key":"vivienda_oeste_04", "paths":["casas/vivienda_oeste_04.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,-254), "size":Vector2(84,82), "hide":["WestHome4Wall","WestHome4Roof","WestHome4Door","WestHome4CollisionBody"]},
	{"key":"vivienda_oeste_05", "paths":["casas/vivienda_oeste_05.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,106), "size":Vector2(84,82), "hide":["WestHome5Wall","WestHome5Roof","WestHome5Door","WestHome5CollisionBody"]},
	{"key":"vivienda_oeste_06", "paths":["casas/vivienda_oeste_06.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,106), "size":Vector2(84,82), "hide":["WestHome6Wall","WestHome6Roof","WestHome6Door","WestHome6CollisionBody"]},
	{"key":"vivienda_oeste_07", "paths":["casas/vivienda_oeste_07.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,216), "size":Vector2(84,82), "hide":["WestHome7Wall","WestHome7Roof","WestHome7Door","WestHome7CollisionBody"]},
	{"key":"vivienda_oeste_08", "paths":["casas/vivienda_oeste_08.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,216), "size":Vector2(84,82), "hide":["WestHome8Wall","WestHome8Roof","WestHome8Door","WestHome8CollisionBody"]},
	{"key":"vivienda_oeste_09", "paths":["casas/vivienda_oeste_09.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-520,-254), "size":Vector2(84,82), "hide":["WestHome9Wall","WestHome9Roof","WestHome9Door","WestHome9CollisionBody"]},
	{"key":"vivienda_oeste_10", "paths":["casas/vivienda_oeste_10.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-520,96), "size":Vector2(84,82), "hide":["WestHome10Wall","WestHome10Roof","WestHome10Door","WestHome10CollisionBody"]},
	{"key":"vivienda_oeste_11", "paths":["casas/vivienda_oeste_11.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-520,206), "size":Vector2(84,82), "hide":["WestHome11Wall","WestHome11Roof","WestHome11Door","WestHome11CollisionBody"]}
]

@onready var _exit: Area2D = $Exit

var _transicionando: bool = false
var _interior_activo: bool = false
var _jugador: Node2D
var _posicion_exterior: Vector2 = Vector2.ZERO
var _visibilidad_exterior: Dictionary = {}
var _estados_colision_exterior: Dictionary = {}
var _capa_interior: Node2D
var _aviso: Label

# Las entradas están cerca de la fachada de cada edificio. Cada clave tiene
# su propio nombre, función y distribución interior.
const ENTRADAS: Array[Dictionary] = [
	{"id":"castillo","nombre":"Castillo de Torres","pos":Vector2(0,-125),"tipo":"castillo"},
	{"id":"panaderia","nombre":"Panadería","pos":Vector2(-245,-117),"tipo":"panaderia"},
	{"id":"posada","nombre":"Posada","pos":Vector2(-385,97),"tipo":"posada"},
	{"id":"vivienda_mason","nombre":"Casa del cantero","pos":Vector2(-235,193),"tipo":"vivienda"},
	{"id":"casa_oriente_a","nombre":"Vivienda oriental","pos":Vector2(220,-117),"tipo":"vivienda"},
	{"id":"casa_oriente_b","nombre":"Vivienda oriental","pos":Vector2(385,-108),"tipo":"vivienda"},
	{"id":"casa_oriente_c","nombre":"Vivienda oriental","pos":Vector2(385,173),"tipo":"vivienda"},
	{"id":"forja","nombre":"Forja","pos":Vector2(-360,-159),"tipo":"forja"},
	{"id":"establos","nombre":"Establos","pos":Vector2(382,217),"tipo":"establos"},
	{"id":"archivo_real","nombre":"Archivo real","pos":Vector2(-170,-610),"tipo":"archivo"},
	{"id":"sala_consejo","nombre":"Sala del consejo","pos":Vector2(170,-605),"tipo":"consejo"},
	{"id":"casa_estudio","nombre":"Casa de estudio de Oris","pos":Vector2(-410,-520),"tipo":"oris"},
	{"id":"casa_comercio","nombre":"Casa de comercio","pos":Vector2(930,-310),"tipo":"comercio"},
	{"id":"alojamiento","nombre":"Alojamiento de caravanas","pos":Vector2(930,-200),"tipo":"posada"},
	{"id":"cuartel","nombre":"Cuartel de la guardia","pos":Vector2(730,-310),"tipo":"cuartel"},
	{"id":"registro","nombre":"Registro de la puerta","pos":Vector2(730,-210),"tipo":"registro"},
	{"id":"reparaciones","nombre":"Taller de reparaciones","pos":Vector2(930,145),"tipo":"taller"},
	{"id":"almacen","nombre":"Almacén público","pos":Vector2(730,145),"tipo":"almacen"},
	{"id":"carpinteria","nombre":"Carpintería","pos":Vector2(930,255),"tipo":"carpinteria"},
	{"id":"granero","nombre":"Granero","pos":Vector2(-450,300),"tipo":"granero"},
	{"id":"molino","nombre":"Molino","pos":Vector2(-270,300),"tipo":"molino"},
	{"id":"aguas","nombre":"Obras de agua","pos":Vector2(250,300),"tipo":"aguas"},
	{"id":"corrales","nombre":"Corrales","pos":Vector2(450,300),"tipo":"corrales"},
	{"id":"casa_granjeros","nombre":"Casa de los agricultores","pos":Vector2(-850,650),"tipo":"vivienda"},
	{"id":"semillas","nombre":"Depósito de semillas","pos":Vector2(800,650),"tipo":"almacen"},
	{"id":"telar","nombre":"Casa de los telares","pos":Vector2(-760,-215),"tipo":"telar"},
	{"id":"alfareria","nombre":"Alfarería","pos":Vector2(-760,145),"tipo":"alfareria"},
	{"id":"banos","nombre":"Baños públicos","pos":Vector2(-760,255),"tipo":"banos"},
	{"id":"vivienda_oeste_01","nombre":"Vivienda del barrio oeste","pos":Vector2(-1040,-313),"tipo":"vivienda"},
	{"id":"vivienda_oeste_02","nombre":"Vivienda del barrio oeste","pos":Vector2(-930,-313),"tipo":"vivienda"},
	{"id":"vivienda_oeste_03","nombre":"Vivienda del barrio oeste","pos":Vector2(-1040,-213),"tipo":"vivienda"},
	{"id":"vivienda_oeste_04","nombre":"Vivienda del barrio oeste","pos":Vector2(-930,-213),"tipo":"vivienda"},
	{"id":"vivienda_oeste_05","nombre":"Vivienda del barrio oeste","pos":Vector2(-1040,147),"tipo":"vivienda"},
	{"id":"vivienda_oeste_06","nombre":"Vivienda del barrio oeste","pos":Vector2(-930,147),"tipo":"vivienda"},
	{"id":"vivienda_oeste_07","nombre":"Vivienda del barrio oeste","pos":Vector2(-1040,257),"tipo":"vivienda"},
	{"id":"vivienda_oeste_08","nombre":"Vivienda del barrio oeste","pos":Vector2(-930,257),"tipo":"vivienda"},
	{"id":"vivienda_oeste_09","nombre":"Vivienda del barrio oeste","pos":Vector2(-520,-213),"tipo":"vivienda"},
	{"id":"vivienda_oeste_10","nombre":"Vivienda del barrio oeste","pos":Vector2(-520,137),"tipo":"vivienda"},
	{"id":"vivienda_oeste_11","nombre":"Vivienda del barrio oeste","pos":Vector2(-520,247),"tipo":"vivienda"}
]


func _ready() -> void:
	_exit.body_entered.connect(_al_entrar_salida)
	_jugador = get_tree().get_first_node_in_group("player") as Node2D
	_capa_interior = Node2D.new()
	_capa_interior.name = "InteriorActivo"
	_capa_interior.visible = false
	add_child(_capa_interior)
	_crear_aviso()
	_cargar_sprites_de_torres()
	_elevar_rotulos()


func _process(_delta: float) -> void:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_jugador):
		return

	if _interior_activo:
		var cerca_salida := _jugador.global_position.distance_to(to_global(Vector2(60, 105))) < 48.0
		_aviso.text = "E — Salir al exterior" if cerca_salida else ""
		_aviso.visible = cerca_salida
		if cerca_salida:
			_aviso.global_position = _jugador.global_position + Vector2(-115, -45)
		if Input.is_action_just_pressed("interact") and cerca_salida:
			_salir_del_interior()
		return

	var entrada_cercana: Dictionary = {}
	var distancia_menor := 58.0
	for entrada: Dictionary in ENTRADAS:
		var distancia := _jugador.global_position.distance_to(to_global(entrada["pos"]))
		if distancia < distancia_menor:
			distancia_menor = distancia
			entrada_cercana = entrada

	if entrada_cercana.is_empty():
		_aviso.text = ""
		_aviso.visible = false
		return

	_aviso.visible = true
	_aviso.global_position = _jugador.global_position + Vector2(-145, -45)
	_aviso.text = "E — Entrar: " + str(entrada_cercana["nombre"])
	if Input.is_action_just_pressed("interact"):
		_entrar_al_interior(entrada_cercana)


func _crear_aviso() -> void:
	_aviso = Label.new()
	_aviso.name = "AvisoEntrada"
	_aviso.position = Vector2(-150, -190)
	_aviso.z_index = 50
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.91, 0.69))
	_aviso.add_theme_color_override("font_shadow_color", Color(0.08, 0.07, 0.06))
	_aviso.add_theme_constant_override("shadow_offset_x", 2)
	_aviso.add_theme_constant_override("shadow_offset_y", 2)
	_aviso.visible = false
	add_child(_aviso)


func _cargar_sprites_de_torres() -> void:
	for building: Dictionary in SPRITE_BUILDINGS:
		var texture := _buscar_textura(building["paths"])
		if texture == null:
			continue

		_ocultar_placeholder(building["hide"])
		var sprite := Sprite2D.new()
		sprite.name = "Sprite_" + String(building["key"]).capitalize()
		sprite.texture = texture
		sprite.position = building["position"]
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var target_size: Vector2 = building["size"]
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var scale_factor := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
			sprite.scale = Vector2.ONE * scale_factor
		sprite.z_index = 3
		add_child(sprite)
		print("ReinoTorres: sprite cargado para ", building["key"], " -> ", texture.resource_path)


func _entrar_al_interior(entrada: Dictionary) -> void:
	if _interior_activo or not is_instance_valid(_jugador):
		return
	_posicion_exterior = _jugador.global_position
	_visibilidad_exterior.clear()
	_estados_colision_exterior.clear()
	for child: Node in get_children():
		if child == _capa_interior or child == _aviso:
			continue
		if child is CanvasItem:
			_visibilidad_exterior[child.get_instance_id()] = (child as CanvasItem).visible
			(child as CanvasItem).visible = false
	_guardar_y_desactivar_colisiones(self)
	_capa_interior.visible = true
	_capa_interior.process_mode = Node.PROCESS_MODE_INHERIT
	_construir_habitacion(entrada)
	_jugador.global_position = to_global(Vector2(60, 90))
	_interterior_colisiones(true)
	_interterior_activo = true
	_aviso.visible = false
	_aviso.text = ""
	print("ReinoTorres: entrando a ", entrada["id"])


func _salir_del_interior() -> void:
	if not _interior_activo or not is_instance_valid(_jugador):
		return
	_capa_interior.visible = false
	_capa_interior.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in get_children():
		if child == _capa_interior or child == _aviso:
			continue
		if child is CanvasItem and _visibilidad_exterior.has(child.get_instance_id()):
			(child as CanvasItem).visible = bool(_visibilidad_exterior[child.get_instance_id()])
	_restaurar_colisiones(self)
	_jugador.global_position = _posicion_exterior
	for hijo: Node in _capa_interior.get_children():
		hijo.free()
	_interterior_colisiones(false)
	_interterior_activo = false
	_aviso.visible = false
	_aviso.text = ""
	print("ReinoTorres: regreso al exterior.")


func _guardar_y_desactivar_colisiones(nodo: Node) -> void:
	for hijo: Node in nodo.get_children():
		if hijo == _capa_interior:
			continue
		if hijo is CollisionShape2D:
			var forma := hijo as CollisionShape2D
			_estados_colision_exterior[forma.get_instance_id()] = forma.disabled
			forma.set_deferred("disabled", true)
		elif hijo is CollisionPolygon2D:
			var poligono := hijo as CollisionPolygon2D
			_estados_colision_exterior[poligono.get_instance_id()] = poligono.disabled
			poligono.set_deferred("disabled", true)
		_guardar_y_desactivar_colisiones(hijo)


func _restaurar_colisiones(nodo: Node) -> void:
	for hijo: Node in nodo.get_children():
		if hijo == _capa_interior:
			continue
		if hijo is CollisionShape2D:
			var forma := hijo as CollisionShape2D
			if _estados_colision_exterior.has(forma.get_instance_id()):
				forma.set_deferred("disabled", bool(_estados_colision_exterior[forma.get_instance_id()]))
		elif hijo is CollisionPolygon2D:
			var poligono := hijo as CollisionPolygon2D
			if _estados_colision_exterior.has(poligono.get_instance_id()):
				poligono.set_deferred("disabled", bool(_estados_colision_exterior[poligono.get_instance_id()]))
		_restaurar_colisiones(hijo)


func _interterior_colisiones(_activar: bool) -> void:
	# Los interiores se dibujan con geometría visual; las paredes se añaden
	# como obstáculos simples en el propio cuarto.
	return


func _construir_habitacion(entrada: Dictionary) -> void:
	for hijo: Node in _capa_interior.get_children():
		hijo.free()
	var cuarto := Node2D.new()
	cuarto.name = "Habitacion_" + str(entrada["id"])
	_capa_interior.add_child(cuarto)

	_agregar_rect(cuarto, "Suelo", Vector2.ZERO, Vector2(440, 270), Color(0.35, 0.29, 0.22), -10)
	_agregar_rect(cuarto, "MuroNorte", Vector2(0, -139), Vector2(456, 12), Color(0.47, 0.39, 0.29), 2)
	_agregar_rect(cuarto, "MuroOeste", Vector2(-226, 0), Vector2(12, 278), Color(0.47, 0.39, 0.29), 2)
	_agregar_rect(cuarto, "MuroEste", Vector2(226, 0), Vector2(12, 278), Color(0.47, 0.39, 0.29), 2)
	_agregar_rect(cuarto, "MuroSurIzq", Vector2(-112, 133), Vector2(232, 12), Color(0.47, 0.39, 0.29), 2)
	_agregar_rect(cuarto, "MuroSurDer", Vector2(172, 133), Vector2(112, 12), Color(0.47, 0.39, 0.29), 2)
	_agregar_colision_muro(cuarto, "ColisionNorte", Vector2(0, -139), Vector2(456, 12))
	_agregar_colision_muro(cuarto, "ColisionOeste", Vector2(-226, 0), Vector2(12, 278))
	_agregar_colision_muro(cuarto, "ColisionEste", Vector2(226, 0), Vector2(12, 278))
	_agregar_colision_muro(cuarto, "ColisionSurIzq", Vector2(-112, 133), Vector2(232, 12))
	_agregar_colision_muro(cuarto, "ColisionSurDer", Vector2(172, 133), Vector2(112, 12))
	_agregar_rect(cuarto, "Alfombra", Vector2(0, 12), Vector2(116, 64), Color(0.49, 0.34, 0.22), -5)

	var titulo := Label.new()
	titulo.text = str(entrada["nombre"]).to_upper()
	titulo.position = Vector2(-205, -128)
	titulo.add_theme_color_override("font_color", Color(0.96, 0.86, 0.66))
	titulo.add_theme_font_size_override("font_size", 12)
	cuarto.add_child(titulo)

	var tipo := str(entrada["tipo"])
	var semilla: int = absi(str(entrada["id"]).hash())
	var madera := Color(0.25, 0.15, 0.09)
	var acento := Color(0.56, 0.39, 0.22)
	var piedra := Color(0.43, 0.42, 0.36)
	var claro := Color(0.68, 0.57, 0.40)

	match tipo:
		"castillo":
			_agregar_rect(cuarto, "MesaDelTrono", Vector2(0, -70), Vector2(110, 28), madera, 1)
			_agregar_rect(cuarto, "Trono", Vector2(0, -100), Vector2(24, 22), claro, 3)
			_agregar_rect(cuarto, "EstandarteOeste", Vector2(-175, -65), Vector2(12, 66), Color(0.45,0.20,0.16), 1)
			_agregar_rect(cuarto, "EstandarteEste", Vector2(175, -65), Vector2(12, 66), Color(0.45,0.20,0.16), 1)
			_agregar_rect(cuarto, "MesaAudiencias", Vector2(0, 45), Vector2(170, 28), madera, 1)
		"panaderia":
			_agregar_rect(cuarto, "Horno", Vector2(-150, -75), Vector2(72, 68), piedra, 1)
			_agregar_rect(cuarto, "BocaHorno", Vector2(-150, -56), Vector2(32, 25), Color(0.19,0.12,0.09), 2)
			_agregar_rect(cuarto, "Mostrador", Vector2(90, -20), Vector2(100, 30), madera, 1)
			_agregar_rect(cuarto, "MesaAmasado", Vector2(70, 65), Vector2(90, 25), acento, 1)
		"posada":
			for i in range(3):
				_agregar_rect(cuarto, "Mesa%d" % i, Vector2(-110 + i * 110, -15), Vector2(54, 34), madera, 1)
				_agregar_rect(cuarto, "Banco%d" % i, Vector2(-110 + i * 110, 10), Vector2(58, 9), acento, 2)
			_agregar_rect(cuarto, "Mostrador", Vector2(0, -95), Vector2(140, 22), madera, 1)
		"forja":
			_agregar_rect(cuarto, "Yunque", Vector2(35, 10), Vector2(52, 35), piedra, 2)
			_agregar_rect(cuarto, "Hogar", Vector2(-145, -70), Vector2(70, 65), Color(0.25,0.18,0.14), 1)
			_agregar_rect(cuarto, "Fuego", Vector2(-145, -70), Vector2(34, 28), Color(0.73,0.29,0.10), 2)
			_agregar_rect(cuarto, "BancoHerramientas", Vector2(115, 65), Vector2(100, 24), madera, 1)
		"establos", "corrales":
			for i in range(3):
				_agregar_rect(cuarto, "Puesto%d" % i, Vector2(-135 + i * 135, 0), Vector2(90, 116), acento, 1)
				_agregar_rect(cuarto, "Comedero%d" % i, Vector2(-135 + i * 135, 42), Vector2(58, 15), madera, 2)
		"archivo":
			for i in range(4):
				_agregar_rect(cuarto, "Estante%d" % i, Vector2(-165 + i * 110, -65), Vector2(30, 115), madera, 1)
				_agregar_rect(cuarto, "Libros%d" % i, Vector2(-165 + i * 110, -72), Vector2(24, 72), acento, 2)
			_agregar_rect(cuarto, "MesaConsulta", Vector2(0, 65), Vector2(125, 30), piedra, 1)
		"consejo":
			_agregar_rect(cuarto, "MesaConsejo", Vector2(0, -5), Vector2(190, 76), madera, 1)
			for i in range(6):
				_agregar_rect(cuarto, "Asiento%d" % i, Vector2(-145 + i * 58, 55), Vector2(24, 20), acento, 2)
		"oris":
			_agregar_rect(cuarto, "MesaEstudio", Vector2(0, 25), Vector2(135, 48), madera, 1)
			_agregar_rect(cuarto, "MesaMuestras", Vector2(-130, -65), Vector2(64, 42), piedra, 1)
			_agregar_rect(cuarto, "Estanteria", Vector2(150, -70), Vector2(36, 100), acento, 1)
			_agregar_rect(cuarto, "CirculoInvestigacion", Vector2(0, -80), Vector2(76, 6), claro, 2)
		"comercio", "registro", "almacen":
			_agregar_rect(cuarto, "Mostrador", Vector2(0, -75), Vector2(180, 25), madera, 1)
			for i in range(4):
				_agregar_rect(cuarto, "Estante%d" % i, Vector2(-165 + i * 110, 45), Vector2(34, 70), acento, 1)
			_agregar_rect(cuarto, "MesaInventario", Vector2(0, 55), Vector2(100, 22), piedra, 2)
		"cuartel":
			for i in range(4):
				_agregar_rect(cuarto, "Litera%d" % i, Vector2(-150 + (i % 2) * 300, -65 + int(i / 2) * 105), Vector2(70, 35), madera, 1)
			_agregar_rect(cuarto, "Armero", Vector2(0, -90), Vector2(90, 24), piedra, 2)
		"taller", "carpinteria":
			_agregar_rect(cuarto, "BancoTrabajo", Vector2(0, 15), Vector2(150, 42), madera, 1)
			_agregar_rect(cuarto, "Herramientas", Vector2(-145, -70), Vector2(48, 82), piedra, 1)
			_agregar_rect(cuarto, "Materiales", Vector2(145, 65), Vector2(65, 40), acento, 1)
		"granero", "molino", "semillas":
			for i in range(4):
				_agregar_rect(cuarto, "Saco%d" % i, Vector2(-145 + i * 95, -45), Vector2(46, 44), acento, 1)
			_agregar_rect(cuarto, "MesaPesaje", Vector2(0, 55), Vector2(110, 25), madera, 1)
			if tipo == "molino":
				_agregar_rect(cuarto, "MecanismoMolino", Vector2(0, -90), Vector2(80, 30), piedra, 2)
		"aguas":
			_agregar_rect(cuarto, "Deposito", Vector2(0, -20), Vector2(140, 90), Color(0.23,0.39,0.43), 1)
			_agregar_rect(cuarto, "Canal", Vector2(0, 60), Vector2(180, 20), Color(0.25,0.46,0.52), 2)
			_agregar_rect(cuarto, "ValvulaOeste", Vector2(-145, -80), Vector2(32, 32), piedra, 2)
		"telar":
			for i in range(3):
				_agregar_rect(cuarto, "Telar%d" % i, Vector2(-120 + i * 120, -15), Vector2(48, 95), madera, 1)
			_agregar_rect(cuarto, "RollosTela", Vector2(0, 75), Vector2(125, 24), Color(0.47,0.31,0.29), 2)
		"alfareria":
			_agregar_rect(cuarto, "HornoCeramica", Vector2(-130, -65), Vector2(66, 66), piedra, 1)
			_agregar_rect(cuarto, "Torno", Vector2(30, 10), Vector2(50, 50), madera, 2)
			_agregar_rect(cuarto, "EstantesVasijas", Vector2(145, -50), Vector2(36, 95), acento, 1)
		"banos":
			for i in range(3):
				_agregar_rect(cuarto, "Pileta%d" % i, Vector2(-130 + i * 130, 0), Vector2(82, 78), Color(0.29,0.43,0.45), 1)
		"vivienda":
			_agregar_rect(cuarto, "Cama", Vector2(-145, -55), Vector2(72, 52), Color(0.42,0.29,0.24), 1)
			_agregar_rect(cuarto, "Mesa", Vector2(75, 20), Vector2(68, 34), madera, 1)
			_agregar_rect(cuarto, "Fogon", Vector2(145, -75), Vector2(36, 36), piedra, 1)
			_agregar_rect(cuarto, "Arcon", Vector2(-55, 70), Vector2(60, 24), acento, 1)

	# Detalles diferentes en cada local para que dos casas del mismo tipo tampoco
	# parezcan copias exactas.
	var detalle_x := -150 + float(semilla % 5) * 65.0
	var detalle_y := -20 + float((semilla / 7) % 4) * 25.0
	_agregar_rect(cuarto, "DetallePropio", Vector2(detalle_x, detalle_y), Vector2(18 + semilla % 17, 12 + semilla % 9), claro, 3)
	_agregar_rect(cuarto, "VentanaNorte", Vector2(-70, -132), Vector2(36, 5), Color(0.22,0.35,0.38), 4)
	_agregar_rect(cuarto, "VentanaEste", Vector2(220, -20), Vector2(5, 34), Color(0.22,0.35,0.38), 4)


func _agregar_colision_muro(padre: Node, nombre: String, posicion: Vector2, tamano: Vector2) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = nombre
	cuerpo.position = posicion
	var forma := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	forma.shape = rectangulo
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)


func _agregar_rect(padre: Node, nombre: String, posicion: Vector2, tamano: Vector2, color: Color, z: int) -> void:
	var pieza := Polygon2D.new()
	pieza.name = nombre
	pieza.position = posicion
	pieza.polygon = PackedVector2Array([
		Vector2(-tamano.x / 2.0, -tamano.y / 2.0),
		Vector2(tamano.x / 2.0, -tamano.y / 2.0),
		Vector2(tamano.x / 2.0, tamano.y / 2.0),
		Vector2(-tamano.x / 2.0, tamano.y / 2.0)
	])
	pieza.color = color
	pieza.z_index = z
	padre.add_child(pieza)


func _buscar_textura(paths: Array) -> Texture2D:
	for relative_path: String in paths:
		var full_path := TORRES_ART_ROOT.path_join(relative_path)
		if not ResourceLoader.exists(full_path):
			continue
		var resource := load(full_path)
		if resource is Texture2D:
			return resource as Texture2D
		push_warning("ReinoTorres: el recurso existe pero no es textura: " + full_path)
	return null


func _ocultar_placeholder(prefixes: Array) -> void:
	for child: Node in get_children():
		for prefix: String in prefixes:
			if child.name.begins_with(String(prefix)) and child is Polygon2D:
				(child as Polygon2D).visible = false
				break


func _elevar_rotulos() -> void:
	for child: Node in get_children():
		if child is Label:
			(child as Label).z_index = 10


func _al_entrar_salida(body: Node2D) -> void:
	if _transicionando:
		return
	if body == null or not body.is_in_group("player"):
		return

	_transicionando = true
	print("ReinoTorres: salida solicitada.")
	salida_solicitada.emit()
