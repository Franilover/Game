extends RefCounted
class_name CharacterAppearance

## Capas visuales del personaje. Cada PNG debe compartir lienzo, pivote y escala
## con el sprite base para que las piezas coincidan sin ajustes por personaje.

const SLOTS: Array[String] = ["body", "hair", "eyes", "shirt", "pants", "shoes"]
const SLOT_DIRECTORIES := {
	"body": "res://assets/art/characters/customization/body/",
	"hair": "res://assets/art/characters/customization/hair/",
	"eyes": "res://assets/art/characters/customization/eyes/",
	"shirt": "res://assets/art/characters/customization/shirts/",
	"pants": "res://assets/art/characters/customization/pants/",
	"shoes": "res://assets/art/characters/customization/shoes/"
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
const CATALOG_ASSETS := {
	"hair": [
		{"name": "1 Front", "path": "res://assets/art/characters/customization/hair/1 Front.png", "texture": preload("res://assets/art/characters/customization/hair/1 Front.png")},
		{"name": "2 Front", "path": "res://assets/art/characters/customization/hair/2 Front.png", "texture": preload("res://assets/art/characters/customization/hair/2 Front.png")},
		{"name": "3 Front", "path": "res://assets/art/characters/customization/hair/3 Front.png", "texture": preload("res://assets/art/characters/customization/hair/3 Front.png")},
		{"name": "curly", "path": "res://assets/art/characters/customization/hair/curly.png", "texture": preload("res://assets/art/characters/customization/hair/curly.png")},
		{"name": "long", "path": "res://assets/art/characters/customization/hair/long.png", "texture": preload("res://assets/art/characters/customization/hair/long.png")},
		{"name": "short", "path": "res://assets/art/characters/customization/hair/short.png", "texture": preload("res://assets/art/characters/customization/hair/short.png")}
	],
	"eyes": [
		{"name": "expressive", "path": "res://assets/art/characters/customization/eyes/expressive.png", "texture": preload("res://assets/art/characters/customization/eyes/expressive.png")},
		{"name": "simple", "path": "res://assets/art/characters/customization/eyes/simple.png", "texture": preload("res://assets/art/characters/customization/eyes/simple.png")}
	],
	"shirt": [
		{"name": "hoodie", "path": "res://assets/art/characters/customization/shirts/hoodie.png", "texture": preload("res://assets/art/characters/customization/shirts/hoodie.png")},
		{"name": "shirt", "path": "res://assets/art/characters/customization/shirts/shirt.png", "texture": preload("res://assets/art/characters/customization/shirts/shirt.png")},
		{"name": "tunic", "path": "res://assets/art/characters/customization/shirts/tunic.png", "texture": preload("res://assets/art/characters/customization/shirts/tunic.png")}
	],
	"pants": [
		{"name": "shorts", "path": "res://assets/art/characters/customization/pants/shorts.png", "texture": preload("res://assets/art/characters/customization/pants/shorts.png")},
		{"name": "skirt", "path": "res://assets/art/characters/customization/pants/skirt.png", "texture": preload("res://assets/art/characters/customization/pants/skirt.png")},
		{"name": "trousers", "path": "res://assets/art/characters/customization/pants/trousers.png", "texture": preload("res://assets/art/characters/customization/pants/trousers.png")}
	],
	"shoes": [
		{"name": "boots", "path": "res://assets/art/characters/customization/shoes/boots.png", "texture": preload("res://assets/art/characters/customization/shoes/boots.png")},
		{"name": "sneakers", "path": "res://assets/art/characters/customization/shoes/sneakers.png", "texture": preload("res://assets/art/characters/customization/shoes/sneakers.png")}
	]
}


static func catalogo(slot: String) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var piezas: Array = CATALOG_ASSETS.get(slot, [])
	for pieza_variant in piezas:
		if not pieza_variant is Dictionary:
			continue
		var pieza: Dictionary = pieza_variant
		resultado.append({
			"id": str(pieza.get("name", "")),
			"nombre": str(pieza.get("name", "")),
			"ruta": str(pieza.get("path", "")),
			"textura": pieza.get("texture") as Texture2D
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
	for slot in ["body", "shoes", "pants", "shirt", "eyes", "hair"]:
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
