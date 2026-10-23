# IA de criaturas: rutinas, interrupciones y plantillas

## Objetivo

Cada criatura mantiene un ciclo diario reconocible. La percepción y los acontecimientos pueden interrumpir una acción, pero no modifican por sí mismos el horario canónico. Las diferencias entre especies se expresan mediante configuración y capacidades explícitas, no mediante copias completas de la IA.

## Capas del comportamiento

1. **Rutina biológica**: actividad determinada por la hora del mundo y por bloques configurados. Ejemplos: dormir, reposar, cazar, patrullar, proteger, alimentarse.
2. **Percepción**: determina qué estímulos son detectables ahora. Tener una referencia de objetivo no significa que esté detectado.
3. **Decisión**: evalúa la respuesta de la especie al objetivo detectado: ignorar, investigar, perseguir, atacar o huir.
4. **Ejecución**: la máquina de estados realiza la acción elegida. El sistema de combate conserva la autoridad sobre daño y resolución de ataques.
5. **Excepciones**: capacidades y eventos explícitos que pueden suspender una acción o, si una regla lo permite, cambiar temporalmente una rutina.

## Invariantes

- Detectar un objetivo, recibir daño o cambiar de objetivo no edita `ia_config.horario`.
- Una interrupción temporal no reescribe los bloques horarios ni el perfil de especie.
- Dormir/reposar no apaga la percepción; solo se interrumpe el descanso ante un estímulo detectado y una respuesta reconocida por esa especie.
- La rutina horaria se publica como `actividad_horaria`; los estados como perseguir/huir/atacar son acciones transitorias y no deben reutilizar ese metadato.
- La ausencia o corrupción de horario produce una actividad por defecto y nunca conserva un valor viejo en metadatos.
- Si se pierde el objetivo o deja de ser válido, la máquina de estados debe salir de la acción dependiente de ese objetivo.
- La actividad `proteger` es una decisión territorial con su propio selector de amenazas; no debe convertirse en una modificación del horario.
- No se introducen efectos de IA dentro del sistema de daño. La IA propone acciones; el sistema de combate resuelve el resultado.

## Selección de objetivos (implementada en Godot)

El selector normal comparte la misma resolución de respuesta que usa la máquina de estados, mediante `_obtener_respuesta_para_objetivo(candidato)`. Una entidad no se convierte en objetivo solo por ser la más cercana:

- Las criaturas no jugadoras deben cumplir el filtro de `objetivos` y la IA debe tener una respuesta ejecutable para ellas.
- El jugador solo entra en la selección normal si el perfil, el comportamiento o una regla especial define una respuesta válida.
- Las respuestas reconocidas en este momento son `atacar`, `huir`, `perseguir` e `investigar`. Si la especie no decide qué hacer con un candidato, este no desplaza a una presa o amenaza relevante.
- Las reglas de agresión del bosque terminan la evaluación del jugador cuando no se cumple su condición; el perfil general no puede saltarse esa protección.
- Las ramas dedicadas a `proteger` y a buscar refugio conservan sus selectores propios.

Este cambio corrige la selección de objetivos en el código, pero aún requiere validación en Godot con escenarios de varias criaturas, jugador cercano, refugios y criaturas en descanso. No afirma que el comportamiento ya haya sido verificado en ejecución.

## Contrato de configuración actual

El motor lee `criatura.ia_config` y utiliza, cuando existen, claves como:

- `perfil`: identidad de conducta de alto nivel.
- `horario.actividad_por_defecto`: actividad de respaldo.
- `horario.bloques[]`: intervalos con `inicio`, `fin` y `actividad`.
- `horario.buscar_refugio`, `horario.refugio_objetivo`, `horario.radio_refugio`, `horario.radio_proteccion`: opciones territoriales ya consumidas por el motor.
- `deteccion`, `movimiento`, `ataque`, `objetivos`: configuración específica leída por los sistemas actuales.

Esta lista describe claves que el código consume; no garantiza que todas las criaturas las tengan definidas ni declara que exista una tabla de plantillas en Supabase.

## Plantillas compartidas: propuesta de evolución

La plantilla debe ser un bloque de valores por defecto, no una nueva fuente de canon paralela. Cada criatura conserva una identidad y solo declara excepciones necesarias.

Forma conceptual futura:

```json
{
  "perfil": "flaxis",
  "plantilla": "depredador_nocturno",
  "horario": {
    "actividad_por_defecto": "reposar",
    "bloques": [
      {"inicio": 0, "fin": 6, "actividad": "cazar"},
      {"inicio": 6, "fin": 18, "actividad": "reposar"},
      {"inicio": 18, "fin": 24, "actividad": "cazar"}
    ]
  },
  "capacidades": {
    "embestida": true
  }
}
```

El ejemplo es ilustrativo y no debe importarse como dato canónico. No existe aún confirmación de que el campo `plantilla` o el mapa `capacidades` estén implementados en Supabase.

Orden de resolución propuesto:

1. Valores base de la plantilla compartida.
2. Sobrescrituras específicas de `ia_config` de la criatura.
3. Validación y normalización.
4. Configuración efectiva inmutable durante la simulación, salvo recarga explícita de configuración.

No combinar arreglos de bloques de manera implícita: una criatura que declare `horario.bloques` debe reemplazar los bloques heredados completos, salvo que se diseñe una operación de parche explícita.

## Validaciones que debe cubrir la siguiente etapa

- Horas finitas y dentro del rango esperado; normalización controlada de horas cíclicas.
- Bloques incompletos o con actividad vacía.
- Solapamientos: emitir diagnóstico y definir prioridad explícita, sin depender accidentalmente del orden de los datos.
- Cruces de medianoche.
- Horarios ausentes, tipos incorrectos y actividad desconocida.
- Interrupciones durante descanso y retorno al horario después de resolver el estímulo.
- Asegurar que la selección de objetivo no convierta cualquier entidad cercana en una amenaza universal.

## Fuente de verdad y despliegue

Supabase sigue siendo la fuente canónica. Este documento y el código de Godot no autorizan cambios de esquema ni de datos remotos. Antes de crear una tabla de plantillas o migrar configuraciones, inspeccionar el contrato de sincronización de `WorldDataService` y mostrar una propuesta no destructiva para revisión. Hasta entonces, la configuración existente debe seguir funcionando sin exigir el nuevo campo `plantilla`.
