# Garlia — propuesta de calibración cartográfica v1

Estado: propuesta técnica; no modifica Supabase ni canon.

## 1. Separación de magnitudes

- `km_por_unidad_longitud`: conversión de la unidad física interna. Actualmente calibrada en 0.001 km/uL_longitud.
- `km_por_unidad_mapa`: escala de coordenadas del plano de presentación. Sigue sin determinarse.
- `proyeccion_mapa`: algoritmo para transformar latitud/longitud a coordenadas planas. Sigue sin determinarse.

No se deduce una escala cartográfica a partir del radio planetario: el radio permite calcular distancias sobre la esfera, pero no indica cuántos píxeles, tiles o unidades de mapa cubre una región.

## 2. Distancia geodésica canónica

Usar el radio medio canónico convertido a kilómetros: R = 6400 km.

Para dos puntos (latitud φ₁, longitud λ₁) y (φ₂, λ₂), convertir primero los ángulos a radianes y calcular:

- Δφ = φ₂ − φ₁
- Δλ = λ₂ − λ₁
- a = sin²(Δφ/2) + cos(φ₁) cos(φ₂) sin²(Δλ/2)
- θ = 2 atan2(√a, √(1−a))
- d_km = R θ

Esta distancia es independiente de la proyección usada para dibujar el mapa. La implementación debe limitar numéricamente a a dentro de [0, 1] antes de aplicar las raíces, para evitar errores de redondeo.

## 3. Proyección para la vista global

Candidata para prototipo: equirectangular, con una latitud estándar φ₀ explícita.

- x = R · (λ − λ₀) · cos(φ₀)
- y = R · (φ − φ₀)

Las longitudes se deben desenvolver alrededor de λ₀ para evitar saltos artificiales en el antimeridiano. La proyección equirectangular es simple, pero distorsiona áreas y escalas según la latitud; no se debe usar la distancia euclidiana proyectada como distancia física canónica.

No establecer `proyeccion_mapa` como definitiva hasta acordar el tipo de mapa, el centro/meridiano de referencia y la extensión geográfica que se mostrará. Para un mapa regional podrían convenir otras proyecciones.

## 4. Escala de juego

No asignar todavía `km_por_unidad_mapa`. Primero se necesita una referencia aprobada entre coordenadas canónicas y espacio de juego, por ejemplo:

- una distancia geodésica verificada entre dos anclas existentes;
- la distancia que esas mismas anclas deben cubrir en unidades de mapa/tile;
- una política explícita sobre si la escala es constante o solo aproximada en la proyección.

Con una referencia validada, la escala candidata sería d_km / d_mapa. Validar con al menos una segunda referencia independiente antes de declararla calibrada. No convertir automáticamente tiles de terreno en kilómetros: el tamaño del mapa de juego no es una medida planetaria salvo que el diseño lo establezca.

## 5. Contrato de anclas

Una ancla apta para materialización debe cumplir todo lo siguiente:

1. Geometría de Garlia, tipo `punto`, estado `validada`.
2. Exactamente un vértice válido con latitud en [-90, 90] y longitud en [-180, 180].
3. Relación inequívoca con un único `lugar_id` mediante el rol acordado `centro` o `referencia`; elegir un rol canónico único antes de activar el consumidor.
4. Lugar presente en `lugares_game` y `activo = true`, sin duplicar identidad por chunk.
5. Escala cartográfica y proyección requeridas por el consumidor ya validadas.

No crear anclas, coordenadas ni lugares ficticios para completar datos ausentes.

## 6. Diagnóstico SQL de solo lectura

Ejecutar para revisar el estado antes de cualquier calibración. Esta consulta no escribe datos:

```sql
select
  m.cuerpo_celeste_id,
  m.km_por_unidad_longitud,
  m.km_por_unidad_mapa,
  m.proyeccion_mapa,
  m.estado_calibracion,
  (select count(*)
     from public.geografia_geometrias_v1 g
    where g.cuerpo_celeste_id = m.cuerpo_celeste_id) as geometria_total,
  (select count(*)
     from public.geografia_geometrias_v1 g
    where g.cuerpo_celeste_id = m.cuerpo_celeste_id
      and g.tipo_geometria = 'punto'
      and g.estado = 'validada') as puntos_validados,
  (select count(*)
     from public.geografia_geometria_vertices_v1 v
     join public.geografia_geometrias_v1 g on g.id = v.geometria_id
    where g.cuerpo_celeste_id = m.cuerpo_celeste_id) as vertices_total,
  (select count(*)
     from public.lugares_game lg
    where lg.activo = true) as lugares_game_activos
from public.geografia_mundos_v1 m
where m.cuerpo_celeste_id = 'f379127e-b271-4548-ab77-4b4782129ac1';
```

## 7. Puertas de habilitación

- Física: aprobada; 1 uL_longitud = 0.001 km.
- Geometría canónica: pendiente de anclas verificadas.
- Proyección: candidata, pendiente de decisión.
- Escala mapa/unidad: pendiente de referencias aprobadas.
- Materialización en Godot: bloqueada hasta cumplir las condiciones del contrato.

No se actualizan `km_por_unidad_mapa`, `proyeccion_mapa`, geometrías, vértices ni filas de `lugares_game` con esta propuesta.
