# Samsung Galaxy A52s 5G — debloat + battery script

An ADB script that debloats a Samsung Galaxy A52s 5G (`SM-A528B`, codename `a52sxq`) and applies a few battery tweaks. Everything is **per-user and reversible** — no root required.

## What it does

| Step | Detail |
|---|---|
| Installs replacements | Chrome (browser) + Google Messages (SMS) so default roles stay covered |
| Uninstalls (user 0) | Facebook installers, Bixby suite, Game/AR extras, Samsung Free, OneDrive, and Samsung apps replaced or unused (Internet, Messages, Calendar, Reminder, Pass, Pay, Galaxy Store, Cloud, …) |
| Disables (`disable-user`) | Bixby Routines (`rubin.app`), Google Location History (`gms.location.history`) |
| Sets defaults | Chrome as default browser, Google Messages as default SMS |
| Restricts background | Instagram, Immich, MyXL set to the `restricted` standby bucket |

`gms.location.history` is only ever **disabled**, never uninstalled (it is a Play Services module).

## Requirements

- Linux/macOS with `adb`
- USB debugging enabled and the device authorized
- Only one device attached, or a Samsung among several (auto-detected). Override with `SERIAL=`:

```bash
SERIAL=RRCRB01AYZX ./debloat-samsung-a52s.sh
```

## Usage

```bash
./debloat-samsung-a52s.sh            # apply everything
./debloat-samsung-a52s.sh restore    # undo: reinstall + re-enable + Samsung defaults
./debloat-samsung-a52s.sh list       # show current state (disabled, uninstalled, roles, buckets)
```

## Reversibility

ADB uninstalls are **per user** — the APK stays on the read-only system image, so:

```bash
adb shell cmd package install-existing --user 0 <package>
```

restores it. Disabled packages come back with:

```bash
adb shell pm enable --user 0 <package>
```

> Exception: apps that are not on the system image can only be reinstalled from a store.

## Caveats

- **OTA updates may reinstall/re-enable preloads** (and can re-add apps you removed). Re-run the script afterwards.
- **Samsung Calendar** has no on-image replacement — install one from the Play Store if needed.
- Removing **Galaxy Store** means no Samsung-app updates through it; restore with `install-existing` if required.
- Removing **Samsung Pass** drops Samsung-account autofill (use a password manager).
- Never uninstall/disable phone core packages (dialer, `providers.contacts`, `telecom`, SystemUI, Settings, GMS/GSF, WebView, IMS).

## Not touched

Device Care (`lool`), Digital Wellbeing, Weather, Adaptive Battery (`turbo`), Android System Intelligence (`as`), Gemini, photo-editor AI models, and the BPJS apps.

## Disclaimer

Use at your own risk. Review the package lists in the script before running.
