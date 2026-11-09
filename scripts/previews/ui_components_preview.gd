@tool
extends Control

## Rellena únicamente la vista de muestra. No modifica datos del juego ni servicios remotos.

const INVENTORY_PREVIEW_ITEMS: Array[Dictionary] = [
	{"nombre": "Espada de Madera", "cantidad": 1, "descripcion": "Arma de muestra"},
	{"nombre": "Pala de Madera", "cantidad": 1, "descripcion": "Herramienta de muestra"},
	{"nombre": "Pico de Piedra", "cantidad": 12, "descripcion": "Herramienta de muestra"},
	{"nombre": "Manzana", "cantidad": 4, "descripcion": "Consumible de muestra"},
	{"nombre": "Flecha de Madera", "cantidad": 24, "descripcion": "Munición de muestra"},
	{"nombre": "Pluma Aoris", "cantidad": 2, "descripcion": "Recurso de muestra"}
]


func _ready() -> void:
	_configurar_inventario()
	_configurar_equipamiento()
	_configurar_interaccion()
	_configurar_manos()


func _configurar_inventario() -> void:
	var titulo := get_node_or_null("InventoryGroup/Title") as Label
	if titulo != null:
		titulo.text = "MOCHILA · VISTA DE COMPONENTES"

	var slots := get_node_or_null("InventoryGroup/Slots")
	if slots == null:
		return

	for indice in range(mini(slots.get_child_count(), INVENTORY_PREVIEW_ITEMS.size())):
		var slot := slots.get_child(indice) as InventorySlot
		if slot != null:
			slot.configurar(INVENTORY_PREVIEW_ITEMS[indice])


func _configurar_equipamiento() -> void:
	var head := get_node_or_null("EquipmentHead") as InventoryEquipmentSlot
	if head != null:
		head.configurar("cabeza", "CASCO")

	var torso := get_node_or_null("EquipmentTorso") as InventoryEquipmentSlot
	if torso != null:
		torso.configurar("torso", "TORSO")

	var feet := get_node_or_null("EquipmentFeet") as InventoryEquipmentSlot
	if feet != null:
		feet.configurar("pies", "PIES")
		feet.configurar_objeto({"nombre": "Botas de Hierro", "tipo": "armadura"})


func _configurar_interaccion() -> void:
	var panel := get_node_or_null("InteractionPanel")
	if panel == null:
		return
	panel.visible = true
	var title := panel.get_node_or_null("Margin/Column/Title") as Label
	var body := panel.get_node_or_null("Margin/Column/Body") as Label
	if title != null:
		title.text = "COFRE ANTIGUO"
	if body != null:
		body.text = "Un contenedor de madera reforzado con metal.\n\n[ E ] Abrir\n[ Esc ] Cerrar"


func _configurar_manos() -> void:
	var left := get_node_or_null("LeftHandSlot") as Button
	if left != null:
		left.text = ""
		left.icon = ItemIconResolver.obtener_icono({"nombre": "Espada de Madera"})
		left.tooltip_text = "Mano izquierda · Espada de Madera"

	var right := get_node_or_null("RightHandSlot") as Button
	if right != null:
		right.text = ""
		right.icon = ItemIconResolver.obtener_icono({"nombre": "Pala de Madera"})
		right.tooltip_text = "Mano derecha · Pala de Madera"
