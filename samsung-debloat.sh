#!/usr/bin/env bash
#
# samsung-debloat.sh
# Generic debloat for Samsung One UI devices (tested on Galaxy A52s 5G / SM-A528B).
# Removes/quiets common PREINSTALLED SYSTEM bloat only -- nothing personal or
# region-specific, so it is safe to run on any Samsung phone.
#
# Usage:
#   ./samsung-debloat.sh            # apply
#   ./samsung-debloat.sh restore    # undo (reinstall + re-enable + Samsung defaults)
#   ./samsung-debloat.sh list       # show current state
#
# Target device: auto-detects a single device, or a Samsung among several.
# Override with:  SERIAL=<serial> ./samsung-debloat.sh
#
# Requires: adb, USB debugging enabled, device authorized.
# NOTE: adb uninstalls are per-user and reversible; the APK stays on the
#       read-only system image, so `install-existing` restores it.
#       (Exception: apps not part of the system image can only come back from a store.)

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
echo ">> Target: $SERIAL ($("${ADB[@]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r'), One UI $("${ADB[@]}" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r'))"

pkg_installed() {
  "${ADB[@]}" shell pm list packages 2>/dev/null | tr -d '\r' | grep -qx "package:$1"
}

# ---------------------------------------------------------------------------
# Universal preinstalled SYSTEM bloat (safe for any Samsung).
# All entries are OEM/partner preloads -- no user-installed or regional apps.
# ---------------------------------------------------------------------------
UNINSTALL_PACKAGES=(
  # --- Facebook / Meta installers ---
  com.facebook.appmanager
  com.facebook.services
  com.facebook.system

  # --- Bixby suite ---
  com.samsung.android.bixby.agent
  com.samsung.android.bixby.wakeup
  com.samsung.android.bixbyvision.framework
  com.samsung.android.app.settings.bixby
  com.samsung.android.svoiceime

  # --- Games / AR ---
  com.samsung.android.game.gamehome
  com.samsung.android.game.gametools
  com.samsung.android.game.gos
  com.samsung.android.arzone
  com.samsung.android.aremoji
  com.samsung.android.aremojieditor

  # --- Samsung preloads / promos ---
  com.samsung.android.app.spage            # Samsung Free (news feed panel)
  com.samsung.android.kidsinstaller        # Kids Mode
  com.samsung.android.livestickers
  com.samsung.android.app.camera.sticker.facearavatar.preload

  # --- Cross-device / continuity ---
  com.samsung.android.mcfds                # Multi Control
  com.samsung.android.mdecservice          # Call & text on other devices

  # --- Cloud / partner ---
  com.microsoft.skydrive                   # OneDrive (preinstalled)
  com.google.android.apps.tachyon          # Google Meet (preinstalled on some)
  com.sec.android.easyMover                # Smart Switch transfer agent
  com.sec.android.easyMover.Agent          # Smart Switch receiving stub

  # --- Universal Samsung/Google services ---
  com.samsung.android.scloud               # Samsung Cloud
  com.samsung.android.app.homestar         # SmartThings
  # com.google.android.ims is KEPT (RCS backend for Google Messages)
)

# ---------------------------------------------------------------------------
# Samsung apps replaced by default alternatives.
# Only removed if the replacement is actually installed (checked at runtime),
# so this is safe even on devices without the replacement.
# ---------------------------------------------------------------------------
REPLACED_PACKAGES=(
  com.sec.android.app.sbrowser             # Samsung Internet  <- Chrome
  com.samsung.android.messaging            # Samsung Messages  <- Google Messages
)
BROWSER_REPLACEMENT=com.android.chrome
SMS_REPLACEMENT=com.google.android.apps.messaging

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
#   com.google.android.as        Android System Intelligence
#   com.samsung.android.forest   Digital Wellbeing
#   com.samsung.android.lool     Device Care
#   com.sec.android.daemonapp    Weather
#   com.google.android.apps.turbo  Adaptive Battery
#   com.samsung.android.providers.contacts / com.samsung.android.dialer  (core)
#
# Already disabled by Samsung/Google at the factory on some models (leave alone):
#   com.google.android.gms.supervision
#   com.samsung.android.knox.zt.framework
#   com.samsung.android.peripheral.framework
#   com.samsung.cmfa.AuthTouch
# ---------------------------------------------------------------------------

apply_replace_role() {
  # $1 = package, $2 = role
  printf '   %-52s -> %s\n' "$1" "$2"
  "${ADB[@]}" shell cmd role add-role-holder --user 0 "$2" "$1" >/dev/null 2>&1 || true
}

apply_disable() {
  echo ">> Ensuring replacements exist"
  for p in "$BROWSER_REPLACEMENT" "$SMS_REPLACEMENT"; do
    printf '   %-52s ' "$p"
    "${ADB[@]}" shell cmd package install-existing --user 0 "$p" >/dev/null 2>&1 || true
    pkg_installed "$p" && echo "ok" || echo "unavailable (skipping its swap)"
  done

  echo
  echo ">> Uninstalling system bloat (pm uninstall --user 0)"
  for p in "${UNINSTALL_PACKAGES[@]}"; do
    printf '   %-52s ' "$p"
    if pkg_installed "$p"; then
      "${ADB[@]}" shell pm uninstall --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
    else
      echo "not present"
    fi
  done

  echo
  echo ">> Replacing stock browser/SMS (only if replacement present)"
  if pkg_installed "$BROWSER_REPLACEMENT"; then
    printf '   %-52s ' "$BROWSER_REPLACEMENT"
    "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.BROWSER "$BROWSER_REPLACEMENT" >/dev/null 2>&1 && echo "set default browser" || echo "role set failed"
    "${ADB[@]}" shell pm uninstall --user 0 com.sec.android.app.sbrowser >/dev/null 2>&1 || true
  else
    echo "   skip browser swap (no replacement)"
  fi
  if pkg_installed "$SMS_REPLACEMENT"; then
    printf '   %-52s ' "$SMS_REPLACEMENT"
    "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.SMS "$SMS_REPLACEMENT" >/dev/null 2>&1 && echo "set default SMS" || echo "role set failed"
    "${ADB[@]}" shell settings put secure sms_default_application "$SMS_REPLACEMENT" >/dev/null 2>&1 || true
    "${ADB[@]}" shell pm uninstall --user 0 com.samsung.android.messaging >/dev/null 2>&1 || true
  else
    echo "   skip SMS swap (no replacement)"
  fi

  echo
  echo ">> Disabling packages (pm disable-user --user 0)"
  for p in "${PACKAGES[@]}"; do
    printf '   %-52s ' "$p"
    if pkg_installed "$p"; then
      "${ADB[@]}" shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
    else
      echo "not present"
    fi
  done

  echo
  echo ">> Restricting background (standby bucket = restricted)"
  if [ "${#RESTRICTED_APPS[@]}" -eq 0 ]; then
    echo "   (none configured -- edit RESTRICTED_APPS in this script)"
  else
    for p in "${RESTRICTED_APPS[@]}"; do
      printf '   %-52s ' "$p"
      if "${ADB[@]}" shell am set-standby-bucket "$p" restricted >/dev/null 2>&1; then
        echo "bucket $("${ADB[@]}" shell am get-standby-bucket "$p" | tr -d '\r')"
      else
        echo "FAILED (app may not be installed)"
      fi
    done
  fi

  echo
  echo "Done. Reboot not required."
}

apply_restore() {
  echo ">> Reinstalling removed packages for user 0"
  for p in "${UNINSTALL_PACKAGES[@]}" "${REPLACED_PACKAGES[@]}"; do
    printf '   %-52s ' "$p"
    "${ADB[@]}" shell cmd package install-existing --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo ">> Re-enabling disabled packages"
  for p in "${PACKAGES[@]}"; do
    printf '   %-52s ' "$p"
    "${ADB[@]}" shell pm enable --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
  done

  echo
  echo ">> Restoring Samsung default roles"
  printf '   browser -> %-40s ' "com.sec.android.app.sbrowser"
  "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.BROWSER com.sec.android.app.sbrowser >/dev/null 2>&1 && echo "ok" || echo "skipped"
  printf '   SMS     -> %-40s ' "com.samsung.android.messaging"
  "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.SMS com.samsung.android.messaging >/dev/null 2>&1 && echo "ok" || echo "skipped"
  "${ADB[@]}" shell settings put secure sms_default_application com.samsung.android.messaging >/dev/null 2>&1 || true

  echo
  echo ">> Restoring background buckets to active"
  for p in "${RESTRICTED_APPS[@]}"; do
    printf '   %-52s ' "$p"
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
  for p in "${UNINSTALL_PACKAGES[@]}" "${REPLACED_PACKAGES[@]}"; do
    if pkg_installed "$p"; then echo "   $p => still installed"; else echo "   $p => uninstalled (user 0)"; fi
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
