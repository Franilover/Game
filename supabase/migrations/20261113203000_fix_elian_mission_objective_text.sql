-- Corrige el texto del objetivo final de Elian para reflejar la consulta a Darven.
-- La misión trata sobre la carreta de harina; no requiere reunir madera.
UPDATE public.misiones_objetivos_game
SET descripcion = 'Vuelve a hablar con Elian y cuéntale lo que averiguaste sobre la carreta.'
WHERE id = 'e455734f-1e29-469d-ba78-8960e3d20581'
  AND clave = 'regreso'
  AND mision_id = '73df4149-39b3-4538-b1e1-e99c0d755a30';
