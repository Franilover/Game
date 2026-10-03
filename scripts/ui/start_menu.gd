extends Control


const MAIN_SCENE_PATH: String = (
	"res://scenes/wold/main.tscn"
)


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

@onready var multiplayer_close_button: Button = (
	$MultiplayerOverlay/MultiplayerPanel/Margin/Content/CloseButton
)


var _login_en_curso: bool = false
var _codigo_sala_actual: String = ""

var _mundo_preparado: bool = false
var _cargando_mundo: bool = false

# Creación de personaje antes de entrar a cualquier partida.
var _character_creation: Control = null


func _ready() -> void:
	start_button.pressed.connect(
		_iniciar_partida
	)

	multiplayer_button.pressed.connect(
		_abrir_multijugador
	)

	host_button.pressed.connect(
		_crear_partida
	)

	join_button.pressed.connect(
		_unirse_partida
	)

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

	_preparar_creador_personaje()

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

	# Si WorldData alcanzó a cargarse desde cache,
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
	_mostrar_creacion_personaje("aventura")

func _iniciar_aventura_con_personaje() -> void:
	if _cargando_mundo:
		return

	if not WorldData.esta_cargado():
		_cargando_mundo = true
		start_button.disabled = true
		start_button.text = "Preparando mundo..."

		SupabaseClient.cargar_mundo_inicial()

		return

	_guardar_configuracion_personaje()

	print(
		"StartMenu: Iniciar partida con personaje"
	)

	start_button.disabled = true

	var error: Error = (
		get_tree().change_scene_to_file(
			MAIN_SCENE_PATH
		)
	)

	if error != OK:
		push_error(
			"StartMenu: no se pudo abrir "
			+ "la escena principal. Error: "
			+ str(error)
		)

		start_button.disabled = false
		start_button.text = "Aventura"


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
	var autenticado: bool = (
		GarliaAuth.esta_autenticado()
	)

	if autenticado:
		_actualizar_perfil_button()

		profile_button.tooltip_text = (
			"Cuenta de "
			+ GarliaAuth.obtener_username()
		)

	else:
		profile_button.text = "P"

		profile_button.tooltip_text = (
			"Perfil / Iniciar sesión"
		)

	if GarliaAuth.esta_restaurando_sesion():
		multiplayer_button.disabled = true

		multiplayer_button.tooltip_text = (
			"Comprobando sesión..."
		)

	elif autenticado:
		multiplayer_button.disabled = false

		multiplayer_button.tooltip_text = (
			"Jugar con otros exploradores"
		)

	else:
		multiplayer_button.disabled = true

		multiplayer_button.tooltip_text = (
			"Inicia sesión para usar el multijugador."
		)


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

func _preparar_creador_personaje() -> void:
	var scene: PackedScene = preload("res://scenes/ui/character_creation.tscn")
	_character_creation = scene.instantiate()
	_character_creation.confirmed.connect(_on_character_confirmed)
	_character_creation.cancelled.connect(_on_character_cancelled)
	add_child(_character_creation)

func _mostrar_creacion_personaje(accion: String) -> void:
	if _character_creation == null:
		_preparar_creador_personaje()
	_character_creation.open(accion)

func _on_character_cancelled() -> void:
	print("StartMenu: creación de personaje cancelada.")

func _on_character_confirmed(config: Dictionary, action: String) -> void:
	GameState.flags["personaje"] = config
	match action:
		"aventura":
			_iniciar_aventura_con_personaje()
		"host":
			_crear_partida_real()
		"join":
			_unirse_partida_real()

# ============================================================
# MULTIJUGADOR
# ============================================================

func _abrir_multijugador() -> void:
	if not GarliaAuth.esta_autenticado():
		multijugador_estado(
			"Debes iniciar sesión para usar el multijugador."
		)

		return

	login_overlay.visible = false
	multiplayer_overlay.visible = true

	multiplayer_status.text = (
		"Listo para crear o unirse a una partida."
	)

	_mostrar_ips_locales()

	ip_input.placeholder_text = (
		"Código de sala (ej: LUNA-4821)"
	)

	port_input.visible = false

	ip_input.grab_focus()


func _cerrar_multijugador() -> void:
	if not GarliaSalas.obtener_codigo_activo().is_empty():
		GarliaSalas.cerrar_sala()

	multiplayer_overlay.visible = false


func _mostrar_ips_locales() -> void:
	var ips: Array[String] = (
		GarliaMultiplayer.obtener_ips_locales()
	)

	if ips.is_empty():
		local_ip_label.text = (
			"Tu IP local: no disponible"
		)

		return

	local_ip_label.text = (
		"Tu IP local: "
		+ " / ".join(ips)
	)


func _crear_partida() -> void:
	_mostrar_creacion_personaje("host")

func _crear_partida_real() -> void:
	if not GarliaAuth.esta_autenticado():
		multiplayer_status.text = (
			"Debes iniciar sesión para crear una partida."
		)

		return

	var ips: Array[String] = (
		GarliaMultiplayer.obtener_ips_locales()
	)

	if ips.is_empty():
		multiplayer_status.text = (
			"No se detectó IP local."
		)

		return

	host_button.disabled = true
	join_button.disabled = true

	multiplayer_status.text = (
		"Creando partida..."
	)

	var creada: bool = (
		GarliaMultiplayer.crear_partida()
	)

	if not creada:
		host_button.disabled = false
		join_button.disabled = false
		return

	multiplayer_status.text = (
		"Publicando sala..."
	)

	await GarliaSalas.publicar_sala(
		ips[0]
	)


func _unirse_partida() -> void:
	_mostrar_creacion_personaje("join")

func _unirse_partida_real() -> void:
	if not GarliaAuth.esta_autenticado():
		multiplayer_status.text = (
			"Debes iniciar sesión para unirte."
		)

		return

	var codigo: String = (
		ip_input.text.strip_edges().to_upper()
	)

	if codigo.is_empty():
		multiplayer_status.text = (
			"Escribe el código de la sala."
		)

		ip_input.grab_focus()
		return

	host_button.disabled = true
	join_button.disabled = true

	multiplayer_status.text = (
		"Buscando sala..."
	)

	await GarliaSalas.buscar_sala(
		codigo
	)


func _partida_creada() -> void:
	_mostrar_ips_locales()

	print(
		"StartMenu: servidor ENet listo."
	)


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
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = (
		"Conectado a la partida."
	)

	print(
		"StartMenu: conectado al multijugador."
	)


func _conexion_fallida() -> void:
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = (
		"No se pudo conectar con la partida."
	)


func _servidor_desconectado() -> void:
	host_button.disabled = false
	join_button.disabled = false

	multiplayer_status.text = (
		"El anfitrión cerró la partida."
	)

	if not GarliaSalas.obtener_codigo_activo().is_empty():
		GarliaSalas.cerrar_sala()


func _multijugador_estado_cambiado(
	mensaje: String
) -> void:
	multiplayer_status.text = mensaje


func multijugador_estado(
	mensaje: String
) -> void:
	multiplayer_status.text = mensaje
