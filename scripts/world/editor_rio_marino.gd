@tool
extends Node2D

# Vista editable del cauce Marino. El nodo padre queda guardado en la escena;
# el compositor se reconstruye al abrirla en el editor y al iniciar el juego.
var _construido: bool = false

func _ready() -> void:
	if _construido:
		return
	_construido = true

	var terreno := WorldTerrainVisual.new()
	terreno.name = "TerrenoDualMarino"
	add_child(terreno)
	terreno.configurar(32)

	# El agua ocupa el plano del antiguo canal: sobre el suelo y bajo puentes.
	for hijo in terreno.get_children():
		if hijo is TileMapDual:
			hijo.z_index = -8
			hijo.z_as_relative = false

	# TileMapDual genera su Display al entrar en el árbol.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(terreno):
		return

	terreno.finalizar_preparacion_renderer()
	for x in range(2, 61):
		terreno.set_zone(Vector2i(x, 38), 4, 4, "Marino")
	terreno.flush()
