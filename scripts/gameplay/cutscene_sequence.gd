@tool
extends Resource
class_name CutsceneSequence

## Secuencia reutilizable y editable desde el Inspector de Godot.
## Cada paso utiliza el formato declarativo que interpreta CutsceneDirector.

@export var clave: String = ""
@export_multiline var descripcion: String = ""
@export_enum("planeada", "en_vivo") var modo: String = "planeada"
@export var pasos: Array[Dictionary] = []
@export var parametros_requeridos: PackedStringArray = []


func _es_parametro_dinamico(valor: Variant) -> bool:
	if not valor is String:
		return false
	var texto := str(valor)
	return texto.contains("{{") and texto.contains("}}")


func _campo_presente(datos: Dictionary, campo: String) -> bool:
	if not datos.has(campo):
		return false
	var valor: Variant = datos[campo]
	if _es_parametro_dinamico(valor):
		return true
	if valor is String:
		return not str(valor).strip_edges().is_empty()
	return valor != null


func _validar_accion_simultanea(accion: Dictionary, paso_indice: int, accion_indice: int) -> Array[String]:
	var errores: Array[String] = []
	var tipo_accion := str(accion.get("tipo", "")).strip_edges().to_lower()
	var prefijo := "Paso %d, acción %d" % [paso_indice + 1, accion_indice + 1]
	if tipo_accion not in ["gesto_npc", "mirar_npc"]:
		errores.append("%s: tipo simultáneo no compatible (%s)." % [prefijo, tipo_accion])
		return errores
	if not _campo_presente(accion, "npc"):
		errores.append("%s: falta identificar al NPC." % prefijo)
	if tipo_accion == "mirar_npc":
		if not _campo_presente(accion, "hacia_npc") and not accion.has("izquierda"):
			errores.append("%s: mirar_npc necesita hacia_npc o izquierda." % prefijo)
	elif accion.has("gesto"):
		var gesto := str(accion.get("gesto", "")).strip_edges().to_lower()
		if not _es_parametro_dinamico(accion.get("gesto")) and gesto not in [
			"asentir", "saludar", "trabajar", "sorpresa", "negar",
			"reir", "triste", "inquieto", "aplaudir", "encogerse", "acomodarse"
		]:
			errores.append("%s: gesto no reconocido (%s)." % [prefijo, gesto])
	return errores


func _recopilar_parametros(valor: Variant, encontrados: Dictionary) -> void:
	if valor is String:
		var texto := str(valor)
		var cursor := 0
		while cursor < texto.length():
			var inicio := texto.find("{{", cursor)
			if inicio < 0:
				break
			var fin := texto.find("}}", inicio + 2)
			if fin < 0:
				break
			var nombre := texto.substr(inicio + 2, fin - inicio - 2).strip_edges()
			if not nombre.is_empty():
				encontrados[nombre] = true
			cursor = fin + 2
	elif valor is Dictionary:
		for elemento in valor.values():
			_recopilar_parametros(elemento, encontrados)
	elif valor is Array:
		for elemento in valor:
			_recopilar_parametros(elemento, encontrados)


func validar() -> Array[String]:
	var errores: Array[String] = []
	if clave.strip_edges().is_empty():
		errores.append("La secuencia necesita una clave.")
	if pasos.is_empty():
		errores.append("La secuencia no contiene pasos.")
	if modo not in ["planeada", "en_vivo"]:
		errores.append("El modo debe ser planeada o en_vivo.")

	var parametros_declarados: Dictionary = {}
	for nombre in parametros_requeridos:
		parametros_declarados[str(nombre)] = true
	var parametros_usados: Dictionary = {}
	_recopilar_parametros(clave, parametros_usados)
	_recopilar_parametros(pasos, parametros_usados)
	for nombre in parametros_usados:
		if not parametros_declarados.has(nombre):
			errores.append("El parámetro {{%s}} se usa pero no está declarado en parametros_requeridos." % nombre)

	var tipos_validos := [
		"dialogo", "esperar", "camara", "gesto_npc",
		"acciones_simultaneas", "mirar_npc", "orientar_grupo", "gesto_grupo", "fundido",
		"temblor_camara", "preparar_npc", "fijar_npc",
		"ruta_npc", "mover_jugador", "mover_npc",
		"evento", "notificacion"
	]
	for indice in range(pasos.size()):
		var paso: Dictionary = pasos[indice]
		var tipo := str(paso.get("tipo", "")).strip_edges().to_lower()
		var numero_paso := indice + 1
		if tipo.is_empty() or tipo not in tipos_validos:
			errores.append("Paso %d: tipo vacío o no reconocido (%s)." % [numero_paso, tipo])
			continue

		match tipo:
			"gesto_npc":
				if not _campo_presente(paso, "npc"):
					errores.append("Paso %d: gesto_npc necesita un NPC." % numero_paso)
				var gesto := str(paso.get("gesto", "asentir")).strip_edges().to_lower()
				if paso.has("gesto") and not _es_parametro_dinamico(paso.get("gesto")) and gesto not in [
					"asentir", "saludar", "trabajar", "sorpresa", "negar",
					"reir", "triste", "inquieto", "aplaudir", "encogerse", "acomodarse"
				]:
					errores.append("Paso %d: gesto no reconocido (%s)." % [numero_paso, gesto])
			"mirar_npc":
				if not _campo_presente(paso, "npc"):
					errores.append("Paso %d: mirar_npc necesita un NPC." % numero_paso)
				if not _campo_presente(paso, "hacia_npc") and not paso.has("izquierda"):
					errores.append("Paso %d: mirar_npc necesita hacia_npc o izquierda." % numero_paso)
			"orientar_grupo":
				if not _campo_presente(paso, "hacia_npc"):
					errores.append("Paso %d: orientar_grupo necesita hacia_npc." % numero_paso)
				var orientados: Variant = paso.get("npcs", [])
				if not orientados is Array or (orientados as Array).is_empty():
					errores.append("Paso %d: orientar_grupo necesita una lista de NPC." % numero_paso)
			"gesto_grupo":
				var participantes: Variant = paso.get("npcs", [])
				if not participantes is Array or (participantes as Array).is_empty():
					errores.append("Paso %d: gesto_grupo necesita una lista de NPC." % numero_paso)
				var gesto_grupo := str(paso.get("gesto", "asentir")).strip_edges().to_lower()
				if not _es_parametro_dinamico(paso.get("gesto", "")) and gesto_grupo not in [
					"asentir", "saludar", "trabajar", "sorpresa", "negar",
					"reir", "triste", "inquieto", "aplaudir", "encogerse", "acomodarse"
				]:
					errores.append("Paso %d: gesto grupal no reconocido (%s)." % [numero_paso, gesto_grupo])
			"acciones_simultaneas":
				var acciones_variant: Variant = paso.get("acciones", [])
				if not acciones_variant is Array:
					errores.append("Paso %d: acciones_simultaneas necesita una lista." % numero_paso)
					continue
				var acciones := acciones_variant as Array
				if acciones.is_empty():
					errores.append("Paso %d: acciones_simultaneas no puede estar vacía." % numero_paso)
					continue
				for accion_indice in range(acciones.size()):
					var accion_variant: Variant = acciones[accion_indice]
					if not accion_variant is Dictionary:
						errores.append("Paso %d: la acción %d no es un Dictionary." % [numero_paso, accion_indice + 1])
						continue
					errores.append_array(_validar_accion_simultanea(accion_variant as Dictionary, indice, accion_indice))
			"preparar_npc", "fijar_npc":
				if not _campo_presente(paso, "npc"):
					errores.append("Paso %d: %s necesita un NPC." % [numero_paso, tipo])
			"ruta_npc", "mover_npc":
				if not _campo_presente(paso, "npc"):
					errores.append("Paso %d: %s necesita un NPC." % [numero_paso, tipo])
				var tiene_puntos := paso.get("puntos", []) is Array and not (paso.get("puntos", []) as Array).is_empty()
				var tiene_coordenadas := _campo_presente(paso, "x") and _campo_presente(paso, "y")
				if not tiene_puntos and not tiene_coordenadas:
					errores.append("Paso %d: %s necesita puntos o coordenadas x/y." % [numero_paso, tipo])
			"mover_jugador":
				if not _campo_presente(paso, "x") or not _campo_presente(paso, "y"):
					errores.append("Paso %d: mover_jugador necesita coordenadas x/y." % numero_paso)
			"esperar":
				if paso.has("variacion") and not _es_parametro_dinamico(paso.get("variacion")):
					var variacion: Variant = paso.get("variacion")
					if (variacion is int or variacion is float) and float(variacion) < 0.0:
						errores.append("Paso %d: la variación de espera no puede ser negativa." % numero_paso)
			"fundido":
				var modo_fundido := str(paso.get("modo", "entrada")).strip_edges().to_lower()
				if paso.has("modo") and not _es_parametro_dinamico(paso.get("modo")) and modo_fundido not in [
					"entrada", "salida", "oscurecer", "cerrar"
				]:
					errores.append("Paso %d: modo de fundido no reconocido (%s)." % [numero_paso, modo_fundido])
			"evento":
				if not _campo_presente(paso, "clave"):
					errores.append("Paso %d: evento necesita una clave." % numero_paso)
			"notificacion":
				if not _campo_presente(paso, "texto"):
					errores.append("Paso %d: notificacion necesita texto." % numero_paso)
			"dialogo":
				var datos_variant: Variant = paso.get("datos", paso)
				if not datos_variant is Dictionary:
					errores.append("Paso %d: los datos del diálogo deben ser un Dictionary." % numero_paso)
	return errores
