extends RefCounted
class_name SharedAssetLibrary

## Punto único de acceso a recursos visuales compartidos.
## ResourceLoader ya mantiene caché propia; esta capa evita además repetir
## búsquedas, conversiones de tipo y carga desde cada sistema de presentación.

static var _recursos: Dictionary = {}
static var _rutas_ausentes: Dictionary = {}


static func obtener_recurso(ruta: String) -> Resource:
	var clave := ruta.strip_edges()
	if clave.is_empty():
		return null

	var referencia_cache: Variant = _recursos.get(clave)
	if referencia_cache is WeakRef:
		var recurso_cache: Variant = (referencia_cache as WeakRef).get_ref()
		if recurso_cache is Resource and is_instance_valid(recurso_cache):
			return recurso_cache as Resource
		_recursos.erase(clave)
	if _rutas_ausentes.has(clave):
		return null
	if not ResourceLoader.exists(clave):
		_rutas_ausentes[clave] = true
		return null

	var recurso := ResourceLoader.load(clave)
	if recurso != null:
		_recursos[clave] = weakref(recurso)
	return recurso


static func textura(ruta: String) -> Texture2D:
	return obtener_recurso(ruta) as Texture2D


static func escena(ruta: String) -> PackedScene:
	return obtener_recurso(ruta) as PackedScene


## Útil para herramientas del editor cuando un recurso cambia en caliente.
static func invalidar(ruta: String = "") -> void:
	if ruta.strip_edges().is_empty():
		_recursos.clear()
		_rutas_ausentes.clear()
	else:
		var clave := ruta.strip_edges()
		_recursos.erase(clave)
		_rutas_ausentes.erase(clave)
