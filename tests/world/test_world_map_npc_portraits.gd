extends Node

const WorldMapScript = preload("res://scripts/ui/world_map.gd")


func _ready() -> void:
	var mapa := WorldMapScript.new()
	var npc := Node2D.new()
	var sprite := Sprite2D.new()
	var imagen := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(imagen)
	npc.add_child(sprite)
	add_child(npc)
	npc.hide()

	var textura: Texture2D = mapa.call("_obtener_textura_mapa_npc", npc)
	if textura != sprite.texture:
		push_error("WorldMapNPCPortraits: FAIL: un NPC oculto por LOD perdió su retrato en el mapa.")
		get_tree().quit(1)
		return

	print("WorldMapNPCPortraits: PASS hidden_npc_keeps_skin_texture=true")
		
	mapa.free()
	npc.queue_free()
	get_tree().quit(0)
