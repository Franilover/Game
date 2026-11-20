# Contrato actual de vínculos Garumi

> Este documento reemplaza el diseño histórico de enfrentamientos de la rama `feat/garumi-bond-combat`. El sistema de combate exclusivo de Garumis quedó retirado.

## Reglas vigentes

- Los Garumis son entidades de exploración e interacción; se les conoce mediante conversación, relación y encuentros del mundo.
- No se capturan ni se incorporan a un grupo de combate.
- No tienen vida, salud, derrota, experiencia ni estadísticas de combate.
- No reciben daño del sistema común y no forman parte del grupo `damageable`.
- El jugador conserva su combate habitual con armas y ataques normales contra criaturas combatientes.
- Un vínculo Garumi permite conservar la relación y seleccionar una fuente de dones. No convierte al Garumi en una unidad invocable.
- Los Garumis vinculados conservan su posición y su estado propio de Eterium.
- La ejecución de dones prestados todavía requiere una integración explícita con las acciones del jugador. No se deben inventar efectos, costes o habilidades a partir de nombres de elementos.

## Persistencia

La instancia vinculada se restaura con `restaurar_vinculo_persistido(posicion)`. El estado de mundo no debe guardar campos de combate como `health`, `max_health`, `is_alive`, `nivel` o `experiencia_total`.

## Pruebas

- `tests/creatures/test_garumi_noncombat_contract.gd`
- `tests/world/test_garumi_world_presence.gd`

Ejecutar con Godot 4.7:

```bash
godot --headless --path . --script res://tests/creatures/test_garumi_noncombat_contract.gd
godot --headless --path . --script res://tests/world/test_garumi_world_presence.gd
```
