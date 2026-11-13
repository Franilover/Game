# Misión social de Elian: Una hornada a tiempo

## Objetivo narrativo

Elian, panadero de Torres, se ha quedado corto de leña mientras prepara una hornada encargada. Pide al jugador tres piezas de madera para mantener el horno encendido. La misión sirve como primera plantilla de una misión social corta: petición, tarea, regreso y reconocimiento.

## Secuencia

1. **Primer encuentro:** Elian explica que la carreta con harina aún no ha llegado y no puede abandonar el horno. La acción «Ayudar a Elian» acepta `ayuda_horno_elian`.
2. **Encargo activo:** Elian pide al jugador que consulte a Darven en el puesto de guardia.
3. **Consulta:** al hablar con Darven durante la misión, se muestra su variante contextual. Explica que la carreta tuvo que detenerse por una rueda dañada y que ya retomó el camino.
4. **Regreso:** al completar la consulta, la variante `regreso` de Elian se habilita. Hablar con él registra el segundo objetivo.
5. **Desenlace:** al completarse la misión, el selector vuelve a evaluar el diálogo y presenta `despedida`. Al aceptar su agradecimiento se registra `promesa_cumplida`, que aumenta amistad y confianza según la personalidad de Elian.

## Datos y claves

- Misión: `ayuda_horno_elian`
- Objetivo 1: `consulta_elian`, tipo `hablar_personaje`, personaje Darven.
- Objetivo 2: `regreso`, tipo `hablar_personaje`, personaje Elian.
- Dependencia: el objetivo `regreso` contiene `datos.requiere_objetivo_clave = "consulta_elian"`.
- Variantes de Elian: `principal`, `encargo_activo`, `regreso`, `despedida`.
- Variante de Darven: `consulta_elian`, activa solo mientras la misión está en curso.

## Reglas técnicas añadidas

- `MissionManagerService.cumple_requisito_dialogo()` valida estado de misión y progreso de objetivo antes de mostrar una variante narrativa.
- `_objetivo_habilitado_por_dependencias()` evita que el diálogo de regreso avance antes de terminar la recolección.
- `DialogueSystem` prioriza las variantes condicionadas por misión sobre los saludos basados en amistad o confianza. Si no hay una variante de misión aplicable, mantiene la selección social existente.
- La progresión se guarda con el estado y progreso normal de misiones.

La misión no requiere objetos ni consume inventario. Su consecuencia al cerrar el favor es social: el evento `promesa_cumplida`.
