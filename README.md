# Samsung debloat script

A practical ADB debloat for Samsung One UI devices (tested on Galaxy A52s 5G / `SM-A528B`).
It **disables** preinstalled system/Samsung apps and **uninstalls** genuine store apps, and skips anything not present on the device — so it is safe to run on any Samsung phone. Everything is **per-user and reversible**; no root required.

> [!IMPORTANT]
> **Update the device to the latest firmware first.**
> Before running this script, make sure the phone is **fully updated** — install every pending **Software update** (Settings → Software update → Download and install) and let all Play Store / Galaxy Store updates finish.
> Debloating a *partially updated* phone is unreliable: finishing the update can re-install/re-enable preloads, change package names, and undo your debloat. Update once, reboot, then debloat.

## What it does

| Step | Detail |
|---|---|
| Uninstalls (user 0) | Genuine **store apps** only: Facebook, Google Photos, Google TV, Outlook |
| Disables (`disable-user`) | Everything else preinstalled — Bixby, Game services, AR (Zone/Emoji/Doodle), Samsung Free, Kids, sticker preloads, Multi Control, continuity (mdx/mcfserver/beacon/aware), Samsung Cloud, Calendar, Reminder, Samsung Pass/Pay, Samsung Gift, Find, Tips, Health, Edge panels, Themes*, video/Single Take/AR extras, Samsung TTS, vision/OCR/handwriting, plus Google agents (adservices, feedback, partnersetup, print, carrier-wifi, restore, health-connect, federatedcompute, telemetry), Snap camera-kit, OneDrive, Link to Windows |
| Replaces stock apps | Samsung Internet → Chrome, Samsung Messages → Google Messages — **only if the replacement is present and enabled** |

\* `themestore` / `themecenter` are **protected** packages — they cannot be disabled without root, so the script skips them.

**Why disable instead of uninstall?** On Samsung firmware, *uninstalled* preloads can be re-installed on boot (or by an update), whereas **disabling is the durable stock method**. Genuine store apps aren't on the system image, so uninstalling them sticks.

## Safe on any device

Every package is checked before it is touched:

```
if pkg_installed "$p"; then <act>; else echo "not present"; fi
```

So a device that doesn't have a given app simply skips it. The browser/SMS swap is also conditional: the stock app is only removed if its replacement is actually installed **and enabled** — otherwise your default SMS/browser is left alone (so you can never end up with no SMS app).

**KEPT on purpose:** Galaxy Store (`samsungapps`, for Samsung app updates), Android Auto (`gearhead`), `dressroom` (wallpaper engine), Device Care (`lool`), Digital Wellbeing (`forest`), Adaptive Battery (`turbo`), Android System Intelligence (`as`), `smartface` (face unlock), core phone (dialer / contacts / providers / IMS / ePDG), keyboard, camera, Gallery, launcher, My Files, Clock, Calculator, Notes, Maps, Gmail, YouTube.

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
./samsung-debloat.sh restore    # undo: re-enable + reinstall + Samsung defaults
./samsung-debloat.sh list       # show current state (disabled + per-preload enabled state)
```

## Reversibility

Disabled packages come back with `adb shell pm enable --user 0 <package>`.
ADB uninstalls are per-user — the APK stays on the read-only system image:

```bash
adb shell cmd package install-existing --user 0 <package>
```

> Exception: apps not on the system image can only be reinstalled from a store.

## Caveats

- **Run after a firmware update.** Updates and the Play/Samsung auto-install can reinstall preloads — just re-run the script.
- Disabling the stock **browser**/**Messages** is skipped when Chrome/Google Messages aren't installed.
- Never disable phone-core packages (dialer, `providers.contacts`, `telecom`, SystemUI, Settings, GMS/GSF, WebView, IMS).

## Customizing

- Add more store apps to `UNINSTALL_PACKAGES`.
- Add preinstalled apps to `PRELOAD_DISABLE`.
- Add heavy/background apps to `RESTRICTED_APPS` (restricted standby bucket).

## Disclaimer

Use at your own risk. Review the package lists in the script before running.
