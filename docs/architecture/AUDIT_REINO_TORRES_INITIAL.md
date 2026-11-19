# Auditoría inicial: Reino Torres

**Rama inspeccionada:** `feat/npc-relational-memory-decay`  
**Alcance:** inspección estática inicial del script y escena de Reino Torres, estructura del repositorio y workflows existentes.  
**Estado:** diagnóstico preliminar; no se han movido funciones ni eliminado código.

## 1. Evidencia de tamaño y responsabilidades

- `scripts/world/reino_torres.gd`: 2900 líneas y 115 funciones declaradas.
- `scenes/kingdom/reino_torres.tscn`: 293 declaraciones de nodos; la escena contiene la composición editable del mapa y edificios.
- Pruebas localizadas en `tests/world/`: 30 archivos entre scripts y escenas de prueba.

Distribución funcional preliminar:
Inicialización y accesos: 10 funciones
Terreno y decoración: 9 funciones
Ambiente y eventos: 9 funciones
Pixel art: 6 funciones
Interiores y NPC: 25 funciones
Servicios interiores: 16 funciones
Estaciones y comercio: 18 funciones
Vivero y viaje: 18 funciones

## 2. Hallazgos confirmados por inspección

### RT-01 — Coordinación de demasiados dominios en un solo script
El script coordina inicialización del mapa, terreno, arte ambiental, clima/eventos, interiores, ciclo de NPC, servicios de edificios, vivero y viajes. Las áreas de interiores/servicios son candidatas a revisión separada de la generación del mapa.

**Riesgo:** cambios de interfaz o de interiores pueden afectar al script principal del mapa, y viceversa.

### RT-02 — Construcción visual y comportamiento mezclados
El archivo contiene funciones de carga/agrupación de sprites y polígonos junto con interacciones, persistencia y navegación. Hay responsabilidades de presentación que conviene contrastar con `torres_pixel_art.gd`, `torres_tilemap_layout.gd` y `building_interior_style.gd` antes de crear nuevas abstracciones.

### RT-03 — Interiores y servicios acoplados
La construcción de habitaciones, sincronización de NPC, colisiones, estado de interior y servicios de posada/archivo/laboratorio/comercio viven en el mismo script. La extracción debe conservar las rutas de nodos y los contratos de entrada/salida.

### RT-04 — La escena es una fuente de configuración editable
`reino_torres.tscn` contiene grupos de edificios, marcadores y nodos de colisión. No se debe trasladar su distribución a datos generados ni a otra escena sin una razón aprobada. Los marcadores deben seguir editándose desde el editor.

### RT-05 — CI repetido y desigual
Hay workflows especializados que vuelven a descargar e instalar Godot 4.7 y repiten la importación headless. El workflow principal contiene una batería extensa; los otros dos repiten parte del arranque y validación. Antes de consolidar, hay que preservar los disparadores y las pruebas únicas.

### RT-06 — Lint/format no integrado en CI
En los workflows revisados no aparece ejecución de `gdlint` ni `gdformat`. Se recomienda introducir primero un diagnóstico informativo/no bloqueante y medir los hallazgos antes de definir reglas obligatorias.

## 3. Herramientas propuestas

- `gdtoolkit`: diagnóstico con `gdlint` y formato con `gdformat`. No reformatear masivamente durante la primera fase.
- Godot 4.7 headless: importación y validación de recursos/scripts.
- Batería actual de pruebas: conservar los contratos propios antes de evaluar otro framework.
- GitHub Actions: comenzar con lint informativo; convertirlo en bloqueo por etapas cuando la deuda heredada esté clasificada.

No se propone instalar un plugin de editor adicional todavía. La herramienta de lint puede ejecutarse desde terminal/CI y no necesita añadir un addon al proyecto.

## 4. Secuencia segura de refactor

1. Mapear las dependencias externas de cada grupo de funciones: referencias desde escenas, scripts, señales, grupos, autoloads y llamadas dinámicas.
2. Identificar estado compartido y ciclo de vida: jugador, NPC, interior activo, cámara, contenedores, clima y datos guardados.
3. Definir límites de extracción con interfaces pequeñas y dependencias explícitas.
4. Extraer primero una unidad de bajo acoplamiento con pruebas de contrato; evitar comenzar por la posada o el flujo de interiores que comparten estado.
5. Ejecutar importación headless y pruebas relevantes tras cada extracción.
6. Actualizar documentación y tracker con evidencia reproducible.

## 5. No concluido / no afirmar todavía

- No se ha demostrado que haya funciones sin uso.
- No se han probado visualmente los interiores, colisiones o posiciones de NPC.
- No se ha ejecutado Godot ni gdtoolkit en un entorno local en esta auditoría.
- No se ha medido rendimiento.
- No se han cambiado scripts, escenas, recursos ni datos de Supabase.

## 6. Criterio para retirar código

Solo marcar una función o recurso como candidato a eliminación después de revisar llamadas directas, `preload/load`, referencias de escena, señales, grupos, `call()/call_deferred()`, `Callable`, nombres de nodos y rutas dinámicas, autoloads, clases globales, pruebas y recursos de exportación.
