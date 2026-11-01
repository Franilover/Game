extends Node
## Preferencias de audio locales. Los buses se crean aquí para que la mezcla
## funcione incluso si el proyecto todavía no tiene pistas de audio.

const CONFIG_PATH := "user://audio_settings.cfg"
const BUS_GENERAL := "Master"
const BUS_MUSICA := "Musica"
const BUS_EFECTOS := "Efectos"

var _volumenes: Dictionary = {
	BUS_GENERAL: 1.0,
	BUS_MUSICA: 1.0,
	BUS_EFECTOS: 1.0
}


func _ready() -> void:
	_asegurar_bus(BUS_MUSICA)
	_asegurar_bus(BUS_EFECTOS)
	_cargar()
	_aplicar_todos()


func obtener_volumen(bus_nombre: String) -> float:
	return float(_volumenes.get(bus_nombre, 1.0))


func establecer_volumen(bus_nombre: String, valor: float) -> void:
	if not _volumenes.has(bus_nombre):
		push_warning("AudioSettings: bus desconocido: " + bus_nombre)
		return

	var volumen := clampf(valor, 0.0, 1.0)
	_volumenes[bus_nombre] = volumen
	_aplicar_bus(bus_nombre)
	_guardar()


func _asegurar_bus(nombre: String) -> void:
	var indice := AudioServer.get_bus_index(nombre)
	if indice >= 0:
		return

	AudioServer.add_bus()
	indice = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(indice, nombre)
	AudioServer.set_bus_send(indice, BUS_GENERAL)


func _aplicar_todos() -> void:
	for nombre in _volumenes.keys():
		_aplicar_bus(str(nombre))


func _aplicar_bus(nombre: String) -> void:
	var indice := AudioServer.get_bus_index(nombre)
	if indice < 0:
		push_warning("AudioSettings: no existe el bus " + nombre)
		return

	var volumen := obtener_volumen(nombre)
	AudioServer.set_bus_mute(indice, volumen <= 0.0)
	AudioServer.set_bus_volume_db(
		indice,
		linear_to_db(maxf(volumen, 0.0001))
	)


func _cargar() -> void:
	var config := ConfigFile.new()
	var error := config.load(CONFIG_PATH)
	if error != OK:
		return

	for nombre in _volumenes.keys():
		_volumenes[nombre] = clampf(
			float(config.get_value("audio", str(nombre), 1.0)),
			0.0,
			1.0
		)


func _guardar() -> void:
	var config := ConfigFile.new()
	for nombre in _volumenes.keys():
		config.set_value("audio", str(nombre), obtener_volumen(str(nombre)))

	var error := config.save(CONFIG_PATH)
	if error != OK:
		push_warning("AudioSettings: no se pudieron guardar las preferencias.")
