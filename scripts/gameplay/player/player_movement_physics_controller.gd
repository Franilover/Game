extends RefCounted
class_name PlayerMovementPhysicsController

## Ejecuta la integración física de un CharacterBody2D.
## No decide dirección, velocidad, arena, stamina ni estado de gameplay.


func establecer_velocidad(cuerpo: CharacterBody2D, nueva_velocidad: Vector2) -> void:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	cuerpo.velocity = nueva_velocidad


func aplicar_desplazamiento(cuerpo: CharacterBody2D) -> void:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	cuerpo.move_and_slide()
