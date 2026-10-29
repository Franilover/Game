extends RefCounted
## Generador determinista de pixel art para el Reino de Torres.
## Los sprites se rasterizan a baja resolución y usan filtrado nearest; no dependen de arte externo.

const TRANSPARENTE := Color(0.0, 0.0, 0.0, 0.0)

static func crear_edificio(clave: String, variante: int = 0) -> Texture2D:
	var tamano := Vector2i(48, 48)
	if clave == "castillo":
		tamano = Vector2i(112, 88)
	elif clave in ["archivo_real", "sala_consejo", "casa_estudio", "casa_comercio", "alojamiento", "cuartel", "registro", "reparaciones", "almacen", "carpinteria", "granero", "molino", "aguas", "corrales", "casa_granjeros", "semillas"]:
		tamano = Vector2i(64, 56)
	elif clave.begins_with("vivienda_oeste"):
		tamano = Vector2i(42, 42)
	elif clave in ["forja", "establos", "telar", "alfareria", "banos"]:
		tamano = Vector2i(52, 48)

	var imagen := Image.create(tamano.x, tamano.y, false, Image.FORMAT_RGBA8)
	imagen.fill(TRANSPARENTE)
	if clave == "castillo":
		_dibujar_castillo(imagen, variante)
	else:
		_dibujar_casa(imagen, clave, variante)
	return ImageTexture.create_from_image(imagen)


static func crear_superficie(tipo: String, tamano: Vector2i, semilla: int = 0) -> Texture2D:
	var ancho := maxi(1, tamano.x)
	var alto := maxi(1, tamano.y)
	var imagen := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(tipo.hash() + semilla * 7919) + 1

	match tipo:
		"hierba":
			imagen.fill(Color("#344B2C"))
			for i in range(maxi(24, int(ancho * alto / 38))):
				var x := rng.randi_range(0, ancho - 1)
				var y := rng.randi_range(0, alto - 1)
				var w := rng.randi_range(1, 3)
				var h := rng.randi_range(1, 2)
				var tonos: Array[Color] = [Color("#3A5230"), Color("#405A33"), Color("#2D4528"), Color("#465F37")]
				_rect(imagen, x, y, w, h, tonos[rng.randi_range(0, tonos.size() - 1)])
			for i in range(maxi(10, int(ancho * alto / 340))):
				var x := rng.randi_range(0, ancho - 1)
				var y := rng.randi_range(0, alto - 1)
				_rect(imagen, x, y, 1, 1, Color("#6B7642"))
		"camino":
			imagen.fill(Color("#71583A"))
			_rect(imagen, 0, 0, ancho, 1, Color("#59432D"))
			_rect(imagen, 0, alto - 1, ancho, 1, Color("#4F3B29"))
			for y in range(3, alto, 5):
				_rect(imagen, 0, y, ancho, 1, Color("#7B6343"))
			for i in range(maxi(5, int(ancho * alto / 90))):
				var x := rng.randi_range(0, ancho - 1)
				var y := rng.randi_range(1, maxi(1, alto - 2))
				var tonos: Array[Color] = [Color("#876A47"), Color("#624A31"), Color("#9A7950")]
				_rect(imagen, x, y, rng.randi_range(1, 2), 1, tonos[rng.randi_range(0, tonos.size() - 1)])
		"plaza":
			imagen.fill(Color("#554A3B"))
			for y in range(0, alto, 4):
				var desplazamiento := 0 if int(y / 4) % 2 == 0 else 2
				for x in range(-desplazamiento, ancho, 5):
					var tono := Color("#746652") if (x + y + semilla) % 3 == 0 else Color("#675A48")
					_rect(imagen, x + 1, y + 1, 4, 3, tono)
					_rect(imagen, x + 1, y + 1, 3, 1, Color("#84745C"))
					_rect(imagen, x + 1, y + 3, 4, 1, Color("#4A4034"))
		"agua":
			imagen.fill(Color("#244650"))
			for y in range(1, alto, 3):
				var x := rng.randi_range(0, maxi(0, ancho - 1))
				_rect(imagen, x, y, rng.randi_range(2, maxi(2, int(ancho / 5))), 1, Color("#3C7180"))
			for i in range(maxi(8, int(ancho * alto / 70))):
				_rect(imagen, rng.randi_range(0, ancho - 1), rng.randi_range(0, alto - 1), 1, 1, Color("#56838A"))
		"ribera":
			imagen.fill(Color("#34462B"))
			_rect(imagen, 0, 0, ancho, 1, Color("#59482F"))
			_rect(imagen, 0, alto - 1, ancho, 1, Color("#59482F"))
			for i in range(maxi(8, int(ancho * alto / 100))):
				_rect(imagen, rng.randi_range(0, ancho - 1), rng.randi_range(0, alto - 1), rng.randi_range(1, 2), 1, Color("#4A5A32"))
		"puente":
			imagen.fill(Color("#513A27"))
			_rect(imagen, 0, 0, ancho, 1, Color("#392A20"))
			_rect(imagen, 0, alto - 1, ancho, 1, Color("#392A20"))
			for y in range(1, alto - 1, 2):
				_rect(imagen, 1, y, maxi(1, ancho - 2), 1, Color("#8B6843") if int(y / 2) % 2 == 0 else Color("#755337"))
				_rect(imagen, 1, y, maxi(1, ancho - 2), 1, Color("#9C7950") if int(y / 2) % 2 == 0 else Color("#755337"))
				for x in range(3, ancho, 5):
					_rect(imagen, x, y, 1, 1, Color("#4B3425"))
		"muro":
			imagen.fill(Color("#686456"))
			for y in range(0, alto, 3):
				_rect(imagen, 0, y, ancho, 1, Color("#48483F"))
				var offset := 0 if int(y / 3) % 2 == 0 else 2
				for x in range(offset, ancho, 4):
					_rect(imagen, x, y + 1, 1, 2, Color("#4D4C43"))
					_rect(imagen, x + 1, y + 1, 2, 1, Color("#817B69"))
			_rect(imagen, 0, 0, ancho, 1, Color("#A0977F"))
		"jardin":
			imagen.fill(Color("#263D24"))
			for i in range(maxi(12, int(ancho * alto / 16))):
				var tonos: Array[Color] = [Color("#38552B"), Color("#466533"), Color("#5B7138"), Color("#7B8145")]
				_rect(imagen, rng.randi_range(0, ancho - 1), rng.randi_range(0, alto - 1), 1, 1, tonos[rng.randi_range(0, tonos.size() - 1)])
		"tierra":
			imagen.fill(Color("#5F462E"))
			for i in range(maxi(4, int(ancho * alto / 12))):
				_rect(imagen, rng.randi_range(0, ancho - 1), rng.randi_range(0, alto - 1), rng.randi_range(1, 2), 1, Color("#7F6040"))
		"cultivo":
			imagen.fill(Color("#59442C"))
			for y in range(0, alto, 2):
				_rect(imagen, 0, y, ancho, 1, Color("#3D3425"))
				for x in range((y / 2) % 3, ancho, 3):
					_rect(imagen, x, y + 1, 1, 1, Color("#6B8540") if (x + y + semilla) % 4 != 0 else Color("#9A9A4D"))
		_:
			imagen.fill(Color("#555047"))
	return ImageTexture.create_from_image(imagen)


static func crear_decoracion(tipo: String, variante: int = 0) -> Texture2D:
	var tamano := Vector2i(32, 40)
	if tipo == "pozo":
		tamano = Vector2i(32, 28)
	elif tipo == "puesto" or tipo == "puesto_azul":
		tamano = Vector2i(64, 40)
	elif tipo == "lampara":
		tamano = Vector2i(12, 24)
	var imagen := Image.create(tamano.x, tamano.y, false, Image.FORMAT_RGBA8)
	imagen.fill(TRANSPARENTE)

	match tipo:
		"arbol":
			_dibujar_arbol(imagen, variante)
		"pozo":
			_dibujar_pozo(imagen)
		"puesto":
			_dibujar_puesto(imagen, variante, false)
		"puesto_azul":
			_dibujar_puesto(imagen, variante, true)
		"lampara":
			_dibujar_lampara(imagen)
	return ImageTexture.create_from_image(imagen)


static func _dibujar_casa(imagen: Image, clave: String, variante: int) -> void:
	var w := imagen.get_width()
	var h := imagen.get_height()
	var es_piedra := clave in ["vivienda_mason", "archivo_real", "sala_consejo", "cuartel", "banos", "aguas", "registro"]
	var es_granja := clave in ["granero", "casa_granjeros", "semillas", "corrales", "establos"]
	var es_taller := clave in ["forja", "reparaciones", "carpinteria", "alfareria", "telar", "molino"]
	var paredes: Array[Color] = [Color("#B9A17A"), Color("#C5AD84"), Color("#9E8A67"), Color("#A4A07D"), Color("#B9B6A2")]
	var tejados: Array[Color] = [Color("#8A4936"), Color("#704431"), Color("#5A4934"), Color("#596642"), Color("#794D3C")]
	if es_piedra:
		paredes = [Color("#888473"), Color("#A19A84"), Color("#777969"), Color("#96917E"), Color("#A7A08D")]
	if es_granja:
		tejados = [Color("#9A7945"), Color("#8B6B3D"), Color("#6B6040"), Color("#A07B42"), Color("#79643C")]
	if es_taller:
		tejados = [Color("#5D4030"), Color("#684531"), Color("#564B3D"), Color("#6F5140"), Color("#614A33")]
	var indice := absi(clave.hash() + variante * 13)
	var pared := paredes[indice % paredes.size()]
	var tejado := tejados[(indice / 3) % tejados.size()]
	var luz := Color("#DBBD80") if clave in ["panaderia", "posada", "alojamiento"] else Color("#A5C2B5")
	var contorno := Color("#33291F")
	var sombra := Color("#22271E")

	# Sombra pixelada, cimiento y cuerpo de mampostería.
	_rect(imagen, 4, h - 8, w - 8, 4, Color("#22271E", 0.42))
	_rect(imagen, 7, h - 13, w - 14, 7, contorno)
	_rect(imagen, 8, h - 14, w - 16, 7, pared)
	_rect(imagen, 9, h - 13, w - 18, 2, pared.lightened(0.12))
	_rect(imagen, 8, h - 8, w - 16, 2, pared.darkened(0.22))

	var alto_tejado := maxi(12, int(h * 0.43))
	var base_tejado := 3 + alto_tejado
	var centro := int(w / 2)
	var media_maxima := int(w / 2) - 3
	for fila in range(alto_tejado):
		var media := maxi(2, int(float(media_maxima) * float(fila + 1) / float(alto_tejado)))
		var y := 3 + fila
		_rect(imagen, centro - media - 2, y, media * 2 + 4, 1, contorno)
		_rect(imagen, centro - media, y, media * 2, 1, tejado.darkened(0.12) if fila % 4 == 0 else tejado)
		if fila > 2 and fila % 5 == 0:
			_rect(imagen, centro - media + 2, y, maxi(1, media - 2), 1, tejado.lightened(0.15))
		if fila > 4 and fila % 6 == 0:
			_rect(imagen, centro + 2, y, maxi(1, media - 3), 1, tejado.darkened(0.18))
	_rect(imagen, 5, base_tejado - 2, w - 10, 3, contorno)
	_rect(imagen, 7, base_tejado - 1, w - 14, 1, tejado.lightened(0.08))

	# Fachada con zócalo visible, bloques y vigas de madera.
	var pared_y := base_tejado - 2
	var pared_h := h - pared_y - 7
	_rect(imagen, 8, pared_y, w - 16, pared_h, contorno)
	_rect(imagen, 9, pared_y + 1, w - 18, pared_h - 2, pared)
	_rect(imagen, 9, pared_y + 2, w - 18, 1, pared.lightened(0.14))
	_rect(imagen, 9, h - 9, w - 18, 2, pared.darkened(0.20))
	if clave in ["vivienda_mason", "banos", "archivo_real", "sala_consejo"]:
		for fila in range(pared_y + 4, h - 9, 4):
			_rect(imagen, 10, fila, w - 20, 1, pared.darkened(0.12))
			var divisor := 15 if int(fila / 4) % 2 == 0 else 25
			for x in range(divisor, w - 10, 13):
				_rect(imagen, x, fila, 1, 3, pared.darkened(0.18))
	else:
		_rect(imagen, 10, pared_y + 4, w - 20, 2, Color("#76553A"))
		_rect(imagen, 10, h - 14, w - 20, 2, Color("#76553A"))

	# Dos ventanas pequeñas, con marco oscuro y reflejo en el cristal.
	var ventana_y := pared_y + 5
	var ventana_w := 5 if w < 56 else 7
	var ventana_h := 6 if h < 48 else 7
	var ventana_l := 11
	var ventana_r := w - 11 - ventana_w
	for x in [ventana_l, ventana_r]:
		_rect(imagen, x - 1, ventana_y - 1, ventana_w + 2, ventana_h + 2, contorno)
		_rect(imagen, x, ventana_y, ventana_w, ventana_h, Color("#35565B"))
		_rect(imagen, x + 1, ventana_y + 1, maxi(1, ventana_w - 2), 1, Color("#75999A"))
		_rect(imagen, x + int(ventana_w / 2), ventana_y, 1, ventana_h, Color("#9B896A"))
		_rect(imagen, x, ventana_y + int(ventana_h / 2), ventana_w, 1, Color("#9B896A"))

	# Puerta, marco, tablones y manilla: contraste cálido, pero apagado.
	var puerta_w := 7 if w < 56 else 9
	var puerta_h := 11 if h < 48 else 14
	var puerta_x := int((w - puerta_w) / 2)
	var puerta_y := h - 7 - puerta_h
	_rect(imagen, puerta_x - 2, puerta_y - 2, puerta_w + 4, puerta_h + 3, contorno)
	_rect(imagen, puerta_x, puerta_y, puerta_w, puerta_h, Color("#68422B"))
	_rect(imagen, puerta_x + 1, puerta_y + 1, maxi(1, int(puerta_w / 3)), puerta_h - 2, Color("#8A5B36"))
	_rect(imagen, puerta_x + int(puerta_w / 2), puerta_y + 2, 1, puerta_h - 3, Color("#4A3023"))
	_rect(imagen, puerta_x + puerta_w - 2, puerta_y + int(puerta_h / 2), 1, 1, Color("#D7B76F"))
	_rect(imagen, puerta_x - 3, puerta_y - 2, puerta_w + 6, 2, Color("#B9A17A"))

	# Detalles exclusivos por oficio, sin alterar el contorno jugable.
	if clave in ["panaderia", "forja"]:
		_rect(imagen, 8, 4, 7, 11, contorno)
		_rect(imagen, 9, 3, 5, 11, Color("#955A3A") if clave == "panaderia" else Color("#6B6254"))
		_rect(imagen, 9, 5, 5, 2, Color("#B6A083"))
		_rect(imagen, 10, 14, 3, 2, Color("#5B3926"))
	if clave in ["posada", "alojamiento"]:
		_rect(imagen, centro - 7, pared_y + 1, 14, 4, Color("#493127"))
		_rect(imagen, centro - 6, pared_y + 2, 12, 2, Color("#D9BD82"))
		_rect(imagen, centro - 4, pared_y + 2, 8, 1, Color("#815038"))
	if clave in ["forja", "reparaciones"]:
		_rect(imagen, w - 12, pared_y + 5, 4, 7, Color("#3F3329"))
		_rect(imagen, w - 11, pared_y + 7, 2, 3, Color("#CE6B32"))
		_rect(imagen, w - 11, pared_y + 9, 1, 1, Color("#E6B05B"))
	if clave in ["granero", "semillas", "casa_granjeros", "corrales"]:
		_rect(imagen, 4, h - 16, 5, 5, Color("#B69A58"))
		_rect(imagen, 5, h - 15, 3, 3, Color("#D4B96D"))
	if clave == "molino":
		_rect(imagen, 3, 9, 3, 20, Color("#40352A"))
		_rect(imagen, 0, 17, 9, 3, Color("#B49A6A"))
		_rect(imagen, 2, 12, 5, 13, Color("#7F6B4D"))
	if clave == "casa_estudio":
		_rect(imagen, centro - 4, 4, 8, 5, Color("#46565A"))
		_rect(imagen, centro - 2, 1, 4, 4, Color("#758A8A"))
	if clave == "aguas":
		_rect(imagen, centro - 4, h - 19, 8, 4, Color("#305A63"))
		_rect(imagen, centro - 3, h - 18, 6, 2, Color("#79A5A2"))
	if clave == "alfareria":
		_rect(imagen, w - 12, h - 19, 4, 5, Color("#A85E42"))
		_rect(imagen, w - 11, h - 20, 2, 2, Color("#D0A06A"))
	if clave == "telar":
		_rect(imagen, 3, h - 19, 5, 6, Color("#8A5550"))
		_rect(imagen, 4, h - 18, 3, 4, Color("#C6A071"))
	if clave == "banos":
		_rect(imagen, centro - 7, 5, 14, 3, Color("#4F7376"))
		_rect(imagen, centro - 5, 6, 10, 1, Color("#9BBEB4"))
	# Pocas marcas, colocadas en rejilla, dan textura sin ensuciar la silueta.
	for i in range(5):
		var px := 12 + int((indice + i * 11) % maxi(1, w - 24))
		var py := pared_y + 3 + int((indice / (i + 2) + i * 3) % maxi(1, h - pared_y - 15))
		_rect(imagen, px, py, 1, 1, pared.lightened(0.16))


static func _dibujar_castillo(imagen: Image, variante: int) -> void:
	var w := imagen.get_width()
	_rect(imagen, 8, 76, w - 16, 7, Color("#25271F", 0.45))
	# Bloque central y sus sillares.
	_rect(imagen, 29, 20, 54, 58, Color("#37362F"))
	_rect(imagen, 31, 21, 50, 55, Color("#85816E"))
	_rect(imagen, 32, 22, 48, 2, Color("#B5A98C"))
	for y in range(27, 73, 6):
		_rect(imagen, 32, y, 48, 1, Color("#57584D"))
		for x in range(35 + int(y / 6) % 2 * 5, 80, 11):
			_rect(imagen, x, y + 1, 1, 4, Color("#66665A"))
			_rect(imagen, x + 1, y + 1, 7, 1, Color("#A09982"))
	# Dos torres cuadradas, algo más altas que la fachada.
	for x in [10, 84]:
		_rect(imagen, x, 27, 19, 50, Color("#36352F"))
		_rect(imagen, x + 2, 29, 15, 47, Color("#9A927C"))
		_rect(imagen, x + 2, 30, 15, 2, Color("#C3B395"))
		for y in range(37, 73, 7):
			_rect(imagen, x + 3, y, 13, 1, Color("#6C6A5D"))
		# Merlones de la torre.
		for merlon in range(3):
			_rect(imagen, x + 2 + merlon * 5, 24, 3, 7, Color("#A69D85"))
			_rect(imagen, x + 2 + merlon * 5, 24, 3, 1, Color("#D2C1A0"))
	# Remate central con almenas pixeladas.
	_rect(imagen, 34, 15, 44, 12, Color("#3B3931"))
	_rect(imagen, 36, 17, 40, 9, Color("#9A927C"))
	_rect(imagen, 36, 17, 40, 2, Color("#D0BE9D"))
	for merlon in range(5):
		_rect(imagen, 36 + merlon * 8, 12, 4, 8, Color("#B0A58A"))
		_rect(imagen, 36 + merlon * 8, 12, 4, 2, Color("#D4C3A0"))
	# Puerta real con arco escalonado, ventana y pendones.
	_rect(imagen, 49, 57, 14, 21, Color("#2A261F"))
	_rect(imagen, 51, 59, 10, 19, Color("#593A27"))
	_rect(imagen, 52, 61, 2, 15, Color("#84603B"))
	_rect(imagen, 59, 62, 1, 2, Color("#D9B76C"))
	for x in [39, 70]:
		_rect(imagen, x, 35, 7, 10, Color("#282D2A"))
		_rect(imagen, x + 1, 36, 5, 8, Color("#3C6268"))
		_rect(imagen, x + 2, 37, 2, 1, Color("#9AC0B3"))
		_rect(imagen, x + 3, 36, 1, 8, Color("#B09A75"))
	# Detalle heráldico discreto.
	_rect(imagen, 55, 35, 3, 8, Color("#C7A969"))
	_rect(imagen, 54, 36, 5, 4, Color("#6F4432"))
	_rect(imagen, 55, 37, 3, 2, Color("#D5BC78"))


static func _dibujar_arbol(imagen: Image, variante: int) -> void:
	var w := imagen.get_width()
	var centro := int(w / 2)
	_rect(imagen, 7, 34, 18, 4, Color("#22271E", 0.45))
	_rect(imagen, centro - 3, 24, 6, 13, Color("#573A25"))
	_rect(imagen, centro - 1, 25, 2, 11, Color("#8A5D36"))
	var verde_base := Color("#23452C") if variante % 3 == 0 else (Color("#2B4B2B") if variante % 3 == 1 else Color("#2D4935"))
	var verde_sombra := Color("#192F24")
	var verde_luz := Color("#527342") if variante % 2 == 0 else Color("#657746")
	# Tres niveles de ramas escalonadas, de copa angosta a copa ancha.
	for nivel in range(3):
		var inicio_y := 4 + nivel * 8
		var altura := 10
		var ancho_max := 5 + nivel * 4
		for fila in range(altura):
			var media := maxi(1, int(float(ancho_max) * float(fila + 1) / float(altura)))
			var y := inicio_y + fila
			_rect(imagen, centro - media - 1, y, media * 2 + 2, 1, verde_sombra)
			_rect(imagen, centro - media, y, media * 2, 1, verde_base)
			if fila % 4 == 1:
				_rect(imagen, centro - media + 1, y, maxi(1, media / 2), 1, verde_luz)
	_rect(imagen, centro - 1, 6, 2, 2, Color("#789353"))
	_rect(imagen, centro - 8, 14, 4, 2, verde_luz)
	_rect(imagen, centro + 3, 23, 4, 2, verde_luz)


static func _dibujar_pozo(imagen: Image) -> void:
	var w := imagen.get_width()
	_rect(imagen, 1, 22, w - 2, 5, Color("#24271F", 0.45))
	_rect(imagen, 4, 5, w - 8, 20, Color("#35372F"))
	_rect(imagen, 6, 7, w - 12, 16, Color("#827B67"))
	_rect(imagen, 8, 9, w - 16, 12, Color("#264B53"))
	_rect(imagen, 8, 9, w - 16, 2, Color("#609099"))
	_rect(imagen, 3, 3, w - 6, 5, Color("#B3A17B"))
	_rect(imagen, 5, 4, w - 10, 2, Color("#D2BC91"))
	_rect(imagen, 4, 24, w - 8, 2, Color("#514638"))


static func _dibujar_puesto(imagen: Image, variante: int, azul: bool) -> void:
	var w := imagen.get_width()
	_rect(imagen, 4, 34, w - 8, 4, Color("#22271E", 0.45))
	_rect(imagen, 6, 21, w - 12, 14, Color("#4A3424"))
	_rect(imagen, 8, 23, w - 16, 11, Color("#946A41"))
	_rect(imagen, 5, 19, w - 10, 4, Color("#392B20"))
	_rect(imagen, 5, 17, w - 10, 3, Color("#C0A06A"))
	var base := Color("#385E68") if azul else Color("#9A4A36")
	var claro := Color("#D8C28F")
	var oscuro := base.darkened(0.28)
	_rect(imagen, 4, 5, w - 8, 2, oscuro)
	_rect(imagen, 4, 7, w - 8, 12, base)
	for x in range(4, w - 4, 8):
		if int(x / 8 + variante) % 2 == 0:
			_rect(imagen, x, 7, 4, 12, claro)
			_rect(imagen, x, 17, 4, 2, Color("#A28B64"))
	_rect(imagen, 4, 18, w - 8, 2, oscuro)
	for x in [9, w - 12]:
		_rect(imagen, x, 22, 3, 12, Color("#5A3B27"))
	_rect(imagen, 12, 26, w - 24, 2, Color("#B88B55"))


static func _dibujar_lampara(imagen: Image) -> void:
	var w := imagen.get_width()
	_rect(imagen, 2, 20, w - 4, 3, Color("#25271F", 0.45))
	_rect(imagen, 5, 7, 3, 15, Color("#493525"))
	_rect(imagen, 4, 5, 5, 3, Color("#30271F"))
	_rect(imagen, 3, 1, 7, 6, Color("#D1A452"))
	_rect(imagen, 4, 2, 5, 4, Color("#F0CD78"))
	_rect(imagen, 5, 3, 2, 2, Color("#F7E2A2"))
	_rect(imagen, 4, 21, 5, 2, Color("#86603B"))


static func _rect(imagen: Image, x: int, y: int, ancho: int, alto: int, color: Color) -> void:
	if ancho <= 0 or alto <= 0:
		return
	var izquierda := maxi(0, x)
	var arriba := maxi(0, y)
	var derecha := mini(imagen.get_width(), x + ancho)
	var abajo := mini(imagen.get_height(), y + alto)
	if derecha <= izquierda or abajo <= arriba:
		return
	imagen.fill_rect(Rect2i(izquierda, arriba, derecha - izquierda, abajo - arriba), color)
