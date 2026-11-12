extends SceneTree

const ATMOSPHERE_SCRIPT = preload("res://scripts/world/world_atmosphere.gd")
const CLIMATE_SCRIPT = preload("res://scripts/world/world_climate_system.gd")
const WORLD_DATA_SCRIPT = preload("res://scripts/world/world_data.gd")
const CREATURE_AI_SCRIPT = preload("res://scripts/creatures/creature_ai.gd")
const CREATURE_SCRIPT = preload("res://scripts/creatures/creature.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var atmosphere = ATMOSPHERE_SCRIPT.new()
	var noche_inicio: Color = atmosphere.calcular_color_iluminacion(0.0)
	var noche_final: Color = atmosphere.calcular_color_iluminacion(1.0)
	var amanecer: Color = atmosphere.calcular_color_iluminacion(0.25)
	var mediodia: Color = atmosphere.calcular_color_iluminacion(0.50)
	var atardecer: Color = atmosphere.calcular_color_iluminacion(0.79)

	print("ClimateTest: default lighting passed.")
	if not noche_inicio.is_equal_approx(noche_final):
		_fail("The lighting gradient must wrap seamlessly across midnight.")
		return
	if amanecer.r <= amanecer.b or atardecer.r <= atardecer.b:
		_fail("Dawn and sunset must retain their warm orange palette.")
		return
	if mediodia.r <= atardecer.r or mediodia.g <= atardecer.g:
		_fail("Midday must remain brighter and more neutral than sunset.")
		return

	# Cada estación puede definir su propia paleta y sus propios horarios.
	atmosphere.estacion_actual = {
		"config_visual": {
			"horarios": {
				"amanecer_inicio": 0.10,
				"amanecer_fin": 0.24,
				"atardecer_inicio": 0.62,
				"atardecer_fin": 0.78
			},
			"claves_luz": [
				{"hora": 0.0, "color": "#101020"},
				{"hora": 0.5, "color": "#ffffff"},
				{"hora": 1.0, "color": "#101020"}
			]
		}
	}
	if not atmosphere.calcular_color_iluminacion(0.5).is_equal_approx(Color("#ffffff")):
		_fail("A station-specific lighting palette was not used.")
		return
	atmosphere.horas_por_dia = 25.0
	atmosphere.hora_del_dia = 25.0 * 0.15
	if atmosphere._obtener_periodo() != "Amanecer":
		_fail("Station-specific dawn timing was not applied.")
		return
	atmosphere.estacion_actual = {}

	var climate = CLIMATE_SCRIPT.new()
	climate.name = "ClimateSystem"
	atmosphere.add_child(climate)
	if climate.obtener_clima_id() != "despejado":
		_fail("The initial climate must be clear.")
		return
	# La seleccion diaria acepta reglas de Supabase y se mantiene determinista
	# para la misma fecha, estación y hábitat.
	atmosphere.estacion_actual = {
		"id": "season-test",
		"config_climatica": {
			"transicion_segundos": 0.0,
			"perfiles": [{"tipo": "despejado", "peso": 1.0}],
			"eventos": [{
				"clave": "evento_prueba",
				"dia_inicio": 1,
				"dia_fin": 1,
				"probabilidad_diaria": 1.0,
				"efectos": {"actividad_criaturas": "reposar"}
			}],
			"habitats": {
				"habitat-frio": {
					"perfiles": [{
						"tipo": "niebla",
						"peso": 1.0,
						"intensidad_min": 1.0,
						"intensidad_max": 1.0,
						"efectos": {"visibilidad": 0.2}
					}]
				}
			}
		}
	}
	var world_data = WORLD_DATA_SCRIPT.new()
	world_data.mundo = {
		"ambiente_estacional": {
			"season-test": {
				"habitats": {
					"habitat-frio": {
						"temperatura_media": {"valor": 260.15},
						"humedad_relativa": {"valor": 0.9},
						"disponibilidad_agua": {"valor": 0.7},
						"velocidad_medio": {"valor": 0.1}
					}
				}
			}
		}
	}
	print("ClimateTest: configuring climate dependencies.")
	climate.configurar_dependencias(world_data, atmosphere)
	print("ClimateTest: climate dependencies configured.")
	var niebla_a: Dictionary = climate.obtener_estado_para_contexto({"habitat_id": "habitat-frio"})
	climate._estados_contexto_cache.clear()
	var niebla_b: Dictionary = climate.obtener_estado_para_contexto({"habitat_id": "habitat-frio"})
	if niebla_a != niebla_b:
		_fail("The same habitat and world date must resolve to the same climate.")
		return
	if (niebla_a.get("eventos", []) as Array).size() != 1:
		_fail("Habitat-specific weather rules must inherit station-wide seasonal events.")
		return
	var clima_niebla: Dictionary = niebla_a.get("clima", {})
	if str(clima_niebla.get("tipo", "")) != "niebla" or float(clima_niebla.get("visibilidad", 1.0)) > 0.21:
		_fail("Habitat-specific fog rules did not reduce visibility.")
		return
	var ambiente_frio: Dictionary = niebla_a.get("ambiente", {})
	if not is_equal_approx(float(ambiente_frio.get("temperatura_c", 0.0)), -14.0):
		_fail("Seasonal habitat temperature was not converted from Kelvin and combined with weather.")
		return
	var criatura = CREATURE_SCRIPT.new()
	criatura.datos = {"habitat_id": "habitat-frio"}
	var ai = CREATURE_AI_SCRIPT.new()
	ai.criatura = criatura
	ai.world_atmosphere = atmosphere
	if not is_equal_approx(ai._obtener_distancia_deteccion(), 30.0):
		_fail("Fog did not reduce creature detection distance.")
		return
	if not is_equal_approx(ai._obtener_modificador_velocidad_ambiental(), 0.78):
		_fail("Cold did not reduce creature movement speed.")
		return
	ai._aplicar_respuesta_ambiental_rutina()
	if ai.actividad_horaria != "reposar":
		_fail("Cold did not change the creature's activity routine.")
		return
	print("ClimateTest: fog, temperature and creature AI passed.")
	var clima_despejado: Dictionary = climate.obtener_estado_para_contexto({}).get("clima", {})
	if str(clima_despejado.get("tipo", "")) != "despejado":
		_fail("The station-wide climate profile was not used as fallback.")
		return

	var eventos: Array = climate.obtener_estado_para_contexto({}).get("eventos", [])
	if eventos.size() != 1 or str(eventos[0].get("clave", "")) != "evento_prueba":
		_fail("Seasonal events were not resolved from the station configuration.")
		return

	atmosphere.dia_del_anio = 2
	atmosphere.estacion_actual["dia_de_estacion"] = 2
	var eventos_dia_dos: Array = climate.obtener_estado_para_contexto({}).get("eventos", [])
	if not eventos_dia_dos.is_empty():
		_fail("Seasonal events must respect their configured day window.")
		return
	atmosphere.dia_del_anio = 1
	atmosphere.estacion_actual["dia_de_estacion"] = 1

	print("ClimateTest: seasonal event checks passed.")
	if not climate.establecer_clima("lluvia", 0.8, 0.0):
		_fail("A supported weather profile was rejected.")
		return
	var lluvia: Dictionary = climate.obtener_estado()["clima"]
	if float(lluvia.get("precipitacion", 0.0)) <= 0.0:
		_fail("Rain must expose a positive precipitation value.")
		return
	if not climate.establecer_clima("despejado", 1.0, 1.0):
		_fail("A gradual weather transition could not be started.")
		return
	climate._actualizar_transicion_clima(0.5)
	var transicion: Dictionary = climate.obtener_estado()
	var precipitacion_intermedia := float(transicion["clima"].get("precipitacion", -1.0))
	if precipitacion_intermedia <= 0.0 or precipitacion_intermedia >= float(lluvia["precipitacion"]):
		_fail("Weather transition did not interpolate smoothly from its origin.")
		return
	climate._actualizar_transicion_clima(0.5)
	if bool(climate.obtener_estado()["en_transicion"]):
		_fail("Weather transition did not finish at its configured duration.")
		return
	if climate.establecer_clima("clima_inexistente"):
		_fail("An unknown weather profile must be rejected.")
		return
	if not climate.iniciar_fenomeno("terremoto", 0.7, 0.0):
		_fail("Earthquake phenomenon was rejected.")
		return
	if not climate.obtener_estado()["fenomenos"].has("terremoto"):
		_fail("Active natural phenomena must be queryable.")
		return
	if not climate.finalizar_fenomeno("terremoto"):
		_fail("An active phenomenon could not be finalized.")
		return

	print("PASS: seasonal lighting, deterministic local weather, fog visibility, thermal creature responses, seasonal events, and phenomena.")
	quit()


func _fail(message: String) -> void:
	push_error("World climate regression: " + message)
	quit(1)
