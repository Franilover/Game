extends RefCounted
class_name SharedAssetLibrary

## Punto único de acceso a recursos visuales compartidos.
## ResourceLoader ya mantiene caché propia; esta capa evita además repetir
## búsquedas, conversiones de tipo y carga desde cada sistema de presentación.

static var _recursos: Dictionary = {}


static func obtener_recurso(ruta: String) -> Resource:
	var clave := ruta.strip_edges()
	if clave.is_empty():
		return null

	var recurso_cache: Variant = _recursos.get(clave)
	if recurso_cache is Resource and is_instance_valid(recurso_cache):
		return recurso_cache as Resource
	if not ResourceLoader.exists(clave):
		return null

	var recurso := ResourceLoader.load(clave)
	if recurso != null:
		_recursos[clave] = recurso
	return recurso


static func textura(ruta: String) -> Texture2D:
	return obtener_recurso(ruta) as Texture2D


static func escena(ruta: String) -> PackedScene:
	return obtener_recurso(ruta) as PackedScene


## Útil para herramientas del editor cuando un recurso cambia en caliente.
static func invalidar(ruta: String = "") -> void:
	if ruta.strip_edges().is_empty():
		_recursos.clear()
	else:
		_recursos.erase(ruta.strip_edges())
