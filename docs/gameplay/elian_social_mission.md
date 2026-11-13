# Misión social de Elian: Una hornada a tiempo

## Objetivo narrativo

Elian, panadero de Torres, se ha quedado corto de leña mientras prepara una hornada encargada. Pide al jugador tres piezas de madera para mantener el horno encendido. La misión sirve como primera plantilla de una misión social corta: petición, tarea, regreso y reconocimiento.

## Secuencia

1. **Primer encuentro:** Elian explica el problema. La acción «Ayudar a Elian» acepta `ayuda_horno_elian`.
2. **Encargo activo:** al volver antes de reunir los materiales, recuerda que necesita tres piezas de madera.
3. **Recolección:** cada objeto `Madera` recogido suma progreso al objetivo `reunir_lenia`.
4. **Regreso:** al completar las tres piezas, la variante `regreso` se habilita. Hablar con Elian registra el segundo objetivo.
5. **Desenlace:** al completarse la misión, el selector vuelve a evaluar el diálogo y presenta `despedida`. Al aceptar su agradecimiento se registra `promesa_cumplida`, que aumenta amistad y confianza según la personalidad de Elian.

## Datos y claves

- Misión: `ayuda_horno_elian`
- Objetivo 1: `reunir_lenia`, tipo `recoger_item`, item Madera, cantidad 3.
- Objetivo 2: `regreso`, tipo `hablar_personaje`, personaje Elian.
- Dependencia: el objetivo `regreso` contiene `datos.requiere_objetivo_clave = "reunir_lenia"`.
- Variantes de diálogo: `principal`, `encargo_activo`, `regreso`, `despedida`.

## Reglas técnicas añadidas

- `MissionManagerService.cumple_requisito_dialogo()` valida estado de misión y progreso de objetivo antes de mostrar una variante narrativa.
- `_objetivo_habilitado_por_dependencias()` evita que el diálogo de regreso avance antes de terminar la recolección.
- `DialogueSystem` prioriza las variantes condicionadas por misión sobre los saludos basados en amistad o confianza. Si no hay una variante de misión aplicable, mantiene la selección social existente.
- La progresión se guarda con el estado y progreso normal de misiones.

La misión no consume las piezas de Madera del inventario ni concede un objeto físico. Su consecuencia al cerrar el favor es social: el evento `promesa_cumplida`. La entrega física y el sistema de recompensas de inventario quedan fuera de esta primera misión para no simular una operación que el sistema actual todavía no realiza.
