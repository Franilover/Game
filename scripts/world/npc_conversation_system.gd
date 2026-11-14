extends Node
class_name NPCConversationSystem

signal cinematica_acontecimiento_solicitada(posicion_global: Vector2)
signal cinematica_narrativa_solicitada(clave: String, npc_a: String, npc_b: String, posicion_global: Vector2, etapa: int)

const INTERVALO_BUSQUEDA := 0.5
const DISTANCIA_ENTRE_NPC := 180.0
const DISTANCIA_JUGADOR := 220.0
const DISTANCIA_INICIATIVA := 112.0
const DISTANCIA_BUSQUEDA_INICIATIVA := 280.0
const DISTANCIA_LLEGADA_INICIATIVA := 76.0
const TIEMPO_MAX_ACERCAMIENTO := 16.0
const AMISTAD_INICIATIVA_MINIMA := 8.0
const AFECTO_INICIATIVA_MINIMO := 5.0
const DURACION_LINEA := 3.2
const FONT_PIXEL: Font = preload("res://assets/fonts/Pixelgrafia.ttf")

# Sucesos cotidianos breves. Se elige uno por día de forma determinista,
# respetando quién está presente y evitando repetir los últimos acontecimientos.
const ACONTECIMIENTOS_DIARIOS: Array[Dictionary] = [
	{"clave":"elian_saira_paquete","objeto_visual":"Paquete","tipo_visual":"paquete","npc_a":"elian","npc_b":"saira","lineas":[{"npc":"saira","texto":"Dejé un pequeño paquete junto al horno. No era urgente, así que no quise interrumpirte."},{"npc":"elian","texto":"Lo vi al llegar. Gracias por traerlo hasta aquí; hoy tenía las manos ocupadas desde temprano."},{"npc":"saira","texto":"No todo lo que transporto tiene que convertirse en un encargo."},{"npc":"elian","texto":"Entonces la próxima vez te guardaré algo para el camino."}]},
	{"clave":"bruna_darven_cartel","objeto_visual":"Aviso","tipo_visual":"cartel","npc_a":"bruna","npc_b":"darven","lineas":[{"npc":"darven","texto":"El cartel de la plaza volvió a torcerse. Esta vez lo encontré antes de que cayera."},{"npc":"bruna","texto":"Puedo reforzar el soporte, pero alguien tendrá que dejar de colgar avisos en el borde."},{"npc":"darven","texto":"Hablaré con quienes lo usan. No quiero que termines reparándolo cada dos días."},{"npc":"bruna","texto":"Con que no lo conviertan en un tablón de anuncios improvisado, me basta."}]},
	{"clave":"narel_saira_noticia","objeto_visual":"Notas","tipo_visual":"notas","npc_a":"narel","npc_b":"saira","lineas":[{"npc":"narel","texto":"Mencionaste una luz extraña cerca del camino. ¿Alguien más la vio?"},{"npc":"saira","texto":"Dos viajeros hablaron de un reflejo entre los árboles, pero ninguno se acercó."},{"npc":"narel","texto":"Entonces lo anotaré como un testimonio sin verificar, no como un fenómeno confirmado."},{"npc":"saira","texto":"Por eso te lo cuento a ti. Sabía que no ibas a convertirlo en una historia enorme."}]},
	{"clave":"elian_bruna_pan","objeto_visual":"Pan","tipo_visual":"pan","npc_a":"elian","npc_b":"bruna","lineas":[{"npc":"elian","texto":"Aparté una pieza de pan de la última hornada. Quedó más dura de lo que esperaba."},{"npc":"bruna","texto":"No está tan mal. Servirá para probar si el filo de mi herramienta nueva aguanta."},{"npc":"elian","texto":"Preferiría que no usaras mi pan como material de prueba."},{"npc":"bruna","texto":"Entonces la próxima vez hazlo un poco más blando. Problema resuelto."}]},
	{"clave":"darven_narel_turno","objeto_visual":"Registro","tipo_visual":"notas","npc_a":"darven","npc_b":"narel","lineas":[{"npc":"darven","texto":"Hoy la plaza estuvo más tranquila durante el cambio de turno."},{"npc":"narel","texto":"¿Lo atribuyes a la hora o a que hubo menos viajeros?"},{"npc":"darven","texto":"A ambas cosas, probablemente. No tengo suficientes días comparables."},{"npc":"narel","texto":"Puedo llevar un registro sencillo. Así no dependeremos sólo de la impresión."}]},
	{"clave":"bruna_saira_cierre","objeto_visual":"Hebillas","tipo_visual":"metal","npc_a":"bruna","npc_b":"saira","lineas":[{"npc":"saira","texto":"Un comerciante me ofreció unas hebillas viejas a cambio de una entrega."},{"npc":"bruna","texto":"Si no están partidas, puedo aprovechar el metal. Tráelas cuando vuelvas."},{"npc":"saira","texto":"No prometo que sean bonitas."},{"npc":"bruna","texto":"No te pedí que lo fueran. Sólo que no se desarmen al tocarlas."}]},
	{"clave":"elian_darven_merienda","objeto_visual":"Merienda","tipo_visual":"paquete","npc_a":"elian","npc_b":"darven","lineas":[{"npc":"elian","texto":"Te dejé una merienda en el mostrador. Ayer terminaste el turno bastante tarde."},{"npc":"darven","texto":"La encontré. No hacía falta que te tomaras esa molestia."},{"npc":"elian","texto":"No es molestia preparar una porción más."},{"npc":"darven","texto":"Entonces procuraré pasar antes de que se enfríe la próxima vez."}]},
	{"clave":"narel_bruna_medidas","objeto_visual":"Medidas","tipo_visual":"notas","npc_a":"narel","npc_b":"bruna","lineas":[{"npc":"narel","texto":"He ordenado las notas de las últimas reparaciones. Hay una medida que se repite."},{"npc":"bruna","texto":"Si es la del soporte pequeño, ya la conozco. Hice tres iguales esta semana."},{"npc":"narel","texto":"Precisamente. Parece que esa pieza está resolviendo más de un problema."},{"npc":"bruna","texto":"Entonces dejaré un par preparados. No cuesta nada adelantarse."}]}
]

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
		"lineas_tercera_etapa": [{"npc":"darven","texto":"El registro del camino queda actualizado. Si vuelve a deteriorarse, sabremos dónde empezar."},{"npc":"bruna","texto":"Y yo conservaré las medidas de las piezas. No tendremos que improvisar otra vez."},{"npc":"darven","texto":"Admito que tu insistencia ayudó a que revisáramos el tramo completo."},{"npc":"bruna","texto":"Y yo admito que mantener el paso vigilado mientras trabajaban fue útil. No estuvo mal coordinado."}],
"lineas_tercera_tension": [{"npc":"darven","texto":"El registro sigue incompleto. No puedo dar por resuelto el tramo sólo porque ahora parezca firme."},{"npc":"bruna","texto":"Y yo no voy a repetir una inspección cada vez que alguien dude de las piezas."},{"npc":"darven","texto":"No cuestiono tu trabajo. Necesito que el informe y la reparación coincidan."},{"npc":"bruna","texto":"Entonces revisemos ambos juntos. Pero esta vez no decidas antes de mirar."}]
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
var _relationship_system: RelationshipSystemService = null
var _mission_manager: MissionManagerService = null
var _progreso_parejas: Dictionary = {}
var _npc_por_id: Dictionary = {}
var _acercamiento_activo: Dictionary = {}
var _intentos_acercamiento_hasta: Dictionary = {}
var _tiempo_sistema := 0.0
var _temporizador_busqueda := 0.0
var _temporizador_linea := 0.0
var _conversacion_activa: Dictionary = {}
var _indice_linea := 0
var _npc_por_nombre: Dictionary = {}
var _burbujas: Dictionary = {}
var _vistas_por_dia: Dictionary = {}
var _objeto_evento_diario: Node2D = null
var _zona_objeto_evento: Node2D = null


func configurar(
	atmosfera: WorldAtmosphere,
	zone_manager: Node,
	game_state: Node = null,
	relationship_system: RelationshipSystemService = null,
	mission_manager: MissionManagerService = null
) -> void:
	_world_atmosphere = atmosfera
	_zone_manager = zone_manager
	_game_state = game_state
	_relationship_system = relationship_system
	_mission_manager = mission_manager
	add_to_group("npc_conversation_system")
	if is_instance_valid(_game_state) and _game_state.has_method("obtener_conversaciones_npc"):
		var progreso_variant: Variant = _game_state.call("obtener_conversaciones_npc")
		_progreso_parejas = progreso_variant.duplicate(true) if progreso_variant is Dictionary else {}
	if is_instance_valid(_mission_manager) and not _mission_manager.mision_aceptada.is_connected(_al_mision_aceptada):
		_mission_manager.mision_aceptada.connect(_al_mision_aceptada)


func actualizar(
	delta: float,
	jugador: Node2D,
	dialogo: DialogueSystem,
	gestor_misiones: Node
) -> void:
	_tiempo_sistema += maxf(delta, 0.0)
	if not is_instance_valid(_zone_manager):
		_cancelar_acercamiento()
		_ocultar_burbujas()
		return
	if str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		_cancelar_acercamiento()
		_finalizar_conversacion()
		return
	if not is_instance_valid(_world_atmosphere):
		return
	var tiempo_actual := _world_atmosphere.obtener_tiempo()
	if bool(tiempo_actual.get("calendario_cargado", false)):
		_restaurar_objeto_evento_diario(tiempo_actual)

	if not _conversacion_activa.is_empty():
		_actualizar_conversacion(delta, jugador, dialogo)
		return
	if not _acercamiento_activo.is_empty():
		_actualizar_acercamiento(delta, jugador, dialogo)
		return

	_temporizador_busqueda += delta
	if _temporizador_busqueda < INTERVALO_BUSQUEDA:
		return
	_temporizador_busqueda = 0.0

	if not is_instance_valid(jugador) or not jugador.is_inside_tree():
		return
	if is_instance_valid(dialogo) and dialogo.esta_abierto():
		return

	if _actualizar_iniciativas(jugador, dialogo, gestor_misiones):
		return
	_buscar_conversacion(jugador)


## Permite que el jugador presencie la conversación activa al interactuar
## con cualquiera de sus participantes. No abre un diálogo individual ni
## reinicia la intervención que ya está en curso.
func intentar_observar_conversacion(npc_interactuado: Creature, jugador: Node2D, gestor_misiones: Node) -> bool:
	if not is_instance_valid(npc_interactuado) or not is_instance_valid(jugador):
		return false
	if not npc_interactuado.is_in_group("torres_game_npc"):
		return false
	if not is_instance_valid(_zone_manager) or str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		return false
	if not is_instance_valid(_world_atmosphere) or not _mision_carreta_completada(gestor_misiones):
		return false

	var nombre := npc_interactuado.get_nombre_visual().strip_edges().to_lower()
	if not _conversacion_activa.is_empty():
		var participa := nombre == str(_conversacion_activa.get("npc_a", "")) or nombre == str(_conversacion_activa.get("npc_b", ""))
		if participa:
			# La burbuja de la intervención actual puede haberse ocultado si el
			# jugador estaba lejos. Se vuelve a mostrar sin reiniciar su tiempo.
			_mostrar_linea_actual(false)
			return true
		return false

	if not bool(_world_atmosphere.obtener_tiempo().get("calendario_cargado", false)):
		return false
	_obtener_npcs_torres()
	for conversacion in CONVERSACIONES:
		if nombre != str(conversacion.get("npc_a", "")) and nombre != str(conversacion.get("npc_b", "")):
			continue
		var progreso_variant: Variant = _progreso_parejas.get(str(conversacion.get("clave", "")), {})
		var progreso: Dictionary = progreso_variant if progreso_variant is Dictionary else {}
		if int(progreso.get("etapa", 0)) >= 3:
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
		var tiempo := _world_atmosphere.obtener_tiempo()
		_vistas_por_dia["dia"] = "%d:%d" % [int(tiempo.get("anio", 0)), int(tiempo.get("dia", 1))]
		_vistas_por_dia[str(conversacion.get("clave", ""))] = true
		return true
	return false


## Guarda el origen de cada encargo aceptado para que el mismo NPC pueda
## interesarse por el progreso en el momento adecuado.
func _al_mision_aceptada(mision: Dictionary) -> void:
	var personaje_id := str(mision.get("npc_origen_personaje_game_id", "")).strip_edges()
	var mision_id := str(mision.get("id", "")).strip_edges()
	if personaje_id.is_empty() or mision_id.is_empty() or not is_instance_valid(_world_atmosphere):
		return
	var tiempo := _world_atmosphere.obtener_tiempo()
	if not bool(tiempo.get("calendario_cargado", false)):
		return
	var hora := float(tiempo.get("hora_del_dia", 12.0))
	var dias_espera := maxi(0, int(mision.get("seguimiento_dias", mision.get("duracion_dias", 0))))
	if dias_espera <= 0:
		var plazo := str(mision.get("plazo", mision.get("duracion", mision.get("tipo_plazo", mision.get("tipo", ""))))).to_lower()
		var objetivos_variant: Variant = mision.get("objetivos", [])
		var cantidad_objetivos := 0
		if objetivos_variant is Array:
			cantidad_objetivos = (objetivos_variant as Array).size()
		if plazo.contains("largo") or plazo.contains("seman") or plazo.contains("principal") or cantidad_objetivos >= 3:
			dias_espera = 3
	var iniciativas := _obtener_iniciativas()
	var misiones_variant: Variant = iniciativas.get("misiones", {})
	var misiones: Dictionary = misiones_variant.duplicate(true) if misiones_variant is Dictionary else {}
	misiones[mision_id] = {
		"personaje_id": personaje_id,
		"nombre": str(mision.get("nombre", "el encargo")),
		"dia_aceptacion": int(tiempo.get("dia", 1)),
		"anio_aceptacion": int(tiempo.get("anio", 0)),
		"hora_aceptacion": hora,
		"dias_espera": dias_espera,
		"seguimiento_realizado": false
	}
	iniciativas["misiones"] = misiones
	_guardar_iniciativas(iniciativas)


func _obtener_iniciativas() -> Dictionary:
	var iniciativas_variant: Variant = _progreso_parejas.get("_iniciativas", {})
	return iniciativas_variant.duplicate(true) if iniciativas_variant is Dictionary else {}


func _guardar_iniciativas(iniciativas: Dictionary) -> void:
	_progreso_parejas["_iniciativas"] = iniciativas.duplicate(true)
	if is_instance_valid(_game_state) and _game_state.has_method("guardar_conversaciones_npc"):
		_game_state.call("guardar_conversaciones_npc", _progreso_parejas)


func _actualizar_iniciativas(
	jugador: Node2D,
	dialogo: DialogueSystem,
	gestor_misiones: Node
) -> bool:
	if not is_instance_valid(jugador) or not jugador.is_inside_tree() or not is_instance_valid(dialogo):
		return false
	if jugador is CharacterBody2D and (jugador as CharacterBody2D).velocity.length() > 8.0:
		return false
	if dialogo.esta_abierto():
		return false
	var tiempo := _world_atmosphere.obtener_tiempo()
	if not bool(tiempo.get("calendario_cargado", false)):
		return false
	_obtener_npcs_torres()
	var iniciativas := _obtener_iniciativas()
	if not _puede_iniciar_iniciativa_global(iniciativas, tiempo):
		return false

	var misiones_variant: Variant = iniciativas.get("misiones", {})
	var misiones: Dictionary = misiones_variant if misiones_variant is Dictionary else {}
	for mision_id_variant in misiones.keys():
		var mision_id := str(mision_id_variant)
		var registro_variant: Variant = misiones.get(mision_id, {})
		if not registro_variant is Dictionary:
			continue
		var registro := registro_variant as Dictionary
		if bool(registro.get("seguimiento_realizado", false)):
			continue
		if not _seguimiento_mision_vencido(registro, tiempo):
			continue
		if not is_instance_valid(gestor_misiones) or not gestor_misiones.has_method("obtener_estado_mision"):
			continue
		var estado_mision: Dictionary = gestor_misiones.call("obtener_estado_mision", mision_id)
		if estado_mision.is_empty():
			continue
		var estado := str(estado_mision.get("estado", ""))
		if estado != "activa" and estado != "completada" and estado != "reclamada":
			continue
		var npc := _npc_por_id.get(str(registro.get("personaje_id", ""))) as Creature
		if not _npc_puede_acercarse(npc):
			continue
		var distancia := jugador.global_position.distance_to(npc.global_position)
		if distancia > DISTANCIA_BUSQUEDA_INICIATIVA or _esta_en_enfriamiento_acercamiento(npc.get_personaje_game_id()):
			continue
		var datos_dialogo := _crear_dialogo_seguimiento_mision(npc, registro, estado == "completada" or estado == "reclamada")
		if _intentar_iniciativa_o_acercamiento(npc, jugador, dialogo, datos_dialogo, "mision", mision_id, registro, tiempo):
			return true

	var ultima_variant: Variant = iniciativas.get("ultima_iniciativa_dia", {})
	var ultima: Dictionary = ultima_variant if ultima_variant is Dictionary else {}
	var dia_actual := _clave_dia(tiempo)
	for npc_variant in _npc_por_id.values():
		if not npc_variant is Creature:
			continue
		var personaje := npc_variant as Creature
		if not _npc_puede_acercarse(personaje):
			continue
		var personaje_id := personaje.get_personaje_game_id().strip_edges()
		if personaje_id.is_empty() or str(ultima.get(personaje_id, "")) == dia_actual:
			continue
		if _esta_en_enfriamiento_acercamiento(personaje_id):
			continue
		if not is_instance_valid(_relationship_system):
			continue
		var relacion := _relationship_system.obtener_relacion(personaje_id)
		if float(relacion.get("amistad", 0.0)) < AMISTAD_INICIATIVA_MINIMA and float(relacion.get("afecto", 0.0)) < AFECTO_INICIATIVA_MINIMO:
			continue
		var dia_ultima := str(ultima.get(personaje_id, ""))
		if not dia_ultima.is_empty() and _dias_entre_claves(dia_ultima, tiempo) < 2:
			continue
		if jugador.global_position.distance_to(personaje.global_position) > DISTANCIA_BUSQUEDA_INICIATIVA:
			continue
		var datos_amigo := _crear_dialogo_iniciativa_amigo(personaje, tiempo)
		if _intentar_iniciativa_o_acercamiento(personaje, jugador, dialogo, datos_amigo, "amistad", "", {}, tiempo):
			return true
	return false


func _npc_puede_acercarse(npc: Creature) -> bool:
	if not is_instance_valid(npc) or not npc.is_inside_tree() or not npc.is_visible_in_tree() or not npc.is_alive:
		return false
	if bool(npc.get_meta("rutina_en_edificio", false)) or bool(npc.get_meta("rutina_en_transito", false)):
		return false
	if bool(npc.get_meta("acercamiento_social_activo", false)) or npc.velocity.length() > 5.0:
		return false
	return true


func _intentar_iniciativa_o_acercamiento(
	npc: Creature,
	jugador: Node2D,
	dialogo: DialogueSystem,
	datos_dialogo: Dictionary,
	tipo: String,
	mision_id: String,
	registro_mision: Dictionary,
	tiempo: Dictionary
) -> bool:
	var distancia := jugador.global_position.distance_to(npc.global_position)
	if distancia <= DISTANCIA_INICIATIVA:
		if not dialogo.abrir_iniciativa_npc(datos_dialogo, npc):
			return false
		_registrar_iniciativa_realizada(npc, tipo, mision_id, registro_mision, tiempo)
		return true

	var sistema_rutinas := get_tree().get_first_node_in_group("npc_schedule_system") as NPCScheduleSystem
	if not is_instance_valid(sistema_rutinas):
		return false
	if not sistema_rutinas.iniciar_acercamiento_social(npc, jugador):
		_intentos_acercamiento_hasta[npc.get_personaje_game_id()] = _tiempo_sistema + 20.0
		return false
	_acercamiento_activo = {
		"npc": npc,
		"jugador_inicio": jugador.global_position,
		"tiempo_restante": TIEMPO_MAX_ACERCAMIENTO,
		"datos_dialogo": datos_dialogo.duplicate(true),
		"tipo": tipo,
		"mision_id": mision_id,
		"registro_mision": registro_mision.duplicate(true),
		"personaje_id": npc.get_personaje_game_id(),
		"dialogo_iniciado": false
	}
	return true


func _actualizar_acercamiento(delta: float, jugador: Node2D, dialogo: DialogueSystem) -> void:
	var npc := _acercamiento_activo.get("npc") as Creature
	if not is_instance_valid(npc):
		_cancelar_acercamiento()
		return
	if bool(_acercamiento_activo.get("dialogo_iniciado", false)):
		if is_instance_valid(dialogo) and dialogo.esta_abierto():
			return
		_finalizar_acercamiento()
		return
	if not is_instance_valid(jugador) or not jugador.is_inside_tree() or not is_instance_valid(dialogo):
		_cancelar_acercamiento()
		return
	if dialogo.esta_abierto():
		_cancelar_acercamiento()
		return
	if not npc.is_alive or not npc.is_visible_in_tree():
		_cancelar_acercamiento()
		return
	if bool(npc.get_meta("rutina_en_edificio", false)) or bool(npc.get_meta("rutina_en_transito", false)):
		_cancelar_acercamiento()
		return
	if jugador is CharacterBody2D and (jugador as CharacterBody2D).velocity.length() > 8.0:
		_cancelar_acercamiento()
		return
	var posicion_inicial: Vector2 = _acercamiento_activo.get("jugador_inicio", jugador.global_position)
	if jugador.global_position.distance_to(posicion_inicial) > 72.0:
		_cancelar_acercamiento()
		return
	_acercamiento_activo["tiempo_restante"] = float(_acercamiento_activo.get("tiempo_restante", TIEMPO_MAX_ACERCAMIENTO)) - maxf(delta, 0.0)
	if jugador.global_position.distance_to(npc.global_position) <= DISTANCIA_LLEGADA_INICIATIVA:
		var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento != null:
			movimiento.detener_por_rutina()
		var datos_dialogo_variant: Variant = _acercamiento_activo.get("datos_dialogo", {})
		var datos_dialogo: Dictionary = datos_dialogo_variant if datos_dialogo_variant is Dictionary else {}
		if dialogo.abrir_iniciativa_npc(datos_dialogo, npc):
			_acercamiento_activo["dialogo_iniciado"] = true
			var tiempo := _world_atmosphere.obtener_tiempo()
			_registrar_iniciativa_realizada(
				npc,
				str(_acercamiento_activo.get("tipo", "")),
				str(_acercamiento_activo.get("mision_id", "")),
				_acercamiento_activo.get("registro_mision", {}) as Dictionary,
				tiempo
			)
			return
		_cancelar_acercamiento()
		return
	var movimiento_actual := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if float(_acercamiento_activo.get("tiempo_restante", 0.0)) <= 0.0 or (movimiento_actual != null and movimiento_actual.rutina_terminada()):
		_cancelar_acercamiento()


func _registrar_iniciativa_realizada(
	npc: Creature,
	tipo: String,
	mision_id: String,
	registro_mision: Dictionary,
	tiempo: Dictionary
) -> void:
	var iniciativas := _obtener_iniciativas()
	if tipo == "mision":
		var misiones_variant: Variant = iniciativas.get("misiones", {})
		var misiones: Dictionary = misiones_variant if misiones_variant is Dictionary else {}
		var registro := registro_mision.duplicate(true)
		registro["seguimiento_realizado"] = true
		misiones[mision_id] = registro
		iniciativas["misiones"] = misiones
	elif tipo == "amistad":
		var ultima_variant: Variant = iniciativas.get("ultima_iniciativa_dia", {})
		var ultima: Dictionary = ultima_variant if ultima_variant is Dictionary else {}
		ultima[npc.get_personaje_game_id()] = _clave_dia(tiempo)
		iniciativas["ultima_iniciativa_dia"] = ultima
	_registrar_iniciativa_global(iniciativas, tiempo)
	_guardar_iniciativas(iniciativas)


func _esta_en_enfriamiento_acercamiento(personaje_id: String) -> bool:
	return _tiempo_sistema < float(_intentos_acercamiento_hasta.get(personaje_id, 0.0))


func _cancelar_acercamiento() -> void:
	if _acercamiento_activo.is_empty():
		return
	var npc := _acercamiento_activo.get("npc") as Creature
	var personaje_id := str(_acercamiento_activo.get("personaje_id", ""))
	if not bool(_acercamiento_activo.get("dialogo_iniciado", false)) and not personaje_id.is_empty():
		_intentos_acercamiento_hasta[personaje_id] = _tiempo_sistema + 20.0
	if is_instance_valid(npc):
		var sistema_rutinas := get_tree().get_first_node_in_group("npc_schedule_system") as NPCScheduleSystem
		if is_instance_valid(sistema_rutinas):
			sistema_rutinas.finalizar_acercamiento_social(npc)
	_acercamiento_activo.clear()


func _finalizar_acercamiento() -> void:
	var npc := _acercamiento_activo.get("npc") as Creature
	if is_instance_valid(npc):
		var sistema_rutinas := get_tree().get_first_node_in_group("npc_schedule_system") as NPCScheduleSystem
		if is_instance_valid(sistema_rutinas):
			sistema_rutinas.finalizar_acercamiento_social(npc)
	_acercamiento_activo.clear()


func _puede_iniciar_iniciativa_global(iniciativas: Dictionary, tiempo: Dictionary) -> bool:
	var ultima_variant: Variant = iniciativas.get("ultima_global", {})
	if not ultima_variant is Dictionary:
		return true
	var ultima := ultima_variant as Dictionary
	if str(ultima.get("dia", "")) != _clave_dia(tiempo):
		return true
	return float(tiempo.get("hora_del_dia", 0.0)) - float(ultima.get("hora", 0.0)) >= 4.0


func _registrar_iniciativa_global(iniciativas: Dictionary, tiempo: Dictionary) -> void:
	iniciativas["ultima_global"] = {
		"dia": _clave_dia(tiempo),
		"hora": float(tiempo.get("hora_del_dia", 0.0))
	}


func _seguimiento_mision_vencido(registro: Dictionary, tiempo: Dictionary) -> bool:
	var dias_espera := maxi(0, int(registro.get("dias_espera", 0)))
	var dias_transcurridos := _dias_transcurridos(
		int(registro.get("anio_aceptacion", 0)),
		int(registro.get("dia_aceptacion", 1)),
		int(tiempo.get("anio", 0)),
		int(tiempo.get("dia", 1))
	)
	var hora_actual := float(tiempo.get("hora_del_dia", 0.0))
	if dias_espera > 0:
		return dias_transcurridos >= dias_espera and hora_actual >= 8.0
	var hora_aceptacion := float(registro.get("hora_aceptacion", 12.0))
	var dias_hasta_consulta := 1 if hora_aceptacion >= 18.0 else 0
	return dias_transcurridos >= dias_hasta_consulta and hora_actual >= 18.0


func _dias_transcurridos(anio_inicio: int, dia_inicio: int, anio_actual: int, dia_actual: int) -> int:
	if anio_actual < anio_inicio:
		return 0
	if anio_actual == anio_inicio:
		return maxi(0, dia_actual - dia_inicio)
	return maxi(0, (anio_actual - anio_inicio) * 365 + dia_actual - dia_inicio)


func _clave_dia(tiempo: Dictionary) -> String:
	return "%d:%d" % [int(tiempo.get("anio", 0)), int(tiempo.get("dia", 1))]


func _dias_entre_claves(clave: String, tiempo: Dictionary) -> int:
	var partes := clave.split(":")
	if partes.size() != 2:
		return 999
	return _dias_transcurridos(int(partes[0]), int(partes[1]), int(tiempo.get("anio", 0)), int(tiempo.get("dia", 1)))


func _crear_dialogo_seguimiento_mision(npc: Creature, registro: Dictionary, completada: bool) -> Dictionary:
	var nombre := npc.get_nombre_visual()
	var mision := str(registro.get("nombre", "el encargo"))
	var pregunta := "¿Cómo te ha ido con " + mision + "? No quería estar preguntándote a cada rato, pero me acordé del encargo."
	if completada:
		pregunta = "Me enteré de que terminaste " + mision + ". ¿Cómo te fue al final?"
	match nombre.to_lower():
		"elian":
			pregunta = "Hola, me acordé del encargo de " + mision + ". ¿Cómo te está yendo? Espero que no te haya dado demasiados problemas."
		"bruna":
			pregunta = "Una cosa: ¿cómo va " + mision + "? Prefiero preguntar antes de dar por hecho que todo salió bien."
		"darven":
			pregunta = "Quería hacer seguimiento de " + mision + ". ¿Todo marcha según lo previsto o surgió algún inconveniente?"
		"saira":
			pregunta = "¡Justo quería preguntarte por " + mision + "! ¿Cómo va todo? No me gusta dejar un encargo sin saber cómo sigue."
		"narel":
			pregunta = "He estado pensando en " + mision + ". ¿Qué resultados has obtenido hasta ahora? Me interesa saber si apareció algo inesperado."
	if completada:
		pregunta = "¡Supe que terminaste " + mision + "! ¿Cómo te fue? ¿Resultó como esperabas?"
	var respuestas := _crear_respuestas_iniciativa(npc, "mision", completada)
	return {
		"clave": "iniciativa_mision_" + str(registro.get("personaje_id", "")) + "_" + str(registro.get("dia_aceptacion", 0)),
		"lineas": [{"hablante": nombre, "texto": pregunta}],
		"respuestas": respuestas,
		"_iniciativa_npc": true
	}


func _crear_dialogo_iniciativa_amigo(npc: Creature, tiempo: Dictionary) -> Dictionary:
	var nombre := npc.get_nombre_visual()
	var pregunta := "¡Me alegra verte! ¿Cómo has estado? ¿Tienes algún plan para hoy?"
	if float(tiempo.get("hora_del_dia", 12.0)) >= 18.0:
		pregunta = "¡Qué bueno verte! ¿Cómo estuvo tu día? ¿Harás algo mañana?"
	match nombre.to_lower():
		"elian":
			pregunta = "¡Qué bueno verte! ¿Cómo has estado? Si tienes un rato libre, podríamos compartir algo de pan."
		"bruna":
			pregunta = "Hola. ¿Cómo va todo? ¿Tienes algún plan o vas a dejar que el día te sorprenda?"
		"darven":
			pregunta = "¿Todo bien? Te he visto por aquí y quería saber si tienes algún asunto entre manos hoy."
		"saira":
			pregunta = "¡Ah, justo a quien quería encontrar! ¿Cómo estás? ¿Tienes planes para hoy o vas a improvisar?"
		"narel":
			pregunta = "Me preguntaba cómo te ha ido estos días. ¿Tienes algún plan para hoy o algo que te interese investigar?"
	return {
		"clave": "iniciativa_amigo_" + npc.get_personaje_game_id(),
		"lineas": [{"hablante": nombre, "texto": pregunta}],
		"respuestas": _crear_respuestas_iniciativa(npc, "amistad", false),
		"_iniciativa_npc": true
	}


func _crear_respuestas_iniciativa(npc: Creature, tipo: String, completada: bool) -> Array[Dictionary]:
	var nombre := npc.get_nombre_visual().to_lower()
	var respuesta_positiva := "Me alegra escucharlo. Espero que siga yendo bien."
	var respuesta_dificil := "Vaya, lo siento. Si puedo ayudarte con algo, dímelo."
	var respuesta_neutra := "Ya veo. A veces está bien tomarse el tiempo para decidir."
	match nombre:
		"elian":
			respuesta_positiva = "Me alegra. Si necesitas descansar un poco, sabes dónde encontrarme."
			respuesta_dificil = "Lo siento. Si te sirve, puedo guardarte algo de pan para cuando vuelvas."
			respuesta_neutra = "Está bien. No hace falta tener todo resuelto desde temprano."
		"bruna":
			respuesta_positiva = "Bien. Entonces sigue a tu ritmo y no descuides los detalles."
			respuesta_dificil = "Si hay una parte que se pueda reparar o resolver, podemos pensar cómo hacerlo."
			respuesta_neutra = "No es mala idea. A veces conviene mirar antes de decidir."
		"darven":
			respuesta_positiva = "Me alegra. Mantén ese ritmo, pero no olvides revisar los riesgos."
			respuesta_dificil = "Entiendo. Si aparece un problema concreto, puedo ayudarte a buscar una solución."
			respuesta_neutra = "De acuerdo. Lo importante es tener claro qué puedes hacer y qué no."
		"saira":
			respuesta_positiva = "¡Eso suena bien! Luego me cuentas cómo salió; siempre me gustan las buenas noticias."
			respuesta_dificil = "Vaya, espero que mejore. Si escucho algo que pueda servirte, te lo haré saber."
			respuesta_neutra = "¡También vale! A veces los mejores días son los que no tienen demasiados planes."
		"narel":
			respuesta_positiva = "Interesante. Espero que puedas llevarlo a cabo; luego me gustaría saber qué descubriste."
			respuesta_dificil = "Comprendo. Quizá convenga separar lo que sabes de lo que todavía falta averiguar."
			respuesta_neutra = "Es razonable. No siempre hace falta formular una conclusión de inmediato."
	var pregunta_mision := tipo == "mision"
	if pregunta_mision and completada:
		respuesta_positiva = "Me alegra que lo hayas conseguido. Gracias por volver a contarme cómo salió."
		respuesta_dificil = "Bueno, al menos ya sabes qué salió mal. Eso también sirve para la próxima."
		respuesta_neutra = "Entiendo. Lo importante es que pudiste cerrar el asunto."
	return [
		{
			"texto": "Contarle que va bien",
			"jugador": "Va bastante bien. Estoy avanzando y creo que podré resolverlo.",
			"respuesta": respuesta_positiva,
			"evento": "interesarse",
			"clave": "iniciativa_" + tipo + "_va_bien",
			"importancia": 1.0,
			"despedida": true
		},
		{
			"texto": "Decir que ha sido difícil",
			"jugador": "La verdad, me está costando más de lo que esperaba.",
			"respuesta": respuesta_dificil,
			"evento": "apoyar",
			"clave": "iniciativa_" + tipo + "_dificil",
			"importancia": 1.0,
			"despedida": true
		},
		{
			"texto": "Responder con calma",
			"jugador": "Todavía estoy viendo cómo organizarme. Te contaré cuando tenga algo más claro.",
			"respuesta": respuesta_neutra,
			"evento": "interesarse",
			"clave": "iniciativa_" + tipo + "_calma",
			"importancia": 1.0,
			"despedida": true
		}
	]


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

	# Las cadenas narrativas principales conservan su condición de desbloqueo.
	if _mision_carreta_completada(_mission_manager):
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

	_buscar_acontecimiento_diario(jugador, tiempo, clave_dia)


func _buscar_acontecimiento_diario(
	jugador: Node2D,
	tiempo: Dictionary,
	clave_dia: String
) -> void:
	var diario_variant: Variant = _progreso_parejas.get("_acontecimientos_diarios", {})
	var diario: Dictionary = diario_variant.duplicate(true) if diario_variant is Dictionary else {}
	if str(diario.get("ultimo_dia", "")) == clave_dia:
		return
	if bool(_vistas_por_dia.get("acontecimiento_diario", false)):
		return

	var historial_variant: Variant = diario.get("historial", [])
	var historial: Array = historial_variant.duplicate(true) if historial_variant is Array else []
	var claves_recientes: Array[String] = []
	for registro_variant in historial.slice(maxi(0, historial.size() - 3)):
		if registro_variant is Dictionary:
			claves_recientes.append(str((registro_variant as Dictionary).get("clave", "")))

	# La fecha determina el orden inicial, de modo que la partida no repite
	# resultados distintos al recargar el mismo día.
	var base := posmod(int(tiempo.get("anio", 0)) * 367 + int(tiempo.get("dia", 1)), ACONTECIMIENTOS_DIARIOS.size())
	for desplazamiento in range(ACONTECIMIENTOS_DIARIOS.size()):
		var indice := posmod(base + desplazamiento, ACONTECIMIENTOS_DIARIOS.size())
		var acontecimiento: Dictionary = ACONTECIMIENTOS_DIARIOS[indice]
		var clave := str(acontecimiento.get("clave", ""))
		if clave.is_empty() or clave in claves_recientes:
			continue
		var npc_a := _npc_por_nombre.get(str(acontecimiento.get("npc_a", ""))) as Creature
		var npc_b := _npc_por_nombre.get(str(acontecimiento.get("npc_b", ""))) as Creature
		if not _npc_puede_conversar(npc_a) or not _npc_puede_conversar(npc_b):
			continue
		if npc_a.global_position.distance_to(npc_b.global_position) > DISTANCIA_ENTRE_NPC:
			continue
		if jugador.global_position.distance_to(npc_a.global_position) > DISTANCIA_JUGADOR and jugador.global_position.distance_to(npc_b.global_position) > DISTANCIA_JUGADOR:
			continue

		var evento := acontecimiento.duplicate(true)
		evento["clave"] = "diario_%s_%s" % [clave, clave_dia.replace(":", "_")]
		evento["_acontecimiento_diario"] = true
		_iniciar_conversacion(evento)
		_vistas_por_dia["acontecimiento_diario"] = true
		historial.append({"dia": clave_dia, "clave": clave})
		while historial.size() > 12:
			historial.pop_front()
		diario["ultimo_dia"] = clave_dia
		diario["ultimo_evento"] = clave
		diario["historial"] = historial
		_progreso_parejas["_acontecimientos_diarios"] = diario
		if is_instance_valid(_game_state) and _game_state.has_method("guardar_conversaciones_npc"):
			_game_state.call("guardar_conversaciones_npc", _progreso_parejas)
		return


func _guardar_objeto_del_acontecimiento() -> void:
	var etiqueta := str(_conversacion_activa.get("objeto_visual", "")).strip_edges()
	if etiqueta.is_empty():
		return
	var npc_nombre := str(_conversacion_activa.get("npc_b", "")).strip_edges().to_lower()
	var npc := _npc_por_nombre.get(npc_nombre) as Creature
	if not is_instance_valid(npc):
		return
	var tiempo := _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var clave_dia := "%d:%d" % [int(tiempo.get("anio", 0)), int(tiempo.get("dia", 1))]
	var diario_variant: Variant = _progreso_parejas.get("_acontecimientos_diarios", {})
	var diario: Dictionary = diario_variant.duplicate(true) if diario_variant is Dictionary else {}
	diario["objeto_dia"] = clave_dia
	diario["objeto_etiqueta"] = etiqueta
	diario["objeto_tipo"] = str(_conversacion_activa.get("tipo_visual", "paquete"))
	var posicion_objeto := npc.global_position + Vector2(20.0, 12.0)
	diario["objeto_posicion"] = [posicion_objeto.x, posicion_objeto.y]
	_progreso_parejas["_acontecimientos_diarios"] = diario
	if is_instance_valid(_game_state) and _game_state.has_method("guardar_conversaciones_npc"):
		_game_state.call("guardar_conversaciones_npc", _progreso_parejas)
	_restaurar_objeto_evento_diario(tiempo)


func _restaurar_objeto_evento_diario(tiempo: Dictionary) -> void:
	var zona := _zone_manager.obtener_zona_actual() as Node2D if is_instance_valid(_zone_manager) else null
	if not is_instance_valid(zona):
		return
	var diario_variant: Variant = _progreso_parejas.get("_acontecimientos_diarios", {})
	if not diario_variant is Dictionary:
		return
	var diario := diario_variant as Dictionary
	var clave_dia := "%d:%d" % [int(tiempo.get("anio", 0)), int(tiempo.get("dia", 1))]
	if str(diario.get("objeto_dia", "")) != clave_dia:
		if is_instance_valid(_objeto_evento_diario):
			_objeto_evento_diario.queue_free()
		_objeto_evento_diario = null
		_zona_objeto_evento = null
		return
	if is_instance_valid(_objeto_evento_diario) and _zona_objeto_evento != zona:
		_objeto_evento_diario.queue_free()
		_objeto_evento_diario = null
		_zona_objeto_evento = null
	if is_instance_valid(_objeto_evento_diario):
		return
	var posicion_variant: Variant = diario.get("objeto_posicion", [])
	if not posicion_variant is Array or (posicion_variant as Array).size() < 2:
		return
	var posicion_datos := posicion_variant as Array
	var posicion := Vector2(float(posicion_datos[0]), float(posicion_datos[1]))
	var etiqueta := str(diario.get("objeto_etiqueta", "")).strip_edges()
	if etiqueta.is_empty():
		return
	_crear_objeto_visual_evento(zona, posicion, etiqueta, str(diario.get("objeto_tipo", "paquete")))


func _crear_objeto_visual_evento(zona: Node2D, posicion: Vector2, etiqueta: String, tipo: String) -> void:
	var objeto := Node2D.new()
	objeto.name = "DailyEventProp"
	objeto.z_index = 12
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-10.0, -5.0), Vector2(10.0, -5.0),
		Vector2(10.0, 5.0), Vector2(-10.0, 5.0)
	])
	var acento := Polygon2D.new()
	acento.polygon = PackedVector2Array([
		Vector2(-10.0, -5.0), Vector2(10.0, -5.0),
		Vector2(10.0, -2.0), Vector2(-10.0, -2.0)
	])
	match tipo:
		"notas":
			base.color = Color("#D6C49A")
			acento.color = Color("#806B4D")
			base.polygon = PackedVector2Array([Vector2(-9,-6),Vector2(9,-6),Vector2(9,6),Vector2(-9,6)])
			acento.polygon = PackedVector2Array([Vector2(-5,-6),Vector2(-3,-6),Vector2(-3,6),Vector2(-5,6)])
		"metal":
			base.color = Color("#85877F")
			acento.color = Color("#C3BDA7")
			base.polygon = PackedVector2Array([Vector2(-9,-3),Vector2(-5,-7),Vector2(7,-7),Vector2(10,-2),Vector2(7,5),Vector2(-7,5)])
		"cartel":
			base.color = Color("#765035")
			acento.color = Color("#C8AD7A")
			base.polygon = PackedVector2Array([Vector2(-2,-11),Vector2(2,-11),Vector2(2,9),Vector2(-2,9)])
		"pan":
			base.color = Color("#B9854E")
			acento.color = Color("#E0BB7B")
			base.polygon = PackedVector2Array([Vector2(-9,2),Vector2(-8,-3),Vector2(-4,-7),Vector2(5,-7),Vector2(9,-2),Vector2(8,4),Vector2(3,7),Vector2(-6,6)])
		_:
			base.color = Color("#8B6847")
			acento.color = Color("#D4B17A")
	objeto.add_child(base)
	objeto.add_child(acento)
	var sombra := Polygon2D.new()
	sombra.polygon = PackedVector2Array([Vector2(-12,7),Vector2(12,7),Vector2(9,10),Vector2(-9,10)])
	sombra.color = Color(0.05, 0.035, 0.02, 0.42)
	objeto.add_child(sombra)
	objeto.move_child(sombra, 0)
	var nombre := Label.new()
	nombre.text = etiqueta
	nombre.position = Vector2(-34.0, -25.0)
	nombre.custom_minimum_size = Vector2(68.0, 0.0)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.add_theme_font_override("font", FONT_PIXEL)
	nombre.add_theme_font_size_override("font_size", 7)
	nombre.add_theme_color_override("font_color", Color("#F2E8D8"))
	nombre.add_theme_color_override("font_outline_color", Color("#17110D"))
	nombre.add_theme_constant_override("outline_size", 2)
	objeto.add_child(nombre)
	zona.add_child(objeto)
	objeto.global_position = posicion
	_objeto_evento_diario = objeto
	_zona_objeto_evento = zona


func _obtener_npcs_torres() -> Array[Creature]:
	var resultado: Array[Creature] = []
	_npc_por_nombre.clear()
	_npc_por_id.clear()
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if not nodo is Creature or not is_instance_valid(nodo):
			continue
		var npc := nodo as Creature
		var clave := npc.get_nombre_visual().strip_edges().to_lower()
		if clave.is_empty():
			continue
		_npc_por_nombre[clave] = npc
		var personaje_id := npc.get_personaje_game_id().strip_edges()
		if not personaje_id.is_empty():
			_npc_por_id[personaje_id] = npc
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


func _mostrar_linea_actual(reiniciar_temporizador: bool = true) -> void:
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
	if reiniciar_temporizador:
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



## Después de cada acontecimiento, los participantes realizan una acción
## breve relacionada con lo que acaban de hablar.
func _iniciar_actividad_del_acontecimiento() -> void:
	var clave := str(_conversacion_activa.get("clave", ""))
	var actividades: Dictionary = {
		"elian_saira_paquete": {"destino": Vector2(-205.0, -78.0), "duracion": 4.0},
		"bruna_darven_cartel": {"destino": Vector2(0.0, 0.0), "duracion": 6.0},
		"narel_saira_noticia": {"destino": Vector2(-370.0, -482.0), "duracion": 7.0},
		"elian_bruna_pan": {"destino": Vector2(0.0, 0.0), "duracion": 9.0},
		"darven_narel_turno": {"destino": Vector2(690.0, -170.0), "duracion": 6.0},
		"bruna_saira_cierre": {"destino": Vector2(-320.0, -122.0), "duracion": 7.0},
		"elian_darven_merienda": {"destino": Vector2(-205.0, -78.0), "duracion": 10.0},
		"narel_bruna_medidas": {"destino": Vector2(-320.0, -122.0), "duracion": 8.0}
	}
	var actividad_variant: Variant = actividades.get(clave, {})
	if not actividad_variant is Dictionary or actividad_variant.is_empty():
		return
	var actividad: Dictionary = actividad_variant
	var sistema := get_tree().get_first_node_in_group("npc_schedule_system")
	if not is_instance_valid(sistema) or not sistema.has_method("iniciar_actividad_social"):
		return
	var npc_a := _npc_por_nombre.get(str(_conversacion_activa.get("npc_a", ""))) as Creature
	var npc_b := _npc_por_nombre.get(str(_conversacion_activa.get("npc_b", ""))) as Creature
	if not _npc_puede_conversar(npc_a) or not _npc_puede_conversar(npc_b):
		return
	var destino: Vector2 = actividad.get("destino", Vector2.ZERO)
	var duracion := float(actividad.get("duracion", 5.0))
	# Ambos participantes acuden al mismo punto: entrega, encuentro, comida
	# compartida, revisión o consulta según el acontecimiento del día.
	var desplazamiento := Vector2(24.0, 0.0)
	var inicio_a: bool = bool(sistema.call("iniciar_actividad_social", npc_a, destino + desplazamiento, duracion))
	var inicio_b: bool = bool(sistema.call("iniciar_actividad_social", npc_b, destino - desplazamiento, duracion))
	if inicio_a and inicio_b:
		var zona := _zone_manager.obtener_zona_actual() as Node2D if is_instance_valid(_zone_manager) else null
		if is_instance_valid(zona):
			cinematica_acontecimiento_solicitada.emit(zona.to_global(destino))


func _ocultar_burbujas() -> void:
	for burbuja_variant in _burbujas.values():
		var burbuja := burbuja_variant as PanelContainer
		if is_instance_valid(burbuja):
			burbuja.visible = false


func _finalizar_conversacion(completada: bool = false) -> void:
	if completada and bool(_conversacion_activa.get("_acontecimiento_diario", false)):
		_guardar_objeto_del_acontecimiento()
		_iniciar_actividad_del_acontecimiento()
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
			if not bool(_conversacion_activa.get("_acontecimiento_diario", false)) and etapa < 3:
				var npc_a_cinematica := _npc_por_nombre.get(str(_conversacion_activa.get("npc_a", ""))) as Creature
				var npc_b_cinematica := _npc_por_nombre.get(str(_conversacion_activa.get("npc_b", ""))) as Creature
				if is_instance_valid(npc_a_cinematica) and is_instance_valid(npc_b_cinematica):
					var centro_cinematica := (npc_a_cinematica.global_position + npc_b_cinematica.global_position) * 0.5
					cinematica_narrativa_solicitada.emit(
						clave,
						npc_a_cinematica.get_nombre(),
						npc_b_cinematica.get_nombre(),
						centro_cinematica,
						etapa + 1
					)
	_ocultar_burbujas()
	_conversacion_activa.clear()
	_indice_linea = 0
	_temporizador_linea = 0.0
