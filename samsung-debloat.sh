#!/usr/bin/env bash
#
# samsung-debloat.sh
# Debloat for Samsung One UI devices (tested on Galaxy A52s 5G / SM-A528B and Galaxy A24 / SM-A245F).
# Removes/quiets preinstalled system, partner and Samsung apps plus a set of
# background/telemetry agents. Every package is presence-checked at runtime, so
# anything not on the device is simply skipped -- safe to run on any Samsung phone.
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

# enabled = state 0 (default) or 1 (enabled); 2/3/4 = disabled
pkg_enabled() {
  local st
  st=$("${ADB[@]}" shell dumpsys package "$1" 2>/dev/null | grep -m1 -oE "enabled=[0-9]+" | grep -oE "[0-9]+$")
  [ "${st:-9}" = "0" ] || [ "${st:-9}" = "1" ]
}

# ---------------------------------------------------------------------------
# STORE / USER APPS -- fully uninstalled for user 0 (pm uninstall --user 0).
# Not on the read-only system image, so removal sticks across reboots.
# Reverse: reinstall from the store.
# ---------------------------------------------------------------------------
UNINSTALL_PACKAGES=(
  com.facebook.katana                      # Facebook
  com.google.android.apps.photos           # Google Photos
  com.google.android.videos                # Google TV
  com.microsoft.office.outlook             # Outlook
)

# ---------------------------------------------------------------------------
# PREINSTALLED SYSTEM APPS -- DISABLED, not uninstalled (pm disable-user).
# Some Samsung firmware RE-INSTALLS uninstalled preloads on boot; disabling is
# the most durable stock method. Reverse: `pm enable --user 0 <pkg>`.
# ---------------------------------------------------------------------------
PRELOAD_DISABLE=(
  # --- Google background agents / telemetry (Android Auto + GMS kept) ---
  com.google.android.adservices.api
  com.google.mainline.adservices
  com.google.android.ondevicepersonalization.services
  com.google.android.feedback
  com.google.android.partnersetup
  com.google.android.printservice.recommendation
  com.google.android.apps.carrier.carrierwifi
  com.google.android.apps.restore
  com.google.android.healthconnect.controller
  com.google.android.health.connect.backuprestore
  com.google.android.federatedcompute
  com.google.mainline.telemetry
  com.google.ar.core                        # ARCore (re-enable if you use AR apps)
  com.google.android.apps.tachyon           # Google Meet
  com.google.android.apps.docs              # Google Drive
  com.google.android.apps.translate         # Google Translate
  com.google.android.apps.youtube.music     # YouTube Music
  com.snap.camerakit.plugin.v1              # Snapchat camera-kit preload
  com.microsoft.appmanager                  # Link to Windows
  com.microsoft.skydrive                    # OneDrive

  # --- Samsung: Bixby ---
  com.samsung.android.bixby.agent
  com.samsung.android.bixby.wakeup
  com.samsung.android.bixbyvision.framework
  com.samsung.android.app.settings.bixby
  com.samsung.android.svoiceime

  # --- Samsung: Games / AR ---
  com.samsung.android.game.gamehome
  com.samsung.android.game.gametools
  com.samsung.android.game.gos
  com.samsung.android.arzone
  com.samsung.android.aremoji
  com.samsung.android.aremojieditor
  com.samsung.android.ardrawing
  com.samsung.android.visualars
  com.samsung.android.stickercenter
  com.sec.android.mimage.avatarstickers
  com.samsung.app.newtrim
  com.samsung.android.app.camera.sticker.facearavatar.preload

  # --- Samsung: apps / services ---
  com.samsung.android.app.spage
  com.samsung.android.kidsinstaller
  com.samsung.android.scloud
  com.samsung.android.calendar
  com.samsung.android.app.reminder
  com.samsung.android.samsungpass
  com.samsung.android.samsungpassautofill
  com.samsung.android.spayfw
  com.samsung.android.rajaampat
  com.samsung.android.mcfds
  com.samsung.android.mdecservice
  com.samsung.android.app.parentalcare
  com.samsung.android.app.watchmanagerstub
  com.samsung.android.app.aodservice
  com.samsung.android.app.sharelive
  com.samsung.android.app.smartcapture
  com.samsung.android.bluelightfilter
  com.samsung.android.callassistant
  com.samsung.android.mapsagent
  com.samsung.storyservice
  com.samsung.android.video
  com.samsung.android.singletake.service
  com.samsung.android.visionintelligence
  com.samsung.android.sdk.ocr
  com.samsung.android.sdk.handwriting
  com.samsung.android.intellivoiceservice
  com.samsung.SMT
  com.diotek.sec.lookup.dictionary
  com.sec.android.app.magnifier
  com.sec.android.easyonehand
  com.sec.android.app.soundalive
  com.sec.android.mimage.photoretouching

  # --- Samsung: Edge panels ---
  com.samsung.android.app.cocktailbarservice
  com.samsung.android.app.appsedge
  com.samsung.android.app.taskedge
  com.samsung.android.app.clipboardedge

  # --- Samsung: continuity ---
  com.samsung.android.mdx
  com.samsung.android.mdx.kit
  com.samsung.android.mdx.quickboard
  com.samsung.android.mcfserver
  com.samsung.android.beaconmanager
  com.samsung.android.aware.service

  # --- Samsung: telemetry / agents ---
  com.aura.oobe.samsung.gl
  com.samsung.android.smartsuggestions
  com.samsung.android.da.daagent
  com.samsung.android.dqagent
  com.samsung.android.dsms
  com.sec.android.sdhms
  com.sec.android.diagmonagent
  com.samsung.crane
  com.samsung.cmh
  com.samsung.android.gru
  com.hiya.star
  com.samsung.android.smartcallprovider

  # --- Other ---
  com.samsung.android.messaging            # Samsung Messages (Google Messages is default)
  com.srin.indramayu                       # "Samsung Gift Indonesia" preload
  com.sec.android.easyMover                # Smart Switch transfer agent
  com.sec.android.easyMover.Agent          # Smart Switch receiving stub
  # com.samsung.android.themestore / themecenter are PROTECTED (cannot disable)
  # com.sec.android.app.samsungapps          Galaxy Store -- KEPT (Samsung app updates)
  # com.google.android.projection.gearhead   Android Auto -- KEPT
  # com.samsung.android.app.dressroom        wallpaper/theme engine -- KEPT
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
  com.google.android.gms.location.history  # Google Location History (GMS module -> disable, never uninstall)
  com.samsung.android.game.gos             # Game Optimizing Service (privileged; reinstalls itself -> disable, not uninstall)

  # --- Telemetry / optional Samsung agents (safe to disable) ---
  com.aura.oobe.samsung.gl                 # Aura setup/marketing partner
  com.samsung.android.smartsuggestions     # suggestion engine
  com.samsung.android.da.daagent
  com.samsung.android.dqagent
  com.samsung.android.dsms
  com.sec.android.sdhms
  com.sec.android.diagmonagent
  com.samsung.crane
  com.samsung.cmh
  com.samsung.android.gru
  com.hiya.star                            # Hiya caller ID
  com.samsung.android.smartcallprovider
  # com.samsung.android.sm.devicesecurity / com.samsung.android.rampart are KEPT (App protection / Device security)
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
#   com.samsung.android.rubin.app / com.samsung.android.app.routines  (Modes and Routines)
#   com.samsung.android.lool     Device Care
#   com.sec.android.daemonapp    Weather
#   com.google.android.apps.turbo  Adaptive Battery
#   com.sec.android.app.samsungapps  Galaxy Store (Samsung app updates)
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
  echo ">> Uninstalling store apps (pm uninstall --user 0)"
  for p in "${UNINSTALL_PACKAGES[@]}"; do
    printf '   %-52s ' "$p"
    if pkg_installed "$p"; then
      "${ADB[@]}" shell pm uninstall --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
    else
      echo "not present"
    fi
  done

  echo
  echo ">> Disabling preinstalled apps (pm disable-user --user 0)"
  for p in "${PRELOAD_DISABLE[@]}" "${PACKAGES[@]}"; do
    printf '   %-52s ' "$p"
    if pkg_installed "$p"; then
      "${ADB[@]}" shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
    else
      echo "not present"
    fi
  done

  echo
  echo ">> Replacing stock browser/SMS (only if replacement present & enabled)"
  if pkg_enabled "$BROWSER_REPLACEMENT"; then
    printf '   %-52s ' "$BROWSER_REPLACEMENT"
    "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.BROWSER "$BROWSER_REPLACEMENT" >/dev/null 2>&1 && echo "set default browser" || echo "role set failed"
    "${ADB[@]}" shell pm uninstall --user 0 com.sec.android.app.sbrowser >/dev/null 2>&1 || true
  else
    echo "   skip browser swap (no replacement)"
  fi
  if pkg_enabled "$SMS_REPLACEMENT"; then
    printf '   %-52s ' "$SMS_REPLACEMENT"
    "${ADB[@]}" shell cmd role add-role-holder --user 0 android.app.role.SMS "$SMS_REPLACEMENT" >/dev/null 2>&1 && echo "set default SMS" || echo "role set failed"
    "${ADB[@]}" shell settings put secure sms_default_application "$SMS_REPLACEMENT" >/dev/null 2>&1 || true
    "${ADB[@]}" shell pm uninstall --user 0 com.samsung.android.messaging >/dev/null 2>&1 || true
  else
    echo "   skip SMS swap (no replacement)"
  fi

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
  echo ">> Reinstalling uninstalled + re-enabling disabled packages"
  for p in "${UNINSTALL_PACKAGES[@]}" "${REPLACED_PACKAGES[@]}" "${PRELOAD_DISABLE[@]}"; do
    printf '   %-52s ' "$p"
    "${ADB[@]}" shell cmd package install-existing --user 0 "$p" 2>&1 | tr -d '\r' | tail -n1
    "${ADB[@]}" shell pm enable --user 0 "$p" >/dev/null 2>&1 || true
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
  echo ">> Preload disable states (enabled=1 => firmware re-enabled it):"
  for p in "${PRELOAD_DISABLE[@]}"; do
    printf '   %-55s ' "$p"
    if pkg_installed "$p"; then "${ADB[@]}" shell dumpsys package "$p" 2>/dev/null | grep -m1 -oE "enabled=[0-9]+" | tr -d '\r'; else echo "not present"; fi
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
