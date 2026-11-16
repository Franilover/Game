extends "res://scripts/infrastructure/supabase_client.gd"

const AuthScript = preload("res://scripts/infrastructure/garlia_auth.gd")
const CATALOGOS := [
	"eterium_runtime",
	"especie_eterium_game",
	"personaje_social",
	"personaje_regalos",
	"relaciones_ecologicas",
	"reinos_game"
]

var llamadas: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var auth := AuthScript.new()
	auth.access_token = "jwt-de-prueba"
	auth.user_id = "usuario-de-prueba"
	auth.perfil = {"username": "Prueba"}
	configurar_dependencias(auth)

	await get_tree().process_frame
	_comprobar_cargas(errores, "configuración con sesión ya autenticada")

	for catalogo in CATALOGOS:
		llamadas[catalogo] = 0
	auth.session_restored.emit()
	_comprobar_cargas(errores, "restauración de sesión")

	for catalogo in CATALOGOS:
		llamadas[catalogo] = 0
	auth.login_succeeded.emit({"username": "Prueba"})
	_comprobar_cargas(errores, "inicio de sesión normal")

	if not errores.is_empty():
		for error in errores:
			push_error("AuthenticatedCatalogReload: FAIL: " + error)
		get_tree().quit(1)
		return

	print("AuthenticatedCatalogReload: PASS")
	get_tree().quit(0)


func _comprobar_cargas(errores: Array[String], contexto: String) -> void:
	for catalogo in CATALOGOS:
		if int(llamadas.get(catalogo, 0)) != 1:
			errores.append("%s no solicitó exactamente una vez %s." % [contexto, catalogo])


func _registrar_llamada(catalogo: String) -> void:
	llamadas[catalogo] = int(llamadas.get(catalogo, 0)) + 1


func cargar_eterium_runtime() -> void:
	_registrar_llamada("eterium_runtime")


func cargar_especie_eterium_game() -> void:
	_registrar_llamada("especie_eterium_game")


func cargar_personaje_social() -> void:
	_registrar_llamada("personaje_social")


func cargar_personaje_regalos() -> void:
	_registrar_llamada("personaje_regalos")


func cargar_relaciones_ecologicas() -> void:
	_registrar_llamada("relaciones_ecologicas")


func cargar_reinos_game() -> void:
	_registrar_llamada("reinos_game")
