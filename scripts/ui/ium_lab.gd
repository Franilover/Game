extends Control
class_name IUMLab

## IUMLab — menú del Simulador de IUMs.
## Se abre con [M], se cierra con [M] o [Escape].
## El jugador arrastra IUMs al canvas, los conecta y simula.

signal cerrar_lab

# ── Referencia al manager ─────────────────────────────────────
var ium_manager: Node = null
var _admin_console: Node = null

# ── Estado del canvas ─────────────────────────────────────────
var _nodos_canvas: Array = []
var _conexiones: Array = []
var _arrastrando: Node = null
var _arrastrando_ium: Dictionary = {}
var _conectando_desde: int = -1

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
	_aplicar_estilo_interfaz()
	_ajustar_panel_a_pantalla()
	get_viewport().size_changed.connect(_ajustar_panel_a_pantalla)

	_btn_simular.pressed.connect(_simular)
	_btn_limpiar.pressed.connect(_limpiar_canvas)
	_btn_cerrar.pressed.connect(_cerrar)

	_draw_layer.draw.connect(_dibujar_conexiones)


func _ajustar_panel_a_pantalla() -> void:
	var panel := $Panel as Control
	var area := get_viewport_rect().size
	var ancho := minf(area.x * 0.96, 1100.0)
	var alto := minf(area.y * 0.94, 760.0)
	panel.offset_left = -ancho * 0.5
	panel.offset_right = ancho * 0.5
	panel.offset_top = -alto * 0.5
	panel.offset_bottom = alto * 0.5


func _estilo_panel(fondo: Color, borde: Color, grosor: int = 1) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(3)
	return estilo


func _estilizar_boton(boton: Button) -> void:
	boton.add_theme_color_override("font_color", Color(0.82, 0.75, 0.61, 1))
	boton.add_theme_color_override("font_hover_color", Color(0.95, 0.88, 0.7, 1))
	boton.add_theme_color_override("font_pressed_color", Color(0.95, 0.88, 0.7, 1))
	boton.add_theme_color_override("font_disabled_color", Color(0.42, 0.34, 0.24, 1))
	boton.add_theme_stylebox_override("normal", _estilo_panel(Color(0.12, 0.075, 0.045, 0.98), Color(0.29, 0.19, 0.12, 1)))
	boton.add_theme_stylebox_override("hover", _estilo_panel(Color(0.19, 0.13, 0.08, 1), Color(0.55, 0.40, 0.22, 1)))
	boton.add_theme_stylebox_override("pressed", _estilo_panel(Color(0.28, 0.20, 0.12, 1), Color(0.74, 0.62, 0.34, 1), 2))
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _aplicar_estilo_interfaz() -> void:
	for control in find_children("*", "Control", true, false):
		if control is Label:
			(control as Label).add_theme_color_override("font_color", Color(0.82, 0.75, 0.61, 1))
		elif control is Button:
			_estilizar_boton(control as Button)
		elif control is Panel:
			(control as Panel).add_theme_stylebox_override("panel", _estilo_panel(Color(0.055, 0.035, 0.022, 0.96), Color(0.29, 0.19, 0.12, 1)))


func configurar(manager: Node, admin_console: Node) -> void:
	ium_manager = manager
	_admin_console = admin_console
	if not ium_manager.iums_cargados.is_connected(_al_cargar_iums):
		ium_manager.iums_cargados.connect(_al_cargar_iums)
	if not ium_manager.procesos_cargados.is_connected(_al_cargar_procesos):
		ium_manager.procesos_cargados.connect(_al_cargar_procesos)
	if not ium_manager.proceso_descubierto.is_connected(_al_descubrir_proceso):
		ium_manager.proceso_descubierto.connect(_al_descubrir_proceso)
	if not ium_manager.error_ium.is_connected(_al_error):
		ium_manager.error_ium.connect(_al_error)


# ================================================================
# INPUT — Toggle con M
# ================================================================

func _input(event: InputEvent) -> void:
	# La consola de administración tiene prioridad absoluta.
	# Mientras está abierta, ningún menú del juego debe responder
	# a sus teclas de apertura.
	if _consola_admin_abierta():
		return

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


func _consola_admin_abierta() -> bool:
	var consola := _admin_console

	if consola == null:
		return false

	if not is_instance_valid(consola):
		return false

	if consola.has_method("esta_abierta"):
		return consola.esta_abierta()

	return false


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

	btn.text = ium.get(
		"nombre",
		"IUM"
	)

	btn.tooltip_text = ium.get(
		"descripcion",
		""
	)

	btn.custom_minimum_size = Vector2(0, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	_estilizar_boton(btn)

	var oris: Array = ium.get(
		"oris",
		[]
	)

	if not oris.is_empty():
		btn.tooltip_text += (
			"\nOris: "
			+ ", ".join(oris)
		)

	btn.pressed.connect(
		func():
			_agregar_ium_al_canvas(ium)
	)

	return btn


# ================================================================
# CANVAS — AGREGAR / MOVER NODOS
# ================================================================

func _agregar_ium_al_canvas(
	ium: Dictionary
) -> void:
	var nuevo_id := str(ium.get("id", "")).strip_edges()
	if nuevo_id.is_empty():
		_label_estado.text = "No se puede añadir: el IUM no tiene un identificador válido."
		return

	# El RPC identifica los extremos por ium_id, no por instancia de componente.
	# Repetir un IUM volvería ambiguas sus conexiones para el motor actual.
	for entrada in _nodos_canvas:
		if str(entrada["ium"].get("id", "")) == nuevo_id:
			_label_estado.text = "Ese IUM ya está en el canvas; el motor actual no distingue instancias repetidas."
			return

	var slot := _crear_slot_canvas(
		ium,
		_nodos_canvas.size()
	)

	_canvas.add_child(slot)

	var offset := (
		_nodos_canvas.size()
		* 20
	)

	slot.position = Vector2(
		60 + offset,
		60 + offset
	)

	_nodos_canvas.append({
		"ium": ium,
		"slot": slot,
		"idx": _nodos_canvas.size()
	})

	_label_estado.text = (
		"IUM añadida: "
		+ ium.get("nombre", "")
	)

	_draw_layer.queue_redraw()


func _crear_slot_canvas(
	ium: Dictionary,
	idx: int
) -> Panel:
	var panel := Panel.new()

	panel.custom_minimum_size = Vector2(100, 60)
	panel.add_theme_stylebox_override("panel", _estilo_panel(Color(0.16, 0.105, 0.065, 0.98), Color(0.42, 0.29, 0.17, 1)))

	var vbox := VBoxContainer.new()

	vbox.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	var nombre_label := Label.new()

	nombre_label.text = ium.get(
		"nombre",
		"IUM"
	)

	nombre_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	nombre_label.add_theme_font_size_override(
		"font_size",
		11
	)

	nombre_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	var oris_label := Label.new()

	var oris: Array = ium.get(
		"oris",
		[]
	)

	oris_label.text = (
		", ".join(oris)
		if not oris.is_empty()
		else "Sin Ori"
	)

	oris_label.add_theme_color_override(
		"font_color",
		Color(0.74, 0.62, 0.34, 1)
	)

	oris_label.add_theme_font_size_override(
		"font_size",
		9
	)

	oris_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	var hbox := HBoxContainer.new()

	hbox.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	var btn_conectar := Button.new()

	btn_conectar.text = "→"

	btn_conectar.tooltip_text = (
		"Conectar desde aquí"
	)

	btn_conectar.custom_minimum_size = Vector2(24, 20)
	_estilizar_boton(btn_conectar)

	btn_conectar.pressed.connect(
		func():
			_iniciar_conexion(_indice_nodo_de_slot(panel))
	)

	var btn_eliminar := Button.new()

	btn_eliminar.text = "✕"

	btn_eliminar.custom_minimum_size = Vector2(24, 20)
	_estilizar_boton(btn_eliminar)

	btn_eliminar.pressed.connect(
		func():
			_eliminar_nodo(_indice_nodo_de_slot(panel))
	)

	hbox.add_child(btn_conectar)
	hbox.add_child(btn_eliminar)

	vbox.add_child(nombre_label)
	vbox.add_child(oris_label)
	vbox.add_child(hbox)

	panel.add_child(vbox)

	panel.gui_input.connect(
		func(event):
			_mover_slot(
				event,
				panel
			)
	)

	return panel


func _indice_nodo_de_slot(slot: Control) -> int:
	for i in _nodos_canvas.size():
		if _nodos_canvas[i].get("slot") == slot:
			return i
	return -1


func _mover_slot(
	event: InputEvent,
	panel: Control
) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_arrastrando = panel
			else:
				_arrastrando = null

	elif (
		event is InputEventMouseMotion
		and _arrastrando == panel
	):
		panel.position += (
			event as InputEventMouseMotion
		).relative

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

	var nuevas_conexiones: Array = []

	for con in _conexiones:
		if (
			con["origen"] != idx
			and con["destino"] != idx
		):
			nuevas_conexiones.append(con)

	_conexiones = nuevas_conexiones

	_nodos_canvas.remove_at(idx)

	for i in _nodos_canvas.size():
		_nodos_canvas[i]["idx"] = i

	_conectando_desde = -1

	_draw_layer.queue_redraw()

	_label_estado.text = (
		"IUM eliminada."
	)


# ================================================================
# CONEXIONES
# ================================================================

func _iniciar_conexion(
	desde_idx: int
) -> void:
	if _conectando_desde == -1:
		_conectando_desde = desde_idx

		_label_estado.text = (
			"Selecciona el IUM destino "
			+ "(presiona → en otro IUM)"
		)

	else:
		if _conectando_desde != desde_idx:
			_agregar_conexion(
				_conectando_desde,
				desde_idx
			)

		_conectando_desde = -1


func _agregar_conexion(
	origen: int,
	destino: int
) -> void:
	for con in _conexiones:
		if (
			con["origen"] == origen
			and con["destino"] == destino
		):
			_label_estado.text = (
				"Esa conexión ya existe."
			)

			return

	_conexiones.append({
		"origen": origen,
		"destino": destino
	})

	_draw_layer.queue_redraw()

	var nombre_o: String = (
		_nodos_canvas[origen]["ium"].get(
			"nombre",
			"?"
		)
	)

	var nombre_d: String = (
		_nodos_canvas[destino]["ium"].get(
			"nombre",
			"?"
		)
	)

	_label_estado.text = (
		"Conectado: %s → %s"
		% [
			nombre_o,
			nombre_d
		]
	)


func _dibujar_conexiones() -> void:
	for con in _conexiones:
		var o_idx: int = con["origen"]
		var d_idx: int = con["destino"]

		if (
			o_idx >= _nodos_canvas.size()
			or d_idx >= _nodos_canvas.size()
		):
			continue

		var slot_o: Control = (
			_nodos_canvas[o_idx]["slot"]
		)

		var slot_d: Control = (
			_nodos_canvas[d_idx]["slot"]
		)

		if (
			not is_instance_valid(slot_o)
			or not is_instance_valid(slot_d)
		):
			continue

		var desde := (
			slot_o.position
			+ slot_o.size / 2.0
		)

		var hasta := (
			slot_d.position
			+ slot_d.size / 2.0
		)

		_draw_layer.draw_line(
			desde,
			hasta,
			Color(0.74, 0.62, 0.34, 0.9),
			2.0
		)

		var dir := (
			hasta - desde
		).normalized()

		var perp := (
			Vector2(
				-dir.y,
				dir.x
			)
			* 6.0
		)

		var punta := (
			hasta
			- dir * 12.0
		)

		_draw_layer.draw_colored_polygon(
			PackedVector2Array([
				hasta,
				punta + perp,
				punta - perp
			]),
			Color(
				0.4,
				0.9,
				1.0,
				0.85
			)
		)


# ================================================================
# SIMULAR
# ================================================================

func _simular() -> void:
	if _nodos_canvas.is_empty():
		_label_estado.text = (
			"Añade IUMs al canvas primero."
		)

		return

	if ium_manager == null:
		_label_estado.text = (
			"Error: IUM Manager no disponible."
		)

		return

	var nodos: Array = []

	for entrada in _nodos_canvas:
		var slot: Control = entrada["slot"]

		nodos.append({
			"ium_id": entrada["ium"].get("id", ""),
			"nombre": entrada["ium"].get("nombre", ""),
			"orden": nodos.size() + 1,
			"rol": "componente",
			"posicion": "X",
			"posicion_x": slot.position.x,
			"posicion_y": slot.position.y
		})

	var enlaces: Array = []

	for con in _conexiones:
		var o_idx: int = con["origen"]
		var d_idx: int = con["destino"]

		if (
			o_idx < _nodos_canvas.size()
			and d_idx < _nodos_canvas.size()
		):
			enlaces.append({
				"origen": _nodos_canvas[o_idx]["ium"].get("id", ""),
				"destino": _nodos_canvas[d_idx]["ium"].get("id", ""),
				"tipo_union": "dirigida"
			})

	_label_estado.text = "Simulando..."

	_btn_simular.disabled = true

	ium_manager.simular_organizacion(
		nodos,
		enlaces
	)


# ================================================================
# CALLBACKS DEL MANAGER
# ================================================================

func _al_descubrir_proceso(resultado: Dictionary) -> void:
	_btn_simular.disabled = false

	if str(resultado.get("estado", "")) != "simulado":
		_label_estado.text = str(resultado.get("detalle", resultado.get("motivo", "La simulación no pudo resolverse.")))
		return

	var candidatos: Array = resultado.get("procesos_candidatos", [])
	var principal := str(resultado.get("conjuracion_principal", ""))
	var proceso_principal := str(resultado.get("proceso_principal", ""))
	if candidatos.is_empty():
		var salidas: Array = resultado.get("salidas", [])
		_label_estado.text = "Simulación completada. Salidas: " + ", ".join(salidas)
	else:
		if not principal.is_empty():
			_label_estado.text = "Coincidencia principal: %s · proceso: %s · candidatos: %d" % [principal, proceso_principal, candidatos.size()]
		else:
			_label_estado.text = "Simulación completada: %d candidatos; configuración ambigua." % candidatos.size()

	_mostrar_candidatos_simulacion(candidatos)


func _mostrar_candidatos_simulacion(candidatos: Array) -> void:
	for child in _panel_descubiertos.get_children():
		child.queue_free()

	if candidatos.is_empty():
		var vacio := Label.new()
		vacio.text = "No se encontró una conjuración compatible."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_descubiertos.add_child(vacio)
		return

	for candidato_variant in candidatos:
		if not candidato_variant is Dictionary:
			continue
		var candidato := candidato_variant as Dictionary
		var fila := VBoxContainer.new()
		var nombre := Label.new()
		var conjuracion := str(candidato.get("conjuracion", "Conjuración desconocida"))
		var proceso := str(candidato.get("proceso", "Proceso sin nombre"))
		nombre.text = conjuracion + (" · PRINCIPAL" if bool(candidato.get("es_principal", false)) else "")
		nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nombre.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7, 1))
		var detalle := Label.new()
		detalle.text = proceso
		detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detalle.add_theme_font_size_override("font_size", 10)
		fila.add_child(nombre)
		fila.add_child(detalle)
		_panel_descubiertos.add_child(fila)


func _al_error(mensaje: String) -> void:
	_btn_simular.disabled = false

	_label_estado.text = (
		"✗ "
		+ mensaje
	)


# ================================================================
# PROCESOS DESCUBIERTOS
# ================================================================

func _al_cargar_procesos(
	procesos: Array
) -> void:
	for child in _panel_descubiertos.get_children():
		child.queue_free()

	if procesos.is_empty():
		var lbl := Label.new()

		lbl.text = (
			"Ningún proceso descubierto aún."
		)

		lbl.add_theme_color_override(
			"font_color",
			Color(0.65, 0.52, 0.35, 1)
		)

		_panel_descubiertos.add_child(lbl)

		return

	for proceso in procesos:
		var hbox := HBoxContainer.new()

		var lbl := Label.new()

		lbl.text = proceso.get(
			"nombre",
			"Proceso"
		)

		lbl.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		var btn_equipar := Button.new()

		btn_equipar.text = "Equipar"

		btn_equipar.custom_minimum_size = Vector2(70, 0)
		_estilizar_boton(btn_equipar)

		btn_equipar.pressed.connect(
			func():
				_equipar(proceso)
		)

		hbox.add_child(lbl)
		hbox.add_child(btn_equipar)

		_panel_descubiertos.add_child(hbox)


func _equipar(proceso: Dictionary) -> void:
	ium_manager.equipar_proceso(proceso)

	_label_estado.text = (
		"Equipado: "
		+ proceso.get(
			"nombre",
			""
		)
	)


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

	_label_estado.text = (
		"Canvas limpiado."
	)
