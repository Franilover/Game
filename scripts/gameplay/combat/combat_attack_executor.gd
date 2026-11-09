extends RefCounted
class_name CombatAttackExecutor

## Construye las instancias de ejecución de un ataque.
## CombatSystem conserva la decisión de cuándo atacar y cómo resolver sus resultados.


static func crear_ataque_melee(
	atacante: Player,
	direccion: Vector2,
	alcance: float,
	ancho: float,
	objeto: Dictionary,
	duracion: float,
	color: Color,
	danio_directo: int,
	al_detectar_objetivo: Callable
) -> CombatAttackArea:
	if atacante == null or not is_instance_valid(atacante):
		return null

	var ataque := CombatAttackArea.new()
	ataque.configurar(
		atacante,
		direccion,
		alcance,
		ancho,
		objeto,
		duracion,
		color
	)

	if danio_directo >= 0:
		ataque.objeto_ataque["_damage_override"] = danio_directo

	if al_detectar_objetivo.is_valid():
		ataque.objetivo_detectado.connect(
			al_detectar_objetivo.bind(ataque)
		)

	atacante.add_child(ataque)
	return ataque


static func disparar_proyectil(
	atacante: Player,
	raiz_proyectiles: Node,
	direccion: Vector2,
	objeto: Dictionary,
	velocidad: float,
	vida: float,
	radio: float,
	danio: int,
	al_detectar_contacto: Callable,
	al_recibir_impacto: Callable
) -> CombatProjectile:
	if atacante == null or not is_instance_valid(atacante):
		return null
	if raiz_proyectiles == null or not is_instance_valid(raiz_proyectiles):
		return null

	var ataque := CombatAttack.new()
	ataque.configurar(
		atacante,
		direccion,
		objeto,
		"distancia",
		danio,
		"Jugador/Proyectil:" + str(objeto.get("nombre", "Proyectil"))
	)

	var proyectil := CombatProjectile.new()
	raiz_proyectiles.add_child(proyectil)
	proyectil.global_position = atacante.global_position + direccion * 14.0
	proyectil.configurar(
		ataque,
		direccion,
		velocidad,
		vida,
		radio
	)

	if al_detectar_contacto.is_valid():
		proyectil.contacto_detectado.connect(al_detectar_contacto)
	if al_recibir_impacto.is_valid():
		proyectil.objetivo_impactado.connect(al_recibir_impacto)

	return proyectil
