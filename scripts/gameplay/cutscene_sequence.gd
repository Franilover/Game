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


func validar() -> Array[String]:
	var errores: Array[String] = []
	if clave.strip_edges().is_empty():
		errores.append("La secuencia necesita una clave.")
	if pasos.is_empty():
		errores.append("La secuencia no contiene pasos.")

	var tipos_validos := [
		"dialogo", "esperar", "camara", "gesto_npc",
		"acciones_simultaneas", "mirar_npc", "fundido",
		"temblor_camara", "preparar_npc", "fijar_npc",
		"ruta_npc", "mover_jugador", "mover_npc",
		"evento", "notificacion"
	]
	for indice in range(pasos.size()):
		var paso: Dictionary = pasos[indice]
		var tipo := str(paso.get("tipo", "")).strip_edges().to_lower()
		if tipo.is_empty() or not tipos_validos.has(tipo):
			errores.append("Paso %d: tipo vacío o no reconocido (%s)." % [indice + 1, tipo])
			continue
		if tipo == "acciones_simultaneas":
			var acciones_variant: Variant = paso.get("acciones", [])
			if not acciones_variant is Array:
				errores.append("Paso %d: acciones_simultaneas necesita una lista." % (indice + 1))
				continue
			var acciones: Array = acciones_variant
			if acciones.is_empty():
				errores.append("Paso %d: acciones_simultaneas no puede estar vacía." % (indice + 1))
				continue
			for accion_indice in range(acciones.size()):
				var accion_variant: Variant = acciones[accion_indice]
				if not accion_variant is Dictionary:
					errores.append("Paso %d: la acción %d no es un Dictionary." % [indice + 1, accion_indice + 1])
					continue
				var accion: Dictionary = accion_variant
				var tipo_accion := str(accion.get("tipo", "")).strip_edges().to_lower()
				if tipo_accion not in ["gesto_npc", "mirar_npc"]:
					errores.append("Paso %d: acción simultánea no compatible (%s)." % [indice + 1, tipo_accion])
	return errores
