#!/bin/sh
set -eu
ETIQUETA="${1:?falta la etiqueta}"
PROYECTO="${2:?falta el proyecto}"
ARCHIVO=$(mktemp)
trap 'rm -f "$ARCHIVO"' EXIT
gcloud secrets versions access latest --secret=poc-secrets --project="$PROYECTO" > "$ARCHIVO"
python3 - "$ARCHIVO" "$ETIQUETA" <<'PY'
import json, sys
path, etiqueta = sys.argv[1], sys.argv[2]
with open(path) as handle:
    data = json.load(handle)
data["etiqueta"] = etiqueta
with open(path, "w") as handle:
    json.dump(data, handle)
print(etiqueta)
PY
gcloud secrets versions add poc-secrets --data-file="$ARCHIVO" --project="$PROYECTO"
