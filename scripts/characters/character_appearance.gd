extends RefCounted
class_name CharacterAppearance

## Capas visuales del personaje. Cada PNG debe compartir lienzo, pivote y escala
## con el sprite base para que las piezas coincidan sin ajustes por personaje.

const SLOTS: Array[String] = ["body", "hair", "eyes", "shirt", "pants", "shoes"]
const SHARED_ASSET_LIBRARY: Script = preload("res://scripts/shared/assets/shared_asset_library.gd")

# El arte original se conserva en su ubicación histórica para no duplicar
# PNG ni romper referencias de importación. Este catálogo es su única puerta
# de acceso para jugadores, reinos y expediciones.
const PLAYER_ART_DIR := "res://assets/art/kingdom/Torres/Personajes/"
const PLAYER_SPRITES := {
	"idle_front": PLAYER_ART_DIR + "Sprite-0004.png",
	"walk_left": PLAYER_ART_DIR + "Sprite-0004_Walking_Left.png",
	"walk_back": PLAYER_ART_DIR + "Sprite-0004_Walking_Back.png"
}
const SLOT_DIRECTORIES := {
	"body": PLAYER_ART_DIR + "customization/body/",
	"hair": PLAYER_ART_DIR + "customization/hair/",
	"eyes": PLAYER_ART_DIR + "customization/eyes/",
	"shirt": PLAYER_ART_DIR + "customization/shirts/",
	"pants": PLAYER_ART_DIR + "customization/pants/",
	"shoes": PLAYER_ART_DIR + "customization/shoes/"
}
const SLOT_LABELS := {
	"body": "Cuerpo",
	"hair": "Cabello",
	"eyes": "Ojos",
	"shirt": "Parte superior",
	"pants": "Pantalones",
	"shoes": "Zapatos"
}

# Catálogo explícito: los recursos quedan incluidos en la exportación y no
# dependemos de que DirAccess pueda enumerar archivos dentro de res://.
# Catálogo limitado a archivos que existen realmente en el repositorio.
# Se cargan en runtime porque los nombres "1 Front.png", etc. contienen espacios
# y preload() provoca errores de parseo en estas rutas.
const CATALOG_ASSETS := {
	"hair": [
		{"name": "Pelo 1", "path": PLAYER_ART_DIR + "customization/hair/1 Front.png"},
		{"name": "Pelo 2", "path": PLAYER_ART_DIR + "customization/hair/2 Front.png"},
		{"name": "Pelo 3", "path": PLAYER_ART_DIR + "customization/hair/3 Front.png"}
	],
	"eyes": [
		{"name": "expressive", "path": PLAYER_ART_DIR + "customization/eyes/expressive.png"}
	],
	"shirt": [
		{"name": "tunic", "path": PLAYER_ART_DIR + "customization/shirts/tunic.png"}
	],
	"pants": [
		{"name": "skirt", "path": PLAYER_ART_DIR + "customization/pants/skirt.png"}
	],
	"shoes": [
		{"name": "sneakers", "path": PLAYER_ART_DIR + "customization/shoes/sneakers.png"}
	]
}


static func obtener_textura_sprite(clave: String) -> Texture2D:
	return SHARED_ASSET_LIBRARY.textura(str(PLAYER_SPRITES.get(clave, "")))


static func catalogo(slot: String) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var piezas: Array = CATALOG_ASSETS.get(slot, [])
	for pieza_variant in piezas:
		if not pieza_variant is Dictionary:
			continue
		var pieza: Dictionary = pieza_variant
		var ruta := str(pieza.get("path", ""))
		if ruta.is_empty():
			continue
		var textura := SHARED_ASSET_LIBRARY.textura(ruta)
		if textura == null:
			continue
		resultado.append({
			"id": str(pieza.get("name", "")),
			"nombre": str(pieza.get("name", "")),
			"ruta": ruta,
			"textura": textura
		})
	return resultado


static func color_a_html(color: Color) -> String:
	return "#" + color.to_html(false)


static func html_a_color(valor: Variant, predeterminado: Color = Color.WHITE) -> Color:
	var texto := str(valor).strip_edges()
	if texto.is_empty():
		return predeterminado
	if texto.begins_with("#"):
		texto = texto.substr(1)
	if texto.length() == 6:
		texto += "ff"
	if texto.length() != 8:
		return predeterminado
	return Color.from_string("#" + texto, predeterminado)


static func aplicar_capas(visual: Node2D, apariencia: Dictionary) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var apariencia_anterior: Variant = visual.get_meta("character_appearance", null)
	if apariencia_anterior is Dictionary and apariencia_anterior == apariencia:
		return
	for hijo in visual.get_children():
		if hijo is Sprite2D and hijo.is_in_group("character_customization_layer"):
			visual.remove_child(hijo)
			hijo.queue_free()

	var sprite_base := visual.get_node_or_null("Sprite2D") as Sprite2D
	if sprite_base == null:
		return
	var indice_z := 1
	for slot in ["body", "shoes", "pants", "shirt", "eyes", "hair"]:
		var pieza_variant: Variant = apariencia.get(slot, {})
		if not pieza_variant is Dictionary:
			continue
		var pieza := pieza_variant as Dictionary
		var ruta := str(pieza.get("ruta", "")).strip_edges()
		if ruta.is_empty():
			continue
		var textura := SHARED_ASSET_LIBRARY.textura(ruta)
		if textura == null:
			continue
		var capa := Sprite2D.new()
		capa.name = "Appearance_" + slot
		capa.add_to_group("character_customization_layer")
		capa.set_meta("appearance_slot", slot)
		capa.set_meta("appearance_slot_order", indice_z)
		capa.set_meta("appearance_base_path", ruta)
		capa.texture = textura
		capa.position = sprite_base.position
		capa.centered = sprite_base.centered
		capa.offset = sprite_base.offset
		capa.flip_h = sprite_base.flip_h
		capa.flip_v = sprite_base.flip_v
		capa.scale = sprite_base.scale
		capa.texture_filter = sprite_base.texture_filter
		capa.z_index = sprite_base.z_index + indice_z
		capa.modulate = html_a_color(pieza.get("color", "#ffffff"), Color.WHITE)
		visual.add_child(capa)
		indice_z += 1
	visual.set_meta("character_appearance", apariencia.duplicate(true))


static func sincronizar_capas(visual: Node2D) -> void:
	if not is_instance_valid(visual):
		return
	var sprite_base := visual.get_node_or_null("Sprite2D") as Sprite2D
	if sprite_base == null:
		return
	var estado := [
		sprite_base.position, sprite_base.centered, sprite_base.offset,
		sprite_base.flip_h, sprite_base.flip_v, sprite_base.scale,
		sprite_base.texture_filter, sprite_base.z_index
	]
	if visual.get_meta("appearance_transform", []) == estado:
		return
	for hijo in visual.get_children():
		if not hijo is Sprite2D or not hijo.is_in_group("character_customization_layer"):
			continue
		var capa := hijo as Sprite2D
		capa.position = sprite_base.position
		capa.centered = sprite_base.centered
		capa.offset = sprite_base.offset
		capa.flip_h = sprite_base.flip_h
		capa.flip_v = sprite_base.flip_v
		capa.scale = sprite_base.scale
		capa.texture_filter = sprite_base.texture_filter
		capa.z_index = sprite_base.z_index + int(capa.get_meta("appearance_slot_order", 0))
	visual.set_meta("appearance_transform", estado)


static func actualizar_cabello_direccion(visual: Node2D, facing: Vector2) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	var cabello := visual.get_node_or_null("Appearance_hair") as Sprite2D
	if cabello == null:
		return
	var ruta_base := str(cabello.get_meta("appearance_base_path", "")).strip_edges()
	if ruta_base.is_empty():
		return
	var direccion := "Front"
	var invertir := false
	if absf(facing.y) >= absf(facing.x):
		direccion = "Back" if facing.y < 0.0 else "Front"
	else:
		direccion = "Lateral"
		invertir = facing.x > 0.0
	var clave_direccion := direccion + (":flip" if invertir else "")
	if str(cabello.get_meta("appearance_direction", "")) == clave_direccion:
		return
	var numero_pelo := ruta_base.get_file().get_basename().get_slice(" ", 0)
	var ruta := ruta_base.get_base_dir() + "/" + numero_pelo + " " + direccion + ".png"
	var textura := SHARED_ASSET_LIBRARY.textura(ruta)
	if textura == null and ruta != ruta_base:
		textura = SHARED_ASSET_LIBRARY.textura(ruta_base)
	if textura != null:
		cabello.texture = textura
	cabello.flip_h = invertir
	cabello.set_meta("appearance_direction", clave_direccion)
