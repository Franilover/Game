-- Actualiza las descripciones visibles de los objetos con un tono natural y casual.
-- Solo modifica public.items.descripcion; no altera propiedades, recetas ni datos de juego.

DO $$
DECLARE
    filas_actualizadas integer;
BEGIN
    UPDATE public.items AS item
    SET descripcion = cambios.descripcion
    FROM (
        VALUES
            ('9f524a72-5ecf-4439-8aa4-f04036ebf67d'::uuid, 'Un arco de diseño particular, equipado con pequeñas runas en su estructura.'),
            ('5cf49bfb-fd6d-4c51-97b1-2584e5ddcd64'::uuid, 'Unas botas diseñadas para facilitar los saltos y alcanzar lugares elevados.'),
            ('a515ec84-46f3-4e41-ac1c-0e56769ad705'::uuid, 'Unas cartas pequeñas con alas incorporadas, utilizadas para enviar mensajes.'),
            ('58bca445-d9dd-4db1-b7ba-b3be5b73f12c'::uuid, 'Un casco con una protección que cubre el rostro y permite respirar en lugares de gran altura.'),
            ('8a9a4737-41c2-4659-a687-146f24093be2'::uuid, 'Una daga ligera con una runa incorporada en su empuñadura.'),
            ('50dfb777-f324-4080-8c86-a63c26ec6504'::uuid, 'Un preparado de origen poco común que se presenta como un pequeño frasco medicinal.'),
            ('af2646c5-4f66-40a6-949a-ca79592c722b'::uuid, 'Un dispositivo de protección que genera una barrera para resguardar a quien lo utiliza.'),
            ('5500bdfb-e737-4064-886b-e81aacb4a04a'::uuid, 'Una espada con una pequeña runa integrada en la empuñadura.'),
            ('346bcd9f-87b7-43db-b968-f4b1f5dfcefa'::uuid, 'Una espada de hoja recta, fabricada con metal de gran resistencia.'),
            ('2eac0eb8-c33a-47ed-a7b6-dd0342d55ee8'::uuid, 'Una espada sencilla hecha de madera, ligera y fácil de manejar.'),
            ('2655370c-2cf7-410e-8a3f-945feb3214d2'::uuid, 'Una espada hecha con una hoja de piedra y un mango de madera.'),
            ('11cbaf31-fe0f-4682-a443-08ab1b9d3adc'::uuid, 'Una espada de aspecto poco común cuya hoja se siente fría al tacto.'),
            ('4ee3ff16-30d5-4ec8-93f0-9e8b2fffb936'::uuid, 'Una espada conocida por su nombre y su particular diseño.'),
            ('6791be24-76b2-415e-8726-5838cc4343e8'::uuid, 'Una flor de pétalos azules que puedes encontrar creciendo de forma silvestre.'),
            ('222f21a0-21f6-4a35-8239-862c6e072f2e'::uuid, 'Una flor de pétalos morados que crece de forma silvestre.'),
            ('768a51e5-e34b-4f11-92e7-a6e7dd3bf55c'::uuid, 'Madera obtenida de los árboles. Se puede utilizar para fabricar herramientas y otros objetos.'),
            ('41770fa4-849d-4ec6-9d79-5db67bfe1c94'::uuid, 'Una manzana fresca y crujiente, ideal para comer durante un viaje.'),
            ('3386cc91-76d8-4a24-b41d-b52e576d0586'::uuid, 'Un mazo de diseño robusto, equipado con pequeñas runas.'),
            ('289f5fe8-b8b8-4784-b69f-bb5264963f8a'::uuid, 'Un medallón dorado con un símbolo del sol grabado en el centro.'),
            ('878a5507-9564-4dbb-a7e6-752e17e3ffe2'::uuid, 'Un pequeño dispositivo diseñado para reducir la luz a su alrededor.'),
            ('3e4276b3-05c8-4214-a6c2-05f43e1597c5'::uuid, 'Una pala sencilla hecha de madera, útil para remover tierra y trabajar el suelo.'),
            ('eba98757-ea3a-4fe4-a215-7dd6a9a99bda'::uuid, 'Una pala con una hoja de piedra y un mango de madera.'),
            ('988dc246-6f86-4301-90f7-22a32d386ff7'::uuid, 'Pan recién horneado, sencillo y fácil de llevar contigo.'),
            ('e6cbaf78-b344-4e8a-b93c-ee6dcfa19ba4'::uuid, 'Un paraguas especial que permite descender lentamente desde lugares elevados.'),
            ('e5100787-8d50-4a39-b799-5e2484ac6a7f'::uuid, 'Una pechera ligera con aberturas en la espalda para dejar espacio a las alas.'),
            ('0dbd76c0-95db-4a91-a9ad-eb8885c4154b'::uuid, 'Un pico sencillo de madera, pensado para extraer piedra y otros materiales.'),
            ('e71aa2d6-ebe4-4ac5-a60d-360e37478c8d'::uuid, 'Un pico con una cabeza de piedra y un mango de madera, útil para extraer materiales más resistentes.'),
            ('0117d138-51ff-4b1b-a317-f8318bf161fa'::uuid, 'Una piedra de tamaño mediano que puedes recoger del suelo.'),
            ('191edb36-2ad9-4fcc-8840-9260b0530ad3'::uuid, 'Una piedra pequeña y fácil de llevar, que también puede utilizarse para lanzarla.'),
            ('e1dde060-a43d-45dc-a595-4e533136d908'::uuid, 'Una pistola de diseño poco habitual que utiliza mineral de Mana para preparar sus disparos.'),
            ('4b1ee67d-8fab-4562-9f5d-bb57af01b433'::uuid, 'Unas plumas suaves y ligeras.'),
            ('7529cd14-7523-4d57-90d9-bd9bc9e28859'::uuid, 'Un sombrero con pequeñas alas a los lados que permite mantenerse suspendido en el aire.'),
            ('2ab6f2f2-e978-41d7-961c-141e0684570d'::uuid, 'Un tótem asociado con la protección, de aspecto sencillo y fácil de reconocer.'),
            ('674d3dc1-23e1-4c24-b32b-405facbb722e'::uuid, 'Un conjunto de piezas con forma de tótem, cada una con su propio diseño.')
    ) AS cambios(id, descripcion)
    WHERE item.id = cambios.id;

    GET DIAGNOSTICS filas_actualizadas = ROW_COUNT;
    IF filas_actualizadas <> 34 THEN
        RAISE EXCEPTION 'Se esperaban actualizar 34 objetos, pero se actualizaron %.', filas_actualizadas;
    END IF;
END $$;
