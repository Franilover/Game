extends RefCounted
class_name WorldRuntime

## Estado runtime del mundo. No genera terreno ni conoce UI.

var state := WorldState.new()
var discovery := DiscoveryState.new()

func establecer_semilla(semilla: int) -> void:
	state.world_seed = semilla
	state.world_seed_valida = true

func obtener_semilla() -> int:
	return state.world_seed

func establecer_escena(ruta: String) -> void:
	state.current_scene = ruta

func avanzar_tiempo(delta: float) -> void:
	state.elapsed_time += maxf(delta, 0.0)

func registrar_descubrimiento_mundo(
	bioma: Dictionary,
	ecosistema: Dictionary,
	habitats: Array,
	criaturas: Array
) -> bool:
	var nuevo := false

	var bioma_id := str(bioma.get("id", ""))
	if discovery.registrar_bioma(bioma_id):
		nuevo = true

	var ecosistema_id := str(ecosistema.get("id", ""))
	if discovery.registrar_ecosistema(ecosistema_id):
		nuevo = true

	for value in habitats:
		if value is Dictionary and discovery.registrar_habitat(str((value as Dictionary).get("id", ""))):
			nuevo = true

	for value in criaturas:
		if value is Dictionary and discovery.registrar_criatura(str((value as Dictionary).get("id", ""))):
			nuevo = true

	return nuevo
