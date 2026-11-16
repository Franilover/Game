extends RefCounted
class_name NPCVoiceProfile

## Ajustes puntuales de expresión. Cada personaje conserva su propio registro:
## el perfil evita corregir a todos hacia la misma voz o imponer modismos.

static func adaptar(texto_original: String, nombre_personaje: String) -> String:
	var texto := texto_original
	var comunes: Array = [
		["podremos conversar", "podemos hablar"],
		["podemos conversar", "podemos hablar"],
		["en este momento", "ahora"],
		["por el momento", "por ahora"],
		["si necesitas", "si te hace falta"],
		["Si necesitas", "Si te hace falta"]
	]
	for par in comunes:
		texto = texto.replace(str(par[0]), str(par[1]))

	var propios: Dictionary = {
		"elian": [
			["Me alegra que hayas venido", "Qué bueno que viniste"],
			["Me alegra verte", "Qué bueno verte"],
			["La panadería suele estar más tranquila", "A esta hora la panadería está más tranquila"],
			["¡Buenos días! El horno lleva un rato encendido", "¡Hola! El horno lleva un buen rato prendido"],
			["¿Buscabas pan o solo querías saludar?", "¿Venías por pan o pasaste a saludar?"],
			["dime qué necesitas", "cuéntame qué andas buscando"]
		],
		"bruna": [
			["No fabrico piezas a ciegas", "No hago piezas sin saber para qué van"],
			["Cuidado con el paso", "Ojo dónde pisas"],
			["Necesito mantener el ritmo", "No puedo perder el ritmo"],
			["cuando termine esta pieza", "apenas termine esta pieza"]
		],
		"darven": [
			["Este acceso se mantiene vigilado", "Estoy vigilando este acceso"],
			["Alto. Este acceso se mantiene vigilado por orden de la guardia.", "Alto. Este acceso está bajo vigilancia de la guardia."],
			["Si es importante, búscame allí", "Si es urgente, búscame allá"],
			["No puedo abandonar mi recorrido", "No puedo dejar la ronda ahora"]
		],
		"saira": [
			["Si buscas algo concreto", "Si andas buscando algo en particular"],
			["quizá pueda conseguirlo", "a lo mejor te lo puedo conseguir"],
			["podemos ponernos al día", "nos ponemos al día"]
		],
		"narel": [
			["Si tienes una observación concreta", "Si viste algo o se te ocurrió alguna idea"],
			["Un momento, estoy comparando", "Dame un segundo, estoy comparando"],
			["Entonces lo anotaré como un testimonio sin verificar, no como un fenómeno confirmado.", "Ya, lo voy a dejar anotado como algo que contaron, no como algo confirmado."],
			["No tengo una explicación segura", "Todavía no sé explicarlo"],
			["merece la pena", "vale la pena"]
		],
		"mara": [
			["No hace falta que sigas caminando para acompañarnos", "No tienes que seguir caminando sólo por hacernos compañía"],
			["Podemos quedarnos aquí.", "Si quieres, nos quedamos aquí."],
			["No hay ninguna prisa.", "No tenemos apuro."],
			["Te acompaño.", "Voy contigo."],
			["Por ahora eso me basta", "Por ahora está bien así"]
		],
		"ivo": [
			["Me gusta que me inviten", "Igual me gusta que me inviten"],
			["Se me acabó la energía antes de llegar a la otra punta de la plaza.", "Me quedé sin fuerzas antes de llegar al otro lado de la plaza."],
			["Trato hecho.", "Ya, trato."],
			["puedo ayudarte", "te puedo ayudar"],
			["tomarme las cosas con calma", "ir a mi ritmo"],
			["No significa que ya esté bien", "Tampoco es que ya esté recuperado del todo"]
		],
		"nima": [
			["No quiero inventar una explicación", "No quiero sacar conclusiones sin pruebas"],
			["Ivo, ¿te parece si anoto cuándo te cansas y qué estabas haciendo antes?", "Oye, Ivo, ¿te parece si anoto cuándo te cansas y qué estabas haciendo antes?"],
			["Sólo reunir observaciones y ver si aparece algún patrón.", "Quiero juntar observaciones y ver si aparece algún patrón."],
			["De acuerdo. Si sirve para entender qué me pasa, puedo ayudarte.", "Ya. Si sirve para entender qué me pasa, te ayudo."],
			["reunir observaciones", "juntar observaciones"],
			["¿Me acompañas?", "¿Vienes conmigo?"]
		]
	}
	var reemplazos: Array = propios.get(nombre_personaje.strip_edges().to_lower(), [])
	for par in reemplazos:
		texto = texto.replace(str(par[0]), str(par[1]))
	return texto
