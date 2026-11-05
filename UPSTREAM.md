# Vendored upstream

| | |
|---|---|
| Project | https://github.com/Raphire/Win11Debloat (MIT) |
| Tag | `2026.10.30` |
| Commit | `5d88bfe9ef2be5a8a643166a6400eb78a30c46ec` |
| Location | `win11debloat/upstream/` — **unmodified**; `.git` and `.github` omitted |

Upgrade procedure: replace `win11debloat/upstream/` with the new tag's tree, update this file, re-validate every
app ID and tweak name in `win11debloat/dasa-smb-*.json` against the new `upstream/Config/Apps.json` and
`Features.json`, pilot, then bump `VERSION.txt`.
