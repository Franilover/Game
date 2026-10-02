extends Control
## IUMLab — menú del Simulador de IUMs.
## Se abre con [Tab], se cierra con [Tab] o [Escape].
## El jugador arrastra IUMs al canvas, los conecta y simula.

signal cerrar_lab

# ── Referencia al manager ─────────────────────────────────────
var ium_manager: Node = null

# ── Estado del canvas ─────────────────────────────────────────
var _nodos_canvas: Array = []     # [{ium_data, slot_nodo}]
var _conexiones: Array = []       # [{origen_idx, destino_idx, linea}]
var _arrastrando: Node = null
var _arrastrando_ium: Dictionary = {}
var _conectando_desde: int = -1   # índice en _nodos_canvas

# ── UI refs ───────────────────────────────────────────────────
@onready var _panel_lista: VBoxContainer = %ListaIUMs
@onready var _canvas: Control = %Canvas
@onready var _btn_simular: Button = %BtnSimular
@onready var _btn_limpiar: Button = %BtnLimpiar
@onready var _btn_cerrar: Button = %BtnCerrar
@onready var _label_estado: Label = %LabelEstado
@onready var _panel_descubiertos: VBoxContainer = %ListaProcesos
@onready var _draw_layer: Control = %DrawLayer


func _ready() -> void:
	visible = false

	_btn_simular.pressed.connect(_simular)
	_btn_limpiar.pressed.connect(_limpiar_canvas)
	_btn_cerrar.pressed.connect(_cerrar)

	_draw_layer.draw.connect(_dibujar_conexiones)


func configurar(manager: Node) -> void:
	ium_manager = manager
	ium_manager.iums_cargados.connect(_al_cargar_iums)
	ium_manager.procesos_cargados.connect(_al_cargar_procesos)
	ium_manager.proceso_descubierto.connect(_al_descubrir_proceso)
	ium_manager.error_ium.connect(_al_error)


# ================================================================
# INPUT — Toggle con Tab
# ================================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_ium_lab"):
		if visible:
			_cerrar()
		else:
			_abrir()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and visible:
		_cerrar()
		get_viewport().set_input_as_handled()


# ================================================================
# ABRIR / CERRAR
# ================================================================

func _abrir() -> void:
	visible = true
	get_tree().paused = true


func _cerrar() -> void:
	visible = false
	get_tree().paused = false
	cerrar_lab.emit()


# ================================================================
# POBLAR LISTA DE IUMs
# ================================================================

func _al_cargar_iums(iums: Array) -> void:
	for child in _panel_lista.get_children():
		child.queue_free()

	for ium in iums:
		var btn := _crear_boton_ium(ium)
		_panel_lista.add_child(btn)


func _crear_boton_ium(ium: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = ium.get("nombre", "IUM")
	btn.tooltip_text = ium.get("descripcion", "")
	btn.custom_minimum_size = Vector2(140, 36)

	# Tags de oris como color de fondo
	var oris: Array = ium.get("oris", [])
	if not oris.is_empty():
		btn.tooltip_text += "\nOris: " + ", ".join(oris)

	btn.pressed.connect(func(): _agregar_ium_al_canvas(ium))
	return btn


# ================================================================
# CANVAS — AGREGAR / MOVER NODOS
# ================================================================

func _agregar_ium_al_canvas(ium: Dictionary) -> void:
	var slot := _crear_slot_canvas(ium, _nodos_canvas.size())
	_canvas.add_child(slot)

	# Posición escalonada inicial
	var offset := _nodos_canvas.size() * 20
	slot.position = Vector2(60 + offset, 60 + offset)

	_nodos_canvas.append({
		"ium": ium,
		"slot": slot,
		"idx": _nodos_canvas.size()
	})

	_label_estado.text = "IUM añadida: " + ium.get("nombre", "")
	_draw_layer.queue_redraw()


func _crear_slot_canvas(ium: Dictionary, idx: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(100, 60)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	var nombre_label := Label.new()
	nombre_label.text = ium.get("nombre", "IUM")
	nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre_label.add_theme_font_size_override("font_size", 11)
	nombre_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var oris_label := Label.new()
	var oris: Array = ium.get("oris", [])
	oris_label.text = ", ".join(oris) if not oris.is_empty() else "Sin Ori"
	oris_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	oris_label.add_theme_font_size_override("font_size", 9)
	oris_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var btn_conectar := Button.new()
	btn_conectar.text = "→"
	btn_conectar.tooltip_text = "Conectar desde aquí"
	btn_conectar.custom_minimum_size = Vector2(24, 20)
	btn_conectar.pressed.connect(func(): _iniciar_conexion(idx))

	var btn_eliminar := Button.new()
	btn_eliminar.text = "✕"
	btn_eliminar.custom_minimum_size = Vector2(24, 20)
	btn_eliminar.pressed.connect(func(): _eliminar_nodo(idx))

	hbox.add_child(btn_conectar)
	hbox.add_child(btn_eliminar)

	vbox.add_child(nombre_label)
	vbox.add_child(oris_label)
	vbox.add_child(hbox)
	panel.add_child(vbox)

	# Drag
	panel.gui_input.connect(func(event): _mover_slot(event, panel))

	return panel


func _mover_slot(event: InputEvent, panel: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_arrastrando = panel
			else:
				_arrastrando = null

	elif event is InputEventMouseMotion and _arrastrando == panel:
		panel.position += (event as InputEventMouseMotion).relative
		_draw_layer.queue_redraw()


# ================================================================
# ELIMINAR NODO DEL CANVAS
# ================================================================

func _eliminar_nodo(idx: int) -> void:
	if idx < 0 or idx >= _nodos_canvas.size():
		return

	var entrada: Dictionary = _nodos_canvas[idx]
	if is_instance_valid(entrada["slot"]):
		entrada["slot"].queue_free()

	# Quitar conexiones que involucren este nodo
	var nuevas_conexiones: Array = []
	for con in _conexiones:
		if con["origen"] != idx and con["destino"] != idx:
			nuevas_conexiones.append(con)
	_conexiones = nuevas_conexiones

	_nodos_canvas.remove_at(idx)

	# Re-numerar índices en nodos restantes y reconectar botones
	for i in _nodos_canvas.size():
		_nodos_canvas[i]["idx"] = i

	_conectando_desde = -1
	_draw_layer.queue_redraw()
	_label_estado.text = "IUM eliminada."


# ================================================================
# CONEXIONES
# ================================================================

func _iniciar_conexion(desde_idx: int) -> void:
	if _conectando_desde == -1:
		_conectando_desde = desde_idx
		_label_estado.text = "Selecciona el IUM destino (presiona → en otro IUM)"
	else:
		if _conectando_desde != desde_idx:
			_agregar_conexion(_conectando_desde, desde_idx)
		_conectando_desde = -1


func _agregar_conexion(origen: int, destino: int) -> void:
	# Verificar que no exista ya
	for con in _conexiones:
		if con["origen"] == origen and con["destino"] == destino:
			_label_estado.text = "Esa conexión ya existe."
			return

	_conexiones.append({"origen": origen, "destino": destino})
	_draw_layer.queue_redraw()

	var nombre_o: String = _nodos_canvas[origen]["ium"].get("nombre", "?")
	var nombre_d: String = _nodos_canvas[destino]["ium"].get("nombre", "?")
	_label_estado.text = "Conectado: %s → %s" % [nombre_o, nombre_d]


func _dibujar_conexiones() -> void:
	for con in _conexiones:
		var o_idx: int = con["origen"]
		var d_idx: int = con["destino"]

		if o_idx >= _nodos_canvas.size() or d_idx >= _nodos_canvas.size():
			continue

		var slot_o: Control = _nodos_canvas[o_idx]["slot"]
		var slot_d: Control = _nodos_canvas[d_idx]["slot"]

		if not is_instance_valid(slot_o) or not is_instance_valid(slot_d):
			continue

		var desde := slot_o.position + slot_o.size / 2.0
		var hasta := slot_d.position + slot_d.size / 2.0

		_draw_layer.draw_line(
			desde, hasta,
			Color(0.4, 0.9, 1.0, 0.85),
			2.0
		)

		# Flecha
		var dir := (hasta - desde).normalized()
		var perp := Vector2(-dir.y, dir.x) * 6.0
		var punta := hasta - dir * 12.0
		_draw_layer.draw_colored_polygon(PackedVector2Array([
			hasta,
			punta + perp,
			punta - perp
		]), Color(0.4, 0.9, 1.0, 0.85))


# ================================================================
# SIMULAR
# ================================================================

func _simular() -> void:
	if _nodos_canvas.is_empty():
		_label_estado.text = "Añade IUMs al canvas primero."
		return

	if ium_manager == null:
		_label_estado.text = "Error: IUM Manager no disponible."
		return

	# Construir payload de nodos
	var nodos: Array = []
	for entrada in _nodos_canvas:
		var slot: Control = entrada["slot"]
		nodos.append({
			"ium_id": entrada["ium"].get("id", ""),
			"nombre": entrada["ium"].get("nombre", ""),
			"posicion_x": slot.position.x,
			"posicion_y": slot.position.y
		})

	# Construir payload de enlaces
	var enlaces: Array = []
	for con in _conexiones:
		var o_idx: int = con["origen"]
		var d_idx: int = con["destino"]

		if o_idx < _nodos_canvas.size() and d_idx < _nodos_canvas.size():
			enlaces.append({
				"origen_id": _nodos_canvas[o_idx]["ium"].get("id", ""),
				"destino_id": _nodos_canvas[d_idx]["ium"].get("id", ""),
				"tipo_enlace": "secuencial"
			})

	_label_estado.text = "Simulando..."
	_btn_simular.disabled = true

	ium_manager.simular_organizacion(nodos, enlaces)


# ================================================================
# CALLBACKS DEL MANAGER
# ================================================================

func _al_descubrir_proceso(proceso: Dictionary) -> void:
	_btn_simular.disabled = false
	var nombre: String = proceso.get("nombre", "Proceso desconocido")
	_label_estado.text = "¡Proceso descubierto: %s!" % nombre

	# Actualizar lista de procesos
	_al_cargar_procesos(ium_manager.procesos_conocidos)


func _al_error(mensaje: String) -> void:
	_btn_simular.disabled = false
	_label_estado.text = "✗ " + mensaje


# ================================================================
# PROCESOS DESCUBIERTOS
# ================================================================

func _al_cargar_procesos(procesos: Array) -> void:
	for child in _panel_descubiertos.get_children():
		child.queue_free()

	if procesos.is_empty():
		var lbl := Label.new()
		lbl.text = "Ningún proceso descubierto aún."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_panel_descubiertos.add_child(lbl)
		return

	for proceso in procesos:
		var hbox := HBoxContainer.new()

		var lbl := Label.new()
		lbl.text = proceso.get("nombre", "Proceso")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn_equipar := Button.new()
		btn_equipar.text = "Equipar"
		btn_equipar.custom_minimum_size = Vector2(70, 0)
		btn_equipar.pressed.connect(func(): _equipar(proceso))

		hbox.add_child(lbl)
		hbox.add_child(btn_equipar)
		_panel_descubiertos.add_child(hbox)


func _equipar(proceso: Dictionary) -> void:
	ium_manager.equipar_proceso(proceso)
	_label_estado.text = "Equipado: " + proceso.get("nombre", "")


# ================================================================
# LIMPIAR CANVAS
# ================================================================

func _limpiar_canvas() -> void:
	for entrada in _nodos_canvas:
		if is_instance_valid(entrada["slot"]):
			entrada["slot"].queue_free()

	_nodos_canvas.clear()
	_conexiones.clear()
	_conectando_desde = -1

	_draw_layer.queue_redraw()
	_label_estado.text = "Canvas limpiado."
