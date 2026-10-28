extends SceneTree

const GARUMI_SCENE: PackedScene = preload("res://scenes/creatures/garumi.tscn")

var _errores: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var garumi := GARUMI_SCENE.instantiate() as Garumi
	root.add_child(garumi)
	await process_frame

	garumi.configurar({
		"id": "garumi-brain-test",
		"nombre": "Garumi de prueba",
		"ia_config": {
			"garumi": {
				"movimiento": {
					"perfil": "juguetón",
					"radio_social": 120.0,
					"distancia_preferida": 40.0
				},
				"comportamiento": {
					"curiosidad": 0.8,
					"temor": 0.2
				},
				"elementos": ["terava", "lumora", "terava"]
			}
		}
	})

	var cerebro := garumi.get_node_or_null("GarumiBrain") as GarumiBrain
	_expect(cerebro != null, "La escena debe crear el cerebro propio de Garumi.")
	if cerebro != null:
		_expect(cerebro._perfil == "jugueton", "El perfil debe normalizar acentos sin cambiar el identificador mecánico.")
		_expect(cerebro._tiene_perfil_ejecutable(), "El perfil juguetón debe estar soportado.")
		_expect(cerebro.obtener_elementos().size() == 2, "Debe conservar afinidades elementales únicas.")
		_expect(cerebro.obtener_elementos().has("terava"), "Debe leer el primer elemento desde ia_config.")
		_expect(cerebro.obtener_elementos().has("lumora"), "Debe leer el segundo elemento desde ia_config.")
		_expect(float(cerebro.obtener_comportamiento().get("curiosidad", 0.0)) == 0.8, "Debe conservar rasgos de comportamiento.")
		garumi.configurar({
			"id": "garumi-brain-unknown-test",
			"nombre": "Perfil desconocido",
			"ia_config": {"garumi": {"movimiento": {"perfil": "perfil_inventado"}}}
		})
		_expect(not cerebro._tiene_perfil_ejecutable(), "Un perfil desconocido no debe convertirse en otra conducta.")

	garumi.queue_free()
	if _errores.is_empty():
		print("test_garumi_brain: OK")
		quit(0)
	else:
		for error in _errores:
			push_error(error)
		quit(1)


func _expect(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_errores.append(mensaje)
