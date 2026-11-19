extends RefCounted
class_name NPCScheduleRules

## Convierte una hora HH:MM a minutos desde medianoche.
## Devuelve -1 cuando el formato o sus componentes no son válidos.
static func hora_a_minutos(valor: Variant) -> int:
	var partes := str(valor).strip_edges().split(":")
	if partes.size() < 2:
		return -1
	if not partes[0].is_valid_int() or not partes[1].is_valid_int():
		return -1
	var hora := int(partes[0])
	var minuto := int(partes[1])
	if hora < 0 or hora > 23 or minuto < 0 or minuto > 59:
		return -1
	return hora * 60 + minuto


## Comprueba si el día aparece en la lista recibida desde WorldData.
## Acepta int, float y String numérico porque los datos JSON/RPC pueden
## representar el mismo valor con tipos numéricos distintos.
## Una lista vacía o ausente significa que la rutina aplica todos los días.
static func coincide_dia(dias_variant: Variant, dia: int) -> bool:
	if not dias_variant is Array or (dias_variant as Array).is_empty():
		return true

	for dia_variant in dias_variant as Array:
		if dia_variant is int or dia_variant is float:
			if is_equal_approx(float(dia_variant), float(dia)):
				return true
		elif dia_variant is String:
			var dia_texto := str(dia_variant).strip_edges()
			if dia_texto.is_valid_int() and int(dia_texto) == dia:
				return true
	return false
