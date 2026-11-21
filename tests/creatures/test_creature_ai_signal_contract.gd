extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const CombatDamageScript = preload("res://scripts/gameplay/combat/combat_damage.gd")
const EntityScript = preload("res://scripts/characters/entity.gd")
const AtmosphereScript = preload("res://scripts/world/world_atmosphere.gd")


class MockClimateSystem extends Node:
	var consultas: int = 0

	func obtener_estado_para_contexto(_contexto: Dictionary) -> Dictionary:
		consultas += 1
		return {
			"ambiente": {"temperatura_c": 20.0},
			"clima": {"visibilidad": 0.8},
			"eventos": []
		}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var criatura := CreatureScene.instantiate() as Creature
	get_tree().root.add_child(criatura)
	await get_tree().process_frame

	if criatura == null or not is_instance_valid(criatura):
		_fail(errores, "No se pudo instanciar la escena de Creature.")
		return

	var ai := criatura.get_node_or_null("AIController") as CreatureAI
	if ai == null:
		_fail(errores, "La escena no contiene CreatureAI.")
		return

	var config_ia := {
		"perfil": "espiritu_estelar",
		"al_recibir_danio": {
			"tipo": "teletransportarse",
			"inmunidad": 0.8,
			"distancia_minima": 24.0,
			"distancia_maxima": 24.0
		}
	}
	criatura.configurar({
		"id": "creature-ai-signal-test",
		"nombre": "Espiritu Estelar",
		"stats_dnd": {"hp_max": 140, "defensa": 3},
		"ia_config": config_ia
	})

	if ai.perfil != CreatureAI.Perfil.ESPIRITU_ESTELAR:
		errores.append("CreatureAI no recibió la configuración actualizada de su Creature.")

	# El contexto climático se consulta una vez y se reutiliza hasta el siguiente
	# tick ambiental; evita una copia profunda por criatura en cada physics frame.
	var atmosfera := AtmosphereScript.new() as WorldAtmosphere
	var modulacion := CanvasModulate.new()
	modulacion.name = "DayNightModulation"
	atmosfera.add_child(modulacion)
	var clima := MockClimateSystem.new()
	clima.name = "ClimateSystem"
	atmosfera.add_child(clima)
	get_tree().root.add_child(atmosfera)
	criatura.datos["bioma_id"] = "bioma-cache-test"
	ai.world_atmosphere = atmosfera
	ai._estado_ambiental_cache_valido = false
	var ambiente_a := ai._obtener_estado_ambiental()
	var ambiente_b := ai._obtener_estado_ambiental()
	if clima.consultas != 1 or ambiente_a != ambiente_b:
		errores.append("CreatureAI consultó repetidamente el mismo contexto climático dentro del intervalo.")
	ai._refrescar_estado_ambiental_cache()
	if clima.consultas != 2:
		errores.append("CreatureAI no actualizó el contexto climático al solicitar un refresh.")

	if (
		criatura.max_health != 140
		or criatura.health != 140
		or criatura.vital_state.max_health != 140
		or criatura.vital_state.health != 140
	):
		errores.append("Creature no sincronizó max_health/health con VitalState al configurarse.")

	var evento_danio := {"cantidad": 0, "atacante": null}
	criatura.danio_recibido.connect(
		func(cantidad: int, atacante: Node) -> void:
			evento_danio["cantidad"] = cantidad
			evento_danio["atacante"] = atacante
	)

	var atacante := EntityScript.new() as Entity
	get_tree().root.add_child(atacante)
	var salud_antes := criatura.health
	var danio_aplicado := CombatDamageScript.aplicar_y_obtener_danio(
		criatura,
		7,
		"Prueba/SenalDanio",
		Callable(),
		atacante
	)
	if danio_aplicado != 4:
		errores.append("CombatDamage no devolvió el daño efectivo posterior a defensa de Creature.")

	if criatura.health != salud_antes - 4:
		errores.append("Creature no aplicó su defensa antes de reducir la salud.")
	if int(evento_danio["cantidad"]) != 4:
		errores.append("Creature no emitió la cantidad de daño posterior a defensa.")
	if evento_danio["atacante"] != atacante:
		errores.append("Creature no conservó el atacante al emitir el evento.")
	if ai._tiempo_teleport <= 0.0:
		errores.append("CreatureAI no reaccionó al evento de daño recibido.")

	# La defensa no puede convertir el daño entrante en daño negativo ni
	# impedir que un golpe letal derrote a la criatura.
	criatura.stats_dnd["defensa"] = 0
	var muertes := {"cantidad": 0}
	criatura.died.connect(
		func() -> void:
			muertes["cantidad"] = int(muertes["cantidad"]) + 1
	)
	criatura.take_damage(200, "Prueba/MuerteCriatura")
	if criatura.is_alive or criatura.vital_state.is_alive:
		errores.append("La muerte de Creature no sincronizó el estado vital de Entity.")
	if int(muertes["cantidad"]) != 1:
		errores.append("Creature no emitió died exactamente una vez.")
	criatura._die()
	if int(muertes["cantidad"]) != 1:
		errores.append("La llamada repetida a Creature._die() duplicó died.")

	atacante.queue_free()
	criatura.queue_free()
	atmosfera.queue_free()
	await get_tree().process_frame

	if not errores.is_empty():
		_fail(errores, "")
		return

	print("CreatureAISignalContract: PASS")
	get_tree().quit(0)


func _fail(errores: Array[String], mensaje: String) -> void:
	if not mensaje.is_empty():
		errores.append(mensaje)
	for error in errores:
		push_error("CreatureAISignalContract: FAIL: " + error)
	get_tree().quit(1)
