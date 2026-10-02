GARLIA - OFFLINE WORLD SNAPSHOT

Archivos de este parche:

scripts/systems/supabase_client.gd
- Supabase solo se usa como fuente remota.
- Hace la sincronizacion inicial sin bloquear el juego.
- Reintenta si la conexion falla.
- Vuelve a intentar cada 60 segundos.

scripts/world/world_data.gd
- Primero carga user://cache/world_initial.json si es mas reciente que el snapshot incluido.
- Si no existe cache, usa res://data/world_initial.json.
- El mundo local queda disponible antes de consultar internet.
- Las actualizaciones remotas se guardan para la siguiente sesion.
- Mientras hay una partida activa no reemplaza el mundo que ya se esta usando.

 tools/build_release.sh
- Consulta get_mundo_inicial() justo antes del export de Linux.
- Guarda el resultado como data/world_initial.json.
- Si Supabase no esta disponible, reutiliza el snapshot anterior.
- Exporta Garlia.x86_64.
- Genera Garlia.sh como lanzador.

 tools/build_release.ps1
- Igual que el script Linux, pero exporta Windows Desktop a Garlia.exe.

IMPORTANTE

1. Copia estos archivos en las mismas rutas dentro del repo Franilover/Game.
2. Ejecuta el build con internet al menos una vez para generar data/world_initial.json.
3. El archivo data/world_initial.json queda dentro del proyecto y por eso export_presets.cfg con export_filter="all_resources" lo incluye en el build.
4. No se usa service_role. Los scripts de build solo usan la publishable key que ya usa el Game.
5. No se hace ningun cambio en GitHub desde este parche.

Linux:
    ./tools/build_release.sh

Windows PowerShell:
    .\tools\build_release.ps1
