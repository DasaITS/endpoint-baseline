#!/usr/bin/env python3
"""Build a reproducible bundle zip from win11debloat/ and print its SHA256.
Fixed timestamps + sorted entries: same inputs always give the same hash."""
import hashlib, sys, zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "win11debloat"
version = (root / "VERSION.txt").read_text().strip()
out = Path(sys.argv[1] if len(sys.argv) > 1 else f"DASA-Win11Debloat-{version}.zip").resolve()
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(root.rglob("*")):
        if p.is_file():
            zi = zipfile.ZipInfo(p.relative_to(root).as_posix(), date_time=(2026, 1, 1, 0, 0, 0))
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            z.writestr(zi, p.read_bytes())
print(f"{hashlib.sha256(out.read_bytes()).hexdigest()}  {out.name}")
