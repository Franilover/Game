extends RefCounted
class_name WorldSnapshotValidator

## Valida la estructura mínima que necesitan los índices del mundo.
## No interpreta ni corrige datos canónicos: solo rechaza snapshots incompletos.

const CAMPOS_OPCIONALES: Array[String] = [
	"personajes_game",
	"dialogos_game",
	"misiones_game",
	"reinos_game",
	"props_game",
	"lugares_game",
	"garumis_game"
]


static func es_valido(datos: Dictionary) -> bool:
	var biomas_variant: Variant = datos.get("biomas", null)
	if not biomas_variant is Array:
		return false

	var biomas := biomas_variant as Array
	if biomas.is_empty():
		return false

	if not _validar_nivel(
		biomas,
		["ecosistemas", "habitats", "criaturas"]
	):
		return false

	for campo in CAMPOS_OPCIONALES:
		if datos.has(campo) and not datos[campo] is Array:
			return false

	return true


static func _validar_nivel(
	registros: Array,
	campos_hijos: Array
) -> bool:
	var campo_hijos := str(campos_hijos[0])

	for registro_variant in registros:
		if not registro_variant is Dictionary:
			return false

		var registro := registro_variant as Dictionary
		if str(registro.get("id", "")).strip_edges().is_empty():
			return false

		var hijos_variant: Variant = registro.get(campo_hijos, null)
		if not hijos_variant is Array:
			return false

		var hijos := hijos_variant as Array
		if campos_hijos.size() > 1:
			var siguientes_campos: Array = campos_hijos.slice(1)
			if not _validar_nivel(hijos, siguientes_campos):
				return false
		else:
			for criatura_variant in hijos:
				if not criatura_variant is Dictionary:
					return false
				var criatura := criatura_variant as Dictionary
				if (
					str(criatura.get("id", "")).strip_edges().is_empty()
					or str(criatura.get("nombre", "")).strip_edges().is_empty()
				):
					return false

	return true
