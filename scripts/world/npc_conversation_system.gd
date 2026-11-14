extends Node
class_name NPCConversationSystem

const INTERVALO_BUSQUEDA := 0.5
const DISTANCIA_ENTRE_NPC := 180.0
const DISTANCIA_JUGADOR := 220.0
const DURACION_LINEA := 3.2
const FONT_PIXEL: Font = preload("res://assets/fonts/Pixelgrafia.ttf")

# Conversaciones ambientales vinculadas al incidente de la carreta.
# Cada pareja conserva su propia conversación; sólo se muestran después
# de completar la misión que establece el acontecimiento.
const CONVERSACIONES: Array[Dictionary] = [
	{
		"clave": "elian_saira_hornada",
		"tono_relacion": "cercana",
		"efectos_etapa": [{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Saira y Elian acuerdan coordinar los avisos de entrega."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"La entrega llega a tiempo y ambos comparten el resultado."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Su coordinación continúa incluso cuando no hay problemas con la ruta."}],
		"npc_a": "elian",
		"npc_b": "saira",
		"lineas": [
			{"npc":"saira","texto":"Me escribió el conductor. Dice que la rueda aguantó bien el resto del trayecto."},
			{"npc":"elian","texto":"Me alegra. La próxima vez espero tener los ingredientes antes de encender el horno."},
			{"npc":"saira","texto":"Puedo avisarte cuando el cargamento salga. Así no tendrás que calcularlo a ciegas."},
			{"npc":"elian","texto":"Eso me ayudaría bastante. Y si pasas temprano, te guardaré pan recién hecho."}
		],
		"lineas_alternativas": [
			{"npc":"elian","texto":"La gente pregunta si la harina volverá a llegar con retraso."},
			{"npc":"saira","texto":"Les dije que el aviso de ruta ya está circulando. No puedo prometer que no haya demoras, pero sí avisar a tiempo."},
			{"npc":"elian","texto":"Eso es suficiente para organizar los pedidos. Prefiero ajustar el trabajo antes que hacer esperar a todos."},
			{"npc":"saira","texto":"Entonces la próxima entrega te encontrará preparado."}
		],
		"lineas_siguientes": [{"npc":"saira","texto":"El conductor volvió a pasar por Torres. Esta vez llegó con tiempo de sobra."},{"npc":"elian","texto":"Y yo pude preparar la hornada sin cambiar la receta a mitad del trabajo."},{"npc":"saira","texto":"Parece que los avisos y la revisión del camino sirvieron para algo."},{"npc":"elian","texto":"Sí. Cuando vuelva a llegar harina, apartaré una parte para quienes ayudaron."}],
		"lineas_tercera_etapa": [{"npc":"saira","texto":"Ahora puedo avisarte de las entregas con más precisión. Ya sé cuánto margen necesitas."},{"npc":"elian","texto":"Y yo puedo organizar los pedidos sin cambiar todo a última hora. Nos entendimos bien."},{"npc":"saira","texto":"La próxima vez que pase por Torres, no vendré sólo por trabajo."},{"npc":"elian","texto":"Entonces dejaré algo preparado para compartir. No hace falta que traigas noticias cada vez."}],
		"lineas_tercera_tension": [{"npc":"darven","texto":"El registro sigue incompleto. No puedo dar por resuelto el tramo sólo porque ahora parezca firme."},{"npc":"bruna","texto":"Y yo no voy a repetir una inspección cada vez que alguien dude de las piezas."},{"npc":"darven","texto":"No cuestiono tu trabajo. Necesito que el informe y la reparación coincidan."},{"npc":"bruna","texto":"Entonces revisemos ambos juntos. Pero esta vez no decidas antes de mirar."}]
	},
	{
		"clave": "bruna_darven_camino",
		"tono_relacion": "tensa",
		"efectos_etapa": [{"confianza":0.0,"tension":1.0,"colaboracion":0.5,"resumen":"Bruna insiste en reparar el tramo y Darven registra el problema."},{"confianza":0.5,"tension":-1.5,"colaboracion":1.0,"resumen":"La revisión conjunta reduce sus diferencias."},{"confianza":0.5,"tension":-1.0,"colaboracion":0.5,"resumen":"Ambos reconocen el valor del trabajo del otro."}],
		"npc_a": "bruna",
		"npc_b": "darven",
		"lineas": [
			{"npc":"darven","texto":"He revisado el tramo que señalaste. La parte más irregular sigue necesitando mantenimiento."},
			{"npc":"bruna","texto":"Entonces no basta con llevar una rueda de repuesto. Hay que corregir el paso."},
			{"npc":"darven","texto":"Ya lo incluí en la revisión de la ruta. No quiero que otra carreta tenga que detenerse allí."},
			{"npc":"bruna","texto":"Bien. Cuando sepas cuándo van a repararlo, avísame. Puedo preparar las piezas necesarias."}
		],
		"lineas_alternativas": [
			{"npc":"darven","texto":"El equipo de mantenimiento podrá revisar el tramo mañana por la mañana."},
			{"npc":"bruna","texto":"Dejaré las piezas preparadas hoy. No quiero que pierdan tiempo esperando material."},
			{"npc":"darven","texto":"Me encargaré de que el acceso quede libre mientras trabajan."},
			{"npc":"bruna","texto":"Bien. Así cada cual hace su parte y terminamos antes."}
		],
		"lineas_siguientes": [{"npc":"bruna","texto":"El tramo ya está más firme. Revisé las piedras después del mantenimiento."},{"npc":"darven","texto":"El equipo terminó ayer. También dejaron libre el paso para las carretas."},{"npc":"bruna","texto":"Bien. Haré una última comprobación del eje de prueba antes de darlo por resuelto."},{"npc":"darven","texto":"Avísame si encuentras algo. Esta vez podremos corregirlo antes de que cause otro retraso."}],
		"lineas_tercera_etapa": [{"npc":"darven","texto":"El registro del camino queda actualizado. Si vuelve a deteriorarse, sabremos dónde empezar."},{"npc":"bruna","texto":"Y yo conservaré las medidas de las piezas. No tendremos que improvisar otra vez."},{"npc":"darven","texto":"Admito que tu insistencia ayudó a que revisáramos el tramo completo."},{"npc":"bruna","texto":"Y yo admito que mantener el paso vigilado mientras trabajaban fue útil. No estuvo mal coordinado."}]
	},
	{
		"clave": "bruna_narel_evidencia",
		"tono_relacion": "cercana",
		"efectos_etapa": [{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Bruna y Narel acuerdan contrastar mediciones y observaciones."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Separan las causas del daño con mejores evidencias."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Conservan un registro compartido para futuras revisiones."}],
		"npc_a": "bruna",
		"npc_b": "narel",
		"lineas": [
			{"npc":"narel","texto":"Tus observaciones sobre el eje coinciden con las marcas que registré en el camino."},
			{"npc":"bruna","texto":"No necesitabas una teoría complicada. La carga estaba mal distribuida y el terreno terminó de hacer el resto."},
			{"npc":"narel","texto":"Lo sé. Por eso separé las marcas observadas de la explicación que propuse."},
			{"npc":"bruna","texto":"Eso está bien. Si cambian las condiciones, revisamos la conclusión. No antes."}
		],
		"lineas_alternativas": [
			{"npc":"bruna","texto":"¿Terminaste de ordenar las notas de la carreta?"},
			{"npc":"narel","texto":"Sí. Añadí una sección para separar las observaciones nuevas de las anteriores."},
			{"npc":"bruna","texto":"Eso evitará que alguien confunda una medición vieja con el estado actual."},
			{"npc":"narel","texto":"Exactamente. Una anotación útil también debe indicar cuándo dejó de ser válida."}
		],
		"lineas_siguientes": [{"npc":"narel","texto":"Comparé las marcas nuevas con las primeras. La diferencia respalda la explicación del terreno."},{"npc":"bruna","texto":"¿Y la carga? ¿También la revisaste?"},{"npc":"narel","texto":"Sí. La distribución contribuyó, aunque por sí sola no explica todo el daño."},{"npc":"bruna","texto":"Entonces deja ambas causas en el informe. Así nadie simplifica el problema."}],
		"lineas_tercera_etapa": [{"npc":"bruna","texto":"Guardé una copia de las medidas que tomaste. Pueden servir para la próxima revisión."},{"npc":"narel","texto":"Las ordené por fecha y condición del terreno. Así podremos compararlas sin mezclar resultados."},{"npc":"bruna","texto":"Bien. La próxima vez que algo se rompa, tendremos un punto de partida."},{"npc":"narel","texto":"Y una razón para comprobar primero las piezas antes de formular una explicación."}]
	},
	{
		"clave": "darven_saira_avisos",
		"tono_relacion": "prudente",
		"efectos_etapa": [{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Saira y Darven establecen un canal para transmitir avisos fiables."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Los comerciantes reciben información más clara."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"La cooperación permite distribuir mejor las tareas de vigilancia."}],
		"npc_a": "darven",
		"npc_b": "saira",
		"lineas": [
			{"npc":"saira","texto":"Ya avisé a los comerciantes que suelen usar ese tramo. Algunos cambiarán la hora de salida."},
			{"npc":"darven","texto":"Agradezco que transmitieras el aviso sin exagerarlo. No hacía falta provocar alarma."},
			{"npc":"saira","texto":"Una ruta complicada ya es suficiente problema. No necesito inventar otro para que me escuchen."},
			{"npc":"darven","texto":"Si recibes noticias nuevas, tráelas al registro. Las contrastaremos antes de actuar."}
		],
		"lineas_alternativas": [
			{"npc":"saira","texto":"Un comerciante me preguntó si ya puede volver a usar el camino habitual."},
			{"npc":"darven","texto":"Puede pasar con precaución. La reparación completa todavía no está terminada."},
			{"npc":"saira","texto":"Le transmitiré eso. Es mejor una respuesta clara que un sí apresurado."},
			{"npc":"darven","texto":"Gracias. Así evitamos que alguien confunda una revisión con una reparación terminada."}
		],
		"lineas_siguientes": [{"npc":"saira","texto":"Los comerciantes ya están usando el aviso actualizado. Dos cambiaron sus horarios."},{"npc":"darven","texto":"La revisión terminó, pero mantendremos el registro por si vuelve a deteriorarse."},{"npc":"saira","texto":"Les diré que pueden retomar la ruta con cuidado y que avisen si notan algo."},{"npc":"darven","texto":"Eso basta. La información útil llega antes que los rumores."}],
		"lineas_tercera_etapa": [{"npc":"saira","texto":"Ya no tengo que repetir el mismo aviso a cada comerciante. La información está llegando por la ruta."},{"npc":"darven","texto":"Eso libera tiempo para vigilar otros tramos. Mantendré el registro abierto."},{"npc":"saira","texto":"Cuando encuentre una noticia útil, sabré dónde llevarla y qué detalles necesitas."},{"npc":"darven","texto":"Y yo sabré distinguir cuándo hace falta actuar y cuándo basta con informar. Es un buen acuerdo."}]
	},
	{
		"clave": "elian_narel_hornada",
		"tono_relacion": "cordial",
		"efectos_etapa": [{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Elian y Narel comparten observaciones sobre la hornada."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Narel aporta notas y Elian explica el proceso práctico."},{"confianza":0.5,"tension":0.0,"colaboracion":0.5,"resumen":"Acuerdan preparar juntos una nueva hornada."}],
		"npc_a": "elian",
		"npc_b": "narel",
		"lineas": [
			{"npc":"narel","texto":"La hornada que compartiste tenía una textura distinta. ¿Cambiaste la proporción de harina?" },
			{"npc":"elian","texto":"Un poco. Tuve que ajustar la receta con la cantidad que llegó."},
			{"npc":"narel","texto":"Anoté la proporción que mencionaste. Podría servir para comparar futuras tandas."},
			{"npc":"elian","texto":"Puedes anotarla, claro. Pero tendrás que probar el pan para saber si la comparación merece la pena."}
		],
		"lineas_alternativas": [
			{"npc":"elian","texto":"¿Sigues comparando las proporciones de aquella hornada?"},
			{"npc":"narel","texto":"Sólo las anoté para recordar cómo cambió la textura. No pretendo convertir el pan en un experimento."},
			{"npc":"elian","texto":"Menos mal. La próxima vez puedes ayudarme a amasar y sacar tus propias conclusiones."},
			{"npc":"narel","texto":"Acepto. Será una observación más directa que leer una descripción."}
		],
		"lineas_siguientes": [{"npc":"elian","texto":"Narel, guardé una hogaza de la receta ajustada. Quería que la probaras con calma."},{"npc":"narel","texto":"La textura es más uniforme. Esta vez no traje una libreta para anotarlo."},{"npc":"elian","texto":"Mejor. Puedes venir a comer sin convertir cada visita en una investigación."},{"npc":"narel","texto":"Lo intentaré. Aunque admito que la comparación sería interesante."}],
		"lineas_tercera_etapa": [{"npc":"elian","texto":"La receta quedó anotada junto a las observaciones de aquella hornada."},{"npc":"narel","texto":"Y añadí una nota: la textura también depende del tiempo de reposo. No todo estaba en la harina."},{"npc":"elian","texto":"Eso explica por qué la segunda tanda salió distinta. La próxima vez lo tendremos en cuenta."},{"npc":"narel","texto":"Me gustaría ayudar a prepararla. Así podremos comprobarlo sin depender sólo de las notas."}]
	}
]

var _world_atmosphere: WorldAtmosphere = null
var _zone_manager: Node = null
var _game_state: Node = null
var _progreso_parejas: Dictionary = {}
var _temporizador_busqueda := 0.0
var _temporizador_linea := 0.0
var _conversacion_activa: Dictionary = {}
var _indice_linea := 0
var _npc_por_nombre: Dictionary = {}
var _burbujas: Dictionary = {}
var _vistas_por_dia: Dictionary = {}


func configurar(atmosfera: WorldAtmosphere, zone_manager: Node, game_state: Node = null) -> void:
	_world_atmosphere = atmosfera
	_zone_manager = zone_manager
	_game_state = game_state
	if is_instance_valid(_game_state) and _game_state.has_method("obtener_conversaciones_npc"):
		_progreso_parejas = _game_state.call("obtener_conversaciones_npc") as Dictionary


func actualizar(
	delta: float,
	jugador: Node2D,
	dialogo: DialogueSystem,
	gestor_misiones: Node
) -> void:
	if not is_instance_valid(_zone_manager):
		_ocultar_burbujas()
		return
	if str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		_finalizar_conversacion()
		return
	if not is_instance_valid(_world_atmosphere):
		return

	if not _conversacion_activa.is_empty():
		_actualizar_conversacion(delta, jugador, dialogo)
		return

	_temporizador_busqueda += delta
	if _temporizador_busqueda < INTERVALO_BUSQUEDA:
		return
	_temporizador_busqueda = 0.0

	if not _mision_carreta_completada(gestor_misiones):
		return
	if not is_instance_valid(jugador) or not jugador.is_inside_tree():
		return
	if is_instance_valid(dialogo) and dialogo.esta_abierto():
		return

	_buscar_conversacion(jugador)


func _mision_carreta_completada(gestor_misiones: Node) -> bool:
	if not is_instance_valid(gestor_misiones):
		return false
	if not gestor_misiones.has_method("buscar_mision_por_clave"):
		return false
	if not gestor_misiones.has_method("esta_completada"):
		return false
	var mision := gestor_misiones.call("buscar_mision_por_clave", "ayuda_horno_elian") as Dictionary
	if mision.is_empty():
		return false
	var mision_id := str(mision.get("id", "")).strip_edges()
	return not mision_id.is_empty() and bool(gestor_misiones.call("esta_completada", mision_id))


func _buscar_conversacion(jugador: Node2D) -> void:
	var tiempo := _world_atmosphere.obtener_tiempo()
	if not bool(tiempo.get("calendario_cargado", false)):
		return
	var clave_dia := "%d:%d" % [int(tiempo.get("anio", 0)), int(tiempo.get("dia", 1))]
	if _vistas_por_dia.get("dia", "") != clave_dia:
		_vistas_por_dia = {"dia": clave_dia}

	var npcs := _obtener_npcs_torres()
	if npcs.size() < 2:
		return

	for conversacion in CONVERSACIONES:
		var clave := str(conversacion.get("clave", ""))
		var progreso_variant: Variant = _progreso_parejas.get(clave, {})
		var progreso: Dictionary = progreso_variant if progreso_variant is Dictionary else {}
		if int(progreso.get("etapa", 0)) >= 3:
			continue
		if bool(_vistas_por_dia.get(clave, false)):
			continue
		var npc_a := _npc_por_nombre.get(str(conversacion.get("npc_a", ""))) as Creature
		var npc_b := _npc_por_nombre.get(str(conversacion.get("npc_b", ""))) as Creature
		if not _npc_puede_conversar(npc_a) or not _npc_puede_conversar(npc_b):
			continue
		if npc_a.global_position.distance_to(npc_b.global_position) > DISTANCIA_ENTRE_NPC:
			continue
		if jugador.global_position.distance_to(npc_a.global_position) > DISTANCIA_JUGADOR and jugador.global_position.distance_to(npc_b.global_position) > DISTANCIA_JUGADOR:
			continue
		_iniciar_conversacion(conversacion)
		_vistas_por_dia[clave] = true
		return


func _obtener_npcs_torres() -> Array[Creature]:
	var resultado: Array[Creature] = []
	_npc_por_nombre.clear()
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if not nodo is Creature or not is_instance_valid(nodo):
			continue
		var npc := nodo as Creature
		var clave := npc.get_nombre_visual().strip_edges().to_lower()
		if clave.is_empty():
			continue
		_npc_por_nombre[clave] = npc
		resultado.append(npc)
	return resultado


func _npc_puede_conversar(npc: Creature) -> bool:
	if not is_instance_valid(npc) or not npc.is_inside_tree() or not npc.is_visible_in_tree() or not npc.is_alive:
		return false
	if bool(npc.get_meta("rutina_en_edificio", false)) or bool(npc.get_meta("rutina_en_transito", false)):
		return false
	if npc.velocity.length() > 5.0:
		return false
	return true


func _iniciar_conversacion(conversacion: Dictionary) -> void:
	_conversacion_activa = conversacion.duplicate(true)
	var tiempo := _world_atmosphere.obtener_tiempo()
	var clave_progreso := str(_conversacion_activa.get("clave", ""))
	var progreso_variant: Variant = _progreso_parejas.get(clave_progreso, {})
	var progreso: Dictionary = progreso_variant if progreso_variant is Dictionary else {}
	var etapa := int(progreso.get("etapa", 0))
	_conversacion_activa["_etapa_progreso"] = etapa
	if etapa == 1:
		var siguientes_variant: Variant = _conversacion_activa.get("lineas_siguientes", [])
		if siguientes_variant is Array and not (siguientes_variant as Array).is_empty():
			_conversacion_activa["lineas"] = (siguientes_variant as Array).duplicate(true)
	elif etapa == 2:
		var tercera_variant: Variant = _conversacion_activa.get("lineas_tercera_etapa", [])
		if tercera_variant is Array and not (tercera_variant as Array).is_empty():
			_conversacion_activa["lineas"] = (tercera_variant as Array).duplicate(true)
		var tension := float(progreso.get("tension", 0.0))
		var lineas_tensas_variant: Variant = _conversacion_activa.get("lineas_tercera_tension", [])
		if tension > 0.0 and lineas_tensas_variant is Array and not (lineas_tensas_variant as Array).is_empty():
			_conversacion_activa["lineas"] = (lineas_tensas_variant as Array).duplicate(true)
	var anio := int(tiempo.get("anio", 0))
	var dia := int(tiempo.get("dia", 1))
	var hora := float(tiempo.get("hora_del_dia", 12.0))
	var franja := 0
	if hora >= 6.0 and hora < 12.0:
		franja = 1
	elif hora >= 12.0 and hora < 18.0:
		franja = 2
	elif hora >= 18.0:
		franja = 3

	# lineas_alternativas admite tanto el formato antiguo (una lista plana
	# de intervenciones) como una lista de listas para futuras variantes.
	var alternativas_variant: Variant = _conversacion_activa.get("lineas_alternativas", [])
	var variantes: Array = []
	if alternativas_variant is Array and not (alternativas_variant as Array).is_empty():
		var alternativas := alternativas_variant as Array
		if alternativas[0] is Dictionary:
			variantes.append(alternativas)
		else:
			for alternativa_variant in alternativas:
				if alternativa_variant is Array and not (alternativa_variant as Array).is_empty():
					variantes.append(alternativa_variant)

	if etapa == 0 and not variantes.is_empty():
		var tono := str(_conversacion_activa.get("tono_relacion", "cordial"))
		var desplazamiento := 0
		match tono:
			"cercana":
				desplazamiento = 1
			"tensa":
				desplazamiento = 2
			"prudente":
				desplazamiento = 3
		var indice := posmod(anio + dia + franja + desplazamiento, variantes.size() + 1)
		if indice > 0:
			_conversacion_activa["lineas"] = (variantes[indice - 1] as Array).duplicate(true)

	_indice_linea = 0
	_temporizador_linea = 0.0
	_mostrar_linea_actual()
	print("NPCConversationSystem: conversación ambiental iniciada: ", conversacion.get("clave", ""))


func _actualizar_conversacion(delta: float, jugador: Node2D, dialogo: DialogueSystem) -> void:
	if is_instance_valid(dialogo) and dialogo.esta_abierto():
		_ocultar_burbujas()
		return
	if not is_instance_valid(jugador) or not jugador.is_inside_tree():
		_finalizar_conversacion()
		return

	var npc_a := _npc_por_nombre.get(str(_conversacion_activa.get("npc_a", ""))) as Creature
	var npc_b := _npc_por_nombre.get(str(_conversacion_activa.get("npc_b", ""))) as Creature
	if not _npc_puede_conversar(npc_a) or not _npc_puede_conversar(npc_b):
		_finalizar_conversacion()
		return
	if npc_a.global_position.distance_to(npc_b.global_position) > DISTANCIA_ENTRE_NPC * 1.5:
		_finalizar_conversacion()
		return
	if jugador.global_position.distance_to(npc_a.global_position) > DISTANCIA_JUGADOR + 80.0 and jugador.global_position.distance_to(npc_b.global_position) > DISTANCIA_JUGADOR + 80.0:
		_ocultar_burbujas()
		return

	_temporizador_linea -= delta
	if _temporizador_linea <= 0.0:
		_indice_linea += 1
		var lineas: Array = _conversacion_activa.get("lineas", [])
		if _indice_linea >= lineas.size():
			_finalizar_conversacion(true)
			return
		_mostrar_linea_actual()


func _mostrar_linea_actual() -> void:
	var lineas: Array = _conversacion_activa.get("lineas", [])
	if _indice_linea < 0 or _indice_linea >= lineas.size():
		_finalizar_conversacion()
		return
	var linea_variant: Variant = lineas[_indice_linea]
	if not linea_variant is Dictionary:
		_finalizar_conversacion()
		return
	var linea := linea_variant as Dictionary
	var hablante := str(linea.get("npc", "")).strip_edges().to_lower()
	var npc := _npc_por_nombre.get(hablante) as Creature
	if not is_instance_valid(npc):
		_finalizar_conversacion()
		return
	var texto := str(linea.get("texto", "")).strip_edges()
	if texto.is_empty():
		_finalizar_conversacion()
		return

	_ocultar_burbujas()
	var burbuja := _obtener_burbuja(npc)
	if burbuja != null:
		var etiqueta := burbuja.get_node_or_null("Text") as Label
		if etiqueta != null:
			etiqueta.text = npc.get_nombre_visual() + ": " + texto
		burbuja.visible = true
	_temporizador_linea = DURACION_LINEA


func _obtener_burbuja(npc: Creature) -> PanelContainer:
	var clave := npc.get_instance_id()
	var existente := _burbujas.get(clave) as PanelContainer
	if is_instance_valid(existente):
		return existente

	var panel := PanelContainer.new()
	panel.name = "NPCConversationBubble"
	panel.position = Vector2(-84.0, -74.0)
	panel.custom_minimum_size = Vector2(168.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 100
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#2B211B")
	estilo.border_color = Color("#A98A67")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	estilo.content_margin_left = 6.0
	estilo.content_margin_right = 6.0
	estilo.content_margin_top = 4.0
	estilo.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", estilo)

	var etiqueta := Label.new()
	etiqueta.name = "Text"
	etiqueta.custom_minimum_size = Vector2(156.0, 0.0)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_override("font", FONT_PIXEL)
	etiqueta.add_theme_font_size_override("font_size", 8)
	etiqueta.add_theme_color_override("font_color", Color("#F2E8D8"))
	etiqueta.add_theme_color_override("font_outline_color", Color("#17110D"))
	etiqueta.add_theme_constant_override("outline_size", 2)
	panel.add_child(etiqueta)
	npc.add_child(panel)
	_burbujas[clave] = panel
	return panel


func _ocultar_burbujas() -> void:
	for burbuja_variant in _burbujas.values():
		var burbuja := burbuja_variant as PanelContainer
		if is_instance_valid(burbuja):
			burbuja.visible = false


func _finalizar_conversacion(completada: bool = false) -> void:
	if completada and not _conversacion_activa.is_empty():
		var clave := str(_conversacion_activa.get("clave", ""))
		var etapa := int(_conversacion_activa.get("_etapa_progreso", 0))
		if not clave.is_empty():
			var progreso_variant: Variant = _progreso_parejas.get(clave, {})
			var progreso: Dictionary = progreso_variant.duplicate(true) if progreso_variant is Dictionary else {}
			var efecto_variant: Variant = _conversacion_activa.get("efectos_etapa", [])
			var efectos: Array = efecto_variant if efecto_variant is Array else []
			var efecto: Dictionary = {}
			if etapa < efectos.size() and efectos[etapa] is Dictionary:
				efecto = efectos[etapa]
			for atributo in ["confianza", "tension", "colaboracion"]:
				progreso[atributo] = clampf(float(progreso.get(atributo, 0.0)) + float(efecto.get(atributo, 0.0)), -5.0, 5.0)
			var historial: Array = progreso.get("historial", []).duplicate(true)
			var tiempo_actual := _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
			historial.append({
				"etapa": etapa + 1,
				"dia": int(tiempo_actual.get("dia", 0)),
				"anio": int(tiempo_actual.get("anio", 0)),
				"resumen": str(efecto.get("resumen", ""))
			})
			while historial.size() > 12:
				historial.pop_front()
			progreso["historial"] = historial
			progreso["etapa"] = mini(etapa + 1, 3)
			progreso["completada"] = etapa >= 2
			progreso["ultimo_resumen"] = str(efecto.get("resumen", ""))
			_progreso_parejas[clave] = progreso
			if is_instance_valid(_game_state) and _game_state.has_method("guardar_conversaciones_npc"):
				_game_state.call("guardar_conversaciones_npc", _progreso_parejas)
	_ocultar_burbujas()
	_conversacion_activa.clear()
	_indice_linea = 0
	_temporizador_linea = 0.0
