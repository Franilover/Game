# Vínculos y enfrentamientos de Garumis

Rama: `feat/garumi-bond-combat`

## Flujo implementado

- Los Garumis libres son objetivos de interacción contextual al acercarse.
- La interacción abre un menú con **Ofrecer vínculo** y **Enfrentar**.
- La aceptación voluntaria se calcula desde el dato opcional `aceptacion_vinculo` (0 a 1); si falta, usa 0.5. La oferta rechazada no inicia un combate.
- Iniciar un enfrentamiento activa el grupo `damageable` solo para esa instancia y configura su salud de combate (`salud_combate`, predeterminada 40).
- Durante el enfrentamiento, el daño existente de melee y proyectiles/hechizos reduce la salud del Garumi.
- El Garumi nunca muere por esta ruta: su salud mínima es 1.
- Al alcanzar el umbral configurable (`umbral_vinculo_forzado`, predeterminado 25 %), el menú ofrece **Forzar vínculo**.
- Se registran `vinculado` y `tipo_vinculo` en los datos/meta de la instancia; los vínculos voluntarios y forzados se distinguen. El Garumi vinculado deja de ser un objetivo de interacción y daño.

## Prueba

Ejecutar con Godot 4.7:

```bash
godot --headless --path . --script res://tests/world/test_garumi_bond_combat.gd
```

La prueba cubre la inmunidad fuera del combate, daño durante el encuentro, umbral de debilitamiento, vínculo forzado no letal y vínculo voluntario.

## Límite actual

El estado del vínculo vive en la instancia y en su diccionario runtime; todavía no se guarda en Supabase ni en el guardado persistente del jugador. No se ha cambiado el canon ni el esquema de Supabase. La aceptación voluntaria se controla por `aceptacion_vinculo` y queda lista para conectarse con datos canónicos más adelante.
