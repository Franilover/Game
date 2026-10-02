extends Node


const SUPABASE_URL: String = "https://ftdxthnizdosaaavjhah.supabase.co"
const SUPABASE_PUBLISHABLE_KEY: String = "sb_publishable_dZowBcHCW7PJ5tV8aDnAPQ_1URMyPbV"

const SESSION_FILE_PATH: String = "user://garlia_session.json"


signal login_started
signal login_succeeded(perfil: Dictionary)
signal login_failed(message: String)

signal session_restored
signal session_restore_finished

signal logged_out


var access_token: String = ""
var refresh_token: String = ""

var user_id: String = ""
var user_email: String = ""

var perfil: Dictionary = {}


var _request: HTTPRequest = null
var _request_busy: bool = false
var _restaurando_sesion: bool = false


func _ready() -> void:
	_crear_request()

	call_deferred(
		"_restaurar_sesion"
	)


func _crear_request() -> void:
	if _request != null:
		return

	_request = HTTPRequest.new()
	_request.name = "AuthRequest"
	add_child(_request)


func esta_autenticado() -> bool:
	return (
		not access_token.is_empty()
		and not user_id.is_empty()
		and not perfil.is_empty()
	)


func esta_restaurando_sesion() -> bool:
	return _restaurando_sesion


func obtener_perfil() -> Dictionary:
	return perfil


func obtener_user_id() -> String:
	return user_id


func obtener_username() -> String:
	if perfil.is_empty():
		return ""

	return str(
		perfil.get(
			"username",
			""
		)
	)


func iniciar_sesion(
	email: String,
	password: String
) -> void:
	if _restaurando_sesion:
		login_failed.emit(
			"Espera a que termine la comprobación de la sesión."
		)

		return

	if _request_busy:
		login_failed.emit(
			"Ya existe una petición de autenticación en curso."
		)

		return

	if email.strip_edges().is_empty():
		login_failed.emit(
			"Introduce tu correo."
		)

		return

	if password.is_empty():
		login_failed.emit(
			"Introduce tu contraseña."
		)

		return

	login_started.emit()

	var url: String = (
		SUPABASE_URL
		+ "/auth/v1/token?grant_type=password"
	)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + SUPABASE_PUBLISHABLE_KEY
	])

	var body: String = JSON.stringify({
		"email": email.strip_edges(),
		"password": password
	})

	var respuesta: Variant = await _hacer_peticion(
		url,
		HTTPClient.METHOD_POST,
		headers,
		body
	)

	if respuesta == null:
		login_failed.emit(
			"No se pudo conectar con Supabase."
		)

		return

	var datos_respuesta: Dictionary = respuesta

	var result_code: int = int(
		datos_respuesta.get(
			"result_code",
			-1
		)
	)

	var response_code: int = int(
		datos_respuesta.get(
			"response_code",
			0
		)
	)

	var texto: String = str(
		datos_respuesta.get(
			"body",
			""
		)
	)

	if result_code != HTTPRequest.RESULT_SUCCESS:
		login_failed.emit(
			"No se pudo conectar con Supabase."
		)

		return

	var json := JSON.new()

	var parse_error: Error = json.parse(texto)

	if parse_error != OK:
		login_failed.emit(
			"Supabase devolvió una respuesta que no se pudo interpretar."
		)

		return

	if response_code < 200 or response_code >= 300:
		_login_error_desde_respuesta(
			json.data
		)

		return

	if not json.data is Dictionary:
		login_failed.emit(
			"Respuesta inválida de Supabase."
		)

		return

	var auth_data: Dictionary = json.data

	access_token = str(
		auth_data.get(
			"access_token",
			""
		)
	)

	refresh_token = str(
		auth_data.get(
			"refresh_token",
			""
		)
	)

	var usuario_variant: Variant = auth_data.get(
		"user",
		{}
	)

	if not usuario_variant is Dictionary:
		_limpiar_sesion()

		login_failed.emit(
			"Supabase no devolvió los datos del usuario."
		)

		return

	var usuario: Dictionary = usuario_variant

	user_id = str(
		usuario.get(
			"id",
			""
		)
	)

	user_email = str(
		usuario.get(
			"email",
			email
		)
	)

	if access_token.is_empty() or user_id.is_empty():
		_limpiar_sesion()

		login_failed.emit(
			"El inicio de sesión no devolvió una sesión válida."
		)

		return

	var perfil_cargado: bool = await _cargar_perfil()

	if not perfil_cargado:
		_limpiar_sesion()
		return

	_guardar_sesion()

	print(
		"GarliaAuth: sesión iniciada como ",
		obtener_username()
	)

	print(
		"GarliaAuth: perfil cargado correctamente."
	)

	login_succeeded.emit(
		perfil
	)


func _restaurar_sesion() -> void:
	if _restaurando_sesion:
		return

	_restaurando_sesion = true

	if not FileAccess.file_exists(
		SESSION_FILE_PATH
	):
		_restaurando_sesion = false

		session_restore_finished.emit()

		return

	var archivo := FileAccess.open(
		SESSION_FILE_PATH,
		FileAccess.READ
	)

	if archivo == null:
		print(
			"GarliaAuth: no se pudo abrir la sesión guardada."
		)

		_eliminar_sesion_guardada()

		_restaurando_sesion = false

		session_restore_finished.emit()

		return

	var texto: String = archivo.get_as_text()
	archivo.close()

	var json := JSON.new()

	var parse_error: Error = json.parse(texto)

	if parse_error != OK:
		print(
			"GarliaAuth: sesión guardada inválida."
		)

		_eliminar_sesion_guardada()
		_limpiar_sesion()

		_restaurando_sesion = false

		session_restore_finished.emit()

		return

	if not json.data is Dictionary:
		_eliminar_sesion_guardada()
		_limpiar_sesion()

		_restaurando_sesion = false

		session_restore_finished.emit()

		return

	var datos: Dictionary = json.data

	refresh_token = str(
		datos.get(
			"refresh_token",
			""
		)
	)

	user_email = str(
		datos.get(
			"user_email",
			""
		)
	)

	if refresh_token.is_empty():
		print(
			"GarliaAuth: no existe refresh token guardado."
		)

		_eliminar_sesion_guardada()
		_limpiar_sesion()

		_restaurando_sesion = false

		session_restore_finished.emit()

		return

	print(
		"GarliaAuth: restaurando sesión..."
	)

	var restaurada: bool = await _renovar_sesion()

	_restaurando_sesion = false

	if restaurada:
		print(
			"GarliaAuth: sesión restaurada automáticamente como ",
			obtener_username()
		)

		session_restored.emit()
	else:
		_eliminar_sesion_guardada()
		_limpiar_sesion()

	session_restore_finished.emit()


func _renovar_sesion() -> bool:
	if refresh_token.is_empty():
		return false

	if _request_busy:
		return false

	var url: String = (
		SUPABASE_URL
		+ "/auth/v1/token?grant_type=refresh_token"
	)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + SUPABASE_PUBLISHABLE_KEY
	])

	var body: String = JSON.stringify({
		"refresh_token": refresh_token
	})

	var respuesta: Variant = await _hacer_peticion(
		url,
		HTTPClient.METHOD_POST,
		headers,
		body
	)

	if respuesta == null:
		print(
			"GarliaAuth: falló la petición de restauración."
		)

		return false

	var datos_respuesta: Dictionary = respuesta

	var result_code: int = int(
		datos_respuesta.get(
			"result_code",
			-1
		)
	)

	var response_code: int = int(
		datos_respuesta.get(
			"response_code",
			0
		)
	)

	var texto: String = str(
		datos_respuesta.get(
			"body",
			""
		)
	)

	if result_code != HTTPRequest.RESULT_SUCCESS:
		print(
			"GarliaAuth: no se pudo conectar al restaurar sesión."
		)

		return false

	var json := JSON.new()

	var parse_error: Error = json.parse(texto)

	if parse_error != OK:
		return false

	if response_code < 200 or response_code >= 300:
		print(
			"GarliaAuth: refresh token rechazado."
		)

		return false

	if not json.data is Dictionary:
		return false

	var auth_data: Dictionary = json.data

	var nuevo_access_token: String = str(
		auth_data.get(
			"access_token",
			""
		)
	)

	var nuevo_refresh_token: String = str(
		auth_data.get(
			"refresh_token",
			""
		)
	)

	var usuario_variant: Variant = auth_data.get(
		"user",
		{}
	)

	if nuevo_access_token.is_empty():
		return false

	if nuevo_refresh_token.is_empty():
		return false

	if not usuario_variant is Dictionary:
		return false

	var usuario: Dictionary = usuario_variant

	var nuevo_user_id: String = str(
		usuario.get(
			"id",
			""
		)
	)

	if nuevo_user_id.is_empty():
		return false

	access_token = nuevo_access_token
	refresh_token = nuevo_refresh_token

	user_id = nuevo_user_id

	user_email = str(
		usuario.get(
			"email",
			user_email
		)
	)

	var perfil_cargado: bool = await _cargar_perfil()

	if not perfil_cargado:
		return false

	_guardar_sesion()

	print(
		"GarliaAuth: token renovado correctamente."
	)

	print(
		"GarliaAuth: perfil restaurado correctamente."
	)

	return true


func _cargar_perfil() -> bool:
	if access_token.is_empty():
		login_failed.emit(
			"No existe una sesión autenticada."
		)

		return false

	if user_id.is_empty():
		login_failed.emit(
			"No se recibió el ID del usuario."
		)

		return false

	if _request == null:
		_crear_request()

	var url: String = (
		SUPABASE_URL
		+ "/rest/v1/perfiles"
		+ "?select=id,email,rol,username,status,avatar_url,descripcion,"
		+ "personaje_favorito_id,mascota_id,titulo,nivel,xp_total,monedas"
		+ "&id=eq."
		+ user_id
		+ "&limit=1"
	)

	var headers := PackedStringArray([
		"apikey: " + SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + access_token
	])

	var respuesta: Variant = await _hacer_peticion(
		url,
		HTTPClient.METHOD_GET,
		headers
	)

	if respuesta == null:
		login_failed.emit(
			"No se pudo conectar con la base de datos de Garlia."
		)

		return false

	var datos_respuesta: Dictionary = respuesta

	var result_code: int = int(
		datos_respuesta.get(
			"result_code",
			-1
		)
	)

	var response_code: int = int(
		datos_respuesta.get(
			"response_code",
			0
		)
	)

	var texto: String = str(
		datos_respuesta.get(
			"body",
			""
		)
	)

	if result_code != HTTPRequest.RESULT_SUCCESS:
		login_failed.emit(
			"No se pudo conectar con la base de datos de Garlia."
		)

		return false

	var json := JSON.new()

	var parse_error: Error = json.parse(texto)

	if parse_error != OK:
		login_failed.emit(
			"No se pudo interpretar el perfil recibido."
		)

		return false

	if response_code < 200 or response_code >= 300:
		login_failed.emit(
			"No se pudo acceder al perfil de Garlia."
		)

		return false

	if not json.data is Array:
		login_failed.emit(
			"Supabase devolvió un perfil inválido."
		)

		return false

	var perfiles: Array = json.data

	if perfiles.is_empty():
		login_failed.emit(
			"Tu cuenta existe, pero no tiene un perfil de Garlia."
		)

		return false

	var primer_perfil: Variant = perfiles[0]

	if not primer_perfil is Dictionary:
		login_failed.emit(
			"El perfil recibido no es válido."
		)

		return false

	perfil = primer_perfil

	return true


func _hacer_peticion(
	url: String,
	metodo: HTTPClient.Method,
	headers: PackedStringArray,
	cuerpo: String = ""
) -> Variant:
	if _request == null:
		_crear_request()

	if _request_busy:
		push_warning(
			"GarliaAuth: se intentó iniciar una petición mientras había otra activa."
		)

		return null

	_request_busy = true

	var error: Error

	if cuerpo.is_empty():
		error = _request.request(
			url,
			headers,
			metodo
		)
	else:
		error = _request.request(
			url,
			headers,
			metodo,
			cuerpo
		)

	if error != OK:
		_request_busy = false
		return null

	var resultado: Array = await _request.request_completed

	_request_busy = false

	return {
		"result_code": int(resultado[0]),
		"response_code": int(resultado[1]),
		"body": PackedByteArray(resultado[3]).get_string_from_utf8()
	}


func _guardar_sesion() -> void:
	if refresh_token.is_empty():
		return

	var archivo := FileAccess.open(
		SESSION_FILE_PATH,
		FileAccess.WRITE
	)

	if archivo == null:
		push_warning(
			"GarliaAuth: no se pudo guardar la sesión."
		)

		return

	var datos := {
		"refresh_token": refresh_token,
		"user_email": user_email
	}

	archivo.store_string(
		JSON.stringify(datos)
	)

	archivo.close()

	print(
		"GarliaAuth: sesión guardada localmente."
	)


func _eliminar_sesion_guardada() -> void:
	if not FileAccess.file_exists(
		SESSION_FILE_PATH
	):
		return

	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(
			SESSION_FILE_PATH
		)
	)


func _login_error_desde_respuesta(
	datos: Variant
) -> void:
	var mensaje: String = (
		"No se pudo iniciar sesión."
	)

	if datos is Dictionary:
		var datos_dict: Dictionary = datos

		var descripcion: String = str(
			datos_dict.get(
				"error_description",
				""
			)
		)

		if descripcion.is_empty():
			descripcion = str(
				datos_dict.get(
					"msg",
					""
				)
			)

		if not descripcion.is_empty():
			mensaje = descripcion

	login_failed.emit(
		mensaje
	)


func cerrar_sesion() -> void:
	_eliminar_sesion_guardada()
	_limpiar_sesion()

	logged_out.emit()

	print(
		"GarliaAuth: sesión cerrada."
	)


func _limpiar_sesion() -> void:
	access_token = ""
	refresh_token = ""

	user_id = ""
	user_email = ""

	perfil = {}
