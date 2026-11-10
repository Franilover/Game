extends SceneTree

const Resolver = preload("res://scripts/gameplay/combat/combat_item_resolver.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	_probar_clasificacion(errores)
	_probar_modo_ataque(errores)
	_probar_propiedades(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatItemResolver: FAIL: " + error)
		quit(1)
		return

	print("CombatItemResolver: PASS")
	quit(0)


func _probar_clasificacion(errores: Array[String]) -> void:
	if not Resolver.es_arma({"tipo": "arma"}):
		errores.append("No reconoció el tipo directo arma.")
	if not Resolver.es_arma({"es_arma": true}):
		errores.append("No conservó la compatibilidad del indicador es_arma.")
	if not Resolver.es_arma({"categoria": "arma cuerpo a cuerpo"}):
		errores.append("No reconoció una categoría directa de arma.")
	if not Resolver.es_arma({
		"tipo_objeto": {"categoria_canonica": "arma"}
	}):
		errores.append("No reconoció la categoría canónica del tipo enlazado.")
	if not Resolver.es_arma({
		"tipo_objeto": {"plantilla": {"categoria": "arma especial"}}
	}):
		errores.append("No reconoció la categoría de la plantilla.")
	if Resolver.es_arma({"tipo": "consumible"}):
		errores.append("Clasificó un consumible como arma.")

	var herramienta := {"tipo": "herramienta"}
	if not Resolver.es_herramienta(herramienta):
		errores.append("No reconoció una herramienta.")
	if not Resolver.es_objeto_ataque(herramienta):
		errores.append("No reconoció la herramienta como objeto de ataque.")
	if Resolver.es_objeto_ataque({"tipo": "consumible"}):
		errores.append("Clasificó un consumible como objeto de ataque.")


func _probar_modo_ataque(errores: Array[String]) -> void:
	var proyectil_directo := {
		"categoria_canonica": "arma",
		"propiedades_game": {"modo_ataque": "proyectil"}
	}
	if Resolver.obtener_modo_ataque(proyectil_directo) != "distancia":
		errores.append("No detectó el modo proyectil en propiedades_game.")

	var arco_en_plantilla := {
		"tipo_objeto": {
			"categoria_canonica": "arma",
			"plantilla": {"categoria": "arco"}
		}
	}
	if Resolver.obtener_modo_ataque(arco_en_plantilla) != "distancia":
		errores.append("No detectó arco en la plantilla geométrica.")

	var arco_legacy := {
		"tipo": "arma",
		"familia_arma": "bow"
	}
	if Resolver.obtener_modo_ataque(arco_legacy) != "distancia":
		errores.append("No detectó la etiqueta legacy bow.")

	var arco_tipo_catalogo := {
		"tipo": "arma",
		"nombre": "Arco Aoris",
		"tipo_objeto": {
			"clave": "arco",
			"nombre_humano": "Arco"
		}
	}
	if Resolver.obtener_modo_ataque(arco_tipo_catalogo) != "distancia":
		errores.append("No detectó el arco mediante la clave y nombre humano del tipo de catálogo.")

	var arco_solo_nombre := {
		"tipo": "arma",
		"nombre": "Arco de prueba"
	}
	if Resolver.obtener_modo_ataque(arco_solo_nombre) != "distancia":
		errores.append("No detectó un arco identificado por el nombre del objeto.")

	if Resolver.obtener_modo_ataque({"tipo": "arma", "categoria": "espada"}) != "cuerpo":
		errores.append("Una espada no conservó el modo cuerpo a cuerpo por defecto.")


func _probar_propiedades(errores: Array[String]) -> void:
	var objeto := {
		"propiedades_game": {
			"danio": 14,
			"alcance": 72.0,
			"ancho_ataque": 36
		}
	}
	if Resolver.obtener_danio_arma(objeto, 8) != 14:
		errores.append("No leyó el daño numérico del objeto.")
	if not is_equal_approx(Resolver.obtener_alcance_arma(objeto, 64.0), 72.0):
		errores.append("No leyó el alcance del objeto.")
	if not is_equal_approx(Resolver.obtener_ancho_ataque(objeto, 48.0), 36.0):
		errores.append("No leyó el ancho de ataque del objeto.")
	if not is_equal_approx(Resolver.obtener_float_propiedad(objeto, "alcance", 64.0), 72.0):
		errores.append("La lectura genérica de propiedades no conservó el valor.")

	var valores_invalidos := {
		"propiedades_game": {
			"danio": "alto",
			"alcance": "largo",
			"ancho_ataque": -5
		}
	}
	if Resolver.obtener_danio_arma(valores_invalidos, 9) != 9:
		errores.append("No aplicó el daño por defecto cuando el dato no es numérico.")
	if not is_equal_approx(Resolver.obtener_alcance_arma(valores_invalidos, 64.0), 64.0):
		errores.append("No aplicó el alcance por defecto ante datos inválidos.")
	if not is_equal_approx(Resolver.obtener_ancho_ataque(valores_invalidos, 48.0), 0.0):
		errores.append("No limitó a cero el ancho negativo, igual que la implementación anterior.")

	if not Resolver.obtener_propiedades_game({"propiedades_game": []}).is_empty():
		errores.append("Aceptó propiedades_game con un tipo distinto de Dictionary.")
