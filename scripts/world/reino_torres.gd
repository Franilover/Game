extends Node2D

signal salida_solicitada

@onready var _exit: Area2D = $Exit

var _transicionando: bool = false


func _ready() -> void:
	_exit.body_entered.connect(_al_entrar_salida)


func _al_entrar_salida(body: Node2D) -> void:
	if _transicionando:
		return
	if body == null or not body.is_in_group("player"):
		return

	_transicionando = true
	print("ReinoTorres: salida solicitada.")
	salida_solicitada.emit()
