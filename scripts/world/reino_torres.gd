extends Node2D

signal salida_solicitada
signal destino_viaje_solicitado(destino_id: String)

const TORRES_ART_ROOT := "res://assets/art/kingdom/torres"
const TORRES_PIXEL_ART := preload("res://scripts/world/torres_pixel_art.gd")
const ARBOL_PROP_TEXTURE: Texture2D = preload("res://assets/art/props/Árbol.png")
const MUEBLE_CAMA: Texture2D = preload("res://assets/art/places/Muebles/cama.png")
const MUEBLE_MESA: Texture2D = preload("res://assets/art/places/Muebles/mesa.png")
const MUEBLE_HORNO: Texture2D = preload("res://assets/art/places/Muebles/horno.png")
const MUEBLE_COFRE: Texture2D = preload("res://assets/art/places/Muebles/cofre.png")
const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")
const CONTEXTUAL_ACTION_TARGET_SCRIPT = preload("res://scripts/gameplay/interaction/contextual_action_target.gd")
const WORLD_INTERACTABLE_SCRIPT = preload("res://scripts/gameplay/interaction/world_interactable.gd")
const TAMANO_PIXEL_MUNDO := 8.0

# Ampliación moderada respecto al interior original (448x272).
# Mantiene el espacio compacto y reduce los bordes visibles sin vaciar la sala.
const INTERIOR_ANCHO := 560.0
const INTERIOR_ALTO := 352.0
const INTERIOR_MEDIO_ANCHO := INTERIOR_ANCHO / 2.0
const INTERIOR_MEDIO_ALTO := INTERIOR_ALTO / 2.0

# Cada edificio intenta primero su sprite específico y después uno genérico.
# Los recursos ausentes conservan únicamente su estructura pixel-art disponible.
const SPRITE_BUILDINGS: Array[Dictionary] = [
	{"key":"castillo", "paths":["res://assets/art/places/Castillo.png","castillo.png","edificios/castillo.png"], "position":Vector2(0,-205), "size":Vector2(230,190), "hide":["CastleKeep","CastleFacade","CastleRoof","CastleDoor","CastleWindow","CastleTower"]},
	{"key":"panaderia", "paths":["res://assets/art/places/Panaderia.png","casas/panaderia.png","edificios/panaderia.png","casas/casa.png"], "position":Vector2(-245,-157), "size":Vector2(96,92), "hide":["HouseBaker"]},
	{"key":"posada", "paths":["res://assets/art/places/Posada.png","casas/posada.png","edificios/posada.png","casas/casa.png"], "position":Vector2(-385,52), "size":Vector2(104,102), "hide":["HouseInn"]},
	{"key":"casa_bruna", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_mason.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-235,152), "size":Vector2(96,88), "hide":["HouseMason"]},
	{"key":"casa_elian", "paths":["res://assets/art/places/Casa_Comun.png","casas/casa_oriente_a.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(220,-158), "size":Vector2(96,90), "hide":["HouseEastA"]},
	{"key":"casa_darven", "paths":["res://assets/art/places/Casa_Comun.png","casas/casa_oriente_b.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(385,-148), "size":Vector2(96,90), "hide":["HouseEastB"]},
	{"key":"casa_saira", "paths":["res://assets/art/places/Casa_Comun.png","casas/casa_oriente_c.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(385,118), "size":Vector2(96,92), "hide":["HouseEastC"]},
	{"key":"forja", "paths":["res://assets/art/places/Forja.png","edificios/forja.png","edificios/taller.png"], "position":Vector2(-360,-201), "size":Vector2(104,92), "hide":["ForgeBase","ForgeRoof","ForgeOpening","ForgeFire"]},
	{"key":"archivo_real", "paths":["res://assets/art/places/Archivo_Real.png"], "position":Vector2(-170,-657), "size":Vector2(116,94), "hide":["RoyalArchive"]},
	{"key":"sala_consejo", "paths":["res://assets/art/places/Sala_del_Consejo.png"], "position":Vector2(170,-658), "size":Vector2(132,104), "hide":["CouncilHall"]},
	{"key":"casa_estudio", "paths":["res://assets/art/places/Casa_de_Estudio_Oris.png"], "position":Vector2(-410,-564), "size":Vector2(122,98), "hide":["OrisStudy","StudyDome"]},
	{"key":"casa_comercio", "paths":["res://assets/art/places/Casa_de_Comercio.png"], "position":Vector2(930,-358), "size":Vector2(122,100), "hide":["TradeHouse"]},
	{"key":"cuartel", "paths":["edificios/cuartel.png","edificios/edificio.png"], "position":Vector2(730,-358), "size":Vector2(126,104), "hide":["GuardBarracks"]},
	{"key":"registro", "paths":["res://assets/art/places/Registro_de_la_Puerta.png"], "position":Vector2(730,-250), "size":Vector2(108,90), "hide":["GateOffice"]},
	{"key":"reparaciones", "paths":["res://assets/art/places/Taller_de_Reparaciones.png"], "position":Vector2(930,102), "size":Vector2(118,96), "hide":["RepairWorkshop"]},
	{"key":"carpinteria", "paths":["edificios/carpinteria.png","edificios/taller.png","edificios/edificio.png"], "position":Vector2(930,212), "size":Vector2(114,96), "hide":["Cartwright"]},
	{"key":"granero", "paths":["res://assets/art/places/Granero.png"], "position":Vector2(-450,257), "size":Vector2(124,102), "hide":["GrainStore"]},
	{"key":"molino", "paths":["res://assets/art/places/Molino.png"], "position":Vector2(-270,257), "size":Vector2(114,96), "hide":["MillHouse"]},
	{"key":"corrales", "paths":["res://assets/art/places/Corrales.png"], "position":Vector2(450,257), "size":Vector2(122,100), "hide":["AnimalPens"]},
	{"key":"casa_granjeros", "paths":["res://assets/art/places/Casa_Comun.png","edificios/casa_granjeros.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-850,602), "size":Vector2(126,102), "hide":["FarmersHall"]},
	{"key":"vivienda_oeste_01", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_01.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,-354), "size":Vector2(84,82), "hide":["WestHome1Wall","WestHome1Roof","WestHome1Door","WestHome1CollisionBody"]},
	{"key":"vivienda_oeste_02", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_02.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,-354), "size":Vector2(84,82), "hide":["WestHome2Wall","WestHome2Roof","WestHome2Door","WestHome2CollisionBody"]},
	{"key":"vivienda_oeste_03", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_03.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,-254), "size":Vector2(84,82), "hide":["WestHome3Wall","WestHome3Roof","WestHome3Door","WestHome3CollisionBody"]},
	{"key":"vivienda_oeste_04", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_04.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,-254), "size":Vector2(84,82), "hide":["WestHome4Wall","WestHome4Roof","WestHome4Door","WestHome4CollisionBody"]},
	{"key":"vivienda_oeste_05", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_05.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,106), "size":Vector2(84,82), "hide":["WestHome5Wall","WestHome5Roof","WestHome5Door","WestHome5CollisionBody"]},
	{"key":"vivienda_oeste_06", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_06.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,106), "size":Vector2(84,82), "hide":["WestHome6Wall","WestHome6Roof","WestHome6Door","WestHome6CollisionBody"]},
	{"key":"vivienda_oeste_07", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_07.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1040,216), "size":Vector2(84,82), "hide":["WestHome7Wall","WestHome7Roof","WestHome7Door","WestHome7CollisionBody"]},
	{"key":"vivienda_oeste_08", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_08.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-930,216), "size":Vector2(84,82), "hide":["WestHome8Wall","WestHome8Roof","WestHome8Door","WestHome8CollisionBody"]},
	{"key":"casa_narel", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_09.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-520,-254), "size":Vector2(84,82), "hide":["WestHome9Wall","WestHome9Roof","WestHome9Door","WestHome9CollisionBody"]},
	{"key":"vivienda_oeste_10", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_10.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-520,96), "size":Vector2(84,82), "hide":["WestHome10Wall","WestHome10Roof","WestHome10Door","WestHome10CollisionBody"]},
	{"key":"vivienda_oeste_11", "paths":["res://assets/art/places/Casa_Comun.png","casas/vivienda_oeste_11.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-520,206), "size":Vector2(84,82), "hide":["WestHome11Wall","WestHome11Roof","WestHome11Door","WestHome11CollisionBody"]}
]

@onready var _expedition_entrance: Area2D = $ExpeditionEntrance

var _transicionando: bool = false
var _interior_activo: bool = false
var _entrada_interior_id: String = ""
var _jugador: Node2D
var _posicion_exterior: Vector2 = Vector2.ZERO
var _visibilidad_exterior: Dictionary = {}
var _visibilidad_npcs_exterior: Dictionary = {}
var _contenedor_npcs_exterior: Node = null
var _estados_colision_exterior: Dictionary = {}
var _capa_interior: Node2D
var _aviso_panel: PanelContainer
var _aviso: Label
var _boton_entrar: Button
var _entrada_aviso_actual: Dictionary = {}
var _objetivos_entrada: Array[Node2D] = []
var _terreno_dual_listo: bool = false
var _atmosfera_mundo: Node = null
var _luces_faroles: Array[PointLight2D] = []
var _brillos_faroles: Array[Sprite2D] = []
var _capa_brillos_faroles: CanvasLayer = null

# La cámara se limita a la habitación activa y recupera exactamente sus límites
# anteriores al salir, sin alterar el encuadre del exterior de Torres.
var _camara_interior: Camera2D = null
var _selector_viajes_layer: CanvasLayer
var _selector_viajes_root: Control
var _selector_viajes_center: CenterContainer
var _selector_viajes_panel: PanelContainer
var _limites_camara_anteriores: Dictionary = {}

# Las entradas están cerca de la fachada de cada edificio. Cada clave tiene
# su propio nombre, función y distribución interior.
const DISTANCIA_INTERACCION_ENTRADA := 44.0

const ENTRADAS: Array[Dictionary] = [
	{"id":"castillo","nombre":"Castillo de Torres","pos":Vector2(0,-125),"tipo":"castillo"},
	{"id":"panaderia","nombre":"Panadería","pos":Vector2(-245,-117),"tipo":"panaderia"},
	{"id":"posada","nombre":"Posada","pos":Vector2(-385,97),"tipo":"posada"},
	{"id":"vivienda_mason","nombre":"Casa de Bruna","pos":Vector2(-235,193),"tipo":"vivienda"},
	{"id":"casa_oriente_a","nombre":"Casa de Elian","pos":Vector2(220,-117),"tipo":"vivienda"},
	{"id":"casa_oriente_b","nombre":"Casa de Darven","pos":Vector2(385,-108),"tipo":"vivienda"},
	{"id":"casa_oriente_c","nombre":"Casa de Saira","pos":Vector2(385,173),"tipo":"vivienda"},
	{"id":"forja","nombre":"Forja","pos":Vector2(-360,-159),"tipo":"forja"},
	{"id":"archivo_real","nombre":"Archivo real","pos":Vector2(-170,-610),"tipo":"archivo"},
	{"id":"sala_consejo","nombre":"Sala del consejo","pos":Vector2(170,-605),"tipo":"consejo"},
	{"id":"casa_estudio","nombre":"Casa de estudio de Oris","pos":Vector2(-410,-520),"tipo":"oris"},
	{"id":"casa_comercio","nombre":"Casa de comercio","pos":Vector2(930,-310),"tipo":"comercio"},
	{"id":"cuartel","nombre":"Cuartel de la guardia","pos":Vector2(730,-310),"tipo":"cuartel"},
	{"id":"registro","nombre":"Registro de la puerta","pos":Vector2(730,-210),"tipo":"registro"},
	{"id":"reparaciones","nombre":"Taller de reparaciones","pos":Vector2(930,145),"tipo":"taller"},
	{"id":"carpinteria","nombre":"Carpintería","pos":Vector2(930,255),"tipo":"carpinteria"},
	{"id":"granero","nombre":"Granero","pos":Vector2(-450,300),"tipo":"granero"},
	{"id":"molino","nombre":"Molino","pos":Vector2(-270,300),"tipo":"molino"},
	{"id":"corrales","nombre":"Corrales","pos":Vector2(450,300),"tipo":"corrales"},
	{"id":"casa_granjeros","nombre":"Casa de los agricultores","pos":Vector2(-850,650),"tipo":"vivienda"},
	{"id":"vivienda_oeste_01","nombre":"Casa vacía","pos":Vector2(-1040,-313),"tipo":"vivienda"},
	{"id":"vivienda_oeste_02","nombre":"Casa vacía","pos":Vector2(-930,-313),"tipo":"vivienda"},
	{"id":"vivienda_oeste_03","nombre":"Casa vacía","pos":Vector2(-1040,-213),"tipo":"vivienda"},
	{"id":"vivienda_oeste_04","nombre":"Casa vacía","pos":Vector2(-930,-213),"tipo":"vivienda"},
	{"id":"vivienda_oeste_05","nombre":"Casa vacía","pos":Vector2(-1040,147),"tipo":"vivienda"},
	{"id":"vivienda_oeste_06","nombre":"Casa vacía","pos":Vector2(-930,147),"tipo":"vivienda"},
	{"id":"vivienda_oeste_07","nombre":"Casa vacía","pos":Vector2(-1040,257),"tipo":"vivienda"},
	{"id":"vivienda_oeste_08","nombre":"Casa vacía","pos":Vector2(-930,257),"tipo":"vivienda"},
	{"id":"vivienda_oeste_09","nombre":"Casa de Narel","pos":Vector2(-520,-213),"tipo":"vivienda"},
	{"id":"vivienda_oeste_10","nombre":"Casa vacía","pos":Vector2(-520,137),"tipo":"vivienda"},
	{"id":"vivienda_oeste_11","nombre":"Casa vacía","pos":Vector2(-520,247),"tipo":"vivienda"}
]


func _ready() -> void:
	_expedition_entrance.body_entered.connect(_al_entrar_entrada_expedicion)
	_expedition_entrance.body_exited.connect(_al_salir_entrada_expedicion)
	_crear_selector_viajes()
	_jugador = get_tree().get_first_node_in_group("player") as Node2D
	_capa_interior = Node2D.new()
	_capa_interior.name = "InteriorActivo"
	_capa_interior.visible = false
	add_child(_capa_interior)
	_crear_aviso()
	_crear_objetivos_entrada()
	# Preparar primero todos los elementos que sustituyen polígonos vectoriales.
	# Esta fase es síncrona: no debe quedar un frame donde Torres muestre sus
	# superficies de diseño antes de recibir sus sprites definitivos.
	_texturizar_mapa_pixelart()
	_cargar_arboles_pixelart()
	_cargar_puestos_pixelart()
	_cargar_sprites_de_torres()
	_crear_luces_faroles()
	# Las capas estáticas deben reconstruir su caché antes de añadir
	# elementos procedurales. En Godot 4.4+ TileMapDual no infiere los cambios
	# iniciales de las celdas serializadas de la escena.
	await _crear_cesped_tilemap_dual()
	await _crear_muralla_montana()
	await _crear_rio_marino_tilemap()



func _crear_rio_marino_tilemap() -> void:
	# El río reutiliza el compositor TileMapDual y el atlas Marino del mundo.
	# Su origen se ajusta al antiguo cauce: 59 celdas de 32 px forman una
	# franja continua entre los dos puentes, sin geometría vectorial.
	var terreno := WorldTerrainVisual.new()
	terreno.name = "TerrenoRioMarino"
	terreno.position = Vector2(-1184, -694)
	add_child(terreno)
	terreno.configurar(32)

	# El agua debe quedar sobre el suelo opaco y bajo los puentes.
	# WorldTerrainVisual usa por defecto z_index ~ -4091, apropiado para
	# terrenos de fondo como la muralla, pero demasiado bajo para el canal.
	for hijo in terreno.get_children():
		if hijo is TileMapDual:
			hijo.z_index = -8
			hijo.z_as_relative = false

	# TileMapDual crea sus Display durante _ready(); esperar antes de pintar.
	await get_tree().process_frame
	await get_tree().process_frame
	terreno.finalizar_preparacion_renderer()

	for x in range(2, 61):
		terreno.set_zone(Vector2i(x, 38), 4, 4, "Marino")

	terreno.flush()
	print("ReinoTorres: río Marino creado con TileMapDual.")



func _process(_delta: float) -> void:
	_actualizar_luces_faroles()
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_jugador):
		return

	if _interior_activo:
		# El interior es cerrado: limita la posición del jugador al área transitable.
		# La única salida es el umbral de la puerta, que devuelve al exterior automáticamente.
		var posicion_local := to_local(_jugador.global_position)
		posicion_local.x = clampf(posicion_local.x, -INTERIOR_MEDIO_ANCHO + 30.0, INTERIOR_MEDIO_ANCHO - 30.0)
		posicion_local.y = clampf(posicion_local.y, -INTERIOR_MEDIO_ALTO + 30.0, INTERIOR_MEDIO_ALTO - 40.0)
		_jugador.global_position = to_global(posicion_local)

		var cerca_salida := posicion_local.y >= INTERIOR_MEDIO_ALTO - 60.0 \
			and posicion_local.x >= -12.0 \
			and posicion_local.x <= 132.0
		_entrada_aviso_actual.clear()
		_boton_entrar.visible = false
		_aviso_panel.visible = false
		_aviso.text = ""
		if cerca_salida:
			_salir_del_interior()
		return

	var entrada_cercana: Dictionary = {}
	# El cuerpo del jugador puede quedar separado del punto de puerta por las colisiones de fachada.
	var distancia_menor := DISTANCIA_INTERACCION_ENTRADA
	var posicion_jugador_local := to_local(_jugador.global_position)
	for entrada: Dictionary in ENTRADAS:
		var distancia := posicion_jugador_local.distance_to(entrada["pos"])
		if distancia < distancia_menor:
			distancia_menor = distancia
			entrada_cercana = entrada

	_entrada_aviso_actual = entrada_cercana
	if entrada_cercana.is_empty():
		_aviso.text = ""
		_aviso_panel.visible = false
		_boton_entrar.visible = false
		return

	_aviso.text = ""
	_aviso_panel.visible = false
	_boton_entrar.visible = false



func _crear_objetivos_entrada() -> void:
	for entrada: Dictionary in ENTRADAS:
		var objetivo: Node2D = CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
		if not is_instance_valid(objetivo):
			continue
		objetivo.name = "ObjetivoEntrada_" + str(entrada.get("id", "edificio"))
		objetivo.position = entrada.get("pos", Vector2.ZERO)
		var nombre_lugar := str(entrada.get("nombre", "este lugar")).strip_edges()
		var texto_interaccion := "Entrar: " + nombre_lugar
		objetivo.call(
			"configurar",
			texto_interaccion,
			DISTANCIA_INTERACCION_ENTRADA,
			Callable(self, "_puede_interactuar_entrada").bind(entrada),
			Callable(self, "_interactuar_entrada").bind(entrada)
		)
		add_child(objetivo)
		_objetivos_entrada.append(objetivo)


func _puede_interactuar_entrada(jugador: Node, entrada: Dictionary) -> bool:
	if _interior_activo or _transicionando or not is_instance_valid(jugador) or not jugador is Node2D:
		return false
	var posicion: Vector2 = to_global(entrada.get("pos", Vector2.ZERO))
	return (jugador as Node2D).global_position.distance_to(posicion) <= DISTANCIA_INTERACCION_ENTRADA


func _interactuar_entrada(jugador: Node, entrada: Dictionary) -> void:
	if not _puede_interactuar_entrada(jugador, entrada):
		return
	_entrar_al_interior(entrada.duplicate(true))


func _crear_aviso() -> void:
	# Aviso flotante con el mismo panel pixel-art y tratamiento tipográfico del resto de la interfaz.
	_aviso_panel = PanelContainer.new()
	_aviso_panel.name = "AvisoEntradaPanel"
	_aviso_panel.z_index = 50
	_aviso_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_panel.custom_minimum_size = Vector2(0.0, 30.0)

	_aviso = Label.new()
	_aviso.name = "AvisoEntrada"
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.add_theme_color_override("font_color", Color("#FFF3D6"))
	_aviso.add_theme_color_override("font_outline_color", Color("#302014"))
	_aviso.add_theme_constant_override("outline_size", 2)
	_aviso.add_theme_font_size_override("font_size", 11)
	_aviso_panel.add_child(_aviso)
	PIXEL_UI_THEME.apply(_aviso_panel, false)
	_aviso_panel.visible = false

	var capa_ui := CanvasLayer.new()
	capa_ui.name = "AvisoEntradaLayer"
	capa_ui.layer = 110
	add_child(capa_ui)
	capa_ui.add_child(_aviso_panel)

	_boton_entrar = Button.new()
	_boton_entrar.name = "BotonEntrar"
	_boton_entrar.text = "Entrar"
	_boton_entrar.custom_minimum_size = Vector2(88.0, 30.0)
	_boton_entrar.mouse_filter = Control.MOUSE_FILTER_STOP
	_boton_entrar.focus_mode = Control.FOCUS_NONE
	_boton_entrar.z_index = 51
	_boton_entrar.visible = false
	PIXEL_UI_THEME.apply(_boton_entrar, false)
	capa_ui.add_child(_boton_entrar)

func _posicionar_boton_entrada() -> void:
	if not is_instance_valid(_boton_entrar):
		return
	# La interacción queda anclada al HUD, no a la transformación de cámara
	# del jugador. Así siempre aparece en una posición visible del viewport.
	var viewport := get_viewport().get_visible_rect().size
	var tamano := _boton_entrar.get_combined_minimum_size()
	_boton_entrar.size = tamano
	_boton_entrar.position = Vector2(
		(viewport.x - tamano.x) * 0.5,
		viewport.y - tamano.y - 76.0
	)


func _crear_cesped_tilemap_dual() -> void:
	# Torres usa exclusivamente las capas TileMapDual guardadas en la escena.
	# Cada capa contiene una parte del suelo y algunas posiciones se solapan
	# intencionalmente entre atlas. Por eso se valida la huella única del mapa,
	# no la suma de celdas de las tres capas.
	var capas: Array[TileMapDual] = []
	var celdas_por_capa: Dictionary = {}
	var posiciones_unicas: Dictionary = {}
	var celdas_totales := 0
	for zona in [0, 1, 8]:
		var nombre := "TerrainDual_Zone_%02d" % zona
		var capa := get_node_or_null(nombre) as TileMapDual
		if not is_instance_valid(capa):
			push_error("ReinoTorres: falta la capa editable %s." % nombre)
			return
		capas.append(capa)
		var celdas: Array[Vector2i] = capa.get_used_cells()
		if celdas.is_empty():
			push_error("ReinoTorres: la capa %s no contiene celdas." % nombre)
			return
		celdas_por_capa[capa] = celdas
		celdas_totales += celdas.size()
		for celda: Vector2i in celdas:
			posiciones_unicas[celda] = true

	var posiciones_esperadas := 75 * 44
	if posiciones_unicas.size() != posiciones_esperadas:
		push_error(
			"ReinoTorres: la huella del terreno debe cubrir %d posiciones únicas; contiene %d (%d celdas entre las capas)."
			% [posiciones_esperadas, posiciones_unicas.size(), celdas_totales]
		)
		return

	print(
		"ReinoTorres: datos de terreno válidos: %d celdas distribuidas en %d posiciones únicas."
		% [celdas_totales, posiciones_unicas.size()]
	)

	# Esperar a que el _ready diferido de cada TileMapDual cree su Display
	# y lea los atlas. En Godot 4.4+ _changed() no rellena la caché inicial
	# de las celdas serializadas, porque no recibe una lista de cambios.
	var renderers_inicializados := false
	for intento in range(60):
		renderers_inicializados = true
		for capa in capas:
			var diagnostico: Dictionary = capa.obtener_diagnostico()
			if (
				not bool(diagnostico.get("renderer_valid", false))
				or int(diagnostico.get("terrain_layers", 0)) <= 0
			):
				renderers_inicializados = false
				break
		if renderers_inicializados:
			break
		await get_tree().process_frame

	if not renderers_inicializados:
		for capa in capas:
			push_error(
				"ReinoTorres: renderer sin inicializar en %s: %s"
				% [capa.name, JSON.stringify(capa.obtener_diagnostico())]
			)
		return

	# TileMapDual inicializa TerrainDual antes de conectar su señal
	# changed. La lectura inicial del atlas ocurre demasiado pronto y no crea
	# ningún DisplayLayer. Reconstruirlo después de _ready() reproduce el mismo
	# procedimiento que utiliza WorldTerrainVisual en el terreno procedural.
	for capa in capas:
		capa.reconstruir_renderer_dual()
		var diagnostico: Dictionary = capa.obtener_diagnostico()
		if int(diagnostico.get("display_children", 0)) <= 0:
			push_error(
				"ReinoTorres: %s no creó DisplayLayer tras reconstruir: %s"
				% [capa.name, JSON.stringify(diagnostico)]
			)
			return

	# Entregar las celdas guardadas de la escena a las capas Dual.
	# No se oculta el TileMapDual padre: visible=false también oculta sus
	# DisplayLayer hijos. La reconstrucción completa ocurre sin ceder el frame.
	for capa in capas:
		var celdas: Array[Vector2i] = celdas_por_capa[capa]
		capa._update_cells(celdas, false)

	# Comprobar las celdas generadas en el siguiente frame.
	await get_tree().process_frame

	var renderers_listos := true
	for capa in capas:
		var diagnostico: Dictionary = capa.obtener_diagnostico()
		if int(diagnostico.get("display_cells", 0)) <= 0:
			renderers_listos = false
			push_error(
				"ReinoTorres: %s no compuso celdas: %s"
				% [capa.name, JSON.stringify(diagnostico)]
			)

	if not renderers_listos:
		return

	_terreno_dual_listo = true
	print(
		"ReinoTorres: terreno TileMapDual de escena reconstruido y visible (%d celdas en %d posiciones)."
		% [celdas_totales, posiciones_unicas.size()]
	)

func _crear_muralla_montana() -> void:
	# Reutiliza el mismo compositor procedural y el mismo atlas de Montaña
	# que utiliza Mundo Abierto. El offset coincide con el límite del mapa.
	var terreno := WorldTerrainVisual.new()
	terreno.name = "TerrenoMurallaMontana"
	terreno.position = Vector2(-1200, -704)
	add_child(terreno)
	terreno.configurar(32)

	# TileMapDual inicializa sus Display de forma diferida.
	await get_tree().process_frame
	await get_tree().process_frame
	terreno.finalizar_preparacion_renderer()

	# Anillo de una celda (32 px) alrededor del reino. La abertura oriental
	# queda libre para conservar el acceso de la puerta y sus colisiones.
	var celdas_muralla: Dictionary = {}
	for x in range(75):
		celdas_muralla[Vector2i(x, 0)] = true
		celdas_muralla[Vector2i(x, 43)] = true
	for y in range(1, 43):
		celdas_muralla[Vector2i(0, y)] = true
	for y in range(1, 19):
		celdas_muralla[Vector2i(74, y)] = true
	for y in range(25, 43):
		celdas_muralla[Vector2i(74, y)] = true

	for celda_variant in celdas_muralla.keys():
		var celda: Vector2i = celda_variant
		terreno.set_zone(celda, 2, 2, "Montaña")

	terreno.flush()
	print("ReinoTorres: muralla procedural de montaña creada con TileMapDual.")


func _texturizar_mapa_pixelart() -> void:
	# Sustituye las superficies planas por texturas rasterizadas a baja resolución.
	var superficies: Array[Dictionary] = [
		{"nombre": "Plaza", "tipo": "plaza"},
		{"nombre": "PlazaInset", "tipo": "plaza"},
		{"nombre": "CanalBridgeWest", "tipo": "puente"},
		{"nombre": "CanalBridgeEast", "tipo": "puente"},
		{"nombre": "RoyalGardenWalk", "tipo": "plaza"},
		{"nombre": "RoyalGardenCross", "tipo": "plaza"},
		{"nombre": "GardenSoil", "tipo": "tierra"},
		{"nombre": "EastGatePierNorth", "tipo": "muro"},
		{"nombre": "EastGatePierSouth", "tipo": "muro"},
		{"nombre": "EastGateLintel", "tipo": "muro"}
	]
	for i in range(superficies.size()):
		var superficie: Dictionary = superficies[i]
		_texturizar_poligono(str(superficie["nombre"]), str(superficie["tipo"]), i * 17)

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
		var textura: Texture2D = ARBOL_PROP_TEXTURE
		_agregar_sprite_pixelart("Pixel_" + String(prefijo), textura, limites, maxi(tronco.z_index, copa.z_index))
		tronco.visible = false
		copa.visible = false


func _crear_luces_faroles() -> void:
	# Los nodos reales de la escena son Sprite_poste_oeste y Sprite_poste_este.
	# La luz 2D ilumina el mundo; el resplandor visible se dibuja en una
	# CanvasLayer independiente para que CanvasModulate no lo apague.
	var gradiente := Gradient.new()
	# Centro cálido y bordes con pérdida progresiva de intensidad:
	# evita un círculo marcado y deja que la luz se funda con la oscuridad.
	gradiente.set_color(0, Color(1.0, 0.76, 0.43, 0.68))
	gradiente.set_color(1, Color(1.0, 0.48, 0.12, 0.0))
	gradiente.add_point(0.28, Color(1.0, 0.68, 0.34, 0.42))
	gradiente.add_point(0.62, Color(1.0, 0.55, 0.22, 0.14))
	gradiente.add_point(0.84, Color(1.0, 0.48, 0.12, 0.035))

	var textura_luz := GradientTexture2D.new()
	textura_luz.gradient = gradiente
	textura_luz.width = 256
	textura_luz.height = 256
	textura_luz.fill = GradientTexture2D.FILL_RADIAL
	textura_luz.fill_from = Vector2(0.5, 0.5)
	textura_luz.fill_to = Vector2(0.5, 0.0)

	_capa_brillos_faroles = CanvasLayer.new()
	_capa_brillos_faroles.name = "CapaBrillosFaroles"
	_capa_brillos_faroles.layer = 1
	_capa_brillos_faroles.follow_viewport_enabled = true
	add_child(_capa_brillos_faroles)

	var nombres_faroles := ["Sprite_poste_oeste", "Sprite_poste_este"]
	for indice in range(nombres_faroles.size()):
		var farol := get_node_or_null(NodePath(nombres_faroles[indice])) as Sprite2D
		if not is_instance_valid(farol):
			push_warning("ReinoTorres: no se encontró el farol: " + nombres_faroles[indice])
			continue

		# Coordenada global calculada desde el sprite, sin posiciones aproximadas del mapa.
		# Bajar el foco desde la parte alta del poste hacia la zona de la lámpara.
		var posicion_global := farol.to_global(Vector2(0.0, -8.0))
		var posicion_local := to_local(posicion_global)

		# Luz real para iluminar el suelo y los elementos cercanos del mundo.
		var luz := PointLight2D.new()
		luz.name = "LuzFarol" + ("Oeste" if indice == 0 else "Este")
		luz.position = posicion_local
		luz.texture = textura_luz
		luz.texture_scale = 3.8
		luz.color = Color("#ffd18a")
		luz.energy = 1.8
		luz.range_item_cull_mask = 1
		luz.blend_mode = Light2D.BLEND_MODE_ADD
		luz.shadow_enabled = false
		luz.enabled = false
		add_child(luz)
		_luces_faroles.append(luz)

		# Resplandor visible independiente de la iluminación del CanvasItem.
		var brillo := Sprite2D.new()
		brillo.name = "Brillo" + ("Oeste" if indice == 0 else "Este")
		brillo.texture = textura_luz
		brillo.position = posicion_global
		brillo.scale = Vector2(1.45, 1.45)
		brillo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		brillo.visible = false
		var material_brillo := CanvasItemMaterial.new()
		material_brillo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		brillo.material = material_brillo
		_capa_brillos_faroles.add_child(brillo)
		_brillos_faroles.append(brillo)

	if _luces_faroles.size() != 2 or _brillos_faroles.size() != 2:
		push_warning(
			"ReinoTorres: faroles preparados: %d luces y %d brillos."
			% [_luces_faroles.size(), _brillos_faroles.size()]
		)
	else:
		print("ReinoTorres: dos faroles con luz y resplandor preparados.")

	_actualizar_luces_faroles()


func _actualizar_luces_faroles() -> void:
	if _luces_faroles.is_empty() and _brillos_faroles.is_empty():
		return

	# WorldAtmosphere pertenece a la escena principal, no a la zona.
	# Buscar desde SceneTree.root evita depender de cuál sea current_scene.
	if not is_instance_valid(_atmosfera_mundo):
		_atmosfera_mundo = get_tree().root.find_child("WorldAtmosphere", true, false)

	var intensidad := 0.0
	if is_instance_valid(_atmosfera_mundo) and _atmosfera_mundo.has_method("obtener_tiempo"):
		var tiempo: Dictionary = _atmosfera_mundo.call("obtener_tiempo")
		if bool(tiempo.get("calendario_cargado", false)):
			var horas_por_dia := maxf(float(tiempo.get("horas_por_dia", 24.0)), 1.0)
			var hora_normalizada := fposmod(
				float(tiempo.get("hora_del_dia", 0.0)) / horas_por_dia,
				1.0
			)
			# Encendido progresivo al atardecer y apagado gradual al amanecer.
			if hora_normalizada >= 0.82 or hora_normalizada < 0.20:
				intensidad = 1.0
			elif hora_normalizada >= 0.72:
				intensidad = _suavizar_luz(clampf((hora_normalizada - 0.72) / 0.10, 0.0, 1.0))
			elif hora_normalizada < 0.30:
				intensidad = 1.0 - _suavizar_luz(clampf((hora_normalizada - 0.20) / 0.10, 0.0, 1.0))
		else:
			intensidad = _obtener_intensidad_desde_modulacion()
	else:
		intensidad = _obtener_intensidad_desde_modulacion()

	# Los faroles pertenecen al exterior. Su CanvasLayer no se oculta junto
	# con los CanvasItem hijos de la zona al entrar a una habitación.
	var mostrar_faroles := intensidad > 0.01 and not _interior_activo
	if is_instance_valid(_capa_brillos_faroles):
		_capa_brillos_faroles.visible = not _interior_activo

	for luz: PointLight2D in _luces_faroles:
		if is_instance_valid(luz):
			luz.enabled = mostrar_faroles
			luz.energy = 1.8 * intensidad

	for brillo: Sprite2D in _brillos_faroles:
		if is_instance_valid(brillo):
			brillo.visible = mostrar_faroles
			brillo.modulate = Color(1.0, 0.82, 0.58, intensidad)


func _obtener_intensidad_desde_modulacion() -> float:
	# Respaldo para escenas donde el calendario todavía no esté disponible:
	# el color de CanvasModulate ya refleja si el mundo está de día o de noche.
	var modulacion := get_tree().root.find_child("DayNightModulation", true, false) as CanvasModulate
	if not is_instance_valid(modulacion):
		return 0.0
	var color := modulacion.color
	var luminancia := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return _suavizar_luz(1.0 - clampf((luminancia - 0.08) / 0.62, 0.0, 1.0))


func _suavizar_luz(valor: float) -> float:
	var t := clampf(valor, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
	if get_node_or_null("Sprite_pozo") != null:
		_ocultar_placeholder(["WellShadow", "WellOuter", "WellWater", "WellLipTop"])
	else:
		_agrupar_poligonos_pixelart(
			["WellShadow", "WellOuter", "WellWater", "WellLipTop"],
			"pozo", 0
		)
	_ocultar_placeholder(["LampWestPost", "LampEastPost"])
	_agrupar_poligonos_pixelart(["LampWestGlow"], "lampara", 0)
	_agrupar_poligonos_pixelart(["LampEastGlow"], "lampara", 1)


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

		# Los sprites oficiales están guardados en la escena para editarlos desde Godot.
		_ocultar_placeholder(building["hide"])
		var sprite_existente := get_node_or_null(NodePath("Sprite_" + clave)) as Sprite2D
		if is_instance_valid(sprite_existente):
			if tiene_textura_personalizada:
				print("ReinoTorres: sprite oficial de escena activo para ", clave)
			continue
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
	_boton_entrar.visible = false
	_ocultar_npcs_exteriores()
	_posicion_exterior = _jugador.global_position
	_entrada_interior_id = str(entrada.get("id", ""))
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
	_ubicar_npcs_del_edificio_en_interior(entrada)
	_jugador.global_position = to_global(Vector2(0, 70))
	_limitar_camara_a_interior()
	_interterior_colisiones(true)
	_interior_activo = true
	_aviso_panel.visible = false
	_aviso.text = ""
	print("ReinoTorres: entrando a ", entrada["id"])


func _ocultar_npcs_exteriores() -> void:
	_visibilidad_npcs_exterior.clear()
	for npc in get_tree().get_nodes_in_group("torres_game_npc"):
		if not is_instance_valid(npc) or not npc is CanvasItem:
			continue
		if _contenedor_npcs_exterior == null:
			_contenedor_npcs_exterior = npc.get_parent()
		var visual := npc as CanvasItem
		_visibilidad_npcs_exterior[visual.get_instance_id()] = visual.visible
		visual.visible = false
		# Ocultarlo no basta: el sistema de clics sigue encontrándolo
		# mientras pertenezca al grupo interactable.
		npc.remove_from_group("interactable")


func _restaurar_npcs_exteriores() -> void:
	for npc in get_tree().get_nodes_in_group("torres_game_npc"):
		if not is_instance_valid(npc) or not npc is CanvasItem:
			continue
		var visual := npc as CanvasItem
		var sigue_dentro := bool(npc.get_meta("rutina_en_edificio", false))
		visual.visible = not sigue_dentro
		if sigue_dentro:
			npc.remove_from_group("interactable")
		elif npc is Creature:
			npc.add_to_group("interactable")
	_visibilidad_npcs_exterior.clear()


func _obtener_entrada_por_id(entrada_id: String) -> Dictionary:
	for entrada: Dictionary in ENTRADAS:
		if str(entrada.get("id", "")) == entrada_id:
			return entrada
	return {}


func _ubicar_npcs_del_edificio_en_interior(entrada: Dictionary) -> void:
	var entrada_id := str(entrada.get("id", ""))
	var cuarto := _capa_interior.get_node_or_null("Habitacion_" + entrada_id) as Node2D
	if not is_instance_valid(cuarto):
		return
	var posiciones := [
		Vector2(-90.0, 20.0), Vector2(85.0, 20.0),
		Vector2(-10.0, -5.0), Vector2(135.0, 70.0)
	]
	# Las claves de rutina y los IDs de puerta no siempre tienen el mismo
	# nombre (por ejemplo, casa_elian -> casa_oriente_a).
	var ubicacion_rutina_por_entrada := {
		"panaderia": "panaderia",
		"forja": "forja",
		"cuartel": "cuartel",
		"registro": "registro",
		"casa_comercio": "casa_comercio",
		"archivo_real": "archivo_real",
		"casa_estudio": "casa_estudio",
		"casa_oriente_a": "casa_elian",
		"vivienda_mason": "casa_bruna",
		"casa_oriente_b": "casa_darven",
		"casa_oriente_c": "casa_saira",
		"vivienda_oeste_09": "casa_narel",
		"castillo": "castillo"
	}
	var ubicacion_rutina_esperada := str(ubicacion_rutina_por_entrada.get(entrada_id, ""))
	var indice := 0
	for npc in get_tree().get_nodes_in_group("torres_game_npc"):
		if not is_instance_valid(npc) or not npc is Node2D:
			continue
		var ya_asignado_a_esta_puerta := (
			bool(npc.get_meta("rutina_en_edificio", false))
			and str(npc.get_meta("rutina_edificio_id", "")) == entrada_id
		)
		var va_a_este_edificio := (
			not ubicacion_rutina_esperada.is_empty()
			and str(npc.get_meta("rutina_ubicacion", "")) == ubicacion_rutina_esperada
		)
		# Si el jugador entra antes de que termine la caminata, el NPC debe
		# estar atendiendo dentro igualmente, no quedarse fuera de la sala.
		if not ya_asignado_a_esta_puerta and not va_a_este_edificio:
			continue
		if npc.get_parent() != cuarto:
			npc.reparent(cuarto, true)
		var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento != null:
			movimiento.detener_por_rutina()
		npc.set_meta("rutina_en_edificio", true)
		npc.set_meta("rutina_edificio_id", entrada_id)
		var actor := npc as Node2D
		actor.position = posiciones[indice % posiciones.size()]
		actor.visible = true
		# Los NPC trasladados al cuarto sí pueden recibir interacciones.
		npc.add_to_group("interactable")
		indice += 1


func teletransportar_jugador_a_npc(npc: Node) -> bool:
	if not is_instance_valid(npc) or not is_instance_valid(_jugador):
		return false
	if not get_tree().get_nodes_in_group("torres_game_npc").has(npc):
		return false

	var esta_en_edificio := bool(npc.get_meta("rutina_en_edificio", false))
	var edificio_destino := str(npc.get_meta("rutina_edificio_id", ""))
	if _interior_activo and esta_en_edificio and _entrada_interior_id == edificio_destino:
		_jugador.global_position = (npc as Node2D).global_position + Vector2(42.0, 28.0)
		return true

	# Salir del interior actual antes de cambiar de edificio o ir al exterior.
	if _interior_activo:
		_salir_del_interior()

	if esta_en_edificio:
		var entrada := _obtener_entrada_por_id(edificio_destino)
		if entrada.is_empty():
			return false
		_entrar_al_interior(entrada)
		if not _interior_activo or not is_instance_valid(npc):
			return false
		_jugador.global_position = (npc as Node2D).global_position + Vector2(42.0, 28.0)
		return true

	if not npc is Node2D:
		return false
	_jugador.global_position = (npc as Node2D).global_position + Vector2(36.0, 24.0)
	return true


func sacar_npc_del_interior(npc: Node) -> void:
	if not is_instance_valid(npc) or _contenedor_npcs_exterior == null:
		return
	if not _capa_interior.is_ancestor_of(npc):
		return
	var edificio_id := str(npc.get_meta("rutina_edificio_id", ""))
	var entrada := _obtener_entrada_por_id(edificio_id)
	npc.reparent(_contenedor_npcs_exterior, true)
	if not entrada.is_empty() and npc is Node2D:
		(npc as Node2D).global_position = to_global(entrada.get("pos", Vector2.ZERO) + Vector2(0.0, 28.0))
	if npc is CanvasItem:
		(npc as CanvasItem).visible = false
	npc.remove_from_group("interactable")


func _devolver_npcs_del_interior_al_exterior() -> void:
	if _contenedor_npcs_exterior == null:
		return
	for npc in get_tree().get_nodes_in_group("torres_game_npc"):
		if not is_instance_valid(npc) or not _capa_interior.is_ancestor_of(npc):
			continue
		var edificio_id := str(npc.get_meta("rutina_edificio_id", ""))
		var entrada := _obtener_entrada_por_id(edificio_id)
		npc.reparent(_contenedor_npcs_exterior, true)
		if not entrada.is_empty() and npc is Node2D:
			(npc as Node2D).global_position = to_global(entrada.get("pos", Vector2.ZERO) + Vector2(0.0, 28.0))
		if npc is CanvasItem:
			(npc as CanvasItem).visible = false


func _salir_del_interior() -> void:
	if not _interior_activo or not is_instance_valid(_jugador):
		return
	_devolver_npcs_del_interior_al_exterior()
	_restaurar_npcs_exteriores()
	_capa_interior.visible = false
	_capa_interior.process_mode = Node.PROCESS_MODE_DISABLED
	_boton_entrar.visible = false
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
	_entrada_interior_id = ""
	_aviso_panel.visible = false
	_aviso.text = ""
	print("ReinoTorres: regreso al exterior.")


func obtener_estado_guardado() -> Dictionary:
	return {
		"interior_activo": _interior_activo,
		"entrada_id": _entrada_interior_id,
		"posicion_exterior": {
			"x": _posicion_exterior.x,
			"y": _posicion_exterior.y
		}
	}


func restaurar_estado_guardado(estado: Dictionary) -> void:
	if not bool(estado.get("interior_activo", false)):
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_jugador):
		return

	var entrada_id := str(estado.get("entrada_id", "")).strip_edges()
	var entrada_guardada: Dictionary = {}
	for entrada: Dictionary in ENTRADAS:
		if str(entrada.get("id", "")) == entrada_id:
			entrada_guardada = entrada
			break
	if entrada_guardada.is_empty():
		push_warning("ReinoTorres: no se pudo restaurar el interior; entrada desconocida: " + entrada_id)
		return

	var exterior_variant: Variant = estado.get("posicion_exterior", {})
	if exterior_variant is Dictionary:
		var exterior := exterior_variant as Dictionary
		_posicion_exterior = Vector2(float(exterior.get("x", 0.0)), float(exterior.get("y", 0.0)))
		_jugador.global_position = _posicion_exterior

	var posicion_interior := _jugador.global_position
	_entrar_al_interior(entrada_guardada)
	_jugador.global_position = posicion_interior
	print("ReinoTorres: interior restaurado → ", entrada_id)


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
	var esquina_superior_izquierda := to_global(Vector2(-INTERIOR_MEDIO_ANCHO, -INTERIOR_MEDIO_ALTO))
	var esquina_inferior_derecha := to_global(Vector2(INTERIOR_MEDIO_ANCHO, INTERIOR_MEDIO_ALTO))
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

	# El suelo se conserva como TileMap y las paredes mantienen sus colisiones.
	# Los muebles existentes se representan con sprites oficiales. Los objetos
	# sin sprite propio quedan fuera hasta que se dibujen sus recursos pixel art.
	_agregar_suelo_tilemap(cuarto)
	# Muros perimetrales ampliados con una abertura de puerta al sur.
	_agregar_colision_muro(cuarto, "ColisionNorte", Vector2(0, -INTERIOR_MEDIO_ALTO - 4.0), Vector2(INTERIOR_ANCHO + 16.0, 16))
	_agregar_colision_muro(cuarto, "ColisionOeste", Vector2(-INTERIOR_MEDIO_ANCHO - 4.0, 0), Vector2(16, INTERIOR_ALTO + 16.0))
	_agregar_colision_muro(cuarto, "ColisionEste", Vector2(INTERIOR_MEDIO_ANCHO + 4.0, 0), Vector2(16, INTERIOR_ALTO + 16.0))
	_agregar_colision_muro(cuarto, "ColisionSurIzq", Vector2((-INTERIOR_MEDIO_ANCHO - 4.0 - 12.0) / 2.0, INTERIOR_MEDIO_ALTO + 4.0), Vector2(INTERIOR_MEDIO_ANCHO - 12.0, 16))
	_agregar_colision_muro(cuarto, "ColisionSurDer", Vector2((132.0 + INTERIOR_MEDIO_ANCHO + 4.0) / 2.0, INTERIOR_MEDIO_ALTO + 4.0), Vector2(INTERIOR_MEDIO_ANCHO - 128.0, 16))

	var tipo := str(entrada["tipo"])
	match tipo:
		"castillo":
			_agregar_sprite_mueble(cuarto, "MesaDelTrono", MUEBLE_MESA, Vector2(0, -70), Vector2(1.6, 1), 1)
			_agregar_sprite_mueble(cuarto, "MesaAudiencias", MUEBLE_MESA, Vector2(0, 45), Vector2(2.2, 1), 1)
		"panaderia":
			_agregar_sprite_mueble(cuarto, "Horno", MUEBLE_HORNO, Vector2(-150, -75), Vector2(2, 2), 1)
			_agregar_sprite_mueble(cuarto, "Mostrador", MUEBLE_MESA, Vector2(90, -20), Vector2(1.5, 1), 1)
			_agregar_sprite_mueble(cuarto, "MesaAmasado", MUEBLE_MESA, Vector2(70, 65), Vector2(1.3, 1), 1)
		"posada":
			for i in range(3):
				_agregar_sprite_mueble(cuarto, "Mesa%d" % i, MUEBLE_MESA, Vector2(-110 + i * 110, -15), Vector2(1.0, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "Mostrador", MUEBLE_MESA, Vector2(0, -95), Vector2(2.0, 1), 1)
		"forja":
			_agregar_sprite_mueble(cuarto, "Hogar", MUEBLE_HORNO, Vector2(-145, -70), Vector2(2, 2), 1)
			_agregar_sprite_mueble(cuarto, "BancoHerramientas", MUEBLE_MESA, Vector2(115, 65), Vector2(1.4, 1), 1)
		"archivo":
			_agregar_sprite_mueble(cuarto, "MesaConsulta", MUEBLE_MESA, Vector2(0, 65), Vector2(1.8, 1), 1)
		"consejo":
			_agregar_sprite_mueble(cuarto, "MesaConsejo", MUEBLE_MESA, Vector2(0, -5), Vector2(2.8, 1.8), 1)
		"oris":
			_agregar_sprite_mueble(cuarto, "MesaEstudio", MUEBLE_MESA, Vector2(0, 25), Vector2(2.0, 1.4), 1)
			_agregar_sprite_mueble(cuarto, "MesaMuestras", MUEBLE_MESA, Vector2(-130, -65), Vector2(1.0, 1.1), 1)
		"comercio", "registro", "almacen":
			_agregar_sprite_mueble(cuarto, "Mostrador", MUEBLE_MESA, Vector2(0, -75), Vector2(2.6, 1), 1)
			_agregar_sprite_mueble(cuarto, "MesaInventario", MUEBLE_MESA, Vector2(0, 55), Vector2(1.5, 1), 2)
		"cuartel":
			for i in range(4):
				var posicion_litera := Vector2(-150 + (i % 2) * 300, -65 + int(i / 2) * 105)
				_agregar_sprite_mueble(cuarto, "Litera%d" % i, MUEBLE_CAMA, posicion_litera, Vector2(0.85, 0.85), 1)
		"taller", "carpinteria":
			_agregar_sprite_mueble(cuarto, "BancoTrabajo", MUEBLE_MESA, Vector2(0, 15), Vector2(2.2, 1.4), 1)
			_agregar_sprite_mueble(cuarto, "Materiales", MUEBLE_COFRE, Vector2(145, 65), Vector2.ONE, 1)
		"granero", "molino", "semillas":
			_agregar_sprite_mueble(cuarto, "MesaPesaje", MUEBLE_MESA, Vector2(0, 55), Vector2(1.6, 1), 1)
		"alfareria":
			_agregar_sprite_mueble(cuarto, "HornoCeramica", MUEBLE_HORNO, Vector2(-130, -65), Vector2(1.8, 1.8), 1)
		"vivienda":
			var posicion_cama := Vector2(-145, -55)
			_agregar_sprite_mueble(cuarto, "Cama", MUEBLE_CAMA, posicion_cama, Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "Mesa", MUEBLE_MESA, Vector2(75, 20), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "Fogon", MUEBLE_HORNO, Vector2(145, -75), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "Arcon", MUEBLE_COFRE, Vector2(-55, 70), Vector2.ONE, 1)


func _agregar_sprite_mueble(padre: Node, nombre: String, textura: Texture2D, posicion: Vector2, escala: Vector2 = Vector2.ONE, z: int = 1) -> void:
	if textura == null:
		push_warning("ReinoTorres: no se pudo cargar el sprite del mueble: " + nombre)
		return
	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = textura
	sprite.position = posicion
	sprite.scale = escala
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z
	padre.add_child(sprite)

	# El tipo de mueble determina automáticamente su interacción compartida.
	if textura == MUEBLE_CAMA or textura == MUEBLE_COFRE:
		var objetivo: Node2D = WORLD_INTERACTABLE_SCRIPT.new() as Node2D
		if not is_instance_valid(objetivo):
			return
		objetivo.name = "Interaccion_" + nombre
		objetivo.position = posicion
		if textura == MUEBLE_CAMA:
			objetivo.call("configurar_cama")
		else:
			objetivo.call("configurar_cofre", "torres:" + _entrada_interior_id + ":" + nombre)
		padre.add_child(objetivo)


func _agregar_suelo_tilemap(padre: Node) -> void:
	var textura := load("res://assets/tilesets/Suelo.png") as Texture2D
	if textura == null:
		push_warning("ReinoTorres: no se pudo cargar assets/tilesets/Suelo.png")
		return

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	tileset.add_source(atlas, 0)

	var capa := TileMapLayer.new()
	capa.name = "SueloTileMap"
	capa.position = Vector2(-INTERIOR_MEDIO_ANCHO, -INTERIOR_MEDIO_ALTO)
	capa.tile_set = tileset
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.z_index = -10
	padre.add_child(capa)

	# Los tiles cubren exactamente los 560 x 352 puntos del interior.
	for y in range(int(INTERIOR_ALTO / 16.0)):
		for x in range(int(INTERIOR_ANCHO / 16.0)):
			capa.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


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




func _buscar_textura(paths: Array) -> Texture2D:
	for relative_path: String in paths:
		var full_path := relative_path if relative_path.begins_with("res://") else TORRES_ART_ROOT.path_join(relative_path)
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




func _al_entrar_entrada_expedicion(body: Node2D) -> void:
	if _transicionando or body == null or not body.is_in_group("player"):
		return
	_actualizar_selector_viajes()
	if is_instance_valid(_selector_viajes_layer):
		_selector_viajes_layer.visible = true
		_posicionar_selector_viajes()


func _al_salir_entrada_expedicion(body: Node2D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if is_instance_valid(_selector_viajes_layer):
		_selector_viajes_layer.visible = false


func _crear_selector_viajes() -> void:
	_selector_viajes_layer = CanvasLayer.new()
	_selector_viajes_layer.name = "SelectorViajesLayer"
	_selector_viajes_layer.layer = 80
	_selector_viajes_layer.visible = false
	add_child(_selector_viajes_layer)

	# La interfaz ocupa el viewport completo y el contenedor centra el panel
	# usando su tamaño real, sin depender de offsets calculados a mano.
	_selector_viajes_root = Control.new()
	_selector_viajes_root.name = "SelectorViajesRoot"
	_selector_viajes_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selector_viajes_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selector_viajes_layer.add_child(_selector_viajes_root)

	_selector_viajes_center = CenterContainer.new()
	_selector_viajes_center.name = "SelectorViajesCenter"
	_selector_viajes_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selector_viajes_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selector_viajes_root.add_child(_selector_viajes_center)

	_selector_viajes_panel = PanelContainer.new()
	_selector_viajes_panel.name = "SelectorViajes"
	_selector_viajes_panel.custom_minimum_size = Vector2(380.0, 0.0)
	_selector_viajes_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_selector_viajes_center.add_child(_selector_viajes_panel)

	var contenido := VBoxContainer.new()
	contenido.name = "Contenido"
	contenido.add_theme_constant_override("separation", 8)
	_selector_viajes_panel.add_child(contenido)

	var estaciones := Label.new()
	estaciones.name = "StationsHeading"
	estaciones.text = "Estaciones"
	estaciones.add_theme_font_size_override("font_size", 12)
	contenido.add_child(estaciones)
	_agregar_boton_destino(contenido, "Torres", "torres")
	_agregar_boton_destino(contenido, "Mundo Abierto", "mundo_abierto")

	var expediciones := Label.new()
	expediciones.name = "ExpeditionsHeading"
	expediciones.text = "Expediciones"
	expediciones.add_theme_font_size_override("font_size", 12)
	contenido.add_child(expediciones)

	var lista_dinamica := VBoxContainer.new()
	lista_dinamica.name = "DynamicDestinations"
	lista_dinamica.add_theme_constant_override("separation", 6)
	contenido.add_child(lista_dinamica)

	var cerrar := Button.new()
	cerrar.name = "CloseTravelSelector"
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size.y = 34.0
	cerrar.pressed.connect(func() -> void:
		_selector_viajes_layer.visible = false
	)
	contenido.add_child(cerrar)

	PIXEL_UI_THEME.apply(_selector_viajes_panel, false)
	PIXEL_UI_THEME.apply(contenido, false)


func _agregar_boton_destino(contenedor: VBoxContainer, texto: String, destino_id: String) -> void:
	var boton := Button.new()
	boton.name = "Destino_" + destino_id
	boton.text = texto
	boton.custom_minimum_size = Vector2(0.0, 38.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.pressed.connect(_seleccionar_destino_viaje.bind(destino_id))
	contenedor.add_child(boton)


func _actualizar_selector_viajes() -> void:
	if not is_instance_valid(_selector_viajes_panel):
		return
	var lista := _selector_viajes_panel.get_node_or_null("Contenido/DynamicDestinations") as VBoxContainer
	if lista == null:
		return
	for hijo in lista.get_children():
		lista.remove_child(hijo)
		hijo.queue_free()

	var expediciones := _selector_viajes_panel.get_node_or_null("Contenido/ExpeditionsHeading") as Label
	var hay_primera_expedicion := not _primera_expedicion_finalizada()
	if is_instance_valid(expediciones):
		expediciones.visible = hay_primera_expedicion
	lista.visible = hay_primera_expedicion
	if hay_primera_expedicion:
		_agregar_boton_destino(lista, "Primera expedición", "expedicion_bosque")


func _primera_expedicion_finalizada() -> bool:
	var zone_manager := get_tree().get_first_node_in_group("zone_manager")
	if not is_instance_valid(zone_manager) or not zone_manager.has_method("_primera_expedicion_finalizada"):
		return false
	return bool(zone_manager.call("_primera_expedicion_finalizada"))

func _seleccionar_destino_viaje(destino_id: String) -> void:
	if _transicionando:
		return
	_transicionando = destino_id != "torres"
	if is_instance_valid(_selector_viajes_layer):
		_selector_viajes_layer.visible = false
	destino_viaje_solicitado.emit(destino_id)


func _posicionar_selector_viajes() -> void:
	if not is_instance_valid(_selector_viajes_center):
		return
	_selector_viajes_center.queue_sort()
	_selector_viajes_panel.reset_size()
