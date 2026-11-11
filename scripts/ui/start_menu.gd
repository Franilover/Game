extends Control

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const SETTINGS_SCENE = preload("res://scenes/ui/settings_panel.tscn")
const COMMUNITY_SERVER_MANAGER_SCENE = preload("res://scenes/ui/community_server_manager.tscn")


@onready var start_button: Button = (
	$Center/StartButton
)

@onready var multiplayer_button: Button = (
	$Center/MultiplayerButton
)

@onready var exit_button: Button = (
	$Center/ExitButton
)

@onready var profile_button: Button = (
	$ProfileButton
)

@onready var settings_button: Button = $SettingsButton

@onready var login_overlay: ColorRect = (
	$LoginOverlay
)

@onready var email_input: LineEdit = (
	$LoginOverlay/LoginPanel/Margin/Content/EmailInput
)

@onready var password_input: LineEdit = (
	$LoginOverlay/LoginPanel/Margin/Content/PasswordInput
)

@onready var message_label: Label = (
	$LoginOverlay/LoginPanel/Margin/Content/Message
)

@onready var login_button: Button = (
	$LoginOverlay/LoginPanel/Margin/Content/Buttons/LoginButton
)

@onready var close_button: Button = (
	$LoginOverlay/LoginPanel/Margin/Content/Buttons/CloseButton
)

@onready var multiplayer_overlay: ColorRect = (
	$MultiplayerOverlay
)

@onready var host_button: Button = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/HostButton
)

@onready var local_ip_label: Label = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/LocalIPLabel
)

@onready var ip_input: LineEdit = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/IPInput
)

@onready var port_input: LineEdit = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/PortInput
)

@onready var join_button: Button = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/JoinButton
)

@onready var multiplayer_status: Label = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/Status
)

@onready var server_name_input: LineEdit = $MultiplayerOverlay/MultiplayerPanel/Margin/Content/ServerNameInput
@onready var saved_servers_list: ItemList = $MultiplayerOverlay/MultiplayerPanel/Margin/Content/SavedServersList
@onready var save_server_button: Button = $MultiplayerOverlay/MultiplayerPanel/Margin/Content/SaveServerButton
@onready var remove_server_button: Button = $MultiplayerOverlay/MultiplayerPanel/Margin/Content/RemoveServerButton
@onready var public_directory_label: Label = $MultiplayerOverlay/MultiplayerPanel/Margin/Content/PublicDirectoryLabel
@onready var community_server_manager_button: Button = $MultiplayerOverlay/MultiplayerPanel/Margin/Content/CommunityServerManagerButton
@onready var community_certificate_check: CheckBox = $MultiplayerOverlay/MultiplayerPanel/Margin/Content/CommunityCertificateCheck

const SERVER_BOOKMARKS_PATH := "user://garlia_servers.json"
var _saved_servers: Array[Dictionary] = []

@onready var multiplayer_close_button: Button = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/CloseButton
)


var _settings_panel: SettingsPanel = null
var _login_en_curso: bool = false
var _codigo_sala_actual: String = ""
var _config_personaje_multijugador: Dictionary = {}

var _mundo_preparado: bool = false
var _cargando_mundo: bool = false

# Creación de personaje antes de entrar a cualquier partida.
@onready var _character_creation: Control = $CharacterCreation


func _ready() -> void:
	# Diagnóstico de arranque: se registra antes de inicializar servicios o layouts.
	call_deferred("_debug_ventana_inicio")
	# El servidor dedicado reutiliza el runtime del mundo, no el menú ni una partida local.
	if OS.get_cmdline_user_args().has("--garlia-server"):
		call_deferred("_entrar_runtime_servidor")
		return

	SupabaseClient.configurar_dependencias(GarliaAuth)
	GarliaMultiplayer.configurar_dependencias(GarliaAuth)
	GarliaSalas.configurar_dependencias(GarliaAuth)

	if WorldData.has_method("configurar_dependencias"):
		WorldData.configurar_dependencias(SupabaseClient)

	start_button.pressed.connect(
		_iniciar_partida
	)

	settings_button.pressed.connect(_abrir_configuracion)

	multiplayer_button.pressed.connect(
		_abrir_multijugador
	)

	host_button.pressed.connect(
		_crear_partida
	)

	join_button.pressed.connect(
		_unirse_partida
	)
	save_server_button.pressed.connect(_guardar_servidor_local)
	community_server_manager_button.pressed.connect(_abrir_administrador_servidores)
	remove_server_button.pressed.connect(_eliminar_servidor_local)
	saved_servers_list.item_selected.connect(_seleccionar_servidor_guardado)
	_cargar_servidores_guardados()

	multiplayer_close_button.pressed.connect(
		_cerrar_multijugador
	)

	exit_button.pressed.connect(
		_salir
	)

	profile_button.pressed.connect(
		_abrir_login
	)

	login_button.pressed.connect(
		_intentar_login
	)

	close_button.pressed.connect(
		_cerrar_login
	)

	GarliaAuth.login_started.connect(
		_login_empezado
	)

	GarliaAuth.login_succeeded.connect(
		_login_exitoso
	)

	GarliaAuth.login_failed.connect(
		_login_fallido
	)

	GarliaAuth.session_restored.connect(
		_sesion_restaurada
	)

	GarliaAuth.session_restore_finished.connect(
		_sesion_restauracion_terminada
	)

	GarliaAuth.logged_out.connect(
		_sesion_cerrada
	)

	GarliaMultiplayer.status_changed.connect(
		_multijugador_estado_cambiado
	)

	if not GarliaWorldNetwork.mundo_global_listo.is_connected(_al_mundo_global_listo):
		GarliaWorldNetwork.mundo_global_listo.connect(_al_mundo_global_listo)
	if not GarliaWorldNetwork.mundo_global_rechazado.is_connected(_al_mundo_global_rechazado):
		GarliaWorldNetwork.mundo_global_rechazado.connect(_al_mundo_global_rechazado)

	GarliaMultiplayer.host_created.connect(
		_partida_creada
	)

	GarliaMultiplayer.join_started.connect(
		_union_iniciada
	)

	GarliaMultiplayer.connected_to_game.connect(
		_conectado_a_partida
	)

	GarliaMultiplayer.connection_failed.connect(
		_conexion_fallida
	)

	GarliaMultiplayer.server_disconnected.connect(
		_servidor_desconectado
	)

	GarliaSalas.sala_creada.connect(
		_on_sala_creada
	)

	GarliaSalas.sala_unida.connect(
		_on_sala_unida
	)

	GarliaSalas.sala_no_encontrada.connect(
		_on_sala_no_encontrada
	)

	GarliaSalas.sala_llena.connect(
		_on_sala_llena
	)

	GarliaSalas.error_sala.connect(
		_on_error_sala
	)

	if not _character_creation.confirmed.is_connected(_on_character_confirmed):
		_character_creation.confirmed.connect(_on_character_confirmed)
	if not _character_creation.cancelled.is_connected(_on_character_cancelled):
		_character_creation.cancelled.connect(_on_character_cancelled)

	if not WorldData.mundo_listo.is_connected(
		_al_mundo_listo
	):
		WorldData.mundo_listo.connect(
			_al_mundo_listo
		)

	if not SupabaseClient.error_conexion.is_connected(
		_al_error_mundo
	):
		SupabaseClient.error_conexion.connect(
			_al_error_mundo
		)

	start_button.grab_focus()

	_actualizar_estado_cuenta()

	if GarliaAuth.esta_restaurando_sesion():
		login_button.disabled = true
		multiplayer_button.disabled = true

	_actualizar_estado_mundo()
	PIXEL_UI_THEME.apply(self)
	get_viewport().size_changed.connect(_configurar_layout_responsive)
	_configurar_layout_responsive()


func _debug_ventana_inicio() -> void:
	# Captura el estado inmediato, después del primer frame y tras un segundo.
	# Esto permite detectar si Godot o el compositor cambian el tamaño/posición.
	_imprimir_estado_ventana("INMEDIATO")
	await get_tree().process_frame
	_imprimir_estado_ventana("PRIMER_FRAME")
	await get_tree().create_timer(1.0).timeout
	_imprimir_estado_ventana("1_SEGUNDO")


func _imprimir_estado_ventana(momento: String) -> void:
	var pantalla := DisplayServer.window_get_current_screen()
	var viewport := get_viewport()
	var ventana := get_window()
	var centro := get_node_or_null("Center") as Control
	var papel := get_node_or_null("Paper") as Control

	print("\n========== [VENTANA][", momento, "] ==========")
	print("[VENTANA] PID: ", OS.get_process_id())
	print("[VENTANA] SO: ", OS.get_name(), " | Godot: ", Engine.get_version_info())
	print("[VENTANA] Modo ventana (enum): ", DisplayServer.window_get_mode())
	print("[VENTANA] Tamaño ventana: ", DisplayServer.window_get_size())
	print("[VENTANA] Posición ventana: ", DisplayServer.window_get_position())
	print("[VENTANA] Pantalla actual: ", pantalla)
	print("[VENTANA] Tamaño pantalla: ", DisplayServer.screen_get_size(pantalla))
	print("[VENTANA] Posición pantalla: ", DisplayServer.screen_get_position(pantalla))
	print("[VENTANA] Tamaño viewport visible: ", viewport.get_visible_rect().size)
	print("[VENTANA] Tamaño viewport: ", viewport.size)
	print("[VENTANA] Escala contenido ventana: ", ventana.content_scale_size)
	print("[VENTANA] Modo escala contenido: ", ventana.content_scale_mode)
	print("[VENTANA] Aspecto escala contenido: ", ventana.content_scale_aspect)
	print("[VENTANA] Config proyecto - modo: ", ProjectSettings.get_setting("display/window/size/mode", "NO_DEFINIDO"))
	print("[VENTANA] Config proyecto - override: ", Vector2i(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	))
	print("[VENTANA] Config proyecto - viewport: ", Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	))
	print("[VENTANA] Config proyecto - stretch mode: ", ProjectSettings.get_setting("display/window/stretch/mode", "NO_DEFINIDO"))
	print("[VENTANA] Config proyecto - stretch aspect: ", ProjectSettings.get_setting("display/window/stretch/aspect", "NO_DEFINIDO"))
	print("[VENTANA] Config proyecto - scale mode: ", ProjectSettings.get_setting("display/window/stretch/scale_mode", "NO_DEFINIDO"))
	print("[VENTANA] Menú root rect global: ", get_global_rect())
	if is_instance_valid(centro):
		print("[VENTANA] Center rect global: ", centro.get_global_rect(), " | size: ", centro.size, " | position: ", centro.position)
	if is_instance_valid(papel):
		print("[VENTANA] Paper rect global: ", papel.get_global_rect(), " | size: ", papel.size, " | position: ", papel.position)
	print("========== [/VENTANA] ==========")


func _configurar_layout_responsive() -> void:
	# Paper y Center ya tienen anclas centradas y dimensiones fijas en la escena.
	# No recalcular su posición desde el viewport: hacerlo aquí desincroniza
	# sus offsets respecto al área lógica y desplaza el bloque principal.
	# Solo los paneles superpuestos necesitan reducirse en ventanas pequeñas.
	var area := get_viewport().get_visible_rect().size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	_ajustar_panel_centrado(
		get_node_or_null("LoginOverlay/LoginPanel") as Control,
		Vector2(380.0, 330.0),
		area
	)
	_ajustar_panel_centrado(
		get_node_or_null("MultiplayerOverlay/MultiplayerPanel") as Control,
		Vector2(500.0, 570.0),
		area
	)


func _ajustar_panel_centrado(panel: Control, maximo: Vector2, area: Vector2) -> void:
	if not is_instance_valid(panel):
		return
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var margen := Vector2(24.0, 24.0)
	var minimo := Vector2(240.0, 260.0)
	var disponible := Vector2(
		maxf(minimo.x, area.x - margen.x * 2.0),
		maxf(minimo.y, area.y - margen.y * 2.0)
	)
	panel.size = Vector2(minf(maximo.x, disponible.x), minf(maximo.y, disponible.y))
	panel.position = -panel.size * 0.5


func _entrar_runtime_servidor() -> void:
	if not GarliaMultiplayer.iniciar_servidor_dedicado_desde_argumentos():
		push_error("StartMenu: se pidió modo servidor, pero WSS/TLS no pudo iniciar. Revisa el certificado, la clave privada y el puerto.")
		get_tree().quit(1)
		return
	var error := get_tree().change_scene_to_file("res://scenes/world/main.tscn")
	if error != OK:
		push_error("StartMenu: no se pudo cargar el runtime del servidor. Error: " + str(error))
		get_tree().quit(1)


func _abrir_configuracion() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		return

	login_overlay.visible = false
	multiplayer_overlay.visible = false
	_settings_panel = SETTINGS_SCENE.instantiate() as SettingsPanel
	if _settings_panel == null:
		push_error("StartMenu: no se pudo crear el panel de configuración.")
		return

	_settings_panel.closed.connect(_cerrar_configuracion)
	add_child(_settings_panel)
	_settings_panel.z_index = 5000


func _cerrar_configuracion() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	_settings_panel = null


func _actualizar_estado_mundo() -> void:
	if WorldData.esta_cargado():
		_al_mundo_listo()
		return

	_mundo_preparado = false
	_cargando_mundo = true

	start_button.disabled = true
	start_button.text = "Preparando mundo..."

	print(
		"StartMenu: esperando datos del mundo."
	)


func _al_mundo_listo() -> void:
	_mundo_preparado = true
	_cargando_mundo = false

	start_button.disabled = false
	start_button.text = "Aventura"

	print(
		"StartMenu: mundo listo para Aventura."
	)


func _al_error_mundo(
	mensaje: String
) -> void:
	_cargando_mundo = false

	# Si WorldDataService alcanzó a cargarse desde cache,
	# no mostramos error como si el juego estuviera roto.
	if WorldData.esta_cargado():
		_al_mundo_listo()
		return

	_mundo_preparado = false

	start_button.disabled = false
	start_button.text = "Reintentar"

	print(
		"StartMenu: no se pudo preparar "
		+ "el mundo → ",
		mensaje
	)


func _iniciar_partida() -> void:
	_abrir_selector_partidas()

func _abrir_selector_partidas() -> void:
	var selector_scene: PackedScene = load(
		"res://scenes/ui/save_selector.tscn"
	) as PackedScene

	if selector_scene == null:
		push_error(
			"StartMenu: no se pudo cargar save_selector.tscn."
		)
		return

	if get_node_or_null("LocalSaveSelector") != null:
		return

	var selector := selector_scene.instantiate() as Control
	if selector == null:
		push_error("StartMenu: save_selector.tscn no tiene una raiz Control.")
		return
	selector.name = "LocalSaveSelector"
	add_child(selector)
	# La escena se agrega en tiempo de ejecucion: fuerza el rectangulo completo
	# respecto al StartMenu, y vuelve a aplicar el layout tras el primer frame.
	selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selector.position = Vector2.ZERO
	selector.call_deferred("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
	selector.call_deferred("_configurar_diseno_responsive")

	print("StartMenu: selector de partidas abierto.")

func _iniciar_aventura_con_personaje(config: Dictionary = {}) -> void:
	if _cargando_mundo:
		return

	if not WorldData.esta_cargado():
		_cargando_mundo = true
		start_button.disabled = true
		start_button.text = "Preparando mundo..."
		SupabaseClient.cargar_mundo_inicial()
		return

	print("StartMenu: creando partida desde personaje.")

	var nombre_partida := str(config.get("nombre_partida", "Partida")).strip_edges()
	var semilla := str(config.get("semilla", "")).strip_edges()

	if nombre_partida.is_empty():
		nombre_partida = "Partida"

	var id := GameState.crear_partida(nombre_partida, semilla, config)
	if id.is_empty():
		start_button.disabled = false
		return

	start_button.disabled = true
	if not GameState.iniciar_partida(id):
		start_button.disabled = false


func _salir() -> void:
	print(
		"StartMenu: Salir"
	)

	get_tree().quit()


# ============================================================
# CUENTA
# ============================================================

func _abrir_login() -> void:
	login_overlay.visible = true

	_actualizar_panel_cuenta()


func _cerrar_login() -> void:
	if _login_en_curso:
		return

	login_overlay.visible = false


func _actualizar_panel_cuenta() -> void:
	if GarliaAuth.esta_autenticado():
		var username: String = (
			GarliaAuth.obtener_username()
		)

		if username.is_empty():
			username = "Explorador"

		var titulo: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/Title
		)

		var subtitulo: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/Subtitle
		)

		var email_label: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/EmailLabel
		)

		var password_label: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/PasswordLabel
		)

		titulo.text = "Tu cuenta"

		subtitulo.text = (
			"Sesión iniciada como "
			+ username
		)

		email_label.visible = false
		password_label.visible = false

		email_input.visible = false
		password_input.visible = false

		message_label.text = (
			"¡Bienvenido de nuevo, "
			+ username
			+ "!"
		)

		login_button.text = (
			"Cerrar sesión"
		)

		close_button.text = "Volver"

		login_button.disabled = false
		close_button.disabled = false

		_actualizar_perfil_button()

	else:
		var titulo: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/Title
		)

		var subtitulo: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/Subtitle
		)

		var email_label: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/EmailLabel
		)

		var password_label: Label = (
			$LoginOverlay/LoginPanel/Margin/Content/PasswordLabel
		)

		titulo.text = "Iniciar sesión"

		subtitulo.text = (
			"Usa tu cuenta de Garlia."
		)

		email_label.visible = true
		password_label.visible = true

		email_input.visible = true
		password_input.visible = true

		login_button.text = "Entrar"
		close_button.text = "Volver"

		login_button.disabled = false
		close_button.disabled = false

		message_label.text = ""


func _intentar_login() -> void:
	if GarliaAuth.esta_autenticado():
		GarliaAuth.cerrar_sesion()
		return

	if _login_en_curso:
		return

	if GarliaAuth.esta_restaurando_sesion():
		message_label.text = (
			"Comprobando la sesión guardada..."
		)

		return

	var email: String = (
		email_input.text.strip_edges()
	)

	var password: String = (
		password_input.text
	)

	if email.is_empty():
		message_label.text = (
			"Introduce tu correo."
		)

		email_input.grab_focus()
		return

	if password.is_empty():
		message_label.text = (
			"Introduce tu contraseña."
		)

		password_input.grab_focus()
		return

	_login_en_curso = true

	login_button.disabled = true
	close_button.disabled = true

	message_label.text = (
		"Conectando con la cuenta de Garlia..."
	)

	GarliaAuth.iniciar_sesion(
		email,
		password
	)


func _login_empezado() -> void:
	_login_en_curso = true

	login_button.disabled = true
	close_button.disabled = true

	message_label.text = (
		"Conectando con la cuenta de Garlia..."
	)


func _login_exitoso(
	perfil: Dictionary
) -> void:
	_login_en_curso = false

	var username: String = str(
		perfil.get(
			"username",
			""
		)
	)

	if username.is_empty():
		username = "Explorador"

	print(
		"StartMenu: perfil cargado → ",
		username
	)

	_actualizar_estado_cuenta()
	_actualizar_panel_cuenta()

	login_overlay.visible = false


func _login_fallido(
	mensaje: String
) -> void:
	_login_en_curso = false

	login_button.disabled = false
	close_button.disabled = false

	message_label.text = mensaje

	print(
		"StartMenu: error de login → ",
		mensaje
	)


func _sesion_restaurada() -> void:
	_actualizar_estado_cuenta()

	print(
		"StartMenu: sesión guardada restaurada → ",
		GarliaAuth.obtener_username()
	)


func _sesion_restauracion_terminada() -> void:
	if not _login_en_curso:
		login_button.disabled = false

	_actualizar_estado_cuenta()


func _sesion_cerrada() -> void:
	_login_en_curso = false

	email_input.text = ""
	password_input.text = ""

	login_overlay.visible = false
	multiplayer_overlay.visible = false

	_actualizar_estado_cuenta()

	print(
		"StartMenu: sesión cerrada."
	)


func _actualizar_estado_cuenta() -> void:
	var autenticado: bool = GarliaAuth.esta_autenticado()

	if autenticado:
		_actualizar_perfil_button()
		profile_button.tooltip_text = "Cuenta de " + GarliaAuth.obtener_username()
	else:
		profile_button.text = "P"
		profile_button.tooltip_text = "Perfil / Iniciar sesión"

	# El acceso multijugador permanece desactivado mientras se trabaja en esa función.
	multiplayer_button.disabled = true
	multiplayer_button.tooltip_text = "Multijugador temporalmente desactivado."


func _actualizar_perfil_button() -> void:
	var username: String = (
		GarliaAuth.obtener_username()
	)

	if username.is_empty():
		username = "P"

	profile_button.text = (
		username.left(1).to_upper()
	)

	profile_button.tooltip_text = (
		"Cuenta de "
		+ username
	)



# ============================================================
# CREACIÓN DE PERSONAJE
# ============================================================

func _mostrar_creacion_personaje(accion: String) -> void:
	# El creador debe quedar por encima de cualquier overlay del menú.
	multiplayer_overlay.visible = false
	login_overlay.visible = false
	_character_creation.z_index = 4000
	_character_creation.show()
	_character_creation.open(accion)

	print(
		"StartMenu: abriendo creación de personaje → ",
		accion
	)

func _on_character_cancelled() -> void:
	print("StartMenu: creación de personaje cancelada.")

func _on_character_confirmed(config: Dictionary, action: String) -> void:
	match action:
		"aventura":
			_iniciar_aventura_con_personaje(config)
		"host":
			_crear_partida_real()
		"join":
			_config_personaje_multijugador = config.duplicate(true)
			GarliaWorldNetwork.configurar_personaje_local(_config_personaje_multijugador)
			_unirse_partida_real()

# ============================================================
# MULTIJUGADOR
# ============================================================

func _abrir_multijugador() -> void:
	if not GarliaAuth.esta_autenticado():
		multijugador_estado("Inicia sesión para entrar a servidores. El acceso como invitado se integrará en otra etapa.")
		return
	login_overlay.visible = false
	multiplayer_overlay.visible = true
	multiplayer_status.text = "Selecciona un servidor guardado o introduce una dirección."
	public_directory_label.text = "Directorio público: pendiente de conectar al servicio central."
	port_input.text = str(GarliaMultiplayer.DEFAULT_PORT)
	_cargar_servidores_guardados()
	ip_input.grab_focus()


func _cerrar_multijugador() -> void:
	multiplayer_overlay.visible = false


func _cargar_servidores_guardados() -> void:
	_saved_servers.clear()
	saved_servers_list.clear()
	var archivo := FileAccess.open(SERVER_BOOKMARKS_PATH, FileAccess.READ)
	if archivo == null:
		return
	var parsed: Variant = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not parsed is Array:
		return
	for entry_variant in parsed:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var server_name := str(entry.get("name", "")).strip_edges()
		var address := str(entry.get("address", "")).strip_edges()
		var port := int(entry.get("port", GarliaMultiplayer.DEFAULT_PORT))
		if server_name.is_empty() or address.is_empty() or port < 1 or port > 65535:
			continue
		_saved_servers.append({"name": server_name, "address": address, "port": port})
		saved_servers_list.add_item("%s — %s:%d" % [server_name, address, port])
		saved_servers_list.set_item_metadata(saved_servers_list.item_count - 1, _saved_servers.size() - 1)


func _guardar_archivo_servidores() -> void:
	var archivo := FileAccess.open(SERVER_BOOKMARKS_PATH, FileAccess.WRITE)
	if archivo == null:
		multiplayer_status.text = "No se pudo guardar la lista local."
		return
	archivo.store_string(JSON.stringify(_saved_servers, "\t"))
	archivo.close()


func _guardar_servidor_local() -> void:
	var server_name := server_name_input.text.strip_edges()
	var address := ip_input.text.strip_edges()
	var port_text := port_input.text.strip_edges()
	if server_name.is_empty() or address.is_empty():
		multiplayer_status.text = "Escribe un nombre y una dirección."
		return
	if address.begins_with("wss://"):
		address = address.trim_prefix("wss://")
	if address.contains("://") or "/" in address or " " in address:
		multiplayer_status.text = "Introduce solo una IP o dominio, sin protocolo ni rutas."
		return
	if not port_text.is_valid_int():
		multiplayer_status.text = "El puerto debe ser un número entre 1 y 65535."
		return
	var port := int(port_text)
	if port < 1 or port > 65535:
		multiplayer_status.text = "El puerto debe ser un número entre 1 y 65535."
		return
	for entry in _saved_servers:
		if str(entry.get("address", "")).to_lower() == address.to_lower() and int(entry.get("port", 0)) == port:
			entry["name"] = server_name
			_guardar_archivo_servidores()
			_cargar_servidores_guardados()
			multiplayer_status.text = "Servidor guardado actualizado."
			return
	_saved_servers.append({"name": server_name, "address": address, "port": port})
	_guardar_archivo_servidores()
	_cargar_servidores_guardados()
	multiplayer_status.text = "Servidor guardado en este dispositivo."


func _seleccionar_servidor_guardado(indice: int) -> void:
	if indice < 0 or indice >= saved_servers_list.item_count:
		return
	var entry_index := int(saved_servers_list.get_item_metadata(indice))
	if entry_index < 0 or entry_index >= _saved_servers.size():
		return
	var entry: Dictionary = _saved_servers[entry_index]
	server_name_input.text = str(entry.get("name", ""))
	ip_input.text = str(entry.get("address", ""))
	port_input.text = str(entry.get("port", GarliaMultiplayer.DEFAULT_PORT))


func _eliminar_servidor_local() -> void:
	var selected := saved_servers_list.get_selected_items()
	if selected.is_empty():
		multiplayer_status.text = "Selecciona un servidor guardado."
		return
	var entry_index := int(saved_servers_list.get_item_metadata(selected[0]))
	if entry_index < 0 or entry_index >= _saved_servers.size():
		return
	_saved_servers.remove_at(entry_index)
	_guardar_archivo_servidores()
	_cargar_servidores_guardados()
	multiplayer_status.text = "Servidor eliminado de la lista local."


func _abrir_administrador_servidores() -> void:
	var existing := get_node_or_null("CommunityServerManager")
	if existing != null:
		return
	var manager := COMMUNITY_SERVER_MANAGER_SCENE.instantiate() as Control
	if manager == null:
		multiplayer_status.text = "No se pudo abrir el administrador de servidores."
		return
	manager.name = "CommunityServerManager"
	manager.closed.connect(_al_cerrar_administrador_servidores)
	add_child(manager)
	manager.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	manager.z_index = 6000
	manager.call_deferred("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)


func _al_cerrar_administrador_servidores() -> void:
	if is_instance_valid(community_server_manager_button):
		community_server_manager_button.grab_focus()


func _crear_partida() -> void:
	multiplayer_status.text = "Aloja un servidor comunitario ejecutando el servidor dedicado en un equipo o VPS."


func _crear_partida_real() -> void:
	_crear_partida()


func _unirse_partida() -> void:
	_mostrar_creacion_personaje("join")


func _unirse_partida_real() -> void:
	if not GarliaAuth.esta_autenticado():
		multiplayer_status.text = "Debes iniciar sesión para entrar a este servidor."
		return
	var address := ip_input.text.strip_edges()
	if address.is_empty():
		multiplayer_status.text = "Introduce una IP o dominio."
		ip_input.grab_focus()
		return
	if address.begins_with("wss://"):
		address = address.trim_prefix("wss://")
	if address.contains("://") or "/" in address or " " in address:
		multiplayer_status.text = "Introduce solo una IP o dominio con TLS válido."
		return
	var port_text := port_input.text.strip_edges()
	if not port_text.is_valid_int():
		multiplayer_status.text = "El puerto debe ser un número entre 1 y 65535."
		return
	var port := int(port_text)
	if port < 1 or port > 65535:
		multiplayer_status.text = "El puerto debe ser un número entre 1 y 65535."
		return
	host_button.disabled = true
	join_button.disabled = true
	multiplayer_status.text = "Conectando a %s:%d..." % [address, port]
	if not GarliaWorldNetwork.conectar_a_servidor_global(address, port, community_certificate_check.button_pressed):
		host_button.disabled = false
		join_button.disabled = false


func _partida_creada() -> void:
	multiplayer_status.text = "Servidor iniciado. La conexión comunitaria utiliza WSS/TLS."

	print("StartMenu: señal de servidor creado recibida.")


func _on_sala_creada(
	codigo: String
) -> void:
	_codigo_sala_actual = codigo

	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = (
		"Sala creada. Comparte el código: "
		+ codigo
	)

	local_ip_label.text = (
		"Código de sala: "
		+ codigo
	)

	print(
		"StartMenu: sala publicada con código ",
		codigo
	)


func _on_sala_unida(
	ip: String,
	puerto: int
) -> void:
	multiplayer_status.text = (
		"Sala encontrada. Conectando..."
	)

	GarliaMultiplayer.unirse_partida(
		ip,
		puerto
	)


func _on_sala_no_encontrada() -> void:
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = (
		"Código no encontrado o sala expirada."
	)


func _on_sala_llena() -> void:
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = (
		"La sala está llena."
	)


func _on_error_sala(
	mensaje: String
) -> void:
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = mensaje


func _union_iniciada() -> void:
	multiplayer_status.text = (
		"Conectando con la partida..."
	)


func _conectado_a_partida() -> void:
	multiplayer_status.text = "Conectado. Verificando cuenta y cargando el mundo global..."
	print("StartMenu: transporte WSS conectado; esperando autorización del mundo global.")


func _al_mundo_global_listo(semilla: int, tipo_zona: String, reinos_globales: Dictionary, tiempo_mundo: Dictionary) -> void:
	# La creación de personaje oculta el overlay antes de conectar; el handshake
	# debe poder completar la entrada aunque el panel ya no esté visible.
	multiplayer_status.text = "Entrando al mundo compartido..."
	var id_guardado := ""
	for partida in GameState.obtener_partidas():
		if str(partida.get("nombre", "")) == "Mundo compartido global" and int(partida.get("semilla", 0)) == semilla:
			id_guardado = str(partida.get("id", ""))
			break
	if id_guardado.is_empty():
		id_guardado = GameState.crear_partida("Mundo compartido global", str(semilla), _config_personaje_multijugador)
	if id_guardado.is_empty() or not GameState.establecer_zona_mundo_global(id_guardado, tipo_zona, reinos_globales, tiempo_mundo):
		host_button.disabled = false
		join_button.disabled = false
		multiplayer_status.text = "No se pudo preparar la zona global en tu guardado local."
		GarliaMultiplayer.cerrar_partida()
		return
	if not GameState.iniciar_partida(id_guardado):
		host_button.disabled = false
		join_button.disabled = false
		multiplayer_status.text = "No se pudo abrir tu guardado del mundo compartido."
		GarliaMultiplayer.cerrar_partida()
		return
	GameState.establecer_semilla_mundo(semilla)


func _al_mundo_global_rechazado(mensaje: String) -> void:
	host_button.disabled = false
	join_button.disabled = false
	multiplayer_status.text = mensaje


func _conexion_fallida() -> void:
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = (
		"No se pudo conectar con el servidor global."
	)


func _servidor_desconectado() -> void:
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = "El servidor del mundo global se desconectó."


func _multijugador_estado_cambiado(
	mensaje: String
) -> void:
	multiplayer_status.text = mensaje


func multijugador_estado(
	mensaje: String
) -> void:
	multiplayer_status.text = mensaje
