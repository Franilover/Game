extends RefCounted
class_name NPCVoiceProfile

## Ajustes pequeños de registro para que las voces suenen conversadas.
## No agrega información ni cambia decisiones: sólo acerca la frase al habla cotidiana chilena.

static func adaptar(texto_original: String, nombre_personaje: String) -> String:
	var texto := texto_original
	var nombre := nombre_personaje.strip_edges().to_lower()
	var comunes: Array = [
		["Me alegra que hayas venido", "Qué bueno que viniste"],
		["Me alegra verte", "Qué bueno verte"],
		["me alegra encontrarte", "qué bueno encontrarte"],
		["podremos conversar", "podemos hablar"],
		["podemos conversar", "podemos hablar"],
		["conversar un momento", "hablar un rato"],
		["conversar un poco", "hablar un rato"],
		["¿Qué te interesa encontrar?", "¿Qué andas buscando?"],
		["¿Te apetece", "¿Te tinca"],
		["Debo ", "Tengo que "],
		["debo ", "tengo que "],
		["procuraré ", "voy a tratar de "],
		["procurar ", "tratar de "],
		["en este momento", "ahora"],
		["por el momento", "por ahora"],
		["si necesitas", "si te hace falta"],
		["Si necesitas", "Si te hace falta"]
	]
	for par in comunes:
		texto = texto.replace(str(par[0]), str(par[1]))

	var propios: Dictionary = {
		"elian": [
			["La panadería suele estar más tranquila", "A esta hora la panadería está más tranquila"],
			["¿Buscabas pan o solo querías saludar?", "¿Venías por pan o pasaste a saludar?"],
			["dime qué necesitas", "cuéntame qué andas buscando"]
		],
		"bruna": [
			["No fabrico piezas a ciegas", "No hago piezas sin saber para qué van"],
			["Necesito mantener el ritmo", "Tengo que mantener el ritmo"],
			["cuando termine esta pieza", "apenas termine esta pieza"]
		],
		"darven": [
			["Este acceso se mantiene vigilado", "Estoy vigilando este acceso"],
			["Si es importante, búscame allí", "Si es urgente, búscame allá"],
			["No puedo abandonar mi recorrido", "No puedo dejar la ronda botada"]
		],
		"saira": [
			["Si buscas algo concreto", "Si andas buscando algo en particular"],
			["quizá pueda conseguirlo", "a lo mejor te lo puedo conseguir"],
			["podemos ponernos al día", "nos ponemos al día"]
		],
		"narel": [
			["Si tienes una observación concreta", "Si viste algo o se te ocurrió alguna idea"],
			["No tengo una explicación segura", "Todavía no tengo clara la explicación"],
			["merece la pena", "vale la pena"]
		],
		"mara": [
			["No hace falta que sigas caminando para acompañarnos", "No tienes que seguir caminando sólo para hacernos compañía"],
			["Por ahora eso me basta", "Por ahora estoy bien así"]
		],
		"ivo": [
			["Me gusta que me inviten", "Igual me gusta que me inviten"],
			["tomarme las cosas con calma", "ir a mi ritmo"],
			["No significa que ya esté bien", "Tampoco es que ya esté perfecto"]
		],
		"nima": [
			["No quiero inventar una explicación", "No quiero sacar conclusiones porque sí"],
			["reunir observaciones", "juntar observaciones"],
			["¿Me acompañas?", "¿Vienes conmigo?"]
		]
	}
	var reemplazos: Array = propios.get(nombre, [])
	for par in reemplazos:
		texto = texto.replace(str(par[0]), str(par[1]))
	return texto
