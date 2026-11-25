extends Node2D

signal salida_solicitada
signal destino_viaje_solicitado(destino_id: String)

const TORRES_ART_ROOT := "res://assets/art/kingdom/torres"
const TORRES_PIXEL_ART := preload("res://scripts/world/torres_pixel_art.gd")
const ARBOL_PROP_TEXTURE: Texture2D = preload("res://assets/art/props/Árbol.png")
const MUEBLE_CAMA: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/cama.png")
const MUEBLE_MESA: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/mesa.png")
const MUEBLE_HORNO: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/horno.png")
const MUEBLE_COFRE: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/cofre.png")
const MUEBLE_SILLA_DERECHA: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/Silla Derecha.png")
const MUEBLE_SILLA_FRENTE: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/Silla Frente.png")
const MUEBLE_ASIENTO: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/asiento.png")
const MUEBLE_YUNQUE: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/Yunque.png")
const MUEBLE_ESTANTERIA_PAN: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/estanteria con pan.png")
const MUEBLE_ARMARIO: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/armario.png")
const MUEBLE_MESA_DOCUMENTOS: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/mesa documentos.png")
const MUEBLE_MESA_PLATOS: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Muebles/mesa platos.png")
const MERCADO_PUESTO: Texture2D = preload("res://assets/art/kingdom/Torres/Edificios/Mercado Puesto.png")
const PRODUCTO_PAN: Texture2D = preload("res://assets/art/items/Pan.png")
const PRODUCTO_MANZANA: Texture2D = preload("res://assets/art/items/Manzana.png")
const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")
const CONTEXTUAL_ACTION_TARGET_SCRIPT = preload("res://scripts/gameplay/interaction/contextual_action_target.gd")
const WATERING_INTERACTABLE_SCRIPT: Script = preload("res://scripts/gameplay/watering_interactable.gd")
const WORLD_INTERACTABLE_SCRIPT = preload("res://scripts/gameplay/interaction/world_interactable.gd")
const RESEARCH_LAB_UI_SCENE: PackedScene = preload("res://scenes/ui/research_lab.tscn")
const ROYAL_ARCHIVE_UI_SCRIPT: Script = preload("res://scripts/ui/royal_archive.gd")
const BUILDING_SERVICE_UI_SCRIPT: Script = preload("res://scripts/ui/building_service_ui.gd")
const GARUMI_HUB_SCENE: PackedScene = preload("res://scenes/ui/garumi_hub.tscn")
const TAMANO_PIXEL_MUNDO := 8.0
const TORRES_TILEMAP_LAYOUT = preload("res://scripts/world/torres_tilemap_layout.gd")
const BUILDING_INTERIOR_STYLE_SCRIPT: Script = preload("res://scripts/world/building_interior_style.gd")
const TORRES_VIVERO_BUILDER: Script = preload("res://scripts/world/torres_vivero_builder.gd")
const POSICIONES_NPC_CASTILLO_INTERIOR: Array[Vector2] = [
	Vector2(-210.0, -140.0), Vector2(-150.0, -140.0),
	Vector2(-90.0, -140.0), Vector2(90.0, -140.0),
	Vector2(150.0, -140.0), Vector2(210.0, -140.0),
	Vector2(-225.0, -70.0), Vector2(-165.0, -70.0),
	Vector2(165.0, -70.0), Vector2(225.0, -70.0),
	Vector2(-225.0, 5.0), Vector2(-165.0, 5.0),
	Vector2(165.0, 5.0), Vector2(225.0, 5.0),
	Vector2(-225.0, 80.0), Vector2(-165.0, 80.0),
	Vector2(165.0, 80.0), Vector2(225.0, 80.0),
	Vector2(-180.0, 135.0), Vector2(-120.0, 135.0),
	Vector2(120.0, 135.0), Vector2(180.0, 135.0)
]
const POSICIONES_NPC_INTERIOR: Array[Vector2] = [
	Vector2(-90.0, 20.0), Vector2(85.0, 20.0),
	Vector2(-10.0, -5.0), Vector2(135.0, 70.0)
]

# Dimensión base. Los edificios grandes usan perfiles ampliados en _obtener_dimensiones_interior().
const INTERIOR_ANCHO := 512.0
const INTERIOR_ALTO := 320.0
var _interior_ancho_actual: float = INTERIOR_ANCHO
var _interior_alto_actual: float = INTERIOR_ALTO

# Cada edificio intenta primero su sprite específico y después uno genérico.
# Los recursos ausentes conservan únicamente su estructura pixel-art disponible.
const SPRITE_BUILDINGS: Array[Dictionary] = [
	{"key":"castillo", "paths":["res://assets/art/kingdom/Torres/Edificios/Castillo.png","castillo.png","edificios/castillo.png"], "position":Vector2(0,-850), "size":Vector2(230,190), "hide":["CastleKeep","CastleFacade","CastleRoof","CastleDoor","CastleWindow","CastleTower"]},
	{"key":"panaderia", "paths":["res://assets/art/kingdom/Torres/Edificios/Panaderia.png","casas/panaderia.png","edificios/panaderia.png","casas/casa.png"], "position":Vector2(-360,-120), "size":Vector2(96,92), "hide":["HouseBaker"]},
	{"key":"posada", "paths":["res://assets/art/kingdom/Torres/Edificios/Posada.png","casas/posada.png","edificios/posada.png","casas/casa.png"], "position":Vector2(360,-120), "size":Vector2(104,102), "hide":["HouseInn"]},
	{"key":"herbolario", "paths":["res://assets/art/kingdom/Torres/Edificios/Herbolario.png"], "position":Vector2(-150,160), "size":Vector2(112,96), "hide":[]},
	{"key":"vivero", "paths":["res://assets/art/kingdom/Torres/Edificios/Vivero.png"], "position":Vector2(150,160), "size":Vector2(112,96), "hide":[]},
	{"key":"casa_bruna", "sprite_node":"Sprite_Casa_Bruna", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_mason.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1000,-350), "size":Vector2(96,88), "hide":["HouseMason"]},
	{"key":"casa_elian", "sprite_node":"Sprite_Casa_Elian", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/casa_oriente_a.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(700,-350), "size":Vector2(96,90), "hide":["HouseEastA"]},
	{"key":"casa_darven", "sprite_node":"Sprite_Casa_Darven", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/casa_oriente_b.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(850,-350), "size":Vector2(96,90), "hide":["HouseEastB"]},
	{"key":"casa_saira", "sprite_node":"Sprite_Casa_Saira", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/casa_oriente_c.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(1000,-350), "size":Vector2(96,92), "hide":["HouseEastC"]},
	{"key":"forja", "paths":["res://assets/art/kingdom/Torres/Edificios/Forja.png","edificios/forja.png","edificios/taller.png"], "position":Vector2(-500,180), "size":Vector2(104,92), "hide":["ForgeBase","ForgeRoof","ForgeOpening","ForgeFire"]},
	{"key":"archivo_real", "paths":["res://assets/art/kingdom/Torres/Edificios/Archivo_Real.png"], "position":Vector2(-170,-280), "size":Vector2(116,94), "hide":["RoyalArchive"]},
	{"key":"sala_consejo", "paths":["res://assets/art/kingdom/Torres/Edificios/Sala_del_Consejo.png"], "position":Vector2(170,-280), "size":Vector2(132,104), "hide":["CouncilHall"]},
	{"key":"casa_estudio", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_de_Estudio_Oris.png"], "position":Vector2(-520,-430), "size":Vector2(122,98), "hide":["OrisStudy","StudyDome"]},
	{"key":"biblioteca", "paths":["res://assets/art/kingdom/Torres/Edificios/Biblioteca.png"], "position":Vector2(0,-540), "size":Vector2(124,112), "hide":[]},
	{"key":"centro_expediciones", "paths":["res://assets/art/kingdom/Torres/Edificios/Centro de Expediciones.png"], "position":Vector2(1180,300), "size":Vector2(136,120), "hide":[]},
	{"key":"taberna", "paths":["res://assets/art/kingdom/Torres/Edificios/Taberna.png","res://assets/art/kingdom/Torres/Edificios/taberna.png"], "position":Vector2(760,-540), "size":Vector2(126,108), "hide":[]},
	{"key":"escuela", "paths":["res://assets/art/kingdom/Torres/Edificios/Escuela.png","res://assets/art/kingdom/Torres/Edificios/escuela.png"], "position":Vector2(-760,-540), "size":Vector2(126,108), "hide":[]},
	{"key":"clinica", "paths":["res://assets/art/kingdom/Torres/Edificios/Clinica.png"], "position":Vector2(360,430), "size":Vector2(116,104), "hide":[]},
	{"key":"casa_comercio", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_de_Comercio.png"], "position":Vector2(500,180), "size":Vector2(122,100), "hide":["TradeHouse"]},
	{"key":"cuartel", "paths":["res://assets/art/kingdom/Torres/Edificios/Cuartel_de_la_Guardia.png"], "position":Vector2(520,-430), "size":Vector2(126,104), "hide":["GuardBarracks","BarracksBed","BarracksBunk","BarracksArmor","BarracksArmory","BarracksWeaponRack","CuartelDetalle","DetalleCuartel"]},
	{"key":"registro", "paths":["res://assets/art/kingdom/Torres/Edificios/Registro_de_la_Puerta.png"], "position":Vector2(1480,0), "size":Vector2(108,90), "hide":["GateOffice"]},
	{"key":"reparaciones", "paths":["res://assets/art/kingdom/Torres/Edificios/Taller_de_Reparaciones.png"], "position":Vector2(-420,430), "size":Vector2(118,96), "hide":["RepairWorkshop"]},
	{"key":"carpinteria", "paths":["res://assets/art/kingdom/Torres/Edificios/Carpinteria.png"], "position":Vector2(-160,430), "size":Vector2(114,96), "hide":["Cartwright","CarpentryWorkbench","CarpentryTools","CarpentryMaterials","CarpentryWood","CarpinteriaDetalle","DetalleCarpinteria"]},
	{"key":"granero", "paths":["res://assets/art/kingdom/Torres/Edificios/Granero.png"], "position":Vector2(-760,600), "size":Vector2(124,102), "hide":["GrainStore"]},
	{"key":"molino", "paths":["res://assets/art/kingdom/Torres/Edificios/Molino.png"], "position":Vector2(-500,600), "size":Vector2(114,96), "hide":["MillHouse"]},
	{"key":"corrales", "paths":["res://assets/art/kingdom/Torres/Edificios/Corrales.png"], "position":Vector2(650,650), "size":Vector2(122,100), "hide":["AnimalPens"]},
	{"key":"casa_granjeros", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","edificios/casa_granjeros.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(950,850), "size":Vector2(126,102), "hide":["FarmersHall"]},
	{"key":"casa_vacia_01", "sprite_node":"Sprite_Casa_Vacia_01", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_01.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-700,-350), "size":Vector2(84,82), "hide":["WestHome1Wall","WestHome1Roof","WestHome1Door","Casa_Vacia_01"]},
	{"key":"casa_vacia_02", "sprite_node":"Sprite_Casa_Vacia_02", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_02.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1000,-100), "size":Vector2(84,82), "hide":["WestHome2Wall","WestHome2Roof","WestHome2Door","Casa_Vacia_02"]},
	{"key":"casa_vacia_03", "sprite_node":"Sprite_Casa_Vacia_03", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_03.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-850,-100), "size":Vector2(84,82), "hide":["WestHome3Wall","WestHome3Roof","WestHome3Door","Casa_Vacia_03"]},
	{"key":"casa_vacia_04", "sprite_node":"Sprite_Casa_Vacia_04", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_04.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-700,-100), "size":Vector2(84,82), "hide":["WestHome4Wall","WestHome4Roof","WestHome4Door","Casa_Vacia_04"]},
	{"key":"casa_vacia_05", "sprite_node":"Sprite_Casa_Vacia_05", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_05.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-1000,150), "size":Vector2(84,82), "hide":["WestHome5Wall","WestHome5Roof","WestHome5Door","Casa_Vacia_05"]},
	{"key":"casa_vacia_06", "sprite_node":"Sprite_Casa_Vacia_06", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_06.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-850,150), "size":Vector2(84,82), "hide":["WestHome6Wall","WestHome6Roof","WestHome6Door","Casa_Vacia_06"]},
	{"key":"casa_vacia_07", "sprite_node":"Sprite_Casa_Vacia_07", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_07.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(700,-100), "size":Vector2(84,82), "hide":["WestHome7Wall","WestHome7Roof","WestHome7Door","Casa_Vacia_07"]},
	{"key":"casa_vacia_08", "sprite_node":"Sprite_Casa_Vacia_08", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_08.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(850,-100), "size":Vector2(84,82), "hide":["WestHome8Wall","WestHome8Roof","WestHome8Door","Casa_Vacia_08"]},
	{"key":"casa_narel", "sprite_node":"Sprite_Casa_Narel", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_09.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(-850,-350), "size":Vector2(84,82), "hide":["WestHome9Wall","WestHome9Roof","WestHome9Door","Casa_Narel"]},
	{"key":"casa_vacia_10", "sprite_node":"Sprite_Casa_Vacia_10", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_10.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(1000,-100), "size":Vector2(84,82), "hide":["WestHome10Wall","WestHome10Roof","WestHome10Door","Casa_Vacia_10"]},
	{"key":"casa_vacia_11", "sprite_node":"Sprite_Casa_Vacia_11", "paths":["res://assets/art/kingdom/Torres/Edificios/Casa_Comun.png","casas/vivienda_oeste_11.png","casas/vivienda.png","casas/casa.png"], "position":Vector2(850,150), "size":Vector2(84,82), "hide":["WestHome11Wall","WestHome11Roof","WestHome11Door","Casa_Vacia_11"]}
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
var _objetivos_entrada: Array[Node2D] = []
var _terreno_dual_listo: bool = false
var _atmosfera_mundo: Node = null
var _luces_faroles: Array[PointLight2D] = []
var _brillos_faroles: Array[Sprite2D] = []
var _capa_brillos_faroles: CanvasLayer = null
var _ventanas_hogares: Array[Sprite2D] = []
var _charcos_torres: Array[Polygon2D] = []
var _brillos_charcos_torres: Array[Polygon2D] = []
var _sistema_clima_torres: Node = null
var _nivel_charcos_torres: float = 0.0
var _tiempo_ambiente_torres: float = 0.0
var _aviso_evento_torres: Label = null
var _decoracion_evento_torres: Node2D = null
var _evento_decoracion_actual: String = ""
var _menu_posada_layer: CanvasLayer = null
var _menu_posada_panel: PanelContainer = null
var _menu_posada_contenido: VBoxContainer = null
var _menu_posada_estado: Label = null
var _menu_posada_vista := "principal"
const POSADA_COSTE_MENSUAL := 100
const POSADA_DURACION_MES_DIAS := 30
const POSADA_FLAG := "posada_estado"
# Precios iniciales de la tienda; se mantienen centralizados para poder ajustar la economía.
const POSADA_CATALOGO_MUEBLES: Array[Dictionary] = [
	{"id": "mesa", "nombre": "Mesa", "precio": 35},
	{"id": "silla", "nombre": "Silla", "precio": 20},
	{"id": "armario", "nombre": "Armario", "precio": 60},
	{"id": "cofre", "nombre": "Cofre", "precio": 100}
]

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

const UBICACION_RUTINA_POR_ENTRADA: Dictionary = {
	"panaderia": "panaderia",
	"posada": "posada",
	"herbolario": "herbolario",
	"vivero": "vivero",
	"forja": "forja",
	"cuartel": "cuartel",
	"registro": "registro",
	"casa_comercio": "casa_comercio",
	"archivo_real": "archivo_real",
	"sala_consejo": "sala_consejo",
	"casa_estudio": "casa_estudio",
	"biblioteca": "biblioteca",
	"centro_expediciones": "centro_expediciones",
	"taberna": "taberna",
	"escuela": "escuela",
	"clinica": "clinica",
	"reparaciones": "reparaciones",
	"carpinteria": "carpinteria",
	"granero": "granero",
	"molino": "molino",
	"corrales": "corrales",
	"casa_elian": "casa_elian",
	"casa_bruna": "casa_bruna",
	"casa_darven": "casa_darven",
	"casa_saira": "casa_saira",
	"casa_narel": "casa_narel",
	"casa_vacia_01": "vivienda_oeste_01",
	"casa_vacia_02": "vivienda_oeste_02",
	"casa_vacia_03": "vivienda_oeste_03",
	"casa_vacia_04": "vivienda_oeste_04",
	"casa_vacia_05": "vivienda_oeste_05",
	"casa_vacia_06": "vivienda_oeste_06",
	"casa_vacia_07": "vivienda_oeste_07",
	"casa_vacia_08": "vivienda_oeste_08",
	"casa_vacia_10": "vivienda_oeste_10",
	"casa_vacia_11": "vivienda_oeste_11",
	"casa_granjeros": "casa_granjeros",
	"castillo": "castillo"
}

const ENTRADAS: Array[Dictionary] = [
	{"id":"castillo","nombre":"Castillo de Torres","pos":Vector2(0,-738),"tipo":"castillo"},
	{"id":"panaderia","nombre":"Panadería","pos":Vector2(-360,-58),"tipo":"panaderia"},
	{"id":"posada","nombre":"Posada","pos":Vector2(360,-53),"tipo":"posada"},
	{"id":"herbolario","nombre":"Herbolario","pos":Vector2(-150,222),"tipo":"herbolario"},
	{"id":"vivero","nombre":"Vivero","pos":Vector2(150,222),"tipo":"vivero"},
	{"id":"casa_bruna","nombre":"Casa de Bruna","pos":Vector2(-1000,-296),"tipo":"vivienda"},
	{"id":"casa_elian","nombre":"Casa de Elian","pos":Vector2(700,-296),"tipo":"vivienda"},
	{"id":"casa_darven","nombre":"Casa de Darven","pos":Vector2(850,-296),"tipo":"vivienda"},
	{"id":"casa_saira","nombre":"Casa de Saira","pos":Vector2(1000,-296),"tipo":"vivienda"},
	{"id":"forja","nombre":"Forja","pos":Vector2(-500,242),"tipo":"forja"},
	{"id":"archivo_real","nombre":"Archivo real","pos":Vector2(-170,-217),"tipo":"archivo"},
	{"id":"sala_consejo","nombre":"Sala del consejo","pos":Vector2(170,-212),"tipo":"consejo"},
	{"id":"casa_estudio","nombre":"Laboratorio de Oris","pos":Vector2(-520,-365),"tipo":"laboratorio"},
	{"id":"biblioteca","nombre":"Biblioteca","pos":Vector2(0,-478),"tipo":"biblioteca"},
	{"id":"centro_expediciones","nombre":"Gremio de Aventureros","pos":Vector2(1180,362),"tipo":"centro_expediciones"},
	{"id":"taberna","nombre":"Taberna","pos":Vector2(760,-478),"tipo":"taberna"},
	{"id":"escuela","nombre":"Escuela de Oficios","pos":Vector2(-760,-478),"tipo":"escuela"},
	{"id":"clinica","nombre":"Clínica","pos":Vector2(360,492),"tipo":"clinica"},
	{"id":"casa_comercio","nombre":"Casa de comercio","pos":Vector2(500,246),"tipo":"comercio"},
	{"id":"cuartel","nombre":"Cuartel de la guardia","pos":Vector2(520,-362),"tipo":"cuartel"},
	{"id":"registro","nombre":"Registro de la puerta","pos":Vector2(1480,61),"tipo":"registro"},
	{"id":"reparaciones","nombre":"Taller de reparaciones","pos":Vector2(-420,494),"tipo":"taller"},
	{"id":"carpinteria","nombre":"Carpintería","pos":Vector2(-160,494),"tipo":"carpinteria"},
	{"id":"granero","nombre":"Granero","pos":Vector2(-760,667),"tipo":"granero"},
	{"id":"molino","nombre":"Molino","pos":Vector2(-500,664),"tipo":"molino"},
	{"id":"corrales","nombre":"Corrales","pos":Vector2(650,716),"tipo":"corrales"},
	{"id":"casa_granjeros","nombre":"Casa de los agricultores","pos":Vector2(950,898),"tipo":"vivienda"},
	{"id":"casa_vacia_01","nombre":"Casa vacía","pos":Vector2(-700,-296),"tipo":"vivienda"},
	{"id":"casa_vacia_02","nombre":"Casa vacía","pos":Vector2(-1000,-46),"tipo":"vivienda"},
	{"id":"casa_vacia_03","nombre":"Casa vacía","pos":Vector2(-850,-46),"tipo":"vivienda"},
	{"id":"casa_vacia_04","nombre":"Casa vacía","pos":Vector2(-700,-46),"tipo":"vivienda"},
	{"id":"casa_vacia_05","nombre":"Casa vacía","pos":Vector2(-1000,204),"tipo":"vivienda"},
	{"id":"casa_vacia_06","nombre":"Casa vacía","pos":Vector2(-850,204),"tipo":"vivienda"},
	{"id":"casa_vacia_07","nombre":"Casa vacía","pos":Vector2(700,-46),"tipo":"vivienda"},
	{"id":"casa_vacia_08","nombre":"Casa vacía","pos":Vector2(850,-46),"tipo":"vivienda"},
	{"id":"casa_narel","nombre":"Casa de Narel","pos":Vector2(-850,-296),"tipo":"vivienda"},
	{"id":"casa_vacia_10","nombre":"Casa vacía","pos":Vector2(1000,-46),"tipo":"vivienda"},
	{"id":"casa_vacia_11","nombre":"Casa vacía","pos":Vector2(850,204),"tipo":"vivienda"}
]


func _exit_tree() -> void:
	# La interfaz de la posada vive en SceneTree.root, fuera de esta escena.
	# Ocultarla y liberarla evita conservar botones con Callables a este nodo.
	_cerrar_menu_posada()
	if is_instance_valid(_menu_posada_layer):
		_menu_posada_layer.queue_free()
	_menu_posada_layer = null
	_menu_posada_panel = null
	_menu_posada_contenido = null
	_menu_posada_estado = null


func _ready() -> void:
	# Los dos accesos laterales quedan cerrados: no abren selector ni cambian de zona.
	if is_instance_valid(_expedition_entrance):
		_expedition_entrance.set_deferred("monitoring", false)
		_expedition_entrance.set_deferred("monitorable", false)
		_expedition_entrance.collision_layer = 0
		_expedition_entrance.collision_mask = 0
	_crear_selector_viajes()
	_jugador = get_tree().get_first_node_in_group("player") as Node2D
	_capa_interior = Node2D.new()
	_capa_interior.name = "InteriorActivo"
	_capa_interior.visible = false
	add_child(_capa_interior)
	_crear_grupos_edificios_nuevos()
	_crear_objetivos_entrada()
	# Preparar primero todos los elementos que sustituyen polígonos vectoriales.
	# Esta fase es síncrona: no debe quedar un frame donde Torres muestre sus
	# superficies de diseño antes de recibir sus sprites definitivos.
	_texturizar_mapa_pixelart()
	_cargar_arboles_pixelart()
	_cargar_puestos_pixelart()
	_cargar_sprites_de_torres()
	_registrar_pozos_agua()
	_crear_luces_faroles()
	_crear_ventanas_hogares()
	_crear_charcos_torres()
	_crear_aviso_evento_torres()
	_crear_contenedor_decoracion_eventos()
	# Las capas estáticas deben reconstruir su caché antes de añadir
	# elementos procedurales. En Godot 4.4+ TileMapDual no infiere los cambios
	# iniciales de las celdas serializadas de la escena.
	await _crear_cesped_tilemap_dual()
	await _crear_muralla_montana()




func _registrar_pozos_agua() -> void:
	# El pozo de la plaza conserva su sprite de escena; añadimos un objetivo
	# independiente para no alterar su textura ni sus colisiones.
	for nodo_variant in find_children("*", "Sprite2D", true, false):
		if not nodo_variant is Sprite2D:
			continue
		var sprite := nodo_variant as Sprite2D
		if not sprite.name.to_lower().contains("pozo"):
			continue
		var objetivo := WATERING_INTERACTABLE_SCRIPT.new() as Node2D
		objetivo.name = "InteraccionPozoAgua"
		add_child(objetivo)
		objetivo.global_position = sprite.global_position
		objetivo.call("configurar_pozo")


func _process(_delta: float) -> void:
	_actualizar_luces_faroles()
	_actualizar_ambiente_torres(_delta)
	# Mientras el diálogo de viaje está abierto, ocultamos el aviso contextual
	# para que no quede superpuesto el botón «Solicitar».
	if get_tree().get_first_node_in_group("travel_ticket_dialog") != null:
		var hud := get_tree().get_first_node_in_group("hud")
		if is_instance_valid(hud) and hud.has_method("ocultar_interaccion"):
			hud.call("ocultar_interaccion")
	if _interior_activo and _entrada_interior_id == "posada_habitacion" and not _posada_tiene_acceso():
		_salir_del_interior()
		Events.notification_pushed.emit("Tu estancia terminó. Tus pertenencias siguen guardadas.")
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_jugador) or not _interior_activo:
		return
	var posicion_local := to_local(_jugador.global_position)
	var mitad_ancho := _interior_ancho_actual / 2.0
	var mitad_alto := _interior_alto_actual / 2.0
	posicion_local.x = clampf(posicion_local.x, -mitad_ancho + 30.0, mitad_ancho - 30.0)
	posicion_local.y = clampf(posicion_local.y, -mitad_alto + 30.0, mitad_alto - 40.0)
	_jugador.global_position = to_global(posicion_local)
	var cerca_salida := posicion_local.y >= mitad_alto - 60.0 \
		and posicion_local.x >= -12.0 \
		and posicion_local.x <= 132.0
	if cerca_salida:
		if _entrada_interior_id == "posada_habitacion":
			_volver_al_lobby_posada()
		else:
			_salir_del_interior()


func _obtener_grupo_entrada(entrada: Dictionary) -> Node2D:
	var grupos := {
		"casa_bruna": "Grupo_casa_bruna",
		"casa_elian": "Grupo_casa_elian",
		"casa_darven": "Grupo_casa_darven",
		"casa_saira": "Grupo_casa_saira",
		"casa_vacia_01": "Grupo_casa_vacia_01",
		"casa_vacia_02": "Grupo_casa_vacia_02",
		"casa_vacia_03": "Grupo_casa_vacia_03",
		"casa_vacia_04": "Grupo_casa_vacia_04",
		"casa_vacia_05": "Grupo_casa_vacia_05",
		"casa_vacia_06": "Grupo_casa_vacia_06",
		"casa_vacia_07": "Grupo_casa_vacia_07",
		"casa_vacia_08": "Grupo_casa_vacia_08",
		"casa_narel": "Grupo_casa_narel",
		"casa_vacia_10": "Grupo_casa_vacia_10",
		"casa_vacia_11": "Grupo_casa_vacia_11",
		"casa_granjeros": "Grupo_casa_granjeros",
		"castillo": "Grupo_edificio_castillo",
		"panaderia": "Grupo_edificio_panaderia",
		"posada": "Grupo_edificio_posada",
		"forja": "Grupo_edificio_forja",
		"archivo_real": "Grupo_edificio_archivo_real",
		"sala_consejo": "Grupo_edificio_sala_consejo",
		"casa_estudio": "Grupo_edificio_casa_estudio",
		"biblioteca": "Grupo_edificio_biblioteca",
		"centro_expediciones": "Grupo_edificio_centro_expediciones",
		"clinica": "Grupo_edificio_clinica",
		"casa_comercio": "Grupo_edificio_casa_comercio",
		"cuartel": "Grupo_edificio_cuartel",
		"registro": "Grupo_edificio_registro",
		"reparaciones": "Grupo_edificio_reparaciones",
		"carpinteria": "Grupo_edificio_carpinteria",
		"granero": "Grupo_edificio_granero",
		"molino": "Grupo_edificio_molino",
		"corrales": "Grupo_edificio_corrales",
	}
	var grupo_nombre := str(grupos.get(str(entrada.get("id", "")), ""))
	if grupo_nombre.is_empty():
		return null
	return get_node_or_null(grupo_nombre) as Node2D


func _crear_grupos_edificios_nuevos() -> void:
	# Estos tres edificios no tenían nodos de fachada en la escena original.
	# Los grupos mantienen una referencia estable para sprites, entradas y rutinas NPC.
	for grupo_nombre: String in [
		"Grupo_edificio_biblioteca",
		"Grupo_edificio_centro_expediciones",
		"Grupo_edificio_clinica"
	]:
		if is_instance_valid(get_node_or_null(grupo_nombre)):
			continue
		var grupo := Node2D.new()
		grupo.name = grupo_nombre
		add_child(grupo)


func _obtener_marcador_entrada(entrada: Dictionary) -> Marker2D:
	var id := str(entrada.get("id", ""))
	var marcador_escena := get_node_or_null("LayoutEdificios/Posicion_entrada_" + id) as Marker2D
	if is_instance_valid(marcador_escena):
		return marcador_escena
	var grupo := _obtener_grupo_entrada(entrada)
	if not is_instance_valid(grupo):
		return null
	return grupo.get_node_or_null("Entrada") as Marker2D


func _obtener_posicion_entrada_global(entrada: Dictionary) -> Vector2:
	var marcador := _obtener_marcador_entrada(entrada)
	if is_instance_valid(marcador):
		return marcador.global_position
	return to_global(entrada.get("pos", Vector2.ZERO))


func obtener_posicion_mapa_npc(npc: Node) -> Variant:
	if not is_instance_valid(npc):
		return null

	var entrada_id := str(npc.get_meta("rutina_edificio_id", "")).strip_edges()
	if entrada_id.is_empty():
		var ubicacion := str(npc.get_meta("rutina_ubicacion", "")).strip_edges()
		for id_entrada in UBICACION_RUTINA_POR_ENTRADA:
			if str(UBICACION_RUTINA_POR_ENTRADA[id_entrada]) == ubicacion:
				entrada_id = id_entrada
				break
	if entrada_id.is_empty():
		return null

	var grupo := _obtener_grupo_entrada({"id": entrada_id})
	if not is_instance_valid(grupo):
		return null

	# El sprite real es la referencia visual del edificio. Si falta, el grupo
	# de la escena sigue proporcionando una posición estable y editable.
	for nodo in grupo.find_children("*", "Sprite2D", true, false):
		var sprite := nodo as Sprite2D
		if sprite != null and sprite.texture != null and sprite.is_visible_in_tree():
			return to_local(sprite.global_position)
	return to_local(grupo.global_position)


func _crear_objetivos_entrada() -> void:
	for entrada: Dictionary in ENTRADAS:
		var grupo := _obtener_grupo_entrada(entrada)
		var marcador := _obtener_marcador_entrada(entrada)
		var objetivo: Node2D = CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
		if not is_instance_valid(objetivo):
			continue
		objetivo.name = "ObjetivoEntrada_" + str(entrada.get("id", "edificio"))
		if is_instance_valid(marcador):
			objetivo.position = grupo.to_local(marcador.global_position) if is_instance_valid(grupo) else to_local(marcador.global_position)
		else:
			objetivo.position = entrada.get("pos", Vector2.ZERO)
		var nombre_lugar := str(entrada.get("nombre", "este lugar")).strip_edges()
		objetivo.call(
			"configurar",
			"Entrar: " + nombre_lugar,
			DISTANCIA_INTERACCION_ENTRADA,
			Callable(self, "_puede_interactuar_entrada").bind(entrada),
			Callable(self, "_interactuar_entrada").bind(entrada)
		)
		if is_instance_valid(grupo):
			grupo.add_child(objetivo)
		else:
			add_child(objetivo)
		_objetivos_entrada.append(objetivo)


func _puede_interactuar_entrada(jugador: Node, entrada: Dictionary) -> bool:
	if _interior_activo or _transicionando or not is_instance_valid(jugador) or not jugador is Node2D:
		return false
	return (jugador as Node2D).global_position.distance_to(_obtener_posicion_entrada_global(entrada)) <= DISTANCIA_INTERACCION_ENTRADA


func _interactuar_entrada(jugador: Node, entrada: Dictionary) -> void:
	if not _puede_interactuar_entrada(jugador, entrada):
		return
	_entrar_al_interior(entrada.duplicate(true))


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

	# La distribución guardada en reino_torres.tscn es la fuente de verdad.
	# No se compara contra una cantidad fija ni se corrige el origen en runtime:
	# así puedes pintar, borrar, ampliar o desplazar las capas desde el editor
	# sin que el juego deshaga esos cambios al iniciar la zona.
	if posiciones_unicas.is_empty():
		push_error("ReinoTorres: las capas editables no contienen celdas.")
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
	# Si la muralla fue generada y guardada desde el editor, reutilizarla.
	# Sólo crearla aquí como respaldo para escenas antiguas aún no guardadas.
	if get_node_or_null("TerrenoMurallaMontana") != null:
		return
	# Reutiliza el mismo compositor procedural y el mismo atlas de Montaña
	# que utiliza Mundo Abierto. El offset coincide con el límite del mapa.
	var terreno := WorldTerrainVisual.new()
	terreno.name = "TerrenoMurallaMontana"
	terreno.position = Vector2(-1664, -1088)
	add_child(terreno)
	terreno.configurar(32)

	# TileMapDual inicializa sus Display de forma diferida.
	await get_tree().process_frame
	await get_tree().process_frame
	terreno.finalizar_preparacion_renderer()

	# Anillo de una celda (32 px) alrededor del reino. La abertura oriental
	# queda libre para conservar el acceso de la puerta y sus colisiones.
	var celdas_muralla: Dictionary = {}
	for x in range(104):
		celdas_muralla[Vector2i(x, 0)] = true
		celdas_muralla[Vector2i(x, 67)] = true
	for y in range(1, 67):
		celdas_muralla[Vector2i(0, y)] = true
	for y in range(1, 30):
		celdas_muralla[Vector2i(103, y)] = true
	for y in range(38, 67):
		celdas_muralla[Vector2i(103, y)] = true

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


## Iluminación cálida en las viviendas habitadas. Las casas vacías permanecen
## apagadas; las ventanas acompañan el ciclo real de día y noche.
func _crear_ventanas_hogares() -> void:
	var imagen := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0.0, 0.0, 0.0, 0.0))
	var marco := Color("#563b2a")
	var luz := Color("#ffd58a")
	for y in range(5):
		for x in range(5):
			if x == 0 or x == 4 or y == 0 or y == 4:
				imagen.set_pixel(x, y, marco)
			else:
				imagen.set_pixel(x, y, luz)
	var textura_ventana := ImageTexture.create_from_image(imagen)
	var hogares_ocupados: Array[String] = [
		"Sprite_Casa_Bruna",
		"Sprite_Casa_Narel",
		"Sprite_Casa_Elian",
		"Sprite_Casa_Darven",
		"Sprite_Casa_Saira",
		"Sprite_Casa_Vacia_01",
		"Sprite_Casa_Vacia_02",
		"Sprite_Casa_Vacia_03",
		"Sprite_casa_granjeros"
	]
	for nombre_casa in hogares_ocupados:
		# Las viviendas están dentro de grupos (Grupo_casa_*), no como
		# hijos directos de ReinoTorres. La búsqueda recursiva resuelve la ruta
		# real sin generar advertencias falsas ni omitir sus ventanas.
		var casa := find_child(nombre_casa, true, false) as Sprite2D
		if not is_instance_valid(casa):
			push_warning("ReinoTorres: no se encontró la vivienda para iluminar: " + nombre_casa)
			continue
		var posiciones_ventana: Array[Vector2] = [
			Vector2(-10.0, -5.0),
			Vector2(10.0, -5.0)
		]
		for posicion_ventana: Vector2 in posiciones_ventana:
			var ventana := Sprite2D.new()
			ventana.name = "VentanaIluminada"
			ventana.texture = textura_ventana
			ventana.position = posicion_ventana
			ventana.z_index = 1
			ventana.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ventana.visible = false
			casa.add_child(ventana)
			_ventanas_hogares.append(ventana)


func _actualizar_ventanas_hogares() -> void:
	if _ventanas_hogares.is_empty():
		return
	var intensidad := 0.0
	if not is_instance_valid(_atmosfera_mundo):
		_atmosfera_mundo = get_tree().root.find_child("WorldAtmosphere", true, false)
	if is_instance_valid(_atmosfera_mundo) and _atmosfera_mundo.has_method("obtener_tiempo"):
		var tiempo: Dictionary = _atmosfera_mundo.call("obtener_tiempo")
		if bool(tiempo.get("calendario_cargado", false)):
			var horas_por_dia := maxf(float(tiempo.get("horas_por_dia", 24.0)), 1.0)
			var hora_normalizada := fposmod(float(tiempo.get("hora_del_dia", 0.0)) / horas_por_dia, 1.0)
			if hora_normalizada >= 0.82 or hora_normalizada < 0.20:
				intensidad = 1.0
			elif hora_normalizada >= 0.72:
				intensidad = _suavizar_luz((hora_normalizada - 0.72) / 0.10)
			elif hora_normalizada < 0.30:
				intensidad = 1.0 - _suavizar_luz((hora_normalizada - 0.20) / 0.10)
	for ventana in _ventanas_hogares:
		if is_instance_valid(ventana):
			ventana.visible = intensidad > 0.02 and not _interior_activo
			ventana.modulate = Color(1.0, 0.91, 0.72, intensidad)


## Los charcos se forman lentamente con la lluvia y desaparecen después,
## dejando reflejos discretos sobre los caminos y sus bordes.
func _crear_charcos_torres() -> void:
	var ubicaciones: Array[Dictionary] = [
		{"pos": Vector2(-300.0, 86.0), "rx": 17.0, "ry": 5.0},
		{"pos": Vector2(-238.0, 188.0), "rx": 13.0, "ry": 4.0},
		{"pos": Vector2(242.0, 182.0), "rx": 18.0, "ry": 5.0},
		{"pos": Vector2(326.0, 82.0), "rx": 14.0, "ry": 4.0},
		{"pos": Vector2(-520.0, -86.0), "rx": 16.0, "ry": 5.0},
		{"pos": Vector2(520.0, -86.0), "rx": 15.0, "ry": 4.0},
		{"pos": Vector2(-520.0, 390.0), "rx": 18.0, "ry": 5.0},
		{"pos": Vector2(520.0, 390.0), "rx": 16.0, "ry": 5.0}
	]
	for indice in range(ubicaciones.size()):
		var ubicacion: Dictionary = ubicaciones[indice]
		var radio_x := float(ubicacion.get("rx", 14.0))
		var radio_y := float(ubicacion.get("ry", 4.0))
		var charco := Polygon2D.new()
		charco.name = "CharcoLluvia_%02d" % indice
		var posicion_charco: Vector2 = ubicacion.get("pos", Vector2.ZERO)
		charco.position = posicion_charco
		charco.polygon = _crear_poligono_elipse(radio_x, radio_y)
		charco.color = Color("#58798a")
		charco.z_index = -5
		charco.z_as_relative = false
		charco.modulate.a = 0.0
		add_child(charco)
		_charcos_torres.append(charco)

		var brillo := Polygon2D.new()
		brillo.name = "ReflejoCharco_%02d" % indice
		brillo.position = charco.position + Vector2(-radio_x * 0.22, -0.8)
		brillo.polygon = _crear_poligono_elipse(radio_x * 0.42, maxf(radio_y * 0.20, 1.0))
		brillo.color = Color("#c5d9df")
		brillo.z_index = -4
		brillo.z_as_relative = false
		brillo.modulate.a = 0.0
		add_child(brillo)
		_brillos_charcos_torres.append(brillo)


func _crear_poligono_elipse(radio_x: float, radio_y: float) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for indice in range(12):
		var angulo := TAU * float(indice) / 12.0
		puntos.append(Vector2(cos(angulo) * radio_x, sin(angulo) * radio_y))
	return puntos


func _actualizar_ambiente_torres(delta: float) -> void:
	_tiempo_ambiente_torres += delta
	if _tiempo_ambiente_torres < 0.20:
		return
	var paso := _tiempo_ambiente_torres
	_tiempo_ambiente_torres = 0.0
	_actualizar_ventanas_hogares()
	_actualizar_aviso_evento_torres()
	_actualizar_decoracion_evento_torres()
	if _charcos_torres.is_empty():
		return
	if not is_instance_valid(_sistema_clima_torres):
		_sistema_clima_torres = get_tree().root.find_child("ClimateSystem", true, false)
	var precipitacion := 0.0
	if is_instance_valid(_sistema_clima_torres) and _sistema_clima_torres.has_method("obtener_estado"):
		var estado: Dictionary = _sistema_clima_torres.call("obtener_estado")
		var clima_variant: Variant = estado.get("clima", {})
		if clima_variant is Dictionary:
			precipitacion = clampf(float((clima_variant as Dictionary).get("precipitacion", 0.0)), 0.0, 1.0)
	if precipitacion > 0.02:
		_nivel_charcos_torres = move_toward(_nivel_charcos_torres, precipitacion, paso * 0.22)
	else:
		_nivel_charcos_torres = move_toward(_nivel_charcos_torres, 0.0, paso * 0.018)
	for indice in range(_charcos_torres.size()):
		var charco := _charcos_torres[indice]
		if is_instance_valid(charco):
			charco.modulate.a = _nivel_charcos_torres * 0.78
		if indice < _brillos_charcos_torres.size():
			var brillo := _brillos_charcos_torres[indice]
			if is_instance_valid(brillo):
				brillo.modulate.a = _nivel_charcos_torres * 0.48



## Indicador discreto sobre la plaza para que el jugador sepa cuándo hay
## mercado, comida vecinal o celebración estacional.
func _crear_aviso_evento_torres() -> void:
	_aviso_evento_torres = Label.new()
	_aviso_evento_torres.name = "AvisoEventoComunitario"
	_aviso_evento_torres.position = Vector2(-120.0, -154.0)
	_aviso_evento_torres.size = Vector2(240.0, 22.0)
	_aviso_evento_torres.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_evento_torres.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso_evento_torres.add_theme_color_override("font_color", Color("#f4dfb5"))
	_aviso_evento_torres.add_theme_color_override("font_outline_color", Color("#33271f"))
	_aviso_evento_torres.add_theme_constant_override("outline_size", 3)
	_aviso_evento_torres.add_theme_font_size_override("font_size", 12)
	_aviso_evento_torres.z_index = 12
	_aviso_evento_torres.visible = false
	add_child(_aviso_evento_torres)


func _actualizar_aviso_evento_torres() -> void:
	if not is_instance_valid(_aviso_evento_torres):
		return
	if _interior_activo or not is_instance_valid(_atmosfera_mundo):
		_aviso_evento_torres.visible = false
		return
	if not _atmosfera_mundo.has_method("obtener_tiempo"):
		_aviso_evento_torres.visible = false
		return
	var tiempo: Dictionary = _atmosfera_mundo.call("obtener_tiempo")
	if not bool(tiempo.get("calendario_cargado", false)):
		_aviso_evento_torres.visible = false
		return
	var minutos := int(floor(float(tiempo.get("hora_del_dia", 0.0)) * 60.0))
	var dia := int(tiempo.get("dia", 1))
	var dia_semana := posmod(dia - 1, 5)
	var dia_estacion := int(tiempo.get("dia_de_estacion", 0))
	var titulo := ""
	if dia_estacion == 1 and minutos >= 840 and minutos < 1200:
		titulo = "CELEBRACION DE TEMPORADA"
	elif dia_semana == 4 and minutos >= 540 and minutos < 1020:
		titulo = "MERCADO VECINAL"
	elif dia_semana == 4 and minutos >= 1020 and minutos < 1200:
		titulo = "COMIDA COMUNITARIA"
	if titulo.is_empty():
		_aviso_evento_torres.visible = false
		return
	if is_instance_valid(_jugador):
		var centro_plaza := to_global(Vector2.ZERO)
		if _jugador.global_position.distance_to(centro_plaza) > 420.0:
			_aviso_evento_torres.visible = false
			return
	_aviso_evento_torres.text = titulo
	_aviso_evento_torres.visible = true



## Los acontecimientos modifican físicamente la plaza. Los puestos y adornos
## sólo existen durante su evento; al terminar se retiran sin alterar el mapa base.
func _crear_contenedor_decoracion_eventos() -> void:
	_decoracion_evento_torres = Node2D.new()
	_decoracion_evento_torres.name = "DecoracionEventosComunitarios"
	_decoracion_evento_torres.z_index = 4
	_decoracion_evento_torres.visible = false
	add_child(_decoracion_evento_torres)


func _actualizar_decoracion_evento_torres() -> void:
	if not is_instance_valid(_decoracion_evento_torres) or _interior_activo:
		return
	if not is_instance_valid(_atmosfera_mundo):
		_atmosfera_mundo = get_tree().root.find_child("WorldAtmosphere", true, false)
	if not is_instance_valid(_atmosfera_mundo) or not _atmosfera_mundo.has_method("obtener_tiempo"):
		return
	var tiempo: Dictionary = _atmosfera_mundo.call("obtener_tiempo")
	if not bool(tiempo.get("calendario_cargado", false)):
		return

	var minutos := int(floor(float(tiempo.get("hora_del_dia", 0.0)) * 60.0))
	var dia := int(tiempo.get("dia", 1))
	var dia_semana := posmod(dia - 1, 5)
	var dia_estacion := int(tiempo.get("dia_de_estacion", 0))
	var evento := ""
	if dia_estacion == 1 and minutos >= 840 and minutos < 1200:
		evento = "temporada"
	elif dia_semana == 4 and minutos >= 540 and minutos < 1020:
		evento = "mercado"
	elif dia_semana == 4 and minutos >= 1020 and minutos < 1200:
		evento = "comida"

	if evento == _evento_decoracion_actual:
		return
	_evento_decoracion_actual = evento
	for hijo: Node in _decoracion_evento_torres.get_children():
		_decoracion_evento_torres.remove_child(hijo)
		hijo.queue_free()
	_decoracion_evento_torres.visible = not evento.is_empty()
	if evento.is_empty():
		return

	match evento:
		"mercado":
			# Mercadería limitada a los sprites originales de pan y manzana.
			_crear_puesto_evento("PuestoMercadoOeste", Vector2(-112.0, -54.0), false, 4)
			_crear_producto_puesto_evento("PanMercadoOeste", PRODUCTO_PAN, Vector2(-118.0, -42.0), 5)
			_crear_producto_puesto_evento("ManzanaMercadoOeste", PRODUCTO_MANZANA, Vector2(-105.0, -42.0), 5)
			_crear_puesto_evento("PuestoMercadoEste", Vector2(112.0, -54.0), true, 4)
			_crear_producto_puesto_evento("PanMercadoEste", PRODUCTO_PAN, Vector2(105.0, -42.0), 5)
			_crear_producto_puesto_evento("ManzanaMercadoEste", PRODUCTO_MANZANA, Vector2(118.0, -42.0), 5)
		"comida":
			# La mesa con platos ya contiene su comida: no se superponen
			# raciones, adornos ni asientos generados por código.
			for indice in range(3):
				var x := -104.0 + float(indice) * 104.0
				var mesa := Sprite2D.new()
				mesa.name = "MesaComunitaria_%02d" % indice
				mesa.texture = MUEBLE_MESA_PLATOS
				mesa.position = Vector2(x, 66.0)
				mesa.scale = Vector2(0.9, 0.8)
				mesa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				mesa.z_index = 4
				_decoracion_evento_torres.add_child(mesa)
		"temporada":
			# La celebración se anuncia, pero sus adornos esperan sprites propios.
			pass


func _crear_puesto_evento(nombre: String, posicion: Vector2, invertir: bool, z: int) -> void:
	if not is_instance_valid(_decoracion_evento_torres) or MERCADO_PUESTO == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = MERCADO_PUESTO
	sprite.position = posicion
	sprite.centered = true
	sprite.flip_h = invertir
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# El puesto conserva su proporción y se adapta a la huella de los puestos
	# que ya ocupaban la plaza, sin deformar el dibujo original.
	var tamano := MERCADO_PUESTO.get_size()
	if tamano.x > 0.0 and tamano.y > 0.0:
		var escala := minf(84.0 / tamano.x, 76.0 / tamano.y)
		sprite.scale = Vector2.ONE * escala
	sprite.z_index = z
	_decoracion_evento_torres.add_child(sprite)


func _crear_producto_puesto_evento(nombre: String, textura: Texture2D, posicion: Vector2, z: int) -> void:
	if not is_instance_valid(_decoracion_evento_torres) or textura == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = textura
	sprite.position = posicion
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tamano := textura.get_size()
	if tamano.x > 0.0 and tamano.y > 0.0:
		var escala := minf(13.0 / tamano.x, 13.0 / tamano.y)
		sprite.scale = Vector2.ONE * escala
	sprite.z_index = z
	_decoracion_evento_torres.add_child(sprite)


func _crear_luces_faroles() -> void:
	# Los dos postes originales se conservan y se añaden otros a intervalos
	# regulares sobre el camino principal de Torres.
	# La luz 2D ilumina el suelo; el brillo tenue queda sobre una CanvasLayer
	# para que CanvasModulate no lo apague.
	var gradiente: Gradient = Gradient.new()
	gradiente.set_color(0, Color(1.0, 0.76, 0.43, 0.34))
	gradiente.set_color(1, Color(1.0, 0.48, 0.12, 0.0))
	gradiente.add_point(0.28, Color(1.0, 0.68, 0.34, 0.22))
	gradiente.add_point(0.62, Color(1.0, 0.55, 0.22, 0.07))
	gradiente.add_point(0.84, Color(1.0, 0.48, 0.12, 0.015))

	var textura_luz: GradientTexture2D = GradientTexture2D.new()
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

	# Los postes siguen las calles longitudinales de los barrios y los accesos
	# norte/sur del centro; quedan sobre caminos y no en los extremos del mapa.
	var faroles: Array[Dictionary] = [
		{"nombre": "OesteNorte", "nodo": "Sprite_poste_oeste"},
		{"nombre": "OesteCentroNorte", "nodo": "Sprite_poste_OesteCentroNorte"},
		{"nombre": "OesteCentro", "nodo": "Sprite_poste_OesteCentro"},
		{"nombre": "OesteCentroSur", "nodo": "Sprite_poste_OesteCentroSur"},
		{"nombre": "OesteSur", "nodo": "Sprite_poste_OesteSur"},
		{"nombre": "EsteNorte", "nodo": "Sprite_poste_este"},
		{"nombre": "EsteCentroNorte", "nodo": "Sprite_poste_EsteCentroNorte"},
		{"nombre": "EsteCentro", "nodo": "Sprite_poste_EsteCentro"},
		{"nombre": "EsteCentroSur", "nodo": "Sprite_poste_EsteCentroSur"},
		{"nombre": "EsteSur", "nodo": "Sprite_poste_EsteSur"},
		{"nombre": "AccesoNorte", "nodo": "Sprite_poste_AccesoNorte"},
		{"nombre": "AccesoSur", "nodo": "Sprite_poste_AccesoSur"}
	]

	for farol_datos: Dictionary in faroles:
		var farol := get_node_or_null(NodePath(str(farol_datos["nodo"]))) as Sprite2D
		if not is_instance_valid(farol):
			push_warning("ReinoTorres: falta el poste editable en la escena: " + str(farol_datos["nodo"]))
			continue
		var posicion_global := farol.to_global(Vector2(0.0, -8.0))

		var nombre_farol := str(farol_datos["nombre"])
		var posicion_local: Vector2 = to_local(posicion_global)
		var luz: PointLight2D = PointLight2D.new()
		luz.name = "LuzFarol" + nombre_farol
		luz.position = posicion_local
		luz.texture = textura_luz
		luz.texture_scale = 2.8
		luz.color = Color("#ffd9a6")
		luz.energy = 0.72
		luz.range_item_cull_mask = 1
		luz.blend_mode = Light2D.BLEND_MODE_ADD
		luz.shadow_enabled = false
		luz.enabled = false
		add_child(luz)
		_luces_faroles.append(luz)

		var brillo: Sprite2D = Sprite2D.new()
		brillo.name = "Brillo" + nombre_farol
		brillo.texture = textura_luz
		brillo.position = posicion_global
		brillo.scale = Vector2(0.9, 0.9)
		brillo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		brillo.visible = false
		var material_brillo: CanvasItemMaterial = CanvasItemMaterial.new()
		material_brillo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		brillo.material = material_brillo
		_capa_brillos_faroles.add_child(brillo)
		_brillos_faroles.append(brillo)

	print("ReinoTorres: %d postes con iluminación tenue preparados." % _luces_faroles.size())
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
			luz.energy = 0.72 * intensidad

	for brillo: Sprite2D in _brillos_faroles:
		if is_instance_valid(brillo):
			brillo.visible = mostrar_faroles
			brillo.modulate = Color(1.0, 0.86, 0.68, intensidad * 0.55)


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
	# Los puestos usan el sprite dibujado para Torres; no se rasterizan
	# toldos, mostradores ni franjas mediante el generador procedural.
	_agrupar_poligonos_con_textura(
		["MarketCounter", "MarketCounterTop", "MarketAwningBase", "MarketAwningStripe1", "MarketAwningStripe2", "MarketAwningStripe3"],
		MERCADO_PUESTO, false
	)
	_agrupar_poligonos_con_textura(
		["FishStall", "FishStallAwning", "FishStallStripe"],
		MERCADO_PUESTO, true
	)
	for indice in range(1, 5):
		_agrupar_poligonos_con_textura(
			["MarketExtension%d" % indice, "MarketExtensionAwning%d" % indice, "MarketExtensionLegL%d" % indice, "MarketExtensionLegR%d" % indice],
			MERCADO_PUESTO, indice % 2 == 1
		)
	# El pozo ya tiene sprite propio en la escena.
	if get_node_or_null("Sprite_pozo") != null:
		_ocultar_placeholder(["WellShadow", "WellOuter", "WellWater", "WellLipTop"])
	_ocultar_placeholder(["LampWestPost", "LampEastPost"])
	_agrupar_poligonos_pixelart(["LampWestGlow"], "lampara", 0)
	_agrupar_poligonos_pixelart(["LampEastGlow"], "lampara", 1)


func _agrupar_poligonos_con_textura(nombres: Array, textura: Texture2D, invertir: bool) -> void:
	if textura == null:
		return
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
	var sprite := Sprite2D.new()
	sprite.name = "PuestoSprite_" + str(nombres[0])
	sprite.texture = textura
	sprite.position = limites.get_center()
	sprite.centered = true
	sprite.flip_h = invertir
	sprite.scale = Vector2(limites.size.x / textura.get_width(), limites.size.y / textura.get_height())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_mayor
	add_child(sprite)
	for poligono: Polygon2D in encontrados:
		poligono.visible = false


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

		# Ocultar primero los antiguos polígonos vectoriales del edificio.
		# Los sprites guardados en la escena son la fuente visual definitiva.
		_ocultar_placeholder(building["hide"])
		var grupo_edificio := _obtener_grupo_entrada({"id": clave})
		var contenedor_sprite: Node = grupo_edificio if is_instance_valid(grupo_edificio) else self
		var marcador_sprite := get_node_or_null("LayoutEdificios/Posicion_sprite_" + clave) as Marker2D
		var sprite_existente := contenedor_sprite.get_node_or_null(NodePath(String(building.get("sprite_node", "Sprite_" + clave)))) as Sprite2D
		if is_instance_valid(sprite_existente):
			if is_instance_valid(marcador_sprite):
				sprite_existente.position = contenedor_sprite.to_local(marcador_sprite.global_position)
			print("ReinoTorres: sprite oficial de escena activo para ", clave)
			continue

		# Solo generar arte procedural cuando el edificio todavía no tiene
		# un Sprite2D editable definido en la escena.
		var texture := _buscar_textura(building["paths"])
		var tiene_textura_personalizada := texture != null
		if not tiene_textura_personalizada:
			texture = TORRES_PIXEL_ART.crear_edificio(clave, absi(clave.hash()) % 7)

		var sprite := Sprite2D.new()
		sprite.name = String(building.get("sprite_node", "Sprite_" + clave.capitalize()))
		sprite.texture = texture
		if is_instance_valid(marcador_sprite):
			sprite.position = contenedor_sprite.to_local(marcador_sprite.global_position)
		else:
			sprite.position = building["position"]
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var target_size: Vector2 = building["size"]
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var scale_factor := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
			sprite.scale = Vector2.ONE * scale_factor
		sprite.z_index = 3
		if is_instance_valid(grupo_edificio):
			grupo_edificio.add_child(sprite)
		else:
			add_child(sprite)
		if tiene_textura_personalizada:
			print("ReinoTorres: sprite externo cargado para ", clave)
		else:
			print("ReinoTorres: pixel art procedural cargado para ", clave)




func obtener_posicion_exterior_para_viaje() -> Vector2:
	if _interior_activo:
		return _posicion_exterior
	if is_instance_valid(_jugador):
		return _jugador.global_position
	return Vector2.ZERO


func _entrar_al_interior(entrada: Dictionary) -> void:
	if _interior_activo or not is_instance_valid(_jugador):
		return
	if str(entrada.get("id", "")) == "posada_habitacion" and not _posada_tiene_acceso():
		Events.notification_pushed.emit("Tu suscripción de la posada no está activa.")
		return
	_ocultar_npcs_exteriores(get_tree().get_nodes_in_group("torres_game_npc"))
	_posicion_exterior = _jugador.global_position
	_entrada_interior_id = str(entrada.get("id", ""))
	_visibilidad_exterior.clear()
	_estados_colision_exterior.clear()
	for child: Node in get_children():
		if child == _capa_interior or child == _aviso_evento_torres:
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
	if _entrada_interior_id == "cuartel":
		_abrir_menu_servicio_edificio("cuartel")
	print("ReinoTorres: entrando a ", entrada["id"])


## Registra NPCs creados después de entrar a un edificio. La entidad sigue
## perteneciendo al contenedor exterior y debe permanecer oculta/no interactuable
## hasta que el jugador vuelva a salir del interior.
func desactivar_colision_npc_exterior(npc: Node) -> void:
	if not is_instance_valid(npc) or not npc is CollisionObject2D:
		return
	var cuerpo := npc as CollisionObject2D
	if not npc.has_meta("rutina_colision_original"):
		npc.set_meta("rutina_colision_original", {
			"layer": cuerpo.collision_layer,
			"mask": cuerpo.collision_mask
		})
	cuerpo.collision_layer = 0
	cuerpo.collision_mask = 0


func restaurar_colision_npc(npc: Node) -> void:
	if not is_instance_valid(npc) or not npc is CollisionObject2D:
		return
	var estado_variant: Variant = npc.get_meta("rutina_colision_original", {})
	if not estado_variant is Dictionary:
		return
	var estado := estado_variant as Dictionary
	var cuerpo := npc as CollisionObject2D
	cuerpo.collision_layer = int(estado.get("layer", cuerpo.collision_layer))
	cuerpo.collision_mask = int(estado.get("mask", cuerpo.collision_mask))
	npc.remove_meta("rutina_colision_original")


func _restaurar_formas_colision_npc(npc: Node) -> void:
	if not is_instance_valid(npc):
		return
	for forma_variant in npc.find_children("*", "CollisionShape2D", true, false):
		if not forma_variant is CollisionShape2D:
			continue
		var forma := forma_variant as CollisionShape2D
		var deshabilitada := bool(_estados_colision_exterior.get(forma.get_instance_id(), forma.disabled))
		forma.set_deferred("disabled", deshabilitada)
	for poligono_variant in npc.find_children("*", "CollisionPolygon2D", true, false):
		if not poligono_variant is CollisionPolygon2D:
			continue
		var poligono := poligono_variant as CollisionPolygon2D
		var deshabilitado := bool(_estados_colision_exterior.get(poligono.get_instance_id(), poligono.disabled))
		poligono.set_deferred("disabled", deshabilitado)


func _guardar_estado_visibilidad_npc(npc: Node) -> void:
	if not is_instance_valid(npc) or not npc is CanvasItem:
		return
	var visual := npc as CanvasItem
	var instance_id := visual.get_instance_id()
	if _visibilidad_npcs_exterior.has(instance_id):
		return
	_visibilidad_npcs_exterior[instance_id] = {
		"visible": visual.visible,
		"interactable": npc.is_in_group("interactable")
	}


func registrar_npc_materializado(npc: Node) -> void:
	if not _interior_activo or not is_instance_valid(npc):
		return
	_guardar_estado_visibilidad_npc(npc)
	if _contenedor_npcs_exterior == null:
		_contenedor_npcs_exterior = npc.get_parent()
	if is_instance_valid(_contenedor_npcs_exterior) and npc.get_parent() != _contenedor_npcs_exterior:
		npc.reparent(_contenedor_npcs_exterior, true)
	desactivar_colision_npc_exterior(npc)
	if npc is CanvasItem:
		(npc as CanvasItem).visible = false
	npc.remove_from_group("interactable")


func _ocultar_npcs_exteriores(npcs: Array) -> void:
	_visibilidad_npcs_exterior.clear()
	for npc in npcs:
		if not is_instance_valid(npc) or not npc is CanvasItem:
			continue
		if _contenedor_npcs_exterior == null:
			_contenedor_npcs_exterior = npc.get_parent()
		_guardar_estado_visibilidad_npc(npc)
		(npc as CanvasItem).visible = false
		# Ocultarlo no basta: el sistema de clics sigue encontrándolo
		# mientras pertenezca al grupo interactable.
		npc.remove_from_group("interactable")


func _restaurar_npcs_exteriores(npcs: Array) -> void:
	for npc in npcs:
		if not is_instance_valid(npc) or not npc is CanvasItem:
			continue
		var visual := npc as CanvasItem
		var sigue_dentro := bool(npc.get_meta("rutina_en_edificio", false))
		var estado_variant: Variant = _visibilidad_npcs_exterior.get(visual.get_instance_id(), {})
		var visible_antes := not sigue_dentro
		var interactuable_antes := npc is Creature
		if estado_variant is Dictionary:
			var estado := estado_variant as Dictionary
			visible_antes = bool(estado.get("visible", visible_antes))
			interactuable_antes = bool(estado.get("interactable", interactuable_antes))
		if sigue_dentro:
			desactivar_colision_npc_exterior(npc)
		else:
			restaurar_colision_npc(npc)
		visual.visible = not sigue_dentro and visible_antes
		if visual.visible and interactuable_antes:
			npc.add_to_group("interactable")
		else:
			npc.remove_from_group("interactable")
	_visibilidad_npcs_exterior.clear()


func _obtener_entrada_por_id(entrada_id: String) -> Dictionary:
	for entrada: Dictionary in ENTRADAS:
		if str(entrada.get("id", "")) == entrada_id:
			return entrada
	return {}


func sincronizar_npcs_del_interior() -> void:
	if not _interior_activo:
		return
	var entrada := _obtener_entrada_por_id(_entrada_interior_id)
	if not entrada.is_empty():
		_ubicar_npcs_del_edificio_en_interior(entrada)


func _ubicar_npcs_del_edificio_en_interior(entrada: Dictionary) -> void:
	var entrada_id := str(entrada.get("id", ""))
	var cuarto := _capa_interior.get_node_or_null("Habitacion_" + entrada_id) as Node2D
	if not is_instance_valid(cuarto):
		return
	# El castillo reúne a muchos más habitantes que una vivienda normal.
	# Los distribuimos alrededor del perímetro, dejando libre el centro y las
	# dos mesas para que puedan circular y conversar sin formar una pila.
	# Las claves de rutina y los IDs de puerta no siempre tienen el mismo
	# nombre (por ejemplo, casa_elian -> casa_oriente_a).
	var ubicacion_rutina_esperada := str(UBICACION_RUTINA_POR_ENTRADA.get(entrada_id, ""))
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
		# La sincronización puede ejecutarse cada ciclo de horarios. No reiniciar
		# la posición ni interrumpir paseos de NPCs que ya están en esta sala.
		if ya_asignado_a_esta_puerta and npc.get_parent() == cuarto:
			continue
		if npc.get_parent() != cuarto:
			npc.reparent(cuarto, true)
		restaurar_colision_npc(npc)
		_restaurar_formas_colision_npc(npc)
		var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento != null:
			movimiento.detener_por_rutina()
		npc.set_meta("rutina_en_edificio", true)
		npc.set_meta("rutina_edificio_id", entrada_id)
		npc.set_meta("rutina_en_transito", false)
		npc.remove_meta("viajando")
		if entrada_id == "castillo":
			npc.datos["actividad_actual"] = "conversando con los demás"
			npc.set_meta("actividad_actual", "conversando con los demás")
		var actor := npc as Node2D
		if entrada_id == "castillo":
			if indice < POSICIONES_NPC_CASTILLO_INTERIOR.size():
				actor.position = POSICIONES_NPC_CASTILLO_INTERIOR[indice]
			else:
				# Respaldo para reuniones con más asistentes que plazas
				# predefinidas: añade filas laterales sin reutilizar coordenadas.
				var extra := indice - POSICIONES_NPC_CASTILLO_INTERIOR.size()
				var columna := posmod(extra, 6)
				var fila := int(extra / 6)
				var lado := -1.0 if columna < 3 else 1.0
				var desplazamiento := posmod(columna, 3) * 52.0
				actor.position = Vector2(lado * (105.0 + desplazamiento), -20.0 + fila * 42.0)
		elif entrada_id == "panaderia":
			var nombre_panaderia := (npc as Creature).get_nombre_visual().strip_edges().to_lower()
			match nombre_panaderia:
				"elian":
					actor.position = Vector2(-42.0, 34.0)
				"ivo":
					actor.position = Vector2(42.0, 34.0)
				_:
					actor.position = POSICIONES_NPC_INTERIOR[indice % POSICIONES_NPC_INTERIOR.size()]
		else:
			actor.position = POSICIONES_NPC_INTERIOR[indice % POSICIONES_NPC_INTERIOR.size()]
		actor.visible = true
		# Los NPC trasladados al cuarto sí pueden recibir interacciones.
		npc.add_to_group("interactable")
		indice += 1


func teletransportar_jugador_a_npc(npc: Node) -> bool:
	if not is_instance_valid(npc) or not is_instance_valid(_jugador):
		return false
	if not npc.is_in_group("torres_game_npc"):
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
	if not is_instance_valid(_capa_interior) or not _capa_interior.is_ancestor_of(npc):
		return
	_devolver_npc_al_exterior(npc)


func _devolver_npc_al_exterior(npc: Node) -> void:
	if not is_instance_valid(npc) or not is_instance_valid(_contenedor_npcs_exterior):
		return
	var edificio_id := str(npc.get_meta("rutina_edificio_id", ""))
	var entrada := _obtener_entrada_por_id(edificio_id)
	npc.reparent(_contenedor_npcs_exterior, true)
	desactivar_colision_npc_exterior(npc)
	if not entrada.is_empty() and npc is Node2D:
		(npc as Node2D).global_position = _obtener_posicion_entrada_global(entrada) + Vector2(0.0, 28.0)
	if npc is CanvasItem:
		(npc as CanvasItem).visible = false
	npc.remove_from_group("interactable")


func _devolver_npcs_del_interior_al_exterior(npcs: Array) -> void:
	if not is_instance_valid(_contenedor_npcs_exterior) or not is_instance_valid(_capa_interior):
		return
	for npc in npcs:
		if not is_instance_valid(npc) or not _capa_interior.is_ancestor_of(npc):
			continue
		_devolver_npc_al_exterior(npc)


func _volver_al_lobby_posada() -> void:
	if not _interior_activo or _entrada_interior_id != "posada_habitacion" or not is_instance_valid(_jugador):
		return
	_entrada_interior_id = "posada"
	_construir_habitacion({"id": "posada", "nombre": "Posada", "tipo": "posada"})
	_jugador.global_position = to_global(Vector2(0, 70))


func _salir_del_interior() -> void:
	if not _interior_activo or not is_instance_valid(_jugador):
		return
	_cerrar_menu_posada()
	var npcs_actuales := get_tree().get_nodes_in_group("torres_game_npc")
	_devolver_npcs_del_interior_al_exterior(npcs_actuales)
	_restaurar_npcs_exteriores(npcs_actuales)
	_capa_interior.visible = false
	_capa_interior.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in get_children():
		if child == _capa_interior or child == _aviso_evento_torres:
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
	if entrada_id == "posada_habitacion":
		entrada_guardada = {"id": "posada_habitacion", "nombre": "Habitación de la posada", "tipo": "habitacion_posada", "pos": Vector2(360, -53)}
	if entrada_guardada.is_empty():
		push_warning("ReinoTorres: no se pudo restaurar el interior; entrada desconocida: " + entrada_id)
		return

	# GameState ya colocó al jugador en sus coordenadas guardadas dentro
	# de la habitación. Conservarlas antes de reconstruir la capa interior.
	var posicion_interior := _jugador.global_position
	var posicion_exterior_guardada := Vector2.ZERO
	var tiene_posicion_exterior := false
	var exterior_variant: Variant = estado.get("posicion_exterior", {})
	if exterior_variant is Dictionary:
		var exterior := exterior_variant as Dictionary
		if exterior.has("x") and exterior.has("y"):
			posicion_exterior_guardada = Vector2(
				float(exterior.get("x", 0.0)),
				float(exterior.get("y", 0.0))
			)
			tiene_posicion_exterior = true

	_entrar_al_interior(entrada_guardada)
	if tiene_posicion_exterior:
		# _entrar_al_interior captura la posición actual como salida; sustituirla
		# por la posición exterior original guardada, no por la interior.
		_posicion_exterior = posicion_exterior_guardada
	else:
		# Compatibilidad con saves antiguos sin coordenadas exteriores:
		# volver a la puerta del edificio en vez de quedar en el interior.
		_posicion_exterior = _obtener_posicion_entrada_global(entrada_guardada)
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
	var esquina_superior_izquierda := to_global(Vector2(-_interior_ancho_actual / 2.0, -_interior_alto_actual / 2.0))
	var esquina_inferior_derecha := to_global(Vector2(_interior_ancho_actual / 2.0, _interior_alto_actual / 2.0))
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


func _obtener_dimensiones_interior(tipo: String) -> Vector2:
	# Las salas grandes ganan espacio para circulación y mobiliario; las
	# viviendas y locales pequeños conservan una escala más íntima.
	match tipo:
		"castillo":
			return Vector2(704.0, 416.0)
		"biblioteca", "archivo", "centro_expediciones", "taberna", "escuela", "comercio", "consejo", "cuartel":
			return Vector2(640.0, 384.0)
		"vivero", "granero", "molino", "corrales", "clinica", "carpinteria", "taller":
			return Vector2(608.0, 368.0)
		_:
			return Vector2(INTERIOR_ANCHO, INTERIOR_ALTO)


func _construir_habitacion(entrada: Dictionary) -> void:
	for hijo: Node in _capa_interior.get_children():
		hijo.free()
	var cuarto := Node2D.new()
	cuarto.name = "Habitacion_" + str(entrada["id"])
	_capa_interior.add_child(cuarto)

	var tipo := str(entrada["tipo"])
	var dimensiones := _obtener_dimensiones_interior(tipo)
	_interior_ancho_actual = dimensiones.x
	_interior_alto_actual = dimensiones.y

	# Cada habitación recibe un acabado propio: suelo, zócalos, paredes y
	# molduras se dibujan con una paleta coherente con el uso del edificio.
	var acabado := Node2D.new()
	acabado.name = "AcabadoInterior"
	acabado.set_script(BUILDING_INTERIOR_STYLE_SCRIPT)
	acabado.z_index = -10
	acabado.call("configurar", tipo, dimensiones, _entrada_interior_id)
	cuarto.add_child(acabado)

	# Las colisiones siguen el tamaño real de esta habitación. La abertura
	# inferior conserva la posición de la puerta usada por el jugador.
	var mitad_ancho := _interior_ancho_actual / 2.0
	var mitad_alto := _interior_alto_actual / 2.0
	_agregar_colision_muro(cuarto, "ColisionNorte", Vector2(0, -mitad_alto - 4.0), Vector2(_interior_ancho_actual + 16.0, 16))
	_agregar_colision_muro(cuarto, "ColisionOeste", Vector2(-mitad_ancho - 4.0, 0), Vector2(16, _interior_alto_actual + 16.0))
	_agregar_colision_muro(cuarto, "ColisionEste", Vector2(mitad_ancho + 4.0, 0), Vector2(16, _interior_alto_actual + 16.0))
	_agregar_colision_muro(cuarto, "ColisionSurIzq", Vector2((-mitad_ancho - 4.0 - 12.0) / 2.0, mitad_alto + 4.0), Vector2(mitad_ancho - 12.0, 16))
	_agregar_colision_muro(cuarto, "ColisionSurDer", Vector2((132.0 + mitad_ancho + 4.0) / 2.0, mitad_alto + 4.0), Vector2(mitad_ancho - 128.0, 16))

	match tipo:
		"castillo":
			_agregar_sprite_mueble(cuarto, "MesaDelTrono", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -78), Vector2(1.5, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "MesaAudiencias", MUEBLE_MESA, Vector2(0, 28), Vector2(2.0, 1), 1)
			for i in range(4):
				var x := -150.0 + float(i) * 100.0
				_agregar_sprite_mueble(cuarto, "AsientoAudiencia%d" % i, MUEBLE_ASIENTO, Vector2(x, 88), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "ArmarioCastilloOeste", MUEBLE_ARMARIO, Vector2(-205, -125), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioCastilloEste", MUEBLE_ARMARIO, Vector2(205, -125), Vector2(0.9, 0.9), 1)
		"panaderia":
			# Zona de producción a la izquierda y exhibición continua al fondo.
			_agregar_sprite_mueble(cuarto, "Horno", MUEBLE_HORNO, Vector2(-190, -78), Vector2(1.8, 1.8), 1)
			for i in range(4):
				_agregar_sprite_mueble(cuarto, "EstanteriaPan%d" % i, MUEBLE_ESTANTERIA_PAN, Vector2(-35 + i * 66, -122), Vector2(1.35, 1.35), 1)
			_agregar_sprite_mueble(cuarto, "Mostrador", MUEBLE_MESA_PLATOS, Vector2(65, -12), Vector2(1.25, 1.05), 1)
			_agregar_sprite_mueble(cuarto, "MesaAmasado", MUEBLE_MESA, Vector2(-35, 78), Vector2(1.2, 1), 1)
			_agregar_sprite_mueble(cuarto, "SillaPanadero", MUEBLE_SILLA_DERECHA, Vector2(55, 105), Vector2.ONE, 1, true)
			_agregar_sprite_mueble(cuarto, "AlmacenHarina", MUEBLE_ARMARIO, Vector2(-205, 65), Vector2(0.9, 0.9), 1)
		"posada":
			_agregar_sprite_mueble(cuarto, "MostradorRecepcion", MUEBLE_MESA, Vector2(0, -112), Vector2(1.8, 1), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioPosada", MUEBLE_ARMARIO, Vector2(-205, -110), Vector2(0.9, 0.9), 1)
			_agregar_estacion_posada(cuarto, Vector2(0, -68))
			for i in range(3):
				var x := -112.0 + float(i) * 112.0
				_agregar_sprite_mueble(cuarto, "Mesa%d" % i, MUEBLE_MESA_PLATOS, Vector2(x, -12), Vector2(0.95, 0.9), 1)
				_agregar_sprite_mueble(cuarto, "SillaMesa%d" % i, MUEBLE_SILLA_FRENTE, Vector2(x, 32), Vector2.ONE, 1)
				_agregar_sprite_mueble(cuarto, "SillaExtra%d" % i, MUEBLE_SILLA_FRENTE, Vector2(x, 72), Vector2.ONE, 1)
		"vivero":
			var tilemap_tierra: TileMapDual = TORRES_VIVERO_BUILDER.crear_tilemap_tierra(cuarto)
			var capa_humedad: TileMapLayer = TORRES_VIVERO_BUILDER.crear_capa_tierra_mojada(cuarto)
			TORRES_VIVERO_BUILDER.agregar_parcela(cuarto, tilemap_tierra, capa_humedad, "BancalOeste", Vector2(-155, -5), Vector2i(3, 2))
			TORRES_VIVERO_BUILDER.agregar_parcela(cuarto, tilemap_tierra, capa_humedad, "BancalCentro", Vector2(0, -5), Vector2i(3, 2))
			TORRES_VIVERO_BUILDER.agregar_parcela(cuarto, tilemap_tierra, capa_humedad, "BancalEste", Vector2(155, -5), Vector2i(3, 2))
			TORRES_VIVERO_BUILDER.agregar_parcela(cuarto, tilemap_tierra, capa_humedad, "BancalSurOeste", Vector2(-155, 92), Vector2i(3, 1))
			TORRES_VIVERO_BUILDER.agregar_parcela(cuarto, tilemap_tierra, capa_humedad, "BancalSurCentro", Vector2(0, 92), Vector2i(3, 1))
			if is_instance_valid(tilemap_tierra):
				tilemap_tierra.call_deferred("reconstruir_renderer_dual")
			_agregar_sprite_mueble(cuarto, "MesaPreparacionCultivo", MUEBLE_MESA, Vector2(115, -125), Vector2(1.1, 0.95), 1)
			_agregar_estacion_edificio(cuarto, "vivero", "Revisar vivero", Vector2(115, -98))
			_agregar_sprite_mueble(cuarto, "CofreSemillasVivero", MUEBLE_COFRE, Vector2(210, 105), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioHerramientasVivero", MUEBLE_ARMARIO, Vector2(-220, 105), Vector2(0.85, 0.85), 1)
		"herbolario":
			_agregar_sprite_mueble(cuarto, "MesaElaboracionHerbolario", MUEBLE_MESA_DOCUMENTOS, Vector2(-105, -78), Vector2(1.35, 1.05), 1)
			_agregar_estacion_edificio(cuarto, "herbolario_elaboracion", "Elaborar infusiones y remedios", Vector2(-105, -48))
			_agregar_sprite_mueble(cuarto, "MesaSecadoTrituracionHerbolario", MUEBLE_MESA_PLATOS, Vector2(90, -78), Vector2(1.25, 1.05), 1)
			_agregar_estacion_edificio(cuarto, "herbolario_procesamiento", "Secar y triturar materiales", Vector2(90, -48))
			_agregar_sprite_mueble(cuarto, "ArmarioMuestrasHerbolario", MUEBLE_ARMARIO, Vector2(-205, 82), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "EstanteHerbolario", MUEBLE_ARMARIO, Vector2(205, 82), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "CofreMuestrasHerbolario", MUEBLE_COFRE, Vector2(0, 115), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "SillaInvestigacionHerbolario", MUEBLE_SILLA_FRENTE, Vector2(-105, -25), Vector2.ONE, 1)
		"taberna":
			# Barra al fondo y cinco mesas en dos zonas para que los grupos
			# puedan reunirse sin bloquear el acceso ni la circulación central.
			_agregar_sprite_mueble(cuarto, "BarraTaberna", MUEBLE_MESA_PLATOS, Vector2(0, -135), Vector2(2.0, 1.1), 1)
			_agregar_sprite_mueble(cuarto, "EstanteTaberna", MUEBLE_ARMARIO, Vector2(-255, -125), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "HogarTaberna", MUEBLE_HORNO, Vector2(255, -125), Vector2(1.25, 1.25), 1)
			for i in range(5):
				var x := -250.0 + float(i) * 125.0
				var y := 12.0 if i % 2 == 0 else 82.0
				_agregar_sprite_mueble(cuarto, "MesaTaberna%d" % i, MUEBLE_MESA_PLATOS, Vector2(x, y), Vector2(0.95, 0.9), 1)
				_agregar_sprite_mueble(cuarto, "SillaTaberna%dA" % i, MUEBLE_SILLA_FRENTE, Vector2(x - 24, y + 34), Vector2.ONE, 1)
				_agregar_sprite_mueble(cuarto, "SillaTaberna%dB" % i, MUEBLE_SILLA_FRENTE, Vector2(x + 24, y - 34), Vector2.ONE, 1)
			_agregar_estacion_edificio(cuarto, "taberna", "Hablar en la taberna", Vector2(0, -85))
		"escuela":
			# Aula ampliada: cuatro columnas de pupitres y un corredor central.
			_agregar_sprite_mueble(cuarto, "PizarraEscuela", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -145), Vector2(1.8, 0.8), 1)
			_agregar_sprite_mueble(cuarto, "MesaDocenteEscuela", MUEBLE_MESA, Vector2(0, -98), Vector2(1.4, 0.9), 1)
			for fila in range(2):
				for columna in range(4):
					var x := -225.0 + float(columna) * 150.0
					var y := -12.0 + float(fila) * 100.0
					_agregar_sprite_mueble(cuarto, "PupitreEscuela_%d_%d" % [fila, columna], MUEBLE_MESA_DOCUMENTOS, Vector2(x, y), Vector2(0.8, 0.7), 1)
					_agregar_sprite_mueble(cuarto, "AsientoEscuela_%d_%d" % [fila, columna], MUEBLE_SILLA_FRENTE, Vector2(x, y + 28), Vector2(0.8, 0.8), 1)
			_agregar_sprite_mueble(cuarto, "EstanteEscuelaOeste", MUEBLE_ARMARIO, Vector2(-275, 112), Vector2(0.85, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "EstanteEscuelaEste", MUEBLE_ARMARIO, Vector2(275, 112), Vector2(0.85, 0.85), 1)
			_agregar_estacion_edificio(cuarto, "escuela", "Consultar lecciones", Vector2(0, -62))
		"habitacion_posada":
			_agregar_sprite_mueble(cuarto, "CamaHabitacion", MUEBLE_CAMA, Vector2(-130, -75), Vector2(1.1, 1.1), 1)
			_agregar_sprite_mueble(cuarto, "CofreHabitacion", MUEBLE_COFRE, Vector2(155, 78), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "MesaHabitacion", MUEBLE_MESA, Vector2(125, -85), Vector2(1.0, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "SillaHabitacion", MUEBLE_SILLA_FRENTE, Vector2(125, -38), Vector2.ONE, 1)
		"forja":
			_agregar_sprite_mueble(cuarto, "Hogar", MUEBLE_HORNO, Vector2(-175, -82), Vector2(1.8, 1.8), 1)
			_agregar_sprite_mueble(cuarto, "Yunque", MUEBLE_YUNQUE, Vector2(65, -20), Vector2(1.3, 1.3), 1)
			_agregar_sprite_mueble(cuarto, "BancoHerramientas", MUEBLE_MESA_DOCUMENTOS, Vector2(105, 92), Vector2(1.2, 1), 1)
			_agregar_sprite_mueble(cuarto, "MesaInspeccionEquipo", MUEBLE_MESA_DOCUMENTOS, Vector2(180, -75), Vector2(1.25, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "AsientoInspeccionEquipo", MUEBLE_SILLA_FRENTE, Vector2(180, -20), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "AlmacenForja", MUEBLE_ARMARIO, Vector2(-190, 95), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "MaterialesForja", MUEBLE_COFRE, Vector2(195, 95), Vector2(0.85, 0.85), 1)
			_agregar_estacion_edificio(cuarto, "forja", "Reparar herramientas", Vector2(65, 20))
			_agregar_estacion_laboratorio(cuarto, "forja_inspeccion", "Inspeccionar armas y herramientas", Vector2(180, -48))
		"archivo":
			_agregar_sprite_mueble(cuarto, "EstanteArchivoOeste", MUEBLE_ARMARIO, Vector2(-195, -105), Vector2(1.0, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "EstanteArchivoCentro", MUEBLE_ARMARIO, Vector2(-95, -105), Vector2(1.0, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "EstanteArchivoEste", MUEBLE_ARMARIO, Vector2(195, -105), Vector2(1.0, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "MesaDocumentosPersonajes", MUEBLE_MESA_DOCUMENTOS, Vector2(-105, 38), Vector2(1.35, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "AsientoPersonajes", MUEBLE_SILLA_FRENTE, Vector2(-105, 88), Vector2.ONE, 1)
			_agregar_estacion_archivo(cuarto, "documentos_personajes", "Consultar personajes", Vector2(-105, 8))
			_agregar_sprite_mueble(cuarto, "MesaHistoriaTorres", MUEBLE_MESA_DOCUMENTOS, Vector2(105, 38), Vector2(1.35, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "AsientoHistoria", MUEBLE_SILLA_FRENTE, Vector2(105, 88), Vector2.ONE, 1)
			_agregar_estacion_archivo(cuarto, "historia_torres", "Consultar historia de Torres", Vector2(105, 8))
		"biblioteca":
			# Estanterías perimetrales, consulta central y dos puestos laterales
			# que aprovechan el ancho extra sin cerrar el corredor de entrada.
			for x in [-280.0, -140.0, 0.0, 140.0, 280.0]:
				_agregar_sprite_mueble(cuarto, "EstanteriaBiblioteca_%d" % int(x), MUEBLE_ARMARIO, Vector2(x, -122), Vector2(0.95, 0.95), 1)
			_agregar_sprite_mueble(cuarto, "MesaConsultaBiblioteca", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -28), Vector2(1.45, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "MostradorBiblioteca", MUEBLE_MESA, Vector2(0, 105), Vector2(1.5, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "MesaLecturaOeste", MUEBLE_MESA_DOCUMENTOS, Vector2(-230, 30), Vector2(0.9, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "MesaLecturaEste", MUEBLE_MESA_DOCUMENTOS, Vector2(230, 30), Vector2(0.9, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "SillaBibliotecaOeste", MUEBLE_SILLA_FRENTE, Vector2(-105, 55), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "SillaBibliotecaEste", MUEBLE_SILLA_FRENTE, Vector2(105, 55), Vector2.ONE, 1)
		"centro_expediciones":
			# La mesa central organiza las rutas; las mesas laterales sirven para
			# revisar mapas y preparar el equipo antes de salir.
			_agregar_sprite_mueble(cuarto, "MesaPlanificacionGremio", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -28), Vector2(1.8, 1.25), 1)
			_agregar_sprite_mueble(cuarto, "MesaRegistroGarumis", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -145), Vector2(1.25, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "AsientoRegistroGarumis", MUEBLE_SILLA_FRENTE, Vector2(0, -102), Vector2.ONE, 1)
			_agregar_estacion_edificio(cuarto, "garumis", "Consultar Garumis", Vector2(0, -108))
			_agregar_sprite_mueble(cuarto, "ArmarioEquipoExpedicionesOeste", MUEBLE_ARMARIO, Vector2(-270, -112), Vector2(0.95, 0.95), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioEquipoExpedicionesEste", MUEBLE_ARMARIO, Vector2(270, -112), Vector2(0.95, 0.95), 1)
			_agregar_sprite_mueble(cuarto, "MesaMapasOeste", MUEBLE_MESA_DOCUMENTOS, Vector2(-225, 8), Vector2(0.9, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "MesaMapasEste", MUEBLE_MESA_DOCUMENTOS, Vector2(225, 8), Vector2(0.9, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "CajaProvisionesExpedicionesOeste", MUEBLE_COFRE, Vector2(-185, 112), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "CajaProvisionesExpedicionesEste", MUEBLE_COFRE, Vector2(185, 112), Vector2(0.9, 0.9), 1)
			_agregar_estacion_edificio(cuarto, "centro_expediciones", "Mesa de expediciones", Vector2(0, 12))
			_agregar_estacion_edificio(cuarto, "viaje_reinos", "Viajar entre reinos", Vector2(0, 145))
		"clinica":
			# La recepción queda al fondo; las camas se mantienen como decoración
			# clínica y no heredan la acción de dormir de las camas domésticas.
			_agregar_sprite_mueble(cuarto, "MostradorClinica", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -118), Vector2(1.45, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioMedicinasClinicaOeste", MUEBLE_ARMARIO, Vector2(-205, -112), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioMedicinasClinicaEste", MUEBLE_ARMARIO, Vector2(205, -112), Vector2(0.9, 0.9), 1)
			_agregar_sprite_decorativo(cuarto, "CamaAtencionClinicaOeste", MUEBLE_CAMA, Vector2(-125, 8), Vector2(1.05, 1.05), 1)
			_agregar_sprite_decorativo(cuarto, "CamaAtencionClinicaEste", MUEBLE_CAMA, Vector2(125, 8), Vector2(1.05, 1.05), 1)
			_agregar_sprite_mueble(cuarto, "AsientoClinicaOeste", MUEBLE_SILLA_FRENTE, Vector2(-125, 72), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "AsientoClinicaEste", MUEBLE_SILLA_FRENTE, Vector2(125, 72), Vector2.ONE, 1)
		"consejo":
			_agregar_sprite_mueble(cuarto, "MesaConsejo", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -5), Vector2(2.0, 1.25), 1)
			for i in range(8):
				var x := -240.0 + float(i % 4) * 160.0
				var y := -105.0 if i < 4 else 92.0
				_agregar_sprite_mueble(cuarto, "SillaConsejo%d" % i, MUEBLE_SILLA_DERECHA, Vector2(x, y), Vector2.ONE, 1, x > 0.0)
			_agregar_sprite_mueble(cuarto, "ArmarioConsejo", MUEBLE_ARMARIO, Vector2(275, -125), Vector2(0.85, 0.85), 1)
		"oris":
			_agregar_sprite_mueble(cuarto, "ArmarioOrisOeste", MUEBLE_ARMARIO, Vector2(-195, -105), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioOrisEste", MUEBLE_ARMARIO, Vector2(195, -105), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "MesaMuestras", MUEBLE_MESA_PLATOS, Vector2(-105, 5), Vector2(1.0, 1.0), 1)
			_agregar_sprite_mueble(cuarto, "MesaEstudio", MUEBLE_MESA_DOCUMENTOS, Vector2(65, 28), Vector2(1.5, 1.1), 1)
			_agregar_sprite_mueble(cuarto, "SillaEstudio", MUEBLE_SILLA_FRENTE, Vector2(65, 82), Vector2.ONE, 1)
		"laboratorio":
			# Una única mesa de análisis: el resto de procedimientos se integrará
			# aquí cuando existan mecánicas reales que los justifiquen.
			_agregar_sprite_mueble(cuarto, "MesaAnalisis", MUEBLE_MESA_DOCUMENTOS, Vector2(0, -42), Vector2(1.45, 1.15), 1)
			_agregar_sprite_mueble(cuarto, "AsientoAnalisis", MUEBLE_SILLA_DERECHA, Vector2(-55, 18), Vector2.ONE, 1)
			_agregar_estacion_laboratorio(cuarto, "examen", "Estudiar", Vector2(0, 18))
		"comercio":
			_agregar_sprite_mueble(cuarto, "EstanteComercioOeste", MUEBLE_ARMARIO, Vector2(-220, -125), Vector2(0.85, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "EstanteComercioEste", MUEBLE_ARMARIO, Vector2(220, -125), Vector2(0.85, 0.85), 1)
			var vendedores := ["Bruna", "Elian", "Darven", "Saira", "Narel", "Nima", "Mara", "Ivo"]
			for i in range(vendedores.size()):
				var columna := i % 4
				var fila := int(i / 4)
				var posicion_puesto := Vector2(-225.0 + columna * 150.0, -48.0 + fila * 142.0)
				_agregar_puesto_comercio(cuarto, str(vendedores[i]), posicion_puesto)
		"registro", "almacen":
			_agregar_sprite_mueble(cuarto, "Mostrador", MUEBLE_MESA, Vector2(0, -95), Vector2(1.9, 1), 1)
			if tipo == "registro":
				_agregar_estacion_edificio(cuarto, "pasaje_exterior", "Solicitar pasaje al mundo exterior", Vector2(0, -42))
			_agregar_sprite_mueble(cuarto, "EstanteComercioOeste", MUEBLE_ARMARIO, Vector2(-190, -95), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "EstanteComercioEste", MUEBLE_ARMARIO, Vector2(190, -95), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "MesaInventario", MUEBLE_MESA_DOCUMENTOS, Vector2(0, 55), Vector2(1.35, 1), 2)
			_agregar_sprite_mueble(cuarto, "SillaInventario", MUEBLE_SILLA_FRENTE, Vector2(0, 103), Vector2.ONE, 1)
		"cuartel":
			_agregar_sprite_mueble(cuarto, "ArmarioCuartelOeste", MUEBLE_ARMARIO, Vector2(-205, -118), Vector2(0.85, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioCuartelEste", MUEBLE_ARMARIO, Vector2(205, -118), Vector2(0.85, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "MesaLicencias", MUEBLE_MESA_DOCUMENTOS, Vector2(-105, 65), Vector2(1.2, 1), 1)
			_agregar_sprite_mueble(cuarto, "MesaArsenal", MUEBLE_MESA, Vector2(105, 65), Vector2(1.2, 1), 1)
			_agregar_sprite_mueble(cuarto, "MesaEntrenamiento", MUEBLE_MESA, Vector2(0, -5), Vector2(1.45, 1.15), 1)
		"taller", "carpinteria":
			_agregar_sprite_mueble(cuarto, "BancoTrabajo", MUEBLE_MESA_DOCUMENTOS, Vector2(-25, 5), Vector2(1.6, 1.1), 1)
			_agregar_sprite_mueble(cuarto, "Materiales", MUEBLE_COFRE, Vector2(180, 72), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioHerramientas", MUEBLE_ARMARIO, Vector2(-190, -105), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioMateriales", MUEBLE_ARMARIO, Vector2(190, -105), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "AsientoTrabajo", MUEBLE_ASIENTO, Vector2(-25, 65), Vector2.ONE, 1)
			if tipo == "carpinteria":
				_agregar_estacion_edificio(cuarto, "carpinteria", "Encargar muebles", Vector2(-25, 5))
		"granero", "molino", "semillas":
			_agregar_sprite_mueble(cuarto, "AlmacenOeste", MUEBLE_ARMARIO, Vector2(-190, -100), Vector2(0.95, 0.95), 1)
			_agregar_sprite_mueble(cuarto, "AlmacenEste", MUEBLE_ARMARIO, Vector2(190, -100), Vector2(0.95, 0.95), 1)
			_agregar_sprite_mueble(cuarto, "MesaPesaje", MUEBLE_MESA, Vector2(0, 45), Vector2(1.5, 1), 1)
			_agregar_sprite_mueble(cuarto, "SacoAlmacen", MUEBLE_COFRE, Vector2(-145, 88), Vector2(0.85, 0.85), 1)
		"corrales":
			_agregar_sprite_mueble(cuarto, "AlmacenForraje", MUEBLE_COFRE, Vector2(-175, -90), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "MesaPreparacion", MUEBLE_MESA, Vector2(100, 65), Vector2(1.2, 1), 1)
			_agregar_sprite_mueble(cuarto, "ArmarioCorrales", MUEBLE_ARMARIO, Vector2(195, -105), Vector2(0.85, 0.85), 1)
		"alfareria":
			_agregar_sprite_mueble(cuarto, "HornoCeramica", MUEBLE_HORNO, Vector2(-130, -65), Vector2(1.8, 1.8), 1)
			_agregar_sprite_mueble(cuarto, "MesaCeramica", MUEBLE_MESA, Vector2(65, 50), Vector2(1.3, 1), 1)
			_agregar_sprite_mueble(cuarto, "AlmacenCeramica", MUEBLE_ARMARIO, Vector2(190, -100), Vector2(0.9, 0.9), 1)
		"vivienda":
			_agregar_sprite_mueble(cuarto, "Cama", MUEBLE_CAMA, Vector2(-145, -55), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "Armario", MUEBLE_ARMARIO, Vector2(-205, -112), Vector2(0.85, 0.85), 1)
			_agregar_sprite_mueble(cuarto, "Mesa", MUEBLE_MESA_PLATOS, Vector2(65, 20), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "Silla", MUEBLE_SILLA_FRENTE, Vector2(65, 65), Vector2.ONE, 1)
			_agregar_sprite_mueble(cuarto, "Fogon", MUEBLE_HORNO, Vector2(165, -75), Vector2(0.9, 0.9), 1)
			_agregar_sprite_mueble(cuarto, "Arcon", MUEBLE_COFRE, Vector2(-55, 78), Vector2(0.9, 0.9), 1)


func _agregar_sprite_mueble(padre: Node, nombre: String, textura: Texture2D, posicion: Vector2, escala: Vector2 = Vector2.ONE, z: int = 1, flip_h: bool = false) -> void:
	if textura == null:
		push_warning("ReinoTorres: no se pudo cargar el sprite del mueble: " + nombre)
		return
	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = textura
	sprite.position = posicion
	sprite.scale = escala
	sprite.centered = true
	sprite.flip_h = flip_h
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


func _agregar_sprite_decorativo(padre: Node, nombre: String, textura: Texture2D, posicion: Vector2, escala: Vector2 = Vector2.ONE, z: int = 1) -> void:
	if textura == null:
		push_warning("ReinoTorres: no se pudo cargar el sprite decorativo: " + nombre)
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


# La estancia usa el calendario jugable: un mes equivale a 30 días del mundo.
# El vencimiento se guarda como día absoluto y nunca depende del reloj del dispositivo.
func _obtener_dia_absoluto_mundo() -> int:
	var atmosfera := GameState._world_atmosphere as WorldAtmosphere
	if not is_instance_valid(atmosfera) or not bool(atmosfera.obtener_tiempo().get("calendario_cargado", false)):
		return -1
	return atmosfera.anio * maxi(atmosfera.dias_por_anio, 1) + atmosfera.dia_del_anio


func _obtener_estado_posada() -> Dictionary:
	var estado_variant: Variant = GameState.world_state.flags.get(POSADA_FLAG, {})
	if estado_variant is Dictionary:
		return (estado_variant as Dictionary).duplicate(true)
	return {}


func _guardar_estado_posada(estado: Dictionary) -> void:
	GameState.world_state.flags[POSADA_FLAG] = estado.duplicate(true)
	GameState.call_deferred("_ejecutar_guardado_rapido")


func _posada_tiene_acceso() -> bool:
	var estado := _obtener_estado_posada()
	if not bool(estado.get("primer_mes_gratis_usado", false)):
		return false
	var hoy := _obtener_dia_absoluto_mundo()
	return hoy >= 0 and int(estado.get("vence_dia_absoluto", -1)) > hoy


func _crear_interfaz_posada() -> void:
	if is_instance_valid(_menu_posada_layer):
		return
	_menu_posada_layer = CanvasLayer.new()
	_menu_posada_layer.name = "InterfazPosada"
	_menu_posada_layer.layer = 45
	get_tree().root.add_child(_menu_posada_layer)

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_posada_layer.add_child(raiz)

	var centrador := CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centrador)

	_menu_posada_panel = PanelContainer.new()
	_menu_posada_panel.name = "PanelPosada"
	_menu_posada_panel.custom_minimum_size = Vector2(310, 0)
	PIXEL_UI_THEME.apply(_menu_posada_panel, false)
	centrador.add_child(_menu_posada_panel)

	_menu_posada_contenido = VBoxContainer.new()
	_menu_posada_contenido.add_theme_constant_override("separation", 8)
	_menu_posada_panel.add_child(_menu_posada_contenido)


func _crear_boton_posada(texto: String, accion: Callable, deshabilitado: bool = false) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(270, 38)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.disabled = deshabilitado
	boton.pressed.connect(accion)
	PIXEL_UI_THEME.apply(boton, false)
	_menu_posada_contenido.add_child(boton)
	return boton


func _mostrar_menu_posada(vista: String = "principal") -> void:
	_crear_interfaz_posada()
	if not is_instance_valid(_menu_posada_contenido):
		return
	_menu_posada_vista = vista
	for hijo in _menu_posada_contenido.get_children():
		hijo.queue_free()

	var panel_estado := PanelContainer.new()
	panel_estado.name = "EstadoPosada"
	panel_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fondo_estado: StyleBoxTexture = PIXEL_UI_THEME.button_surface_style()
	if fondo_estado != null:
		panel_estado.add_theme_stylebox_override("panel", fondo_estado)
	_menu_posada_contenido.add_child(panel_estado)

	_menu_posada_estado = Label.new()
	_menu_posada_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_posada_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_posada_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_estado.add_child(_menu_posada_estado)

	var estado := _obtener_estado_posada()
	var hoy := _obtener_dia_absoluto_mundo()
	var gratis_disponible := not bool(estado.get("primer_mes_gratis_usado", false))
	var activa := hoy >= 0 and int(estado.get("vence_dia_absoluto", -1)) > hoy

	match vista:
		"principal":
			if gratis_disponible:
				_menu_posada_estado.text = "Tu primera estancia de un mes es gratuita."
			elif activa:
				_menu_posada_estado.text = "Tu habitación está disponible."
			else:
				_menu_posada_estado.text = "Tu estancia ha terminado. Tus pertenencias siguen guardadas."
			_crear_boton_posada("Comprar", Callable(self, "_mostrar_menu_posada").bind("comprar"))
			_crear_boton_posada("Ir a la habitación", Callable(self, "_ir_habitacion_posada"), not activa)
		"comprar":
			_menu_posada_estado.text = "La estancia cuesta 100 monedas por mes."
			if gratis_disponible:
				_crear_boton_posada("Activar primer mes gratis", Callable(self, "_comprar_estancia_posada").bind(true))
			elif activa:
				_crear_boton_posada("Estancia activa", Callable(self, "_mostrar_menu_posada").bind("comprar"), true)
			else:
				_crear_boton_posada("Renovar por 100 monedas", Callable(self, "_comprar_estancia_posada").bind(false))
			_crear_boton_posada("Tienda de muebles", Callable(self, "_mostrar_menu_posada").bind("muebles"))
		"muebles":
			_menu_posada_estado.text = "Compra muebles para tu habitación. Las compras quedan guardadas en tu partida; falta conectar su colocación."
			for mueble: Dictionary in POSADA_CATALOGO_MUEBLES:
				var texto := "%s · %d monedas" % [str(mueble.nombre), int(mueble.precio)]
				_crear_boton_posada(texto, Callable(self, "_comprar_mueble_posada").bind(str(mueble.id)))
			_crear_boton_posada("Volver", Callable(self, "_mostrar_menu_posada").bind("comprar"))

	_crear_boton_posada("Cerrar", Callable(self, "_cerrar_menu_posada"))
	_menu_posada_layer.visible = true


func _ir_habitacion_posada() -> void:
	if not _posada_tiene_acceso():
		Events.notification_pushed.emit("Necesitas activar tu estancia en la recepción.")
		_mostrar_menu_posada("principal")
		return
	if _interior_activo:
		if _entrada_interior_id == "posada":
			_cerrar_menu_posada()
			call_deferred("_cambiar_de_lobby_a_habitacion_posada")
		else:
			_cerrar_menu_posada()
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_jugador):
		Events.notification_pushed.emit("No se encontró al jugador para entrar a la habitación.")
		return

	_cerrar_menu_posada()
	var entrada := {
		"id": "posada_habitacion",
		"nombre": "Habitación de la posada",
		"tipo": "habitacion_posada"
	}
	# La transición se ejecuta después de terminar la señal del botón.
	# Así evitamos cambiar visibilidad, colisiones y cámara mientras la UI
	# de recepción todavía está procesando su evento de pulsación.
	call_deferred("_entrar_al_interior", entrada)


func _cambiar_de_lobby_a_habitacion_posada() -> void:
	if not _interior_activo or _entrada_interior_id != "posada" or not _posada_tiene_acceso():
		return
	if not is_instance_valid(_jugador):
		return
	_entrada_interior_id = "posada_habitacion"
	_construir_habitacion({
		"id": "posada_habitacion",
		"nombre": "Habitación de la posada",
		"tipo": "habitacion_posada"
	})
	_jugador.global_position = to_global(Vector2(0, 70))


func _comprar_estancia_posada(gratis: bool) -> void:
	_pagar_estancia_posada(gratis)
	_mostrar_menu_posada("principal")


func _cerrar_menu_posada() -> void:
	if is_instance_valid(_menu_posada_layer):
		_menu_posada_layer.visible = false


func _comprar_mueble_posada(mueble_id: String) -> void:
	var precio := -1
	for mueble: Dictionary in POSADA_CATALOGO_MUEBLES:
		if str(mueble.get("id", "")) == mueble_id:
			precio = int(mueble.get("precio", -1))
			break
	if precio < 0:
		push_warning("Posada: intento de compra con un mueble desconocido: " + mueble_id)
		return
	if not GameState.modificar_dinero(-precio):
		if is_instance_valid(_menu_posada_estado):
			_menu_posada_estado.text = "No tienes suficientes monedas."
		return
	var estado := _obtener_estado_posada()
	var comprados_variant: Variant = estado.get("muebles_comprados", {})
	var comprados: Dictionary = comprados_variant.duplicate(true) if comprados_variant is Dictionary else {}
	comprados[mueble_id] = maxi(0, int(comprados.get(mueble_id, 0))) + 1
	estado["muebles_comprados"] = comprados
	_guardar_estado_posada(estado)
	if is_instance_valid(_menu_posada_estado):
		_menu_posada_estado.text = "Compraste: " + mueble_id.capitalize() + ". Ya está disponible para colocar."
	_mostrar_menu_posada("muebles")


func _pagar_estancia_posada(gratis: bool) -> void:
	var hoy := _obtener_dia_absoluto_mundo()
	if hoy < 0:
		Events.notification_pushed.emit("El calendario del mundo todavía no está disponible.")
		return
	var estado := _obtener_estado_posada()
	if gratis:
		if bool(estado.get("primer_mes_gratis_usado", false)):
			return
		estado["primer_mes_gratis_usado"] = true
	else:
		if not GameState.modificar_dinero(-POSADA_COSTE_MENSUAL):
			Events.notification_pushed.emit("No tienes suficientes monedas. Necesitas 100.")
			return
	var vencimiento_actual := int(estado.get("vence_dia_absoluto", hoy))
	estado["vence_dia_absoluto"] = maxi(hoy, vencimiento_actual) + POSADA_DURACION_MES_DIAS
	_guardar_estado_posada(estado)
	Events.notification_pushed.emit("Tu estancia en la posada está activa durante un mes.")


func _agregar_estacion_posada(padre: Node, posicion: Vector2) -> void:
	var objetivo: Node2D = CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
	if not is_instance_valid(objetivo):
		return
	objetivo.name = "RecepcionPosada"
	objetivo.position = posicion
	objetivo.call("configurar", "Gestionar habitación", 56.0, Callable(self, "_puede_interactuar_recepcion_posada"), Callable(self, "_interactuar_recepcion_posada"))
	padre.add_child(objetivo)


func _puede_interactuar_recepcion_posada(_jugador: Node) -> bool:
	return _interior_activo and _entrada_interior_id == "posada"


func _interactuar_recepcion_posada(_jugador: Node) -> void:
	if _puede_interactuar_recepcion_posada(_jugador):
		_mostrar_menu_posada("principal")


func _agregar_estacion_archivo(padre: Node, estacion_id: String, texto: String, posicion: Vector2) -> void:
	var objetivo: Node2D = CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
	if not is_instance_valid(objetivo):
		return
	objetivo.name = "EstacionArchivo_" + estacion_id
	objetivo.position = posicion
	objetivo.call(
		"configurar",
		texto,
		58.0,
		Callable(self, "_puede_interactuar_estacion_archivo").bind(estacion_id),
		Callable(self, "_interactuar_estacion_archivo").bind(estacion_id)
	)
	padre.add_child(objetivo)


func _puede_interactuar_estacion_archivo(_jugador: Node, estacion_id: String) -> bool:
	return _interior_activo and _entrada_interior_id == "archivo_real" and estacion_id in ["documentos_personajes", "historia_torres"]


func _interactuar_estacion_archivo(_jugador: Node, estacion_id: String) -> void:
	if not _puede_interactuar_estacion_archivo(_jugador, estacion_id):
		return
	if get_tree().get_first_node_in_group("royal_archive_ui") != null:
		return
	var interfaz := ROYAL_ARCHIVE_UI_SCRIPT.new() as CanvasLayer
	if not is_instance_valid(interfaz):
		return
	interfaz.call("configurar_vista", estacion_id)
	interfaz.add_to_group("royal_archive_ui")
	get_tree().root.add_child(interfaz)


func _agregar_estacion_laboratorio(padre: Node, estacion_id: String, texto: String, posicion: Vector2) -> void:
	var objetivo: Node2D = CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
	if not is_instance_valid(objetivo):
		return
	objetivo.name = "EstacionLaboratorio_" + estacion_id
	objetivo.position = posicion
	objetivo.call(
		"configurar",
		texto,
		56.0,
		Callable(self, "_puede_interactuar_estacion_laboratorio").bind(estacion_id),
		Callable(self, "_interactuar_estacion_laboratorio").bind(estacion_id)
	)
	padre.add_child(objetivo)


func _puede_interactuar_estacion_laboratorio(_jugador: Node, estacion_id: String) -> bool:
	return _interior_activo and ((_entrada_interior_id == "casa_estudio" and estacion_id == "examen") or (_entrada_interior_id == "forja" and estacion_id == "forja_inspeccion"))


func _interactuar_estacion_laboratorio(_jugador: Node, estacion_id: String) -> void:
	if not _puede_interactuar_estacion_laboratorio(_jugador, estacion_id):
		return
	if get_tree().get_first_node_in_group("research_lab_ui") != null:
		return
	var inventario_ui := get_tree().get_first_node_in_group("inventory")
	if not is_instance_valid(inventario_ui):
		Events.notification_pushed.emit("No se pudo acceder al inventario.")
		return
	var inventario := inventario_ui.get("inventory_controller") as InventoryController
	if not is_instance_valid(inventario):
		Events.notification_pushed.emit("No se pudo acceder al inventario.")
		return
	var interfaz := RESEARCH_LAB_UI_SCENE.instantiate() as CanvasLayer
	if not is_instance_valid(interfaz):
		return
	get_tree().root.add_child(interfaz)
	interfaz.call("configurar", inventario, estacion_id)


func _agregar_puesto_comercio(padre: Node, vendedor: String, posicion: Vector2) -> void:
	_agregar_sprite_mueble(padre, "Puesto" + vendedor, MERCADO_PUESTO, posicion, Vector2(0.72, 0.72), 1)
	var objetivo: Node2D = CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
	if not is_instance_valid(objetivo):
		return
	objetivo.name = "InteraccionPuesto" + vendedor
	objetivo.position = posicion + Vector2(0, 20)
	objetivo.call(
		"configurar",
		"Puesto de " + vendedor,
		54.0,
		Callable(self, "_puede_interactuar_puesto_comercio").bind(vendedor),
		Callable(self, "_interactuar_puesto_comercio").bind(vendedor)
	)
	padre.add_child(objetivo)


func _puede_interactuar_puesto_comercio(_jugador_objetivo: Node, _vendedor: String) -> bool:
	return (
		_interior_activo
		and _entrada_interior_id == "casa_comercio"
		and _saira_atiende_el_mercado()
	)


func _saira_atiende_el_mercado() -> bool:
	for candidato in get_tree().get_nodes_in_group("torres_game_npc"):
		if not candidato is Creature or not is_instance_valid(candidato):
			continue
		var npc := candidato as Creature
		if (
			npc.is_alive
			and npc.get_nombre_visual().strip_edges().to_lower() == "saira"
			and bool(npc.get_meta("rutina_en_edificio", false))
			and str(npc.get_meta("rutina_edificio_id", "")) == "casa_comercio"
		):
			return true
	return false


func _interactuar_puesto_comercio(_jugador_objetivo: Node, vendedor: String) -> void:
	if not _puede_interactuar_puesto_comercio(_jugador_objetivo, vendedor):
		return
	if get_tree().get_first_node_in_group("npc_market_modal") != null:
		return
	var sistema := get_tree().get_first_node_in_group("interaction_system")
	if not is_instance_valid(sistema):
		Events.notification_pushed.emit("No se pudo acceder al sistema de comercio.")
		return
	var inventario := sistema.get("inventory") as InventoryController
	var world_items := sistema.get("world_items") as GarliaWorldItems
	if not is_instance_valid(inventario) or not is_instance_valid(world_items):
		Events.notification_pushed.emit("No se pudo cargar el inventario o el catálogo.")
		return
	var npc_vendedor: Creature = null
	for candidato in get_tree().get_nodes_in_group("creatures"):
		if not candidato is Creature:
			continue
		var criatura := candidato as Creature
		if criatura.get_nombre_visual().strip_edges().to_lower() == vendedor.to_lower():
			npc_vendedor = criatura
			break
	if not is_instance_valid(npc_vendedor):
		Events.notification_pushed.emit("No se pudo cargar el catálogo de " + vendedor + ".")
		return
	var capa := CanvasLayer.new()
	capa.name = "MercadoNPC_" + vendedor
	capa.layer = 46
	capa.add_to_group("npc_market_modal")
	var tienda := NPCMarketShop.new()
	tienda.configurar(npc_vendedor, inventario, world_items, {"nombre": "Puesto de " + vendedor, "intermediaria_nombre": "Saira"})
	var fisica_previa := _jugador.is_physics_processing() if is_instance_valid(_jugador) else true
	var input_previo := _jugador.is_processing_input() if is_instance_valid(_jugador) else true
	var unhandled_previo := _jugador.is_processing_unhandled_input() if is_instance_valid(_jugador) else true
	if is_instance_valid(_jugador):
		_jugador.set_physics_process(false)
		_jugador.set_process_input(false)
		_jugador.set_process_unhandled_input(false)
	tienda.solicitar_cierre.connect(_cerrar_puesto_comercio.bind(capa, fisica_previa, input_previo, unhandled_previo))
	get_tree().root.add_child(capa)
	capa.add_child(tienda)


func _cerrar_puesto_comercio(capa: CanvasLayer, fisica_previa: bool, input_previo: bool, unhandled_previo: bool) -> void:
	if is_instance_valid(_jugador):
		_jugador.set_physics_process(fisica_previa)
		_jugador.set_process_input(input_previo)
		_jugador.set_process_unhandled_input(unhandled_previo)
	if is_instance_valid(capa):
		capa.queue_free()


func _abrir_menu_servicio_edificio(tipo: String) -> void:
	if get_tree().get_first_node_in_group("building_service_ui") != null:
		return
	var sistema := get_tree().get_first_node_in_group("interaction_system")
	if not is_instance_valid(sistema):
		Events.notification_pushed.emit("No se pudo acceder al sistema de interacción.")
		return
	var inventario := sistema.get("inventory") as InventoryController
	var world_items := sistema.get("world_items") as GarliaWorldItems
	if not is_instance_valid(inventario):
		Events.notification_pushed.emit("No se pudo acceder al inventario.")
		return
	var interfaz := BUILDING_SERVICE_UI_SCRIPT.new() as CanvasLayer
	if not is_instance_valid(interfaz):
		return
	interfaz.add_to_group("building_service_ui")
	if interfaz.has_signal("solicitar_selector_expediciones"):
		interfaz.connect("solicitar_selector_expediciones", Callable(self, "_abrir_selector_viajes_desde_servicio"))
	if interfaz.has_signal("solicitar_expedicion_saltus"):
		interfaz.connect("solicitar_expedicion_saltus", Callable(self, "_iniciar_expedicion_saltus"))
	get_tree().root.add_child(interfaz)
	interfaz.call("configurar", tipo, inventario, world_items, _jugador)


func _iniciar_expedicion_saltus() -> void:
	var gestor := get_tree().get_first_node_in_group("zone_manager")
	if is_instance_valid(gestor) and gestor.has_method("iniciar_expedicion_saltus"):
		gestor.call("iniciar_expedicion_saltus")
	else:
		Events.notification_pushed.emit("No se pudo iniciar la expedición Saltus.")


func _abrir_selector_viajes_desde_servicio() -> void:
	_actualizar_selector_viajes()
	if is_instance_valid(_selector_viajes_layer):
		_selector_viajes_layer.visible = true
		_posicionar_selector_viajes()


func _agregar_estacion_edificio(padre: Node, tipo: String, texto: String, posicion: Vector2) -> void:
	var objetivo: Node2D = CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
	if not is_instance_valid(objetivo):
		return
	objetivo.name = "EstacionEdificio_" + tipo
	objetivo.position = posicion
	objetivo.call(
		"configurar",
		texto,
		58.0,
		Callable(self, "_puede_interactuar_estacion_edificio").bind(tipo),
		Callable(self, "_interactuar_estacion_edificio").bind(tipo)
	)
	padre.add_child(objetivo)


func _puede_interactuar_estacion_edificio(_jugador_objetivo: Node, tipo: String) -> bool:
	if not _interior_activo:
		return false
	if tipo == "pasaje_exterior":
		return _entrada_interior_id == "registro"
	if tipo == "garumis" or tipo == "viaje_reinos":
		return _entrada_interior_id == "centro_expediciones"
	if tipo.begins_with("cuartel_"):
		return _entrada_interior_id == "cuartel"
	if tipo.begins_with("herbolario_"):
		return _entrada_interior_id == "herbolario"
	return _entrada_interior_id == tipo


func _interactuar_estacion_edificio(_jugador_objetivo: Node, tipo: String) -> void:
	if not _puede_interactuar_estacion_edificio(_jugador_objetivo, tipo):
		return
	if tipo == "pasaje_exterior":
		_mostrar_confirmacion_pasaje_exterior()
		return
	if tipo == "garumis":
		_abrir_hub_garumis()
		return
	if tipo == "viaje_reinos":
		var main := get_tree().root.find_child("Main", true, false)
		if is_instance_valid(main) and main.has_method("_abrir_menu_viaje_reinos"):
			main.call("_abrir_menu_viaje_reinos")
		return
	_abrir_menu_servicio_edificio(tipo)


func _abrir_hub_garumis() -> void:
	var existente := get_tree().get_first_node_in_group("garumi_hub")
	if is_instance_valid(existente):
		if existente.has_method("abrir_en_garumis"):
			existente.call("abrir_en_garumis")
		return
	var interfaz := GARUMI_HUB_SCENE.instantiate() as Control
	if not is_instance_valid(interfaz):
		push_warning("ReinoTorres: no se pudo abrir la mesa de Garumis.")
		return
	get_tree().root.add_child(interfaz)


func _mostrar_confirmacion_pasaje_exterior() -> void:
	if get_tree().get_first_node_in_group("travel_ticket_dialog") != null:
		return
	var dialogo := ConfirmationDialog.new()
	dialogo.name = "PasajeMundoExterior"
	dialogo.add_to_group("travel_ticket_dialog")
	dialogo.title = "Viaje al mundo exterior"
	dialogo.dialog_text = "Viajar cuesta 10 monedas.\nDeberás regresar antes de las 22:00; a esa hora volverás automáticamente a Torres.\n\n¿Deseas viajar?"
	dialogo.ok_button_text = "Viajar"
	dialogo.cancel_button_text = "Cancelar"
	dialogo.confirmed.connect(_al_confirmar_pasaje_exterior)
	dialogo.confirmed.connect(dialogo.queue_free)
	dialogo.canceled.connect(dialogo.queue_free)
	get_tree().root.add_child(dialogo)
	PIXEL_UI_THEME.apply(dialogo, false)
	PIXEL_UI_THEME.apply(dialogo.get_ok_button(), false)
	PIXEL_UI_THEME.apply(dialogo.get_cancel_button(), false)
	dialogo.popup_centered()


func _al_confirmar_pasaje_exterior() -> void:
	var zone_manager := get_tree().get_first_node_in_group("zone_manager")
	if not is_instance_valid(zone_manager) or not zone_manager.has_method("iniciar_viaje_exterior"):
		Events.notification_pushed.emit("No se pudo gestionar el pasaje.")
		return
	if not GameState.modificar_dinero(-10):
		Events.notification_pushed.emit("No tienes suficientes monedas. El pasaje cuesta 10.")
		return
	var resultado: Variant = await zone_manager.call("iniciar_viaje_exterior")
	if bool(resultado):
		Events.notification_pushed.emit("Pasaje comprado por 10 monedas. Regresarás a Torres a las 22:00.")
	else:
		GameState.modificar_dinero(10)
		Events.notification_pushed.emit("No se pudo iniciar el viaje. Se devolvieron las 10 monedas.")


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




## Salida peatonal al final del camino occidental de Torres.
## Separa el acceso a la expedición (portón) del regreso directo al Hogar.
func _crear_entrada_hogar_al_final_del_camino() -> void:
	var entrada := Area2D.new()
	entrada.name = "HomeRoadExit"
	entrada.position = Vector2(-1620.0, 0.0)
	entrada.collision_layer = 0
	entrada.collision_mask = 1
	var forma := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = Vector2(24.0, 112.0)
	forma.shape = rectangulo
	entrada.add_child(forma)
	entrada.body_entered.connect(_al_llegar_al_final_del_camino)
	add_child(entrada)


func _al_llegar_al_final_del_camino(body: Node2D) -> void:
	if _transicionando or _interior_activo or body == null or not body.is_in_group("player"):
		return
	var gestor_zonas := get_tree().get_first_node_in_group("zone_manager")
	if not is_instance_valid(gestor_zonas) or not gestor_zonas.has_method("entrar_hogar"):
		push_warning("ReinoTorres: no se encontró ZoneManager para viajar al Hogar.")
		return
	_transicionando = true
	gestor_zonas.call("entrar_hogar")
	_transicionando = false


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
	_agregar_boton_destino(contenido, "Froslia", "froslia")
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
