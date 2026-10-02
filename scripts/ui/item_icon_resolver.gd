extends RefCounted
class_name ItemIconResolver


const ITEMS_ASSET_ROOT: String = "res://assets/art/items"

const EXTENSIONES_IMAGEN: Array[String] = [
	"png",
	"webp",
	"jpg",
	"jpeg"
]


static var _indice_listo: bool = false
static var _rutas_por_nombre: Dictionary = {}
static var _entradas: Array[Dictionary] = []


static func obtener_icono(
	datos: Dictionary
) -> Texture2D:
	if datos.is_empty():
		return null

	var icono: Variant = datos.get(
		"icono",
		null
	)

	if icono is Texture2D:
		return icono

	var nombre := str(
		datos.get(
			"nombre",
			""
		)
	).strip_edges()

	if nombre.is_empty():
		return null

	_asegurar_indice()

	var clave := _normalizar_nombre(
		nombre
	)

	if _rutas_por_nombre.has(clave):
		return _cargar_textura(
			str(_rutas_por_nombre[clave])
		)

	var tokens_item := _normalizar_tokens(
		nombre
	)

	for entrada in _entradas:
		var tokens_sprite: Array[String] = entrada.get(
			"tokens",
			[]
		)

		if not _nombres_compatibles(
			tokens_item,
			tokens_sprite
		):
			continue

		return _cargar_textura(
			str(
				entrada.get(
					"ruta",
					""
				)
			)
		)

	return null


static func _asegurar_indice() -> void:
	if _indice_listo:
		return

	_indice_listo = true

	_rutas_por_nombre.clear()
	_entradas.clear()

	_indexar_directorio(
		ITEMS_ASSET_ROOT
	)


static func _indexar_directorio(
	ruta: String
) -> void:
	var directorio := DirAccess.open(
		ruta
	)

	if directorio == null:
		return

	directorio.list_dir_begin()

	while true:
		var nombre_archivo := directorio.get_next()

		if nombre_archivo.is_empty():
			break

		var ruta_completa := ruta.path_join(
			nombre_archivo
		)

		if directorio.current_is_dir():
			_indexar_directorio(
				ruta_completa
			)
			continue

		if not _es_imagen(
			nombre_archivo
		):
			continue

		var nombre_sin_extension := (
			nombre_archivo.get_basename()
		)

		var clave := _normalizar_nombre(
			nombre_sin_extension
		)

		if clave.is_empty():
			continue

		if not _rutas_por_nombre.has(clave):
			_rutas_por_nombre[clave] = ruta_completa

		_entradas.append({
			"nombre": nombre_sin_extension,
			"ruta": ruta_completa,
			"tokens": _normalizar_tokens(
				nombre_sin_extension
			)
		})

	directorio.list_dir_end()


static func _es_imagen(
	nombre_archivo: String
) -> bool:
	return EXTENSIONES_IMAGEN.has(
		nombre_archivo.get_extension().to_lower()
	)


static func _cargar_textura(
	ruta: String
) -> Texture2D:
	if ruta.is_empty():
		return null

	var recurso := ResourceLoader.load(
		ruta
	)

	if recurso is Texture2D:
		return recurso as Texture2D

	return null


static func _normalizar_nombre(
	nombre: String
) -> String:
	var tokens := _normalizar_tokens(
		nombre
	)

	var resultado := ""

	for token in tokens:
		resultado += token

	return resultado


static func _normalizar_tokens(
	nombre: String
) -> Array[String]:
	var texto := nombre.to_lower()

	texto = texto.replace("á", "a")
	texto = texto.replace("é", "e")
	texto = texto.replace("í", "i")
	texto = texto.replace("ó", "o")
	texto = texto.replace("ú", "u")
	texto = texto.replace("ü", "u")
	texto = texto.replace("ñ", "n")

	var regex := RegEx.new()

	regex.compile(
		"[^a-z0-9]+"
	)

	texto = regex.sub(
		texto,
		" ",
		true
	).strip_edges()

	var partes := texto.split(
		" ",
		false
	)

	var resultado: Array[String] = []

	for parte in partes:
		if not parte.is_empty():
			resultado.append(parte)

	return resultado


static func _nombres_compatibles(
	tokens_a: Array[String],
	tokens_b: Array[String]
) -> bool:
	if tokens_a.size() != tokens_b.size():
		return false

	var diferencias: int = 0

	for i in range(tokens_a.size()):
		var a := tokens_a[i]
		var b := tokens_b[i]

		if a == b:
			continue

		if _es_singular_plural(
			a,
			b
		):
			diferencias += 1
			continue

		return false

	return diferencias <= 1


static func _es_singular_plural(
	a: String,
	b: String
) -> bool:
	if a == b:
		return false

	if a.length() > 3 and a.ends_with("es"):
		var singular_a := a.substr(
			0,
			a.length() - 2
		)

		if singular_a == b:
			return true

	if b.length() > 3 and b.ends_with("es"):
		var singular_b := b.substr(
			0,
			b.length() - 2
		)

		if singular_b == a:
			return true

	if a.length() > 2 and a.ends_with("s"):
		var singular_a := a.substr(
			0,
			a.length() - 1
		)

		if singular_a == b:
			return true

	if b.length() > 2 and b.ends_with("s"):
		var singular_b := b.substr(
			0,
			b.length() - 1
		)

		if singular_b == a:
			return true

	return false
