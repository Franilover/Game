#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="$ROOT_DIR/data"
DIST_DIR="$ROOT_DIR/dist"
SNAPSHOT="$DATA_DIR/world_initial.json"
TEMP_SNAPSHOT="$(mktemp)"

SUPABASE_URL="https://ftdxthnizdosaaavjhah.supabase.co"
RPC_URL="$SUPABASE_URL/rest/v1/rpc/get_mundo_inicial"
SUPABASE_KEY="sb_publishable_dZowBcHCW7PJ5tV8aDnAPQ_1URMyPbV"

cleanup() {
	rm -f "$TEMP_SNAPSHOT"
}
trap cleanup EXIT

find_godot() {
	if command -v godot >/dev/null 2>&1; then
		echo "godot"
		return
	fi

	if command -v godot4 >/dev/null 2>&1; then
		echo "godot4"
		return
	fi

	echo ""
}

validate_snapshot() {
	python3 - "$1" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"Snapshot inválido: {exc}")
    raise SystemExit(1)

if not isinstance(data, dict):
    print("Snapshot inválido: la raíz no es un objeto JSON.")
    raise SystemExit(1)

if not isinstance(data.get("biomas"), list):
    print("Snapshot inválido: falta 'biomas' o no es una lista.")
    raise SystemExit(1)

print(f"Snapshot válido: {len(data['biomas'])} biomas.")
PY
}

mkdir -p "$DATA_DIR" "$DIST_DIR"

echo "== Garlia: preparando snapshot del mundo =="

if curl -fsS \
	--connect-timeout 8 \
	--max-time 30 \
	-X POST \
	-H "apikey: $SUPABASE_KEY" \
	-H "Content-Type: application/json" \
	-H "Accept: application/json" \
	-d '{}' \
	"$RPC_URL" > "$TEMP_SNAPSHOT"; then
	if validate_snapshot "$TEMP_SNAPSHOT"; then
		mv "$TEMP_SNAPSHOT" "$SNAPSHOT"
		echo "Snapshot actualizado desde Supabase."
	fi
else
	echo "No se pudo consultar Supabase durante el build."

	if [ ! -f "$SNAPSHOT" ]; then
		echo "ERROR: no existe un snapshot local para construir el juego offline."
		exit 1
	fi

	echo "Se conservará el snapshot anterior."
fi

GODOT_BIN="$(find_godot)"

if [ -z "$GODOT_BIN" ]; then
	echo "ERROR: no se encontró 'godot' ni 'godot4' en PATH."
	exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "== Garlia: exportando Linux =="

"$GODOT_BIN" \
	--headless \
	--path "$ROOT_DIR" \
	--export-release "Linux" \
	"$DIST_DIR/Garlia.x86_64"

cat > "$DIST_DIR/Garlia.sh" <<'LAUNCHER'
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/Garlia.x86_64" "$@"
LAUNCHER

chmod +x "$DIST_DIR/Garlia.sh"

echo ""
echo "Build terminado."
echo "Linux:"
echo "  $DIST_DIR/Garlia.x86_64"
echo "  $DIST_DIR/Garlia.sh"
echo "Snapshot:"
echo "  $SNAPSHOT"
