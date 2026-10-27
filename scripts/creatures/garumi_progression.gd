extends RefCounted
class_name GarumiProgression

## Reglas iniciales jugables. Las estadísticas de especie se leen del snapshot
## canónico cuando existen; los valores por defecto son sólo fallback temporal.
const NIVEL_MAXIMO: int = 100
const XP_BASE: float = 100.0
const EXPONENTE_XP: float = 1.5
const CRECIMIENTO_POR_NIVEL: float = 0.025

const ESTADISTICAS_BASE := {
	"vida": 40,
	"ataque": 10,
	"defensa": 5,
	"velocidad": 10,
	"eterium": 30
}

var estadisticas_base: Dictionary = ESTADISTICAS_BASE.duplicate(true)


func configurar(datos: Dictionary) -> void:
	var anidadas_variant: Variant = datos.get("estadisticas_combate", {})
	var anidadas: Dictionary = anidadas_variant if anidadas_variant is Dictionary else {}
	estadisticas_base = {
		"vida": maxi(1, int(anidadas.get("vida_maxima", datos.get("vida_maxima", datos.get("salud_combate", ESTADISTICAS_BASE["vida"]))))),
		"ataque": maxi(1, int(anidadas.get("ataque", datos.get("ataque", ESTADISTICAS_BASE["ataque"])))),
		"defensa": maxi(0, int(anidadas.get("defensa", datos.get("defensa", ESTADISTICAS_BASE["defensa"])))),
		"velocidad": maxi(1, int(anidadas.get("velocidad", datos.get("velocidad", ESTADISTICAS_BASE["velocidad"])))),
		"eterium": maxi(0, int(anidadas.get("eterium_maximo", datos.get("eterium_maximo", ESTADISTICAS_BASE["eterium"]))))
	}


func xp_para_siguiente_nivel(nivel_actual: int) -> int:
	var nivel_seguro := clampi(nivel_actual, 1, NIVEL_MAXIMO)
	return ceili(XP_BASE * pow(float(nivel_seguro), EXPONENTE_XP))


func xp_total_para_nivel(nivel_objetivo: int) -> int:
	var objetivo := clampi(nivel_objetivo, 1, NIVEL_MAXIMO)
	var total := 0
	for nivel_actual in range(1, objetivo):
		total += xp_para_siguiente_nivel(nivel_actual)
	return total


func nivel_desde_experiencia(experiencia_total: int) -> int:
	var restante := maxi(0, experiencia_total)
	var nivel_actual := 1
	while nivel_actual < NIVEL_MAXIMO:
		var coste := xp_para_siguiente_nivel(nivel_actual)
		if restante < coste:
			break
		restante -= coste
		nivel_actual += 1
	return nivel_actual


func obtener_estadisticas(nivel_actual: int) -> Dictionary:
	var nivel_seguro := clampi(nivel_actual, 1, NIVEL_MAXIMO)
	var factor := 1.0 + float(nivel_seguro - 1) * CRECIMIENTO_POR_NIVEL
	var resultado: Dictionary = {}
	for clave in ["vida", "ataque", "defensa", "velocidad", "eterium"]:
		var base := int(estadisticas_base.get(clave, ESTADISTICAS_BASE[clave]))
		resultado[clave] = maxi(0, roundi(float(base) * factor))
	resultado["vida"] = maxi(1, int(resultado["vida"]))
	resultado["ataque"] = maxi(1, int(resultado["ataque"]))
	resultado["velocidad"] = maxi(1, int(resultado["velocidad"]))
	return resultado


## Potencia 100 representa el daño base del movimiento; defensa reduce daño
## mediante rendimientos decrecientes y nunca permite un daño negativo.
func calcular_danio(ataque: int, defensa_objetivo: int, potencia: float = 100.0) -> int:
	var ataque_seguro := maxi(1, ataque)
	var defensa_segura := maxi(0, defensa_objetivo)
	var potencia_segura := clampf(potencia, 1.0, 300.0)
	var dano := float(ataque_seguro) * potencia_segura / 100.0
	dano *= 100.0 / (100.0 + float(defensa_segura))
	return maxi(1, roundi(dano))
