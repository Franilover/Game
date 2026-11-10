extends SceneTree

const ATMOSPHERE_SCRIPT = preload("res://scripts/world/world_atmosphere.gd")
const CLIMATE_SCRIPT = preload("res://scripts/world/world_climate_system.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var noche_inicio: Color = ATMOSPHERE_SCRIPT.calcular_color_iluminacion(0.0)
	var noche_final: Color = ATMOSPHERE_SCRIPT.calcular_color_iluminacion(1.0)
	var amanecer: Color = ATMOSPHERE_SCRIPT.calcular_color_iluminacion(0.25)
	var mediodia: Color = ATMOSPHERE_SCRIPT.calcular_color_iluminacion(0.50)
	var atardecer: Color = ATMOSPHERE_SCRIPT.calcular_color_iluminacion(0.79)

	if not noche_inicio.is_equal_approx(noche_final):
		_fail("The lighting gradient must wrap seamlessly across midnight.")
		return
	if amanecer.r <= amanecer.b or atardecer.r <= atardecer.b:
		_fail("Dawn and sunset must retain their warm orange palette.")
		return
	if mediodia.r <= atardecer.r or mediodia.g <= atardecer.g:
		_fail("Midday must remain brighter and more neutral than sunset.")
		return

	var climate = CLIMATE_SCRIPT.new()
	root.add_child(climate)
	if climate.obtener_clima_id() != "despejado":
		_fail("The initial climate must be clear.")
		return
	if not climate.establecer_clima("lluvia", 0.8, 0.0):
		_fail("A supported weather profile was rejected.")
		return
	var lluvia: Dictionary = climate.obtener_estado()["clima"]
	if float(lluvia.get("precipitacion", 0.0)) <= 0.0:
		_fail("Rain must expose a positive precipitation value.")
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

	print("PASS: cyclic dawn/day/sunset gradient, weather profiles, precipitation state, and natural phenomenon lifecycle.")
	quit()


func _fail(message: String) -> void:
	push_error("World climate regression: " + message)
	quit(1)
