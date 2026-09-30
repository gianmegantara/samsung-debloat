#!/usr/bin/env bash
#
# debloat-samsung-a52s.sh
# Re-applies the debloat + battery tweaks done on the Galaxy A52s 5G (SM-A528B).
#
# Usage:
#   ./debloat-samsung-a52s.sh            # apply everything
#   ./debloat-samsung-a52s.sh restore    # undo (reinstall + re-enable + restore defaults)
#   ./debloat-samsung-a52s.sh list       # show current state
#
# Target device: auto-detects a single device, or a Samsung, if several are
# attached. Override with:  SERIAL=RRCRB01AYZX ./debloat-samsung-a52s.sh
#
# Requires: adb, USB debugging enabled, device authorized.
# NOTE: adb uninstalls are per-user and reversible; the APK stays on the
#       read-only system image, so `install-existing` always restores it.
#       (Exception: apps not on the system image can only come back via a store.)

set -u

if ! command -v adb >/dev/null 2>&1; then
  echo "ERROR: adb not found in PATH" >&2
  exit 1
fi

# --- pick target device -----------------------------------------------------
detect_serial() {
  local devs s m
  devs=$(adb devices | awk 'NR>1 && $2=="device"{print $1}')
  if [ "$(printf '%s\n' "$devs" | grep -c .)" -eq 0 ]; then return 1; fi
  if [ "$(printf '%s\n' "$devs" | grep -c .)" -eq 1 ]; then printf '%s' "$devs"; return 0; fi
  for s in $devs; do
    m=$(adb -s "$s" shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r')
    if [ "$m" = "samsung" ]; then printf '%s' "$s"; return 0; fi
  done
  return 1
}

SERIAL="${SERIAL:-$(detect_serial || true)}"
if [ -z "$SERIAL" ]; then
  echo "ERROR: no single target device (found multiple, none Samsung). Set SERIAL=<serial>." >&2
  exit 1
fi
ADB=(adb -s "$SERIAL")
echo ">> Target device: $SERIAL ($("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r'))"

# ---------------------------------------------------------------------------
# REPLACEMENTS: installed (or restored) to cover the default roles we strip.
# ---------------------------------------------------------------------------
REPLACEMENTS=(
  com.android.chrome                       # replaces Samsung Internet
  com.google.android.apps.messaging        # replaces Samsung Messages
)
DEFAULT_BROWSER=com.android.chrome
DEFAULT_SMS=com.google.android.apps.messaging

# Original Samsung role holders (used by `restore`).
SAMSUNG_BROWSER=com.sec.android.app.sbrowser
SAMSUNG_SMS=com.samsung.android.messaging

# ---------------------------------------------------------------------------
# UNINSTALLED for user 0 (pm uninstall --user 0)
# ---------------------------------------------------------------------------
UNINSTALL_PACKAGES=(
  # --- Facebook / Meta installers ---
  com.facebook.appmanager
  com.facebook.services
  com.facebook.system

  # --- Samsung apps replaced or unused ---
  com.sec.android.app.sbrowser             # Samsung Internet (Chrome is default now)
  com.samsung.android.messaging            # Samsung Messages (Google Messages is default)
  com.samsung.android.calendar             # Samsung Calendar (no on-image replacement)
  com.samsung.android.app.reminder         # Samsung Reminder
  com.samsung.android.samsungpass          # Samsung Pass
  com.samsung.android.samsungpassautofill
  com.samsung.android.spayfw               # Samsung Pay/Wallet framework
  com.samsung.android.rajaampat            # Samsung Pay issuer preload
  com.sec.android.app.samsungapps          # Galaxy Store
  com.samsung.android.scloud               # Samsung Cloud
  com.samsung.android.app.spage            # Samsung Free
  com.samsung.android.kidsinstaller
  com.samsung.android.mcfds                # Multi Control
  com.samsung.android.mdecservice          # Call & text on other devices
  com.samsung.android.livestickers
  com.samsung.android.app.camera.sticker.facearavatar.preload
  com.samsung.android.app.homestar         # SmartThings

  # --- Bixby suite ---
  com.samsung.android.bixby.agent
  com.samsung.android.bixby.wakeup
  com.samsung.android.bixbyvision.framework
  com.samsung.android.app.settings.bixby
  com.samsung.android.svoiceime

  # --- Games / AR ---
  com.samsung.android.game.gamehome        # Game Launcher
  com.samsung.android.game.gametools       # Game Tools
  com.samsung.android.game.gos             # Game Optimizing Service
  com.samsung.android.arzone
  com.samsung.android.aremoji
  com.samsung.android.aremojieditor

  # --- Cloud / other ---
  com.microsoft.skydrive                   # OneDrive
  com.google.android.apps.tachyon          # Google Meet
  com.google.android.ims                    # Google/Jibe RCS service
  com.sec.android.easyMover                # Smart Switch transfer agent
  com.sec.android.easyMover.Agent          # Smart Switch receiving stub
  com.srin.indramayu                       # "Samsung Gift Indonesia" preload
)

# ---------------------------------------------------------------------------
# DISABLED with pm disable-user (state = 3). Kept installed.
# ---------------------------------------------------------------------------
PACKAGES=(
  com.samsung.android.rubin.app            # Bixby Routines
  com.google.android.gms.location.history  # Google Location History (GMS module -> disable, never uninstall)
)

# Apps set to the RESTRICTED standby bucket (bucket 45).
# Add your own heavy/background apps here, one package per line, e.g.:
#   com.example.socialapp
#   com.example.shoppingapp
RESTRICTED_APPS=(
)

# ---------------------------------------------------------------------------
# Intentionally KEPT (do NOT touch):
#   com.google.android.as        Android System Intelligence (Live Caption)
#   com.samsung.android.forest   Digital Wellbeing
#   com.samsung.android.smartswitchassistant
#   com.sec.android.daemonapp    Weather
#   com.google.android.apps.bard Gemini
#   com.samsung.aimodelprovider.*  (photo editor AI)
#   com.samsung.android.lool     Device Care
#   com.google.android.apps.turbo  Adaptive Battery
#   com.samsung.android.providers.contacts / com.samsung.android.dialer  (phone/contacts core)
#
# Already disabled by Samsung/Google at the factory (leave alone; shell
# cannot change them; they are NOT runnable anyway):
#   com.google.android.gms.supervision
#   com.samsung.android.knox.zt.framework
#   com.samsung.android.peripheral.framework
#   com.samsung.cmfa.AuthTouch
#
# User-installed apps are left untouched; add any you want to keep out of the
# script by editing the lists above.
# ---------------------------------------------------------------------------

apply_disable() {
  echo ">> Ensuring replacements are installed ($DEFAULT_BROWSER, $DEFAULT_SMS)"
  for p in "${REPLACEMENTS[@]}"; do
    printf '   %-58s ' "$p"
    "${ADB[@]}" shell cmd package install-existing --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo ">> Uninstalling for user 0 (pm uninstall --user 0)"
  for p in "${UNINSTALL_PACKAGES[@]}"; do
    printf '   %-58s ' "$p"
    "${ADB[@]}" shell pm uninstall --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo ">> Disabling packages (pm disable-user --user 0)"
  for p in "${PACKAGES[@]}"; do
    printf '   %-58s ' "$p"
    "${ADB[@]}" shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo ">> Setting default roles"
  printf '   browser -> %-42s ' "$DEFAULT_BROWSER"
  "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.BROWSER "$DEFAULT_BROWSER" >/dev/null 2>&1 && echo "ok" || echo "failed"
  printf '   SMS     -> %-42s ' "$DEFAULT_SMS"
  "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.SMS "$DEFAULT_SMS" >/dev/null 2>&1 && echo "ok" || echo "failed"
  "${ADB[@]}" shell settings put secure sms_default_application "$DEFAULT_SMS" 2>/dev/null

  echo
  echo ">> Restricting background (standby bucket = restricted)"
  for p in "${RESTRICTED_APPS[@]}"; do
    printf '   %-58s ' "$p"
    if "${ADB[@]}" shell am set-standby-bucket "$p" restricted >/dev/null 2>&1; then
      echo "bucket $("${ADB[@]}" shell am get-standby-bucket "$p" | tr -d '\r')"
    else
      echo "FAILED (app may not be installed)"
    fi
  done

  echo
  echo "Done. Reboot not required."
}

apply_restore() {
  echo ">> Reinstalling uninstalled packages for user 0"
  for p in "${UNINSTALL_PACKAGES[@]}"; do
    printf '   %-58s ' "$p"
    "${ADB[@]}" shell cmd package install-existing --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo ">> Re-enabling disabled packages"
  for p in "${PACKAGES[@]}"; do
    printf '   %-58s ' "$p"
    "${ADB[@]}" shell pm enable --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo ">> Restoring Samsung default roles"
  printf '   browser -> %-42s ' "$SAMSUNG_BROWSER"
  "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.BROWSER "$SAMSUNG_BROWSER" >/dev/null 2>&1 && echo "ok" || echo "failed"
  printf '   SMS     -> %-42s ' "$SAMSUNG_SMS"
  "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.SMS "$SAMSUNG_SMS" >/dev/null 2>&1 && echo "ok" || echo "failed"
  "${ADB[@]}" shell settings put secure sms_default_application "$SAMSUNG_SMS" 2>/dev/null

  echo
  echo ">> Restoring background buckets to active"
  for p in "${RESTRICTED_APPS[@]}"; do
    printf '   %-58s ' "$p"
    "${ADB[@]}" shell am set-standby-bucket "$p" active 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo "Done."
}

show_list() {
  echo ">> Disabled packages (pm list packages -d):"
  "${ADB[@]}" shell pm list packages -d | sed 's/package://' | sort
  echo
  echo ">> Uninstalled-for-user packages (expected absent above):"
  for p in "${UNINSTALL_PACKAGES[@]}"; do
    if "${ADB[@]}" shell pm list packages 2>/dev/null | tr -d '\r' | grep -qx "package:$p"; then
      echo "   $p => still installed"
    else
      echo "   $p => uninstalled (user 0)"
    fi
  done
  echo
  echo ">> Default roles:"
  echo "   browser => $("${ADB[@]}" shell cmd role get-role-holders android.app.role.BROWSER 2>/dev/null | tr -d '\r' | tr '\n' ' ')"
  echo "   SMS     => $("${ADB[@]}" shell cmd role get-role-holders android.app.role.SMS 2>/dev/null | tr -d '\r' | tr '\n' ' ')"
  echo
  echo ">> Standby buckets:"
  for p in "${RESTRICTED_APPS[@]}"; do
    echo "   $p => $("${ADB[@]}" shell am get-standby-bucket "$p" | tr -d '\r')"
  done
}

case "${1:-disable}" in
  disable|apply) apply_disable ;;
  restore|undo)  apply_restore ;;
  list)          show_list ;;
  *)
    echo "Usage: $0 [disable|restore|list]" >&2
    exit 2
    ;;
esac
