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
	{"key":"banos", "paths":["edificios/banos.png","edificios/edificio.png"], "position":Vector2(-760,211), "size":Vector2(108,98), "hide":["BathHouse"]}
]

@onready var _exit: Area2D = $Exit

var _transicionando: bool = false


func _ready() -> void:
	_exit.body_entered.connect(_al_entrar_salida)
	_cargar_sprites_de_torres()


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
			if child.name.begins_with(String(prefix)) and child is CanvasItem:
				(child as CanvasItem).visible = false
				break


func _al_entrar_salida(body: Node2D) -> void:
	if _transicionando:
		return
	if body == null or not body.is_in_group("player"):
		return

	_transicionando = true
	print("ReinoTorres: salida solicitada.")
	salida_solicitada.emit()
