extends Node2D

signal salida_solicitada

const TORRES_ART_ROOT := "res://assets/art/kingdom/torres"
const TORRES_PIXEL_ART := preload("res://scripts/world/torres_pixel_art.gd")
const TAMANO_PIXEL_MUNDO := 8.0
const TORRES_GRASS_ATLAS := "res://assets/tilesets/Torres_Cesped.png"
const TORRES_TILE_SIZE := 32
const CESPED_CORNERS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]

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
var _aviso_panel: PanelContainer
var _aviso: Label
var _entrada_aviso_actual: Dictionary = {}
var _cesped_dual: TileMapDual

# La cámara se limita a la habitación activa y recupera exactamente sus límites
# anteriores al salir, sin alterar el encuadre del exterior de Torres.
var _camara_interior: Camera2D = null
var _limites_camara_anteriores: Dictionary = {}

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
	_crear_cesped_tilemap_dual()
	_texturizar_mapa_pixelart()
	_cargar_arboles_pixelart()
	_cargar_puestos_pixelart()
	_cargar_sprites_de_torres()
	_crear_rotulos_edificios()


func _process(_delta: float) -> void:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_jugador):
		return

	if _interior_activo:
		# El interior es cerrado: limita la posición del jugador al área transitable.
		# La única salida es el umbral de la puerta, que devuelve al exterior automáticamente.
		var posicion_local := to_local(_jugador.global_position)
		posicion_local.x = clampf(posicion_local.x, -204.0, 204.0)
		posicion_local.y = clampf(posicion_local.y, -112.0, 108.0)
		_jugador.global_position = to_global(posicion_local)

		var umbral_salida := to_global(Vector2(60, 105))
		var cerca_salida := _jugador.global_position.distance_to(umbral_salida) < 30.0
		_entrada_aviso_actual.clear()
		_aviso_panel.visible = false
		_aviso.text = ""
		if cerca_salida:
			_salir_del_interior()
		return

	var entrada_cercana: Dictionary = {}
	var distancia_menor := 58.0
	for entrada: Dictionary in ENTRADAS:
		var distancia := _jugador.global_position.distance_to(to_global(entrada["pos"]))
		if distancia < distancia_menor:
			distancia_menor = distancia
			entrada_cercana = entrada

	_entrada_aviso_actual = entrada_cercana
	if entrada_cercana.is_empty():
		_aviso.text = ""
		_aviso_panel.visible = false
		return

	_aviso.text = "Entrar: " + str(entrada_cercana["nombre"]) + "   [Clic izq./der.]"
	_aviso_panel.visible = true
	_posicionar_aviso_sobre_jugador()



func _crear_rotulos_edificios() -> void:
	var ids_sin_rotulo := [
		"casa_oriente_a", "casa_oriente_b", "casa_oriente_c",
		"vivienda_oeste_01", "vivienda_oeste_02", "vivienda_oeste_03",
		"vivienda_oeste_04", "vivienda_oeste_05", "vivienda_oeste_06",
		"vivienda_oeste_07", "vivienda_oeste_08", "vivienda_oeste_09",
		"vivienda_oeste_10", "vivienda_oeste_11"
	]
	for entrada: Dictionary in ENTRADAS:
		var id := str(entrada.get("id", ""))
		if ids_sin_rotulo.has(id):
			continue
		var nombre := str(entrada.get("nombre", "")).strip_edges()
		if nombre.is_empty():
			continue

		var placa := PanelContainer.new()
		placa.name = "Rotulo_" + id
		placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placa.z_index = 20
		placa.position = Vector2(float(entrada["pos"].x) - 64.0, float(entrada["pos"].y) - 83.0)
		placa.custom_minimum_size = Vector2(128.0, 22.0)

		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Color("#24180F", 0.94)
		fondo.border_color = Color("#795638", 0.95)
		fondo.set_border_width_all(1)
		fondo.set_corner_radius_all(3)
		fondo.content_margin_left = 6.0
		fondo.content_margin_right = 6.0
		fondo.content_margin_top = 2.0
		fondo.content_margin_bottom = 2.0
		placa.add_theme_stylebox_override("panel", fondo)

		var texto := Label.new()
		texto.name = "Nombre"
		texto.text = nombre
		texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.add_theme_color_override("font_color", Color("#F3E4C5"))
		texto.add_theme_color_override("font_outline_color", Color("#21150E"))
		texto.add_theme_constant_override("outline_size", 2)
		texto.add_theme_font_size_override("font_size", 9)
		texto.clip_text = true
		placa.add_child(texto)
		add_child(placa)

func _crear_aviso() -> void:
	# Botón flotante compacto con el mismo acabado oscuro y borde cálido del menú Garumi.
	_aviso_panel = PanelContainer.new()
	_aviso_panel.name = "AvisoEntradaPanel"
	_aviso_panel.z_index = 50
	_aviso_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_panel.custom_minimum_size = Vector2(0.0, 30.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.105, 0.071, 0.043, 0.98)
	estilo.border_color = Color(0.48, 0.32, 0.17, 1.0)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 9.0
	estilo.content_margin_right = 9.0
	estilo.content_margin_top = 4.0
	estilo.content_margin_bottom = 4.0
	_aviso_panel.add_theme_stylebox_override("panel", estilo)
	var hover := estilo.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.19, 0.125, 0.065, 1.0)
	hover.border_color = Color(0.76, 0.54, 0.29, 1.0)
	_aviso_panel.add_theme_stylebox_override("panel", estilo)
	_aviso_panel.set_meta("estilo_normal", estilo)
	_aviso_panel.set_meta("estilo_hover", hover)
	_aviso_panel.mouse_entered.connect(_al_entrar_aviso)
	_aviso_panel.mouse_exited.connect(_al_salir_aviso)

	_aviso = Label.new()
	_aviso.name = "AvisoEntrada"
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.add_theme_color_override("font_color", Color(0.91, 0.83, 0.70, 1.0))
	_aviso.add_theme_font_size_override("font_size", 11)
	_aviso_panel.add_child(_aviso)
	_aviso_panel.visible = false
	var capa_ui := CanvasLayer.new()
	capa_ui.name = "AvisoEntradaLayer"
	capa_ui.layer = 110
	add_child(capa_ui)
	capa_ui.add_child(_aviso_panel)


func _posicionar_aviso_sobre_jugador() -> void:
	if not is_instance_valid(_aviso_panel) or not is_instance_valid(_jugador):
		return
	var posicion_pantalla: Vector2 = _jugador.get_global_transform_with_canvas().origin
	var tamano := _aviso_panel.get_combined_minimum_size()
	_aviso_panel.size = tamano
	var viewport := get_viewport().get_visible_rect().size
	_aviso_panel.position = Vector2(
		clampf(posicion_pantalla.x - tamano.x * 0.5, 8.0, maxf(8.0, viewport.x - tamano.x - 8.0)),
		clampf(posicion_pantalla.y - tamano.y - 24.0, 8.0, maxf(8.0, viewport.y - tamano.y - 8.0))
	)


func _al_entrar_aviso() -> void:
	if is_instance_valid(_aviso_panel):
		_aviso_panel.add_theme_stylebox_override("panel", _aviso_panel.get_meta("estilo_hover") as StyleBoxFlat)


func _al_salir_aviso() -> void:
	if is_instance_valid(_aviso_panel):
		_aviso_panel.add_theme_stylebox_override("panel", _aviso_panel.get_meta("estilo_normal") as StyleBoxFlat)


func _input(evento: InputEvent) -> void:
	# Mientras haya una entrada/salida al alcance, el clic se consume aquí,
	# independientemente de dónde esté el cursor, antes de que llegue al combate.
	if _entrada_aviso_actual.is_empty() or not _aviso_panel.visible:
		return
	if not evento is InputEventMouseButton:
		return
	var clic := evento as InputEventMouseButton
	if not clic.pressed or clic.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	get_viewport().set_input_as_handled()
	var accion := _entrada_aviso_actual.duplicate(true)
	if bool(accion.get("salir", false)):
		_salir_del_interior()
	else:
		_entrar_al_interior(accion)


func _crear_cesped_tilemap_dual() -> void:
	# El suelo del reino usa Dual Grid real: cada atlas tile define sus cuatro
	# cuadrantes y TileMapDual resuelve bordes/esquinas según las celdas vecinas.
	var textura: Texture2D = load(TORRES_GRASS_ATLAS) as Texture2D
	if textura == null:
		push_error("ReinoTorres: no se pudo cargar el atlas de césped: " + TORRES_GRASS_ATLAS)
		return
	if textura.get_size() != Vector2(TORRES_TILE_SIZE * 4, TORRES_TILE_SIZE * 4):
		push_error("ReinoTorres: Torres_Cesped.png debe ser un atlas de 128x128 con tiles de 32x32.")
		return

	var conjunto := TileSet.new()
	conjunto.tile_size = Vector2i(TORRES_TILE_SIZE, TORRES_TILE_SIZE)
	conjunto.add_terrain_set()
	conjunto.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	conjunto.add_terrain(0)
	conjunto.set_terrain_name(0, 0, "<any>")
	conjunto.add_terrain(0)
	conjunto.set_terrain_name(0, 1, "Césped de Torres")

	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TORRES_TILE_SIZE, TORRES_TILE_SIZE)
	for mascara in range(16):
		atlas.create_tile(Vector2i(mascara % 4, int(mascara / 4)))
	conjunto.add_source(atlas, 0)

	# El índice de máscara usa el mismo orden que el atlas: TL, TR, BL, BR.
	# Se registra el terreno en cada tile para que el addon pueda componer sus
	# DisplayLayer sin una textura completa opaca por debajo de los bordes.
	for mascara in range(16):
		var coordenada := Vector2i(mascara % 4, int(mascara / 4))
		var datos := atlas.get_tile_data(coordenada, 0)
		datos.terrain_set = 0
		datos.terrain = 1
		for bit_index in range(CESPED_CORNERS.size()):
			var conectado := 1 if (mascara & (1 << bit_index)) != 0 else 0
			datos.set_terrain_peering_bit(CESPED_CORNERS[bit_index], conectado)

	_cesped_dual = TileMapDual.new()
	_cesped_dual.name = "TorresCespedDual"
	_cesped_dual.tile_set = conjunto
	_cesped_dual.position = Vector2(-1200, -704)
	_cesped_dual.z_as_relative = false
	_cesped_dual.z_index = -19
	_cesped_dual.rendering_quadrant_size = 16
	_cesped_dual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_cesped_dual)

	# 75 x 44 celdas cubren el suelo de Torres a 32 px por tile. Se mantiene
	# Ground como base de color detrás de las esquinas transparentes del atlas.
	for y in range(44):
		for x in range(75):
			_cesped_dual.set_cell(Vector2i(x, y), 0, Vector2i(3, 3))

	print("ReinoTorres: césped TileMapDual listo (75x44 celdas, atlas propio).")


func _texturizar_mapa_pixelart() -> void:
	# Sustituye las superficies planas por texturas rasterizadas a baja resolución.
	var superficies: Array[Dictionary] = [
		{"nombre": "NorthPath", "tipo": "camino"},
		{"nombre": "MainStreet", "tipo": "camino"},
		{"nombre": "WestStreet", "tipo": "camino"},
		{"nombre": "EastStreet", "tipo": "camino"},
		{"nombre": "SouthPath", "tipo": "camino"},
		{"nombre": "NorthRingRoad", "tipo": "camino"},
		{"nombre": "SouthRingRoad", "tipo": "camino"},
		{"nombre": "WestRingRoad", "tipo": "camino"},
		{"nombre": "EastRingRoad", "tipo": "camino"},
		{"nombre": "NorthCrossStreet", "tipo": "camino"},
		{"nombre": "SouthCrossStreet", "tipo": "camino"},
		{"nombre": "WestCrossStreet", "tipo": "camino"},
		{"nombre": "EastCrossStreet", "tipo": "camino"},
		{"nombre": "Plaza", "tipo": "plaza"},
		{"nombre": "PlazaInset", "tipo": "plaza"},
		{"nombre": "RoadToWorld", "tipo": "camino"},
		{"nombre": "CanalBankNorth", "tipo": "ribera"},
		{"nombre": "CanalBankSouth", "tipo": "ribera"},
		{"nombre": "CanalWater", "tipo": "agua"},
		{"nombre": "CanalBridgeWest", "tipo": "puente"},
		{"nombre": "CanalBridgeEast", "tipo": "puente"},
		{"nombre": "RoyalGardenPlot", "tipo": "jardin"},
		{"nombre": "RoyalGardenWalk", "tipo": "plaza"},
		{"nombre": "RoyalGardenCross", "tipo": "plaza"},
		{"nombre": "GardenBed", "tipo": "jardin"},
		{"nombre": "GardenSoil", "tipo": "tierra"},
		{"nombre": "EastGatePierNorth", "tipo": "muro"},
		{"nombre": "EastGatePierSouth", "tipo": "muro"},
		{"nombre": "EastGateLintel", "tipo": "muro"},
		{"nombre": "WestOuterWall", "tipo": "muro"},
		{"nombre": "NorthOuterWall", "tipo": "muro"},
		{"nombre": "SouthOuterWall", "tipo": "muro"},
		{"nombre": "EastOuterWallNorth", "tipo": "muro"},
		{"nombre": "EastOuterWallSouth", "tipo": "muro"}
	]
	for i in range(superficies.size()):
		var superficie: Dictionary = superficies[i]
		_texturizar_poligono(str(superficie["nombre"]), str(superficie["tipo"]), i * 17)

	# Los cultivos tienen surcos y hojas integrados en el propio sprite.
	for hijo: Node in get_children():
		if hijo is Polygon2D and String(hijo.name).begins_with("FieldFurrow"):
			(hijo as Polygon2D).visible = false
	for indice in range(1, 17):
		_texturizar_poligono("Field%d" % indice, "cultivo", indice * 31)
	for indice in range(1, 5):
		_texturizar_poligono("GardenCrop%d" % indice, "cultivo", indice * 23)

	# Las líneas finas que remataban el camino eran vectoriales; los bordes
	# ahora forman parte de la textura pixelada del camino.
	for nombre_borde in ["RoadEdgeTop", "RoadEdgeBottom"]:
		var borde := get_node_or_null(NodePath(nombre_borde)) as Polygon2D
		if is_instance_valid(borde):
			borde.visible = false


func _texturizar_poligono(nombre: String, tipo: String, semilla: int = 0) -> void:
	var poligono := get_node_or_null(NodePath(nombre)) as Polygon2D
	if not is_instance_valid(poligono) or poligono.polygon.size() < 3:
		return
	var limites := _limites_de_poligono(poligono)
	if limites.size.x <= 0.0 or limites.size.y <= 0.0:
		return
	var ancho_textura := maxi(1, ceili(limites.size.x / TAMANO_PIXEL_MUNDO))
	var alto_textura := maxi(1, ceili(limites.size.y / TAMANO_PIXEL_MUNDO))
	var textura := TORRES_PIXEL_ART.crear_superficie(tipo, Vector2i(ancho_textura, alto_textura), semilla)
	var sprite := Sprite2D.new()
	sprite.name = "Pixel_" + nombre
	sprite.texture = textura
	sprite.position = limites.get_center()
	sprite.centered = true
	sprite.scale = Vector2(limites.size.x / float(ancho_textura), limites.size.y / float(alto_textura))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = poligono.z_index
	add_child(sprite)
	poligono.visible = false


func _cargar_arboles_pixelart() -> void:
	var grupos: Dictionary = {}
	for hijo: Node in get_children():
		if not hijo is Polygon2D:
			continue
		var nombre := String(hijo.name)
		var sufijo := ""
		if nombre.ends_with("Trunk"):
			sufijo = "tronco"
		elif nombre.ends_with("Crown"):
			sufijo = "copa"
		if sufijo.is_empty():
			continue
		var prefijo := nombre.trim_suffix("Trunk") if sufijo == "tronco" else nombre.trim_suffix("Crown")
		if not grupos.has(prefijo):
			grupos[prefijo] = {}
		var grupo: Dictionary = grupos[prefijo]
		grupo[sufijo] = hijo as Polygon2D
		grupos[prefijo] = grupo

	for prefijo in grupos.keys():
		var grupo: Dictionary = grupos[prefijo]
		if not grupo.has("tronco") or not grupo.has("copa"):
			continue
		var tronco: Polygon2D = grupo["tronco"]
		var copa: Polygon2D = grupo["copa"]
		var limites := _limites_de_poligono(tronco).merge(_limites_de_poligono(copa))
		var textura: Texture2D = TORRES_PIXEL_ART.crear_decoracion("arbol", absi(String(prefijo).hash()) % 5)
		_agregar_sprite_pixelart("Pixel_" + String(prefijo), textura, limites, maxi(tronco.z_index, copa.z_index))
		tronco.visible = false
		copa.visible = false


func _cargar_puestos_pixelart() -> void:
	_agrupar_poligonos_pixelart(
		["MarketCounter", "MarketCounterTop", "MarketAwningBase", "MarketAwningStripe1", "MarketAwningStripe2", "MarketAwningStripe3"],
		"puesto", 0
	)
	_agrupar_poligonos_pixelart(
		["FishStall", "FishStallAwning", "FishStallStripe"],
		"puesto_azul", 1
	)
	for indice in range(1, 5):
		_agrupar_poligonos_pixelart(
			["MarketExtension%d" % indice, "MarketExtensionAwning%d" % indice, "MarketExtensionLegL%d" % indice, "MarketExtensionLegR%d" % indice],
			"puesto" if indice % 2 == 0 else "puesto_azul", indice
		)
	_agrupar_poligonos_pixelart(
		["WellShadow", "WellOuter", "WellWater", "WellLipTop"],
		"pozo", 0
	)
	_agrupar_poligonos_pixelart(
		["LampWestPost", "LampWestGlow"],
		"lampara", 0
	)
	_agrupar_poligonos_pixelart(
		["LampEastPost", "LampEastGlow"],
		"lampara", 1
	)


func _agrupar_poligonos_pixelart(nombres: Array, tipo: String, variante: int) -> void:
	var limites := Rect2()
	var primero := true
	var z_mayor := -100
	var encontrados: Array[Polygon2D] = []
	for valor: Variant in nombres:
		var poligono := get_node_or_null(NodePath(String(valor))) as Polygon2D
		if not is_instance_valid(poligono) or poligono.polygon.size() < 3:
			continue
		var limite_poligono := _limites_de_poligono(poligono)
		if primero:
			limites = limite_poligono
			primero = false
		else:
			limites = limites.merge(limite_poligono)
		z_mayor = maxi(z_mayor, poligono.z_index)
		encontrados.append(poligono)
	if primero:
		return
	var textura: Texture2D = TORRES_PIXEL_ART.crear_decoracion(tipo, variante)
	_agregar_sprite_pixelart("Pixel_" + tipo.capitalize() + "_" + str(variante), textura, limites, z_mayor)
	for poligono: Polygon2D in encontrados:
		poligono.visible = false


func _limites_de_poligono(poligono: Polygon2D) -> Rect2:
	var puntos := poligono.polygon
	if puntos.is_empty():
		return Rect2()
	var primer_punto: Vector2 = poligono.transform * puntos[0]
	var limites := Rect2(primer_punto, Vector2.ZERO)
	for punto: Vector2 in puntos:
		limites = limites.expand(poligono.transform * punto)
	return limites


func _agregar_sprite_pixelart(nombre: String, textura: Texture2D, limites: Rect2, z: int) -> void:
	if textura == null or limites.size.x <= 0.0 or limites.size.y <= 0.0:
		return
	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = textura
	sprite.position = limites.get_center()
	sprite.centered = true
	sprite.scale = Vector2(limites.size.x / textura.get_width(), limites.size.y / textura.get_height())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z
	add_child(sprite)


func _cargar_sprites_de_torres() -> void:
	for building: Dictionary in SPRITE_BUILDINGS:
		var clave := String(building["key"])
		var texture := _buscar_textura(building["paths"])
		var tiene_textura_personalizada := texture != null
		if not tiene_textura_personalizada:
			texture = TORRES_PIXEL_ART.crear_edificio(clave, absi(clave.hash()) % 7)

		# Oculta la geometría plana conservando rótulos, entradas y colisiones.
		_ocultar_placeholder(building["hide"])
		var sprite := Sprite2D.new()
		sprite.name = "Sprite_" + clave.capitalize()
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
		if tiene_textura_personalizada:
			print("ReinoTorres: sprite externo cargado para ", clave)
		else:
			print("ReinoTorres: pixel art procedural cargado para ", clave)




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
	_jugador.global_position = to_global(Vector2(0, 70))
	_limitar_camara_a_interior()
	_interterior_colisiones(true)
	_interior_activo = true
	_aviso_panel.visible = false
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
	_restaurar_limites_camara()
	_jugador.global_position = _posicion_exterior
	for hijo: Node in _capa_interior.get_children():
		hijo.free()
	_interterior_colisiones(false)
	_interior_activo = false
	_aviso_panel.visible = false
	_aviso.text = ""
	print("ReinoTorres: regreso al exterior.")


func _limitar_camara_a_interior() -> void:
	_camara_interior = get_viewport().get_camera_2d()
	if not is_instance_valid(_camara_interior):
		push_warning("ReinoTorres: no se encontró Camera2D para limitar el interior.")
		return

	_limites_camara_anteriores = {
		"left": _camara_interior.limit_left,
		"top": _camara_interior.limit_top,
		"right": _camara_interior.limit_right,
		"bottom": _camara_interior.limit_bottom,
		"enabled": _camara_interior.limit_enabled,
	}
	# Coincide con los bordes exteriores de la habitación (incluyendo los muros).
	var esquina_superior_izquierda := to_global(Vector2(-228, -139))
	var esquina_inferior_derecha := to_global(Vector2(228, 139))
	_camara_interior.limit_left = floori(esquina_superior_izquierda.x)
	_camara_interior.limit_top = floori(esquina_superior_izquierda.y)
	_camara_interior.limit_right = ceili(esquina_inferior_derecha.x)
	_camara_interior.limit_bottom = ceili(esquina_inferior_derecha.y)
	_camara_interior.limit_enabled = true
	_camara_interior.reset_smoothing()
	print("ReinoTorres: cámara limitada al interior.")


func _restaurar_limites_camara() -> void:
	if not is_instance_valid(_camara_interior) or _limites_camara_anteriores.is_empty():
		_camara_interior = null
		_limites_camara_anteriores.clear()
		return

	_camara_interior.limit_left = int(_limites_camara_anteriores.get("left", -10000000))
	_camara_interior.limit_top = int(_limites_camara_anteriores.get("top", -10000000))
	_camara_interior.limit_right = int(_limites_camara_anteriores.get("right", 10000000))
	_camara_interior.limit_bottom = int(_limites_camara_anteriores.get("bottom", 10000000))
	_camara_interior.limit_enabled = bool(_limites_camara_anteriores.get("enabled", false))
	_camara_interior.reset_smoothing()
	_camara_interior = null
	_limites_camara_anteriores.clear()
	print("ReinoTorres: límites de cámara exteriores restaurados.")


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
	var detalle_y := -20 + float(int(semilla / 7) % 4) * 25.0
	_agregar_rect(cuarto, "DetallePropio", Vector2(detalle_x, detalle_y), Vector2(18 + semilla % 17, 12 + semilla % 9), claro, 3)
	var paleta: Array[Color] = [madera, acento, piedra, claro, Color(0.40, 0.31, 0.25)]
	for i in range(4):
		var objeto_x := -175.0 + float(int(semilla / (i + 3)) % 8) * 40.0
		var objeto_y := -100.0 + float(int(semilla / (i + 7)) % 5) * 26.0
		var objeto_tamano := Vector2(12 + int(semilla / (i + 2)) % 18, 10 + int(semilla / (i + 5)) % 15)
		_agregar_rect(cuarto, "ObjetoPropio%d" % i, Vector2(objeto_x, objeto_y), objeto_tamano, paleta[int(semilla / (i + 1)) % paleta.size()], 3)
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




func _al_entrar_salida(body: Node2D) -> void:
	if _transicionando:
		return
	if body == null or not body.is_in_group("player"):
		return

	_transicionando = true
	print("ReinoTorres: salida solicitada.")
	salida_solicitada.emit()
