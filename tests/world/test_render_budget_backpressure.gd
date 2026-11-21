extends SceneTree

const RenderManagerScript = preload("res://scripts/world/render/garlia_render_manager.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var manager = RenderManagerScript.new()
	root.add_child(manager)

	manager._frame_start_usec = 0
	var normal_budget := manager.presupuesto_unidades_adaptativo(
		"terrain_variation", 64, 16, 64, 0.85
	)
	assert(normal_budget == 16, "Con presupuesto disponible debe respetar el mínimo normal.")

	manager._frame_start_usec = Time.get_ticks_usec() - 10000
	var exhausted_budget := manager.presupuesto_unidades_adaptativo(
		"terrain_variation", 64, 16, 64, 0.85
	)
	assert(exhausted_budget == 1, "Sin presupuesto debe ceder el frame y procesar como máximo una unidad.")

	print("RenderBudgetBackpressure: PASS normal=%d exhausted=%d" % [normal_budget, exhausted_budget])
	quit(0)
