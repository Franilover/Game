extends RefCounted
class_name CreatureUtilityAI


## Lee valores numéricos opcionales sin convertir cadenas u otros tipos por accidente.
static func leer_numero(configuracion: Dictionary, clave: String, defecto: float) -> float:
	var valor: Variant = configuracion.get(clave, defecto)
	if not (valor is int or valor is float):
		return defecto
	var numero := float(valor)
	return numero if is_finite(numero) else defecto


## Convierte una necesidad que superó su umbral en una urgencia comparable.
## El pequeño valor base hace que alcanzar el umbral ya sea una opción válida.
static func puntuar_urgencia(valor: float, umbral: float, peso: float = 1.0) -> float:
	var valor_seguro := clampf(valor, 0.0, 100.0)
	var umbral_seguro := clampf(umbral, 0.0, 100.0)
	var peso_seguro := maxf(peso, 0.0)
	if valor_seguro < umbral_seguro or peso_seguro <= 0.0:
		return 0.0
	var rango := maxf(100.0 - umbral_seguro, 0.001)
	var urgencia := 0.01 + (valor_seguro - umbral_seguro) / rango
	return clampf(urgencia, 0.0, 1.01) * peso_seguro


## Selecciona la acción con mayor puntuación. En empate conserva la primera
## entrada del diccionario para que la política sea determinista.
static func seleccionar_accion(puntuaciones: Dictionary, accion_respaldo: String = "") -> String:
	var seleccion := accion_respaldo
	var puntuacion_maxima := 0.0
	for clave_variant in puntuaciones:
		var valor: Variant = puntuaciones[clave_variant]
		if not (valor is int or valor is float):
			continue
		var puntuacion := maxf(float(valor), 0.0)
		if puntuacion > puntuacion_maxima:
			puntuacion_maxima = puntuacion
			seleccion = str(clave_variant)
	return seleccion
