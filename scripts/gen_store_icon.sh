#!/usr/bin/env bash
# Generate store listing icons (512×512) from the launcher source.
# Not committed — run before uploading to RuStore.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/images/app_icon_launcher.png"

if [[ ! -f "$SRC" ]]; then
  echo "missing source: $SRC" >&2
  exit 1
fi

python3 - "$SRC" "$ROOT" <<'PY'
import sys
from pathlib import Path
from PIL import Image

src_path, root = Path(sys.argv[1]), Path(sys.argv[2])
src = Image.open(src_path).convert("RGBA")
bg = Image.new("RGB", src.size, (0, 0, 0))
bg.paste(src, mask=src.split()[3])
out = bg.resize((512, 512), Image.Resampling.LANCZOS)
for rel in ("store/rustore/icon-512.png",):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path, "PNG", optimize=True)
    print(path)
PY
