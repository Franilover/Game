# Garlia — Arquitectura 2.0

## Objetivo

Rediseñar el proyecto completo antes de continuar corrigiendo síntomas individuales.

La meta no es tener muchos archivos por tenerlos. La meta es que cada archivo tenga un dueño claro, una responsabilidad única y dependencias previsibles.

Regla principal:

SUPABASE MANDA
→ datos canónicos
→ adaptadores/runtime
→ dominio
→ gameplay
→ presentación

La información no debe viajar en sentido contrario para convertirse en fuente de verdad.

---

## 1. Capas

### Core

Código transversal que no conoce el mundo concreto de Garlia.

- ciclo de vida
- señales/eventos
- input gate
- utilidades
- tipos/contratos compartidos

Core no debe conocer HUD, criaturas, armas concretas ni tablas de Supabase.

### Infrastructure

Comunicación con sistemas externos.

- Supabase/Auth
- Realtime
- persistencia
- multiplayer
- carga remota

Infrastructure obtiene datos. No decide reglas de gameplay.

### Domain

Modelo de Garlia.

- Entity
- Creature
- Player
- Item
- Equipment
- World data
- estados persistentes

Domain no debe dibujar UI.

### Gameplay

Reglas y sistemas interactivos.

- Combat
- Interaction
- Inventory
- Dialogue
- Quests
- Eterium
- Exploration

Gameplay recibe datos del dominio y ejecuta reglas.

### World

Construcción y simulación del mundo.

- terrain
- biome/ecosystem/habitat
- generation
- spawning
- decoration
- streaming
- atmosphere

World no debe contener lógica de inventario, UI o combate.

### Presentation

Representación.

- HUD
- inventory UI
- dialogue UI
- combat feedback
- sprites/animations
- menus

Presentation escucha estado/eventos. No se convierte en fuente de verdad.

### Dev

Herramientas de desarrollo, administración y diagnóstico.

---

## 2. Estructura objetivo

La arquitectura conceptual sigue separando Core, Infrastructure, State, Gameplay, World y Presentation/UI, pero la estructura física del proyecto no crea una carpeta para cada concepto pequeño.

```
scripts/
├── characters/
├── creatures/
├── core/
├── dev/
├── gameplay/
│   ├── combat/
│   ├── inventory/
│   └── player/
├── infrastructure/
├── state/
├── ui/
└── world/
```

Criterio: una carpeta física solo se mantiene cuando agrupa varias piezas relacionadas o representa un límite claro del sistema.

La separación conceptual sigue siendo:

Supabase → Infrastructure → State/World → Gameplay → Characters/Creatures → UI

No usamos `globals`, `domain`, `systems` o `presentation` como cajones genéricos.

## 3. Entity

Entity controla exclusivamente estado físico común:

- health
- max_health
- mana si corresponde
- alive/dead
- daño recibido
- curación
- muerte
- señales de estado

Entity no sabe:

- qué arma golpeó
- cómo se dibuja el ataque
- qué misión está activa
- qué UI está abierta
- cómo decide atacar una criatura

---

## 4. Player

Player será una entidad jugable y un coordinador de movimiento/estado del personaje.

No debe contener:

- implementación completa de combate
- implementación completa de inventario
- UI
- consultas directas arbitrarias a Supabase
- reglas de quests
- lógica de diálogo

Player expresa intención y consume servicios de gameplay.

---

## 5. Combat

### CombatController

Único punto de entrada del jugador al combate.

Recibe intención:

- ataque primario
- ataque secundario
- objeto activo

No aplica daño directamente.

### CombatTargeting

Busca y valida objetivos.

No aplica daño.

### CombatAttack

Representa una instancia concreta de ataque.

Contiene:

- atacante
- dirección
- tipo
- objeto usado
- alcance
- ancho
- duración
- contexto

### CombatAttackArea

Implementa el área física de un ataque melee.

Su visual y hitbox tienen el mismo ciclo de vida.

### CombatDamage

Único camino de resolución de daño del gameplay.

```
Attack
→ Target
→ DamageResolver
→ Entity.take_damage()
```

### CombatProjectile

Ataques de distancia.

El proyectil detecta impacto, pero la resolución final sigue perteneciendo a CombatDamage.

### CombatFeedback

Sólo presentación:

- flash
- animación
- sonido
- números de daño
- efectos

---

## 6. CreatureAI

CreatureAI tiene una sola responsabilidad:

decidir comportamiento.

```
percepción
→ decisión
→ intención
→ CombatController/CombatDamage
```

No debe tener una implementación paralela de daño.

---

## 7. Inventory

Separación estricta:

### InventoryRuntime

Qué objetos existen y en qué cantidades.

### Equipment

Qué objetos están equipados.

### Hotbar

Qué índices están disponibles y cuál está seleccionado.

### InventoryController

Coordina operaciones.

### Inventory UI

Sólo representación e interacción visual.

Regla:

Hotbar seleccionado ≠ objeto equipado.

---

## 8. Input

Debe existir una única autoridad para responder:

¿el gameplay puede recibir input?

El resto de sistemas pregunta a esa autoridad.

No se permiten comprobaciones dispersas de:

- inventory.visible
- HUD.visible
- dialogue.visible
- pausado
- paneles

---

## 9. Supabase

Supabase es fuente canónica.

```
Supabase
  ↓
Repository / Loader
  ↓
Domain Runtime
  ↓
Gameplay
```

No:

```
Gameplay
  ↓
"si no existe, invento el valor"
```

Si un valor de gameplay debe existir en Supabase, Godot no crea una segunda versión.

---

## 10. World

El mundo se separa en:

```
WorldData
  ↓
Biome
  ↓
Ecosystem
  ↓
Habitat
  ↓
Terrain / Spawn / Decoration
```

Generation calcula distribución.

Terrain representa terreno.

Spawner crea entidades.

Decoration coloca decoración.

Atmosphere representa ambiente.

Ninguno debe absorber responsabilidades de los otros.

---

## 11. GameState

GameState actual es demasiado amplio.

Se migrará progresivamente hacia:

- SaveState
- WorldState
- DiscoveryState
- PlayerState
- GameplayInputGate

GameState puede seguir existiendo como fachada temporal para no romper el proyecto.

La fachada se elimina sólo cuando las dependencias hayan migrado.

---

## 12. UI

Regla:

Gameplay → señales/eventos → Presentation.

La UI puede emitir comandos explícitos:

- aceptar misión
- cerrar inventario
- seleccionar slot

Pero no debe modificar directamente estado interno arbitrario.

---

## 13. Reglas de dependencia

Permitido:

Core ← todos

Infrastructure → Core

Domain → Core

Gameplay → Domain + Core

World → Domain + Core + Infrastructure adapters

Presentation → Domain + Gameplay events

No permitido:

Domain → UI

Gameplay → UI internals

Entity → CombatSystem

Entity → Supabase

UI → modificar directamente tablas o datos canónicos

CreatureAI → implementar su propio DamageSystem

---

## 14. Migración

No se corrigen bugs individuales durante la migración salvo errores que impidan continuar.

Orden:

1. Crear arquitectura objetivo.
2. Separar contratos y responsabilidades.
3. Mover entidades.
4. Separar GameState.
5. Separar Inventory.
6. Separar Combat.
7. Separar Interaction/Dialogue/Quests.
8. Separar World.
9. Separar Infrastructure/Supabase.
10. Migrar Presentation.
11. Eliminar sistemas duplicados.
12. Compilar y corregir errores estructurales.
13. Recién después: corregir bugs funcionales.

Cada fase debe conservar el comportamiento existente siempre que no contradiga la nueva arquitectura.

---

## 15. Criterio de terminado

Una funcionalidad está correctamente diseñada cuando podemos responder sin mirar cientos de líneas:

- ¿quién posee este estado?
- ¿quién puede modificarlo?
- ¿de dónde viene el dato?
- ¿quién ejecuta la regla?
- ¿quién lo muestra?
- ¿qué evento comunica el cambio?

Si hay dos respuestas posibles, todavía existe duplicación de responsabilidad.
