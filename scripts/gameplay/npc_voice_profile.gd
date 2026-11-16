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

## Ajusta únicamente los intercambios sociales ambientales. La voz cambia la
## forma de decir algo, no el contenido ni la personalidad establecida.
static func adaptar_social(texto_original: String, nombre_personaje: String, tono: String = "cordial") -> String:
	var texto := texto_original
	var nombre := nombre_personaje.strip_edges().to_lower()
	var aperturas := {
		"elian": ["¿Tienes un momento?", "¿Tienes un ratito?"],
		"bruna": ["¿Tienes un momento?", "¿Qué pasa? Tengo un momento."],
		"darven": ["¿Tienes un momento?", "¿Necesitas hablar?"],
		"saira": ["¿Tienes un momento?", "¿Tienes un minuto? Te quería comentar algo."],
		"narel": ["¿Tienes un momento?", "Quería preguntarte algo, si puedes."],
		"mara": ["¿Tienes un momento?", "¿Podemos hablar un momento?"],
		"ivo": ["¿Tienes un momento?", "¿Tienes un minuto? No te quito toda la tarde."],
		"nima": ["¿Tienes un momento?", "Oye, ¿te puedo preguntar algo?"]
	}
	var apertura: Array = aperturas.get(nombre, [])
	if apertura.size() > 1:
		texto = texto.replace(str(apertura[0]), str(apertura[1]))
	var expresiones: Dictionary = {
		"elian": [["Está bien.", "Claro, cuenta conmigo."], ["Gracias.", "Gracias por venir a contármelo."]],
		"bruna": [["Me parece bien.", "Sí, eso sirve."], ["No hay problema.", "No debería ser complicado."]],
		"darven": [["Me parece bien.", "De acuerdo. Lo tendré presente."], ["Gracias.", "Gracias por avisarme."]],
		"saira": [["Me parece bien.", "Podemos arreglarlo."], ["No lo sé.", "No sabría decirte todavía."]],
		"narel": [["No lo sé.", "Todavía no tengo cómo asegurarlo."], ["Me parece bien.", "Podemos comprobarlo."]],
		"mara": [["Gracias.", "Gracias por decírmelo."], ["Está bien.", "Sí, puedo hacerlo."]],
		"ivo": [["Me parece bien.", "Ya, me parece."], ["No hay problema.", "No te preocupes, lo vemos."]],
		"nima": [["No lo sé.", "Todavía no lo sé. Habría que revisarlo."], ["Me parece bien.", "Sí, probemos."]]
	}
	var reemplazos: Array = expresiones.get(nombre, [])
	for par in reemplazos:
		texto = texto.replace(str(par[0]), str(par[1]))
	if tono == "cercana":
		texto = texto.replace("Gracias.", "Gracias, de verdad.")
	elif tono == "tensa":
		texto = texto.replace("Me parece bien.", "Está bien. Hablemos.")
	return texto


## Tres variantes por motivo; el índice se calcula con el historial de la pareja
## para que sus encuentros no repitan siempre el mismo intercambio.
static func construir_dialogo_social(
	nombre_a: String,
	nombre_b: String,
	tipo: String,
	indice: int,
	tono: String = "cordial",
	detalle: String = "",
	antecedente: String = ""
) -> Array[Dictionary]:
	var bancos: Dictionary = {
		"cumplir_promesa": [
			["Quería contarte que ya hice lo que te había dicho.", "¿Pudiste resolverlo al final?", "Sí. Prefería venir a decírtelo en persona.", "Gracias por acordarte. Me alegra que haya salido bien."],
			["Me quedó dando vueltas lo que te prometí. Ya está resuelto.", "¿En serio? Pensé que todavía te faltaría tiempo.", "Me tomó un poco más de lo que esperaba, pero lo terminé.", "Bueno, me deja tranquilo saberlo. Gracias por cumplir."],
			["Antes de que se me pase, quería decirte que cumplí con aquello.", "Qué bueno. ¿Tuviste algún problema?", "Un par de detalles, pero nada que no pudiera solucionar.", "Igual valoro que hayas vuelto para contármelo."]
		],
		"resolver_asunto": [
			["Me acordé de lo que me contaste. ¿Cómo va eso?", "Sigue complicado. No he encontrado una buena solución.", "Si quieres, podemos revisarlo juntos y ver qué falta.", "Me ayudaría bastante. Gracias por no dejarlo pasar."],
			["Oye, ¿pudiste avanzar con el problema que tenías?", "Un poco, aunque todavía me queda trabajo.", "Podemos pensar otra forma de hacerlo. No tienes que resolverlo todo ahora.", "Eso quería escuchar. Me estaba costando encontrar por dónde seguir."],
			["Quería saber si se resolvió aquello que te preocupaba.", "Todavía no del todo. Hay una parte que no consigo arreglar.", "Entonces empecemos por esa parte. Quizá sea más sencillo de lo que parece.", "De acuerdo. Te muestro lo que he intentado."]
		],
		"compartir_noticia": [
			["¿Has oído algo sobre lo que pasó estos días?", "No mucho. ¿Qué sabes?", "Me llegó este aviso: {detalle}. No sé si ya lo confirmaron.", "Gracias por contármelo. Voy a esperar a tener más información."],
			["Tengo algo que contarte. ¿Has pasado por la plaza últimamente?", "No desde ayer. ¿Ocurrió algo?", "Se está comentando esto: {detalle}. Por ahora lo tomaría con cautela.", "Haré eso. Prefiero saber de dónde viene antes de darlo por cierto."],
			["Me encontré con alguien que mencionó algo interesante.", "Ahora me dio curiosidad. ¿Qué te dijo?", "Habló de esto: {detalle}. No pude comprobarlo todavía.", "Bueno, al menos ya sabemos qué conviene averiguar."]
		],
		"resolver_desacuerdo": [
			["Quería hablar de lo que pasó entre nosotros. No me gustó cómo terminó.", "A mí tampoco. Me fui bastante molesto.", "No espero que estemos de acuerdo en todo, pero sí que podamos escucharnos.", "Está bien. Puedo intentar entender mejor lo que quisiste decir."],
			["¿Podemos aclarar lo del otro día? Me quedé pensando en eso.", "Yo también. Creo que entendimos cosas distintas.", "Puede ser. Prefiero preguntarte antes que seguir suponiendo.", "Y yo debería haberte explicado mejor lo que me molestó."],
			["No quiero que sigamos evitando el tema.", "No lo estaba evitando. Sólo necesitaba un poco de tiempo.", "Lo entiendo. Cuando quieras, podemos hablarlo sin apurarnos.", "Podemos hacerlo ahora. Creo que ya estoy más tranquilo."]
		],
		"visitar_amigo": [
			["Hace días que no coincidíamos. ¿Cómo has estado?", "Con varias cosas, pero bien. ¿Y tú?", "Bien. Me acordé de algunas de nuestras conversaciones.", "Yo también. Siempre terminamos hablando de algo distinto."],
			["Pasaba por aquí y pensé que hacía tiempo que no hablábamos.", "Es verdad. Últimamente casi siempre andamos en cosas distintas.", "No hace falta tener un motivo especial para venir a saludar.", "Me alegra que hayas pasado. Podríamos hacerlo más seguido."],
			["¿Cómo te ha tratado la semana? Hace rato que no sabía de ti.", "Ha sido movida, aunque no todo ha salido mal.", "Si tienes tiempo, me gustaría que me contaras un poco más.", "Claro. Podemos sentarnos un momento."]
		],
		"buscar_compania": [
			["¿Tienes un momento? Me apetecía conversar un rato.", "Sí, justo tengo un descanso. ¿Qué tal va todo?", "Bastante bien. A veces viene bien parar y hablar de otra cosa.", "Sí. Uno se pasa el día de un lado a otro y casi no se da cuenta."],
			["Oye, ¿te parece si nos quedamos un rato por aquí?", "Por mí está bien. No tenía nada urgente ahora.", "Mejor. No quería pasar toda la tarde sin hablar con nadie.", "Entonces aprovechemos el rato. ¿Qué has hecho hoy?"],
			["Qué bueno encontrarte. ¿Tienes tiempo para charlar?", "Un poco, sí. ¿Pasó algo?", "Nada en particular. Sólo quería compañía un rato.", "Me parece bien. A mí también me venía bien despejarme."]
		]
	}
	var variantes: Array = bancos.get(tipo, bancos["buscar_compania"])
	var ajuste := 0
	if tono == "cercana":
		ajuste = 1
	elif tono == "tensa":
		ajuste = 2
	var seleccion := variantes[posmod(indice + ajuste, variantes.size())] as Array
	var resultado: Array[Dictionary] = []
	for i in range(seleccion.size()):
		var hablante := nombre_a if i % 2 == 0 else nombre_b
		var texto := str(seleccion[i])
		if texto.contains("{detalle}"):
			var dato := detalle.strip_edges()
			if dato.is_empty():
				dato = "algo que pasó cerca de aquí"
			texto = texto.replace("{detalle}", dato)
		resultado.append({
			"npc": hablante.strip_edges().to_lower(),
			"texto": adaptar_social(texto, hablante, tono)
		})
	if not antecedente.strip_edges().is_empty() and tipo in ["visitar_amigo", "buscar_compania"]:
		resultado[0]["texto"] = antecedente.strip_edges()
		resultado[0]["texto"] = adaptar_social(str(resultado[0]["texto"]), nombre_a, tono)
	return resultado

