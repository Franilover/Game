extends CanvasLayer
class_name AdminConsole


var _panel: PanelContainer
var _historial: RichTextLabel
var _entrada: LineEdit

var _sugerencias_panel: PanelContainer
var _sugerencias_scroll: ScrollContainer
var _sugerencias_lista: VBoxContainer

var _abierto: bool = false
var _sugerencias: Array[String] = []


const COMANDO_SUMMON: String = "/summon"
const COMANDO_GIVE: String = "/give"
const COMANDO_TIME: String = "/time"
const COMANDO_TP: String = "/tp"
const MAX_SUGERENCIAS_VISIBLES: int = 8
const ANCHO_SUGERENCIAS: float = 320.0
const ALTURA_SUGERENCIAS_POR_FILA: float = 22.0


func _completar_sugerencia(nombre: String) -> void:
	var comando: String = _comando_actual()

	if comando.is_empty():
		return

	var prefijo: String = comando + " "

	if comando == COMANDO_SUMMON:
		var argumento_crudo: String = _entrada.text.substr(
			COMANDO_SUMMON.length()
		)
		var partes: PackedStringArray = PackedStringArray()

		if not argumento_crudo.strip_edges().is_empty():
			partes = argumento_crudo.strip_edges().split(
				" ",
				false
			)

		if (
			not partes.is_empty()
			and partes[0].to_lower() == "humano"
			and (
				partes.size() >= 2
				or _entrada.text.ends_with(" ")
			)
		):
			prefijo = COMANDO_SUMMON + " Humano "

	elif comando == COMANDO_TP:
		var argumento_crudo: String = _entrada.text.substr(
			COMANDO_TP.length()
		)
		var partes: PackedStringArray = PackedStringArray()

		if not argumento_crudo.strip_edges().is_empty():
			partes = argumento_crudo.strip_edges().split(
				" ",
				false
			)

		# Si ya elegimos el tipo (/tp criatura Al), Tab debe
		# completar solo el nombre y conservar la estructura.
		if not partes.is_empty():
			var tipo: String = partes[0]
			if partes.size() >= 2 or _entrada.text.ends_with(" "):
				prefijo = COMANDO_TP + " " + tipo + " "

	_entrada.text = prefijo + nombre
	_entrada.caret_column = _entrada.text.length()
	_actualizar_sugerencias()
	_entrada.grab_focus()


func _comando_actual() -> String:
	var texto: String = _entrada.text

	if _es_comando_con_sugerencias(texto, COMANDO_SUMMON):
		return COMANDO_SUMMON

	if _es_comando_con_sugerencias(texto, COMANDO_GIVE):
		return COMANDO_GIVE

	if _es_comando_con_sugerencias(texto, COMANDO_TP):
		return COMANDO_TP

	return ""


func _es_comando_con_sugerencias(
	texto: String,
	comando: String
) -> bool:
	var limpio: String = texto.strip_edges().to_lower()
	var comando_minusculas: String = comando.to_lower()

	return (
		limpio == comando_minusculas
		or limpio.begins_with(comando_minusculas + " ")
	)


func _extraer_argumento(
	texto: String,
	comando: String
) -> String:
	if not _es_comando_con_sugerencias(texto, comando):
		return ""

	var limpio: String = texto.strip_edges()

	if limpio.to_lower() == comando.to_lower():
		return ""

	return texto.substr(comando.length()).strip_edges()


func _al_input_entrada(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var tecla: InputEventKey = event as InputEventKey

	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode != KEY_TAB:
		return

	if _sugerencias.is_empty():
		return

	_completar_sugerencia(_sugerencias[0])
	get_viewport().set_input_as_handled()
