# Samsung debloat script

A practical ADB debloat for Samsung One UI devices (tested on Galaxy A52s 5G / `SM-A528B`). It removes/quiets **preinstalled system and Samsung apps** and skips anything not present on the device, so it is safe to run on any Samsung phone. Everything is **per-user and reversible**; no root required.

## What it does

| Step | Detail |
|---|---|
| Uninstalls (user 0) | Facebook/Meta installers, Bixby suite, Game services, AR Emoji/Zone, Samsung Free, Kids Mode, camera sticker preloads, Multi Control, Call & Text on other devices, OneDrive, Google Meet, Smart Switch agents, Samsung Cloud, SmartThings, **Samsung Calendar/Reminder/Pass/Pay, Galaxy Store, Samsung Gift** |
| Replaces stock apps | Samsung Internet → Chrome, Samsung Messages → Google Messages — **only if the replacement is present and enabled** |
| Disables (`disable-user`) | Bixby Routines (`rubin.app`), Google Location History (`gms.location.history`), Game Optimizing Service (`game.gos`), plus optional telemetry/agent services (Aura, diagnostics, Hiya, Link to Windows, …) |

`gms.location.history` is only ever **disabled**, never uninstalled (it is a Play Services module).

## Safe on any device

Every package is checked before it is touched:

```
if pkg_installed "$p"; then <act>; else echo "not present"; fi
```

So a device that doesn't have a given app (e.g. a model without Bixby, or one without a specific app) simply skips it. The browser/SMS swap is also conditional: the stock app is only removed if its replacement is actually installed — otherwise your default SMS/browser is left alone (so you can never end up with no SMS app).

## Requirements

- Linux/macOS with `adb`
- USB debugging enabled and the device authorized
- One device attached, or a Samsung among several (auto-detected). Override:

```bash
SERIAL=RRCRB01AYZX ./samsung-debloat.sh
```

## Usage

```bash
./samsung-debloat.sh            # apply
./samsung-debloat.sh restore    # undo: reinstall + re-enable + Samsung defaults
./samsung-debloat.sh list       # show current state
```

## Reversibility

ADB uninstalls are **per user** — the APK stays on the read-only system image:

```bash
adb shell cmd package install-existing --user 0 <package>
```

Disabled packages come back with `adb shell pm enable --user 0 <package>`.

> Exception: apps not on the system image can only be reinstalled from a store.

## Caveats

- **OTA updates may reinstall/re-enable preloads.** Re-run the script afterwards.
- Uninstalling the stock **browser**/**Messages** is skipped when Chrome/Google Messages aren't installed.
- Never uninstall/disable phone core packages (dialer, `providers.contacts`, `telecom`, SystemUI, Settings, GMS/GSF, WebView, IMS).

## Not touched

Device Care (`lool`), Digital Wellbeing, Weather, Adaptive Battery (`turbo`), Android System Intelligence (`as`), photo-editor AI models, and all user-installed apps.

## Customizing

- Add packages you want removed to `UNINSTALL_PACKAGES`.
- Add heavy/background apps to `RESTRICTED_APPS` to put them in the `restricted` standby bucket.

## Disclaimer

Use at your own risk. Review the package lists in the script before running.
