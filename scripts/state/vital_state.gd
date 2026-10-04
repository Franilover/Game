extends RefCounted
class_name VitalState

## Estado vital puro de una entidad.
## No conoce nodos, UI, inventario ni combate.

var health: int = 100
var max_health: int = 100
var mana: int = 100
var max_mana: int = 100
var is_alive: bool = true

func configurar(salud_maxima: int, mana_maximo: int) -> void:
	max_health = maxi(salud_maxima, 0)
	max_mana = maxi(mana_maximo, 0)
	health = max_health
	mana = max_mana
	is_alive = true

func recibir_danio(cantidad: int) -> int:
	if not is_alive:
		return 0

	var dano := maxi(cantidad, 0)
	if dano <= 0:
		return 0

	var anterior := health
	health = maxi(health - dano, 0)

	if health <= 0:
		is_alive = false

	return anterior - health

func curar(cantidad: int) -> int:
	if not is_alive:
		return 0

	var curacion := maxi(cantidad, 0)
	if curacion <= 0:
		return 0

	var anterior := health
	health = mini(health + curacion, max_health)
	return health - anterior

func gastar_mana(cantidad: int) -> bool:
	var gasto := maxi(cantidad, 0)
	if gasto <= 0 or mana < gasto:
		return false
	mana -= gasto
	return true

func restaurar_mana(cantidad: int) -> int:
	if not is_alive:
		return 0

	var recuperacion := maxi(cantidad, 0)
	if recuperacion <= 0:
		return 0

	var anterior := mana
	mana = mini(mana + recuperacion, max_mana)
	return mana - anterior

func esta_vivo() -> bool:
	return is_alive

func esta_muerto() -> bool:
	return not is_alive

func reiniciar() -> void:
	health = max_health
	mana = max_mana
	is_alive = true

func to_dictionary() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"mana": mana,
		"max_mana": max_mana,
		"is_alive": is_alive
	}

func from_dictionary(data: Dictionary) -> void:
	max_health = maxi(int(data.get("max_health", 100)), 0)
	max_mana = maxi(int(data.get("max_mana", 100)), 0)
	health = clampi(int(data.get("health", max_health)), 0, max_health)
	mana = clampi(int(data.get("mana", max_mana)), 0, max_mana)
	is_alive = bool(data.get("is_alive", health > 0))
