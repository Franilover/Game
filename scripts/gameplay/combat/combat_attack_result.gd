extends RefCounted
class_name CombatAttackResult

## Resultado explícito de una solicitud de ataque con arma.
## La aceptación y el contacto no implican necesariamente daño a la salud.

var solicitud_aceptada: bool = false
var contacto_registrado: bool = false
var danio_aplicado: bool = false
var motivo_rechazo: StringName = &""


static func rechazado(motivo: StringName) -> CombatAttackResult:
	var resultado := CombatAttackResult.new()
	resultado.motivo_rechazo = motivo
	return resultado


static func aceptado(
	contacto: bool,
	danio: bool
) -> CombatAttackResult:
	var resultado := CombatAttackResult.new()
	resultado.solicitud_aceptada = true
	resultado.contacto_registrado = contacto
	resultado.danio_aplicado = danio
	return resultado
