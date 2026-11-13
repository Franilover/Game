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

await $Systems/CutsceneDirector.ejecutar("introduccion_narel", pasos)
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
