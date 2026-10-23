extends RefCounted
class_name CharacterAppearance

## Capas visuales del personaje. Cada PNG debe compartir lienzo, pivote y escala
## con el sprite base para que las piezas coincidan sin ajustes por personaje.

const SLOTS: Array[String] = ["hair", "eyes", "shirt", "pants", "shoes"]
const SLOT_DIRECTORIES := {
	"hair": "res://assets/art/characters/customization/hair/",
	"eyes": "res://assets/art/characters/customization/eyes/",
	"shirt": "res://assets/art/characters/customization/shirts/",
	"pants": "res://assets/art/characters/customization/pants/",
	"shoes": "res://assets/art/characters/customization/shoes/"
}
const SLOT_LABELS := {
	"hair": "Cabello",
	"eyes": "Ojos",
	"shirt": "Parte superior",
	"pants": "Pantalones",
	"shoes": "Zapatos"
}


static func catalogo(slot: String) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var directorio_path := str(SLOT_DIRECTORIES.get(slot, ""))
	if directorio_path.is_empty():
		return resultado
	var directorio := DirAccess.open(directorio_path)
	if directorio == null:
		return resultado
	var archivos := directorio.get_files()
	archivos.sort()
	for archivo in archivos:
		if archivo.get_extension().to_lower() not in ["png", "webp"]:
			continue
		var ruta := directorio_path + archivo
		var textura := load(ruta) as Texture2D
		if textura == null:
			continue
		resultado.append({
			"id": archivo.get_basename(),
			"nombre": archivo.get_basename().replace("_", " "),
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
	for hijo in visual.get_children():
		if hijo is Sprite2D and hijo.is_in_group("character_customization_layer"):
			hijo.queue_free()

	var sprite_base := visual.get_node_or_null("Sprite2D") as Sprite2D
	if sprite_base == null:
		return
	var indice_z := 1
	for slot in SLOTS:
		var pieza_variant: Variant = apariencia.get(slot, {})
		if not pieza_variant is Dictionary:
			continue
		var pieza := pieza_variant as Dictionary
		var ruta := str(pieza.get("ruta", "")).strip_edges()
		if ruta.is_empty() or not ResourceLoader.exists(ruta):
			continue
		var textura := load(ruta) as Texture2D
		if textura == null:
			continue
		var capa := Sprite2D.new()
		capa.name = "Appearance_" + slot
		capa.add_to_group("character_customization_layer")
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
