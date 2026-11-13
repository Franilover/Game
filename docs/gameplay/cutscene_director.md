# CutsceneDirector

Sistema de secuencias reutilizable para escenas de historia, eventos de mundo y encuentros con personajes. El director coordina los sistemas existentes; no crea una segunda interfaz de diálogo ni un sistema paralelo de entrada.

## Integración

```gdscript
var pasos: Array[Dictionary] = [
	{
		"tipo": "camara",
		"x": 240.0,
		"y": -80.0,
		"duracion": 1.2
	},
	{
		"tipo": "dialogo",
		"datos": {
			"lineas": [
				{"hablante": "Narel", "texto": "He encontrado algo extraño en los registros."},
				{"hablante": "Jugador", "texto": "¿Qué encontraste?"}
			]
		}
	},
	{"tipo": "esperar", "segundos": 0.4},
	{"tipo": "evento", "clave": "investigacion_narel_iniciada", "datos": {"origen": "cinematica"}}
]

await $CutsceneDirector.ejecutar("introduccion_narel", pasos)
```

El nodo se crea desde `Main` y recibe Player, DialogueSystem y Camera2D. Mientras reproduce una secuencia se agrega a `modal_ui`, bloqueando movimiento, combate e interacciones. El diálogo sigue usando DialogueSystem y sus controles habituales. La cámara deja de seguir al jugador durante la secuencia y vuelve a él al finalizar.

## Tipos de paso

| Tipo | Campos | Comportamiento |
| --- | --- | --- |
| `dialogo` | `datos` | Abre un diálogo normal mediante DialogueSystem y espera a que termine. |
| `esperar` | `segundos` | Pausa la secuencia; máximo 60 segundos. |
| `camara` | `x`, `y`, `duracion`, opcional `objetivo` | Desplaza suavemente la cámara a coordenadas globales o a un Node2D indicado por ruta absoluta. |
| `evento` | `clave`, opcional `datos` | Emite `evento_solicitado(clave, datos)` para que misiones u otros sistemas reaccionen. |
| `notificacion` | `texto` | Publica una notificación mediante Events. |

## Contrato y límites actuales

- Las secuencias son datos (`Array[Dictionary]`), por lo que pueden cargarse desde Supabase cuando exista un esquema de contenido narrativo aprobado.
- No se creó ni modificó ninguna tabla de Supabase: el proyecto sigue sin un contrato de datos de cinemáticas definido.
- La señal `evento_solicitado` permite conectar recompensas, misiones, flags o cambios sociales sin acoplar el director a esos sistemas.
- `cancelar()` cierra el diálogo activo, detiene la interpolación de cámara y libera el bloqueo. Las esperas asíncronas usan una generación de ejecución para impedir que una secuencia cancelada continúe.
- Los diálogos pueden usar las variantes y acciones que DialogueSystem ya admite.


## Consecuencias sociales

Las secuencias y los diálogos pueden registrar hechos con `RelationshipSystem.registrar_evento_social()`. El director de cinemáticas acepta eventos con el prefijo `social:`; sus datos deben incluir el ID de personaje.

Ejemplo de pasos de una cinemática:

```gdscript
[
	{
		"tipo": "dialogo",
		"datos": {
			"lineas": [
				{"hablante": "Narel", "texto": "¿Me ayudarías a revisar estos registros?"}
			]
		}
	},
	{
		"tipo": "evento",
		"clave": "social:ayudar",
		"datos": {
			"personaje_game_id": "ID_DEL_PERSONAJE",
			"evento_id": "narel_archivo_ayuda_01",
			"contexto": {"origen": "historia"}
		}
	}
]
```

Los diálogos admiten una acción `evento_social` en sus acciones de elección:

```json
{
  "tipo": "evento_social",
  "evento": "promesa_cumplida",
  "evento_id": "bruna_encargo_herreria_01",
  "contexto": {"mision": "encargo_herreria"}
}
```

### Eventos reconocidos

| Evento | Efecto base |
| --- | --- |
| `ayudar` | Amistad +1.5, confianza +1 |
| `apoyar` | Amistad +2, afecto +1 |
| `promesa_cumplida` | Amistad +1.5, confianza +4 |
| `promesa_rota` | Amistad -3, confianza -10 |
| `decir_verdad` | Confianza +3 |
| `mentir` | Confianza -8, respeto -1 |
| `demostrar_habilidad` | Respeto +2.5, amistad +0.5 |
| `compartir_conocimiento` | Amistad +1, respeto +1.5 |
| `faltar_respeto` | Respeto -7, amistad -2 |
| `traicionar` | Confianza -20, amistad -8, afecto -4 |

Los valores se limitan al rango -100 a 100. Los rasgos de personalidad modulan la intensidad de la reacción con un multiplicador entre 0.75 y 1.25: generosidad influye en ayudar, sociabilidad en apoyar, curiosidad en conocimiento/habilidad, prudencia en confianza y agresividad en la respuesta al irrespeto. Los cambios se calculan de forma determinista, sin tiradas aleatorias.

`evento_id` evita aplicar dos veces un mismo hecho mientras ese recuerdo permanezca en el historial reciente del personaje (máximo 32 recuerdos). Para hechos únicos de historia o misiones, usar una clave estable y específica.
