# Reglas de arquitectura y mantenimiento

> Documento vivo del proyecto. Registra las reglas acordadas para diseñar, modificar y mantener el código, las escenas y los sistemas de Garlia.
>
> **Alcance:** proyecto Godot. No modifica ni reemplaza el canon de Garlia almacenado en Supabase.

## 1. Propósito

Mantener un proyecto comprensible, ampliable y eficiente. Cada sistema debe resolver su trabajo con la menor complejidad razonable, reutilizando soluciones existentes y evitando código, escenas, recursos o datos que no aporten valor.

La prioridad es que el juego sea fácil de mantener y extender sin sacrificar comportamiento, claridad ni rendimiento.

## 2. Reglas generales

1. **Una responsabilidad clara por sistema.** Un script puede coordinar varias piezas relacionadas, pero no debe convertirse en el dueño de toda la lógica del juego.
2. **Reutilizar antes de duplicar.** Antes de crear una función, componente, escena o servicio, buscar si ya existe una solución equivalente.
3. **Simplicidad proporcional.** No crear abstracciones, gestores, capas o scripts separados si solo añaden indirección sin resolver una necesidad real.
4. **Una sola fuente de verdad.** Una regla o dato debe tener un lugar responsable. Evitar mantener la misma configuración sincronizada manualmente en varios archivos.
5. **Dependencias explícitas.** Los sistemas deben recibir o localizar sus dependencias de forma clara; evitar rutas globales rígidas y referencias ocultas cuando exista una alternativa sencilla.
6. **Separar datos de comportamiento.** Catálogos, configuraciones y parámetros editables deben vivir en recursos o datos cuando eso simplifique su edición y mantenimiento.
7. **No romper contratos existentes.** Antes de cambiar señales, nombres, rutas, formatos de guardado o APIs, buscar todos sus consumidores y definir una migración compatible.
8. **No añadir complejidad preventiva.** No implementar sistemas genéricos para casos hipotéticos. Primero debe existir una necesidad concreta.
9. **No conservar código muerto por costumbre.** Investigar referencias estáticas y dinámicas antes de retirarlo.
10. **No ocultar errores.** Los fallos importantes deben poder diagnosticarse; evitar capturas silenciosas y valores por defecto que disimulen estados inválidos.

## 3. Organización de scripts y sistemas

- Los scripts coordinadores se encargan de conectar sistemas y ordenar el flujo general.
- La lógica especializada pertenece al sistema que realmente la controla.
- Los componentes reutilizables deben tener una API pequeña y estable.
- No crear un script por cada función pequeña: agrupar operaciones que comparten responsabilidad y ciclo de vida.
- Evitar que dos sistemas controlen el mismo estado o ejecuten la misma regla.
- Las dependencias entre sistemas deben apuntar en una dirección comprensible; evitar ciclos.
- Las señales sirven para comunicar acontecimientos entre sistemas desacoplados. No reemplazan llamadas directas cuando existe una relación simple y estable.
- Evitar cadenas largas de `get_node()`, búsquedas repetidas y rutas absolutas dispersas. Centralizar referencias necesarias y validar dependencias en puntos de configuración.
- No usar singletons/autoload como contenedor universal. Reservarlos para servicios realmente globales y de ciclo de vida global.

## 4. Escenas de Godot

1. Las escenas deben seguir siendo editables desde el editor siempre que su contenido represente elementos del mundo o de la interfaz.
2. Mantener juntos los elementos que el usuario necesita editar como una unidad. Por ejemplo, el mapa de Torres, sus TileMaps y sus marcadores de ubicación permanecen en `reino_torres.tscn`.
3. Crear escenas reutilizables para objetos o interfaces que tengan identidad, estructura o comportamiento repetible.
4. No crear escenas adicionales únicamente para envolver un nodo o trasladar datos sin una ventaja clara.
5. Los scripts deben respetar la estructura y los nodos de la escena; evitar reconstruir por código lo que puede editarse directamente en el editor.
6. La lógica de runtime puede instanciar contenido dinámico cuando sea necesario, pero debe reutilizar escenas y componentes existentes.
7. Mantener separadas la presentación visual, las colisiones y la lógica de interacción cuando tengan necesidades distintas.
8. Antes de renombrar o mover nodos, revisar rutas, señales, AnimationPlayer, recursos y scripts que dependan de ellos.

## 5. Reutilización y componentes compartidos

Antes de implementar algo nuevo, comprobar si ya existe:

- Un componente visual o de interacción que pueda configurarse.
- Una función común que resuelva la misma operación.
- Una escena reutilizable que admita parámetros.
- Un recurso de datos que evite repetir constantes.
- Un servicio responsable del mismo dominio.

La reutilización debe reducir duplicación sin crear dependencias excesivas. Si dos funcionalidades solo se parecen visualmente, pero tienen reglas distintas, pueden compartir presentación sin forzar una lógica común.

## 6. Código, nombres y legibilidad

- Usar nombres descriptivos y consistentes con el idioma y convenciones ya presentes en el área del proyecto.
- Mantener funciones enfocadas y con entradas/salidas claras.
- Evitar funciones extensas que mezclen preparación, validación, ejecución y presentación.
- Extraer una función cuando nombre una operación significativa, elimine duplicación o facilite pruebas; no por dividir líneas arbitrariamente.
- Evitar números y cadenas mágicas: usar constantes o datos nombrados cuando representen reglas del juego.
- Evitar comentarios que repitan literalmente el código. Documentar el motivo, las restricciones y los contratos.
- Eliminar variables, parámetros, señales y recursos solo después de comprobar que no se usan indirectamente.
- No añadir dependencias externas si Godot ya ofrece una solución suficiente.

## 7. Datos, estado y guardado

- Cada dato persistente debe tener un responsable claro.
- Separar estado de partida, estado temporal de escena y estado derivado.
- No guardar valores que puedan reconstruirse de forma fiable, salvo que exista una razón de diseño o rendimiento.
- Validar los datos al entrar y salir de los límites del sistema.
- Los cambios al formato de guardado requieren compatibilidad o migración explícita.
- Evitar duplicar en memoria el mismo estado mutable en varios nodos.
- La información canónica remota y sus contratos no se modifican como parte de una refactorización local sin autorización explícita.

## 8. Rendimiento

Optimizar primero los problemas medidos o los costes evidentes.

- Evitar búsquedas de nodos, carga de recursos y construcción de interfaces repetidas cada frame.
- Preferir señales o actualizaciones por cambio cuando no se necesite consultar continuamente.
- Reutilizar recursos y escenas cuando su ciclo de vida lo permita.
- Evitar instanciar nodos temporales en exceso.
- No reemplazar soluciones simples por sistemas complejos de caché sin evidencia de necesidad.
- Mantener el renderizado, colisiones y lógica de simulación separados cuando sus frecuencias o responsabilidades difieran.
- En comprobaciones de proximidad, filtrar primero con `length_squared()` y el radio al cuadrado; calcular la distancia real sólo si la pareja necesita una corrección. Conservar exactamente los límites inclusivos/exclusivos de la regla original.
- Antes de introducir cachés espaciales, particiones o coordinadores globales para bucles de entidades, medir el coste y el volumen real. No sustituir una comparación sencilla por infraestructura más compleja sin beneficio demostrado.
- Probar el impacto real en el hardware objetivo antes de aceptar una optimización como mejora.

## 9. Limpieza segura de código y recursos

Un elemento se considera candidato a eliminación, no basura confirmada, hasta completar estas comprobaciones:

1. Buscar referencias directas en scripts y archivos de proyecto.
2. Buscar referencias indirectas: `preload`, `load`, `load()`, `ResourceLoader`, rutas en texto, nombres de nodos, grupos, señales y configuración.
3. Revisar escenas que instancien scripts o recursos.
4. Revisar autoloads, clases globales (`class_name`), plugins, herramientas y pruebas.
5. Comprobar si el elemento se usa por nombre, reflexión, datos externos o generación dinámica.
6. Eliminar o migrar en un cambio pequeño y rastreable.
7. Ejecutar importación, validación y pruebas pertinentes.
8. Revisar logs y comportamiento del juego.

No borrar por el único motivo de que una búsqueda textual no encuentre referencias.

## 10. Pruebas y validación

Cada cambio debe validarse en proporción al riesgo:

- **Scripts:** análisis/parseo de Godot y pruebas unitarias o de contrato cuando existan.
- **Escenas y recursos:** comprobar que abren, instancian y resuelven sus referencias.
- **Interacciones:** probar el flujo completo, incluidos estados inválidos y salida/cierre.
- **Guardado:** probar carga de partidas nuevas y existentes.
- **Refactorizaciones:** comparar el comportamiento antes y después; no mezclar cambios funcionales no relacionados.
- **Rendimiento:** medir antes y después cuando el objetivo sea optimizar.

Si no se pudo ejecutar Godot o una prueba, dejarlo indicado. Una revisión estática no equivale a una prueba de ejecución.

## 11. Documentación y registro de decisiones

- Registrar aquí las reglas generales que afectan a varias partes del proyecto.
- Documentar contratos concretos cerca del sistema o en `docs/contracts/`.
- Documentar arquitecturas especializadas en `docs/architecture/` o `docs/technical/`.
- Al establecer una regla nueva, indicar si está **Acordada**, **Propuesta** o **En revisión**.
- Registrar el motivo de decisiones importantes y sus consecuencias.
- Actualizar la documentación en el mismo cambio que modifica el comportamiento o contrato documentado.
- Si una decisión cambia, actualizar este documento y los documentos especializados afectados; evitar mantener instrucciones contradictorias.

## 12. Límites de cambios

- Las refactorizaciones deben preservar el comportamiento existente salvo que se apruebe expresamente un cambio funcional.
- No modificar Supabase ni datos canónicos remotos durante limpiezas locales sin autorización explícita.
- No borrar escenas, recursos o sistemas completos sin revisar sus dependencias y alternativas.
- Preferir cambios pequeños, revisables y reversibles.
- No afirmar que algo está probado si no se ejecutó la prueba correspondiente.

## 13. Criterios de aceptación de una refactorización

Una refactorización está lista cuando:

- Reduce duplicación o complejidad real.
- Mantiene una única responsabilidad por sistema.
- No introduce capas o abstracciones innecesarias.
- Conserva contratos y comportamiento, o documenta la migración aprobada.
- No deja referencias rotas ni recursos huérfanos conocidos.
- Incluye validaciones acordes al riesgo.
- Actualiza esta documentación si establece o cambia una regla.

---

## Registro inicial de decisiones

| Regla | Estado | Alcance |
|---|---|---|
| Mantener el mapa de Torres y sus marcadores editables dentro de `reino_torres.tscn` | Acordada | Escena del reino |
| Reutilizar sprites existentes y no generar arte por código para edificios/interiores | Acordada | Arte y escenarios actuales |
| Evitar scripts monolíticos y separar responsabilidades sin fragmentar en exceso | Acordada | Arquitectura general |
| Reutilizar componentes y sistemas antes de duplicar implementaciones | Acordada | Proyecto completo |
| Auditar referencias antes de eliminar código o recursos | Acordada | Limpieza |
| Documentar contratos y reglas que se establezcan durante el trabajo | Acordada | Proyecto completo |
| Mantener cambios locales separados de modificaciones canónicas de Supabase | Acordada | Datos y backend |

## Historial

- **2026-11-19:** creación de las reglas iniciales para la auditoría y refactorización de arquitectura.
- **2026-11-19:** se añade la regla de descarte temprano por distancia al cuadrado para proximidad y el criterio de medir antes de introducir índices/cachés espaciales.


## 14. Límites y composición de sistemas

Estas reglas complementan la responsabilidad única sin imponer un tamaño artificial a los archivos:

- Un archivo se divide cuando contiene responsabilidades con motivos de cambio, dependencias o ciclos de vida diferentes; no por alcanzar un número arbitrario de líneas.
- Antes de extraer un módulo, identificar su dueño, entradas, salidas, estado que controla y consumidores. La extracción debe reducir acoplamiento o duplicación neta.
- Evitar el patrón de «un archivo por función». Las operaciones pequeñas que forman una misma transición permanecen juntas y privadas dentro de su sistema responsable.
- Un sistema coordinador puede orquestar varios sistemas, pero las reglas de dominio deben vivir en un único lugar y no replicarse en el coordinador.
- No crear dos implementaciones activas de la misma regla durante una migración. Si se requiere compatibilidad, el adaptador debe delegar en la implementación canónica.
- Los catálogos constantes se definen una vez en el sistema responsable o en un recurso compartido si varios sistemas realmente los consumen.
- Los componentes base deben resolver una necesidad repetida y estable. No anticipar un framework genérico para sistemas que todavía no comparten un contrato real.

## 15. Contratos base y plantillas

Antes de crear un sistema nuevo, definir brevemente:

1. **Responsabilidad:** qué problema resuelve y qué queda fuera.
2. **Propietario del estado:** qué nodo/servicio es la única autoridad para modificarlo.
3. **API:** operaciones públicas, señales y datos de entrada/salida necesarios.
4. **Dependencias:** qué necesita y cómo se le entrega.
5. **Ciclo de vida:** quién lo crea, configura, pausa, reanuda y destruye.
6. **Persistencia:** qué se guarda, qué es temporal y qué se reconstruye.
7. **Validación:** invariantes y pruebas que protegen el contrato.

Plantilla recomendada para un sistema nuevo (adaptar, no copiar mecánicamente):

```gdscript
extends Node
class_name ExampleSystem

signal state_changed(new_state: Variant)

# Dependencias explícitas configuradas por el propietario.
var _owner: Node

func configurar(owner: Node) -> void:
	_owner = owner

func ejecutar(input: Variant) -> Variant:
	if not is_instance_valid(_owner):
		push_error("ExampleSystem requiere una dependencia válida.")
		return null
	# La regla del dominio vive aquí, en un único lugar.
	return input
```

La plantilla es orientativa: no obliga a añadir señales, estado o métodos que el sistema no necesite. Los nodos de escena, scripts de componentes y recursos de datos deben conservar sus convenciones específicas de Godot.

## 16. Estrategia de pruebas

- Nombrar las pruebas por comportamiento observable o recorrido del jugador, no por el nombre de una función privada.
- Mantener pruebas unitarias para reglas puras; complementarlas con pruebas de integración para transiciones entre sistemas y pruebas de flujo para recorridos completos.
- Una prueba de flujo debe preparar el estado inicial, ejecutar las operaciones públicas reales y verificar tanto el resultado final como los estados intermedios críticos y la limpieza al salir.
- Evitar que la suite dependa de una persona abriendo escenas y repitiendo manualmente los mismos pasos. Automatizar lo determinista; reservar la revisión manual para presentación, controles, legibilidad y sensación de juego.
- Cada escena de prueba referenciada por CI debe existir, cargar el script correcto y terminar con código distinto de cero ante fallos. La importación de scripts por sí sola no prueba que una escena de test exista o se ejecute.
- Los tests deben cubrir contratos y riesgos relevantes, no cada línea ni cada método privado. Si una prueba necesita acceder a muchos detalles internos, evaluar si el contrato está mal definido antes de ampliar la API pública.
- Los fallos de pruebas se diagnostican y corrigen antes de añadir más cobertura sobre el mismo flujo.
- No declarar un sistema completo por pasar una prueba aislada. El estado de cobertura debe describir qué recorridos reales están protegidos y cuáles siguen pendientes.

## 17. Prioridad de mantenimiento

Orden de trabajo acordado:

1. Corregir errores y regresiones verificables.
2. Simplificar y optimizar sistemas existentes, eliminando trabajo repetido y duplicación.
3. Reducir responsabilidades mezcladas en archivos monolíticos sin fragmentar en exceso.
4. Establecer contratos y componentes base cuando haya patrones repetidos comprobados.
5. Automatizar pruebas de integración y recorridos completos para proteger el comportamiento.
6. Ampliar documentación y controles de calidad junto con cada cambio.

Las pruebas, plantillas y documentación respaldan la calidad del juego; no sustituyen la prioridad de mejorar el juego y sus sistemas.

## Registro adicional de decisiones

| Regla | Estado | Alcance |
|---|---|---|
| Dividir archivos por responsabilidad y motivo de cambio, no por tamaño arbitrario | Acordada | Arquitectura general |
| No crear un archivo por función ni sistemas paralelos durante refactorizaciones | Acordada | Arquitectura general |
| Definir propietario del estado, API, dependencias y ciclo de vida antes de crear sistemas | Acordada | Sistemas nuevos |
| Priorizar pruebas de integración y flujos completos junto a pruebas unitarias | Acordada | Validación |
| Automatizar lo determinista y reservar revisión manual para UX/presentación | Acordada | Validación |
| Mejorar primero sistemas existentes; las pruebas acompañan y protegen ese trabajo | Acordada | Proyecto completo |
