# endpoint-baseline

DASA ITS standard Windows 11 endpoint baseline for SMB clients, deployed from NinjaOne.

```
win11debloat/
  upstream/                    vendored Raphire/Win11Debloat (see UPSTREAM.md), unmodified
  dasa-smb-baseline.json       apps to remove + tweaks to apply   <- the reviewed standard
  dasa-smb-oem-optional.json   opt-in OEM bloat list
  dasa-smb-services.json       services startup changes (upstream does not manage services)
  Invoke-DasaDebloatBaseline.ps1   runner (SYSTEM): Default profile + every existing profile + services
ninjaone/NinjaOne-Stub.ps1     paste into NinjaOne; downloads bundle, verifies SHA256, runs runner
build/build-bundle.py          reproducible bundle zip + SHA256
```

## Change process
1. Edit a `dasa-smb-*.json` on a branch; open a PR (the diff *is* the review).
2. Merge, bump `win11debloat/VERSION.txt`, run `python3 build/build-bundle.py`.
3. Publish a GitHub release with the zip; put its URL and SHA256 in `ninjaone/NinjaOne-Stub.ps1`.
4. Pilot with `whatif=true` before wide deployment.

## Status
DRAFT — not yet run on an endpoint. Pilot on a lab VM, then one client, before rollout.
Intune-managed clients: let Intune own diagnostic-data settings (drop `DisableTelemetry`).

## Deliberately kept (not removed even though upstream selects them by default)
`MSTeams`, `Microsoft.MicrosoftOfficeHub`, `Microsoft.MicrosoftStickyNotes`, `Microsoft.Todos`, `Microsoft.PowerAutomateDesktop`, `Microsoft.WindowsAlarms`, `Microsoft.WindowsSoundRecorder`, `MicrosoftCorporationII.QuickAssist` (remote-support tool; added in 2026.10.30-dasa2).

## Start menu
New profiles get an empty Start (no sponsored pins such as Xbox/WhatsApp/LinkedIn): the runner copies upstream's blank `start2.bin` into the Default profile (2026.10.30-dasa4). Existing users keep their pins. Upstream's `ClearStartAllUsers` is deliberately not used because it also wipes existing users' pins.
