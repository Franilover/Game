extends RefCounted
class_name CombatItemResolver

## Interpreta la clasificación y las propiedades de combate de un objeto.
## No crea ataques ni aplica efectos: sólo adapta los datos del catálogo.


static func es_herramienta(objeto: Dictionary) -> bool:
	var tipo := str(objeto.get("tipo", "")).strip_edges().to_lower()
	return tipo == "herramienta"


static func es_objeto_ataque(objeto: Dictionary) -> bool:
	return es_arma(objeto) or es_herramienta(objeto)


static func es_arma(objeto: Dictionary) -> bool:
	var tipo := str(objeto.get("tipo", "")).strip_edges().to_lower()
	if tipo == "arma":
		return true

	# Compatibilidad con partidas antiguas y objetos cuyo tipo de catálogo
	# es genérico, pero cuya clasificación canónica sí declara que son armas.
	if bool(objeto.get("es_arma", false)):
		return true

	var categorias: Array[String] = []
	for clave in ["categoria", "categoria_canonica"]:
		var valor := str(objeto.get(clave, "")).strip_edges().to_lower()
		if not valor.is_empty():
			categorias.append(valor)

	var tipo_objeto_variant: Variant = objeto.get("tipo_objeto", {})
	if tipo_objeto_variant is Dictionary:
		var tipo_objeto := tipo_objeto_variant as Dictionary
		var categoria_tipo := str(tipo_objeto.get("categoria_canonica", "")).strip_edges().to_lower()
		if not categoria_tipo.is_empty():
			categorias.append(categoria_tipo)
		var plantilla_variant: Variant = tipo_objeto.get("plantilla", {})
		if plantilla_variant is Dictionary:
			var categoria_plantilla := str((plantilla_variant as Dictionary).get("categoria", "")).strip_edges().to_lower()
			if not categoria_plantilla.is_empty():
				categorias.append(categoria_plantilla)

	for categoria in categorias:
		if "arma" in categoria:
			return true
	return false


static func obtener_propiedades_game(objeto: Dictionary) -> Dictionary:
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		return propiedades_variant as Dictionary
	return {}


static func obtener_modo_ataque(arma: Dictionary) -> String:
	# La categoría puede venir del objeto, de su tipo enlazado o de la
	# plantilla geométrica. Algunas partidas antiguas sólo conservan una capa.
	var categorias: Array[String] = []
	var categoria_directa := str(
		arma.get("categoria_canonica", arma.get("categoria", ""))
	).strip_edges().to_lower()
	if not categoria_directa.is_empty():
		categorias.append(categoria_directa)

	var tipo_objeto_variant: Variant = arma.get("tipo_objeto", {})
	if tipo_objeto_variant is Dictionary:
		var tipo_objeto := tipo_objeto_variant as Dictionary
		var categoria_tipo := str(tipo_objeto.get("categoria_canonica", "")).strip_edges().to_lower()
		if not categoria_tipo.is_empty():
			categorias.append(categoria_tipo)

		var plantilla_variant: Variant = tipo_objeto.get("plantilla", {})
		if plantilla_variant is Dictionary:
			var plantilla := plantilla_variant as Dictionary
			var categoria_plantilla := str(plantilla.get("categoria", "")).strip_edges().to_lower()
			if not categoria_plantilla.is_empty():
				categorias.append(categoria_plantilla)

	# El catálogo puede declarar un arco por modalidad, subtipo o familia.
	# Revisar todas las etiquetas evita tratar un arco como cuerpo a cuerpo
	# cuando la categoría general sólo dice "arma".
	var propiedades := obtener_propiedades_game(arma)
	var etiquetas: Array[String] = categorias.duplicate()
	for fuente_variant in [arma, tipo_objeto_variant, propiedades]:
		if not fuente_variant is Dictionary:
			continue
		var fuente := fuente_variant as Dictionary
		for clave in [
			"modo_ataque", "tipo_ataque", "modalidad_ataque", "modo_combate",
			"tipo_arma", "clase_arma", "subtipo_arma", "familia_arma",
			"tipo", "clase", "subtipo", "familia", "categoria"
		]:
			var etiqueta := str(fuente.get(clave, "")).strip_edges().to_lower()
			if not etiqueta.is_empty():
				etiquetas.append(etiqueta)

	for etiqueta in etiquetas:
		if (
			"distancia" in etiqueta
			or "proyectil" in etiqueta
			or "ranged" in etiqueta
			or "arco" in etiqueta
			or etiqueta == "bow"
		):
			return "distancia"

	return "cuerpo"


static func obtener_danio_arma(arma: Dictionary, danio_defecto: int) -> int:
	var propiedades := obtener_propiedades_game(arma)
	var danio_variant: Variant = propiedades.get("danio", null)
	if danio_variant is int or danio_variant is float:
		return maxi(0, int(danio_variant))
	return maxi(0, danio_defecto)


static func obtener_float_propiedad(
	objeto: Dictionary,
	nombre: String,
	valor_por_defecto: float
) -> float:
	var propiedades := obtener_propiedades_game(objeto)
	var valor: Variant = propiedades.get(nombre, valor_por_defecto)
	if valor is int or valor is float:
		return maxf(0.0, float(valor))
	return valor_por_defecto


static func obtener_alcance_arma(arma: Dictionary, alcance_defecto: float) -> float:
	return obtener_float_propiedad(arma, "alcance", alcance_defecto)


static func obtener_ancho_ataque(arma: Dictionary, ancho_defecto: float) -> float:
	return obtener_float_propiedad(arma, "ancho_ataque", ancho_defecto)
