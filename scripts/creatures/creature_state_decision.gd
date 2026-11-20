extends RefCounted
class_name CreatureStateDecision


enum Decision {
	SIN_CAMBIO,
	ATACAR,
	HUIR,
	PERSEGUIR,
	INVESTIGAR
}


## Traduce la respuesta de la especie a una intención de estado.
## No ejecuta movimiento, combate ni efectos; esas responsabilidades
## permanecen en CreatureAI.
static func resolver(
	respuesta: String,
	permitir_perseguir: bool = true,
	permitir_investigar: bool = true
) -> Decision:
	match respuesta.strip_edges().to_lower():
		"atacar":
			return Decision.ATACAR
		"huir":
			return Decision.HUIR
		"perseguir":
			return Decision.PERSEGUIR if permitir_perseguir else Decision.SIN_CAMBIO
		"investigar":
			return Decision.INVESTIGAR if permitir_investigar else Decision.SIN_CAMBIO
		_:
			return Decision.SIN_CAMBIO
