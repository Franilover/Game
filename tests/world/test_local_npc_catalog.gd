extends Node

const MainScript = preload("res://scripts/world/main.gd")


func _ready() -> void:
	var errores: Array[String] = []
	var habitantes: Array[Dictionary] = MainScript.HABITANTES_LOCALES
	var claves_esperadas: Array[String] = ["mara", "ivo", "nima"]
	var claves_obtenidas: Array[String] = []

	for habitante in habitantes:
		var clave := str(habitante.get("clave", ""))
		claves_obtenidas.append(clave)
		if str(habitante.get("nombre", "")).is_empty():
			errores.append("Un habitante local no tiene nombre.")
		if str(habitante.get("hogar", "")).is_empty():
			errores.append("%s no tiene hogar." % clave)
		if (habitante.get("rutinas", []) as Array).is_empty():
			errores.append("%s no tiene rutinas." % clave)
		if str(habitante.get("personalidad", "")).is_empty():
			errores.append("%s no tiene perfil de personalidad." % clave)
		if str(habitante.get("historia", "")).is_empty():
			errores.append("%s no tiene historia local." % clave)

	claves_obtenidas.sort()
	claves_esperadas.sort()
	if claves_obtenidas != claves_esperadas:
		errores.append("El catálogo local debe conservar Mara, Ivo y Nima una sola vez.")

	if errores.is_empty():
		print("LocalNPCatalog: PASS")
		get_tree().quit(0)
		return

	for error in errores:
		push_error("LocalNPCatalog: FAIL: " + error)
	get_tree().quit(1)
