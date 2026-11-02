#!/usr/bin/env bash
# Android TV / Google TV cleanup tool.
# Run this from a computer on the SAME Wi-Fi as the TV. Needs "adb" installed.
#
#   ./tv-cleanup.sh connect 192.168.1.50        # connect to the TV (use your TV's IP)
#   ./tv-cleanup.sh check                       # health report, changes nothing
#   ./tv-cleanup.sh clean                       # switch off bloatware (asks first; never uninstalls)
#   ./tv-cleanup.sh speedup                     # free cache, stop background apps, faster animations
#   ./tv-cleanup.sh restore                     # switch back on everything clean turned off
#
# Set TV=ip:port to pick a specific device when several are connected.


HERE="$(cd "$(dirname "$0")" && pwd)"
exec 3<&0   # keep the keyboard on fd 3 so prompts work inside loops
trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$1"; }
PKG_LIST="$HERE/packages.txt"
LOG="$HERE/removed-packages.log"   # apps this tool switched off (used by restore)

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

ask() {  # ask "question" -> returns 0 for yes
  local reply
  read -r -p "$1 [y/N] " reply <&3
  [[ "$reply" =~ ^[Yy] ]]
}

need_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    red "adb is not installed. See README.md, step 1."
    exit 1
  fi
}

pick_device() {
  if [[ -n "${TV:-}" ]]; then DEV="$TV"; return; fi
  local devices
  devices=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  local count
  count=$(printf '%s\n' "$devices" | grep -c . || true)
  if [[ "$count" -eq 0 ]]; then
    red "No TV connected. Run: ./tv-cleanup.sh connect <TV-IP-address>"
    adb devices | awk 'NR>1 && $2=="unauthorized" {print "  " $1 " is waiting: accept the \"Allow debugging?\" popup on the TV."}'
    exit 1
  elif [[ "$count" -gt 1 ]]; then
    red "Several devices are connected. Choose one, e.g.: TV=$(printf '%s\n' "$devices" | head -1) ./tv-cleanup.sh $CMD"
    printf '%s\n' "$devices"
    exit 1
  fi
  DEV="$devices"
}

sh_tv() { adb -s "$DEV" shell "$@" </dev/null 2>/dev/null | tr -d '\r'; }

installed_packages() { sh_tv pm list packages | sed 's/^package://' | sort; }

# ---------------------------------------------------------------- connect
cmd_connect() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    red "Usage: ./tv-cleanup.sh connect <TV-IP>[:port]"
    echo "Find the IP on the TV: Settings > Network & Internet > (your Wi-Fi) > IP address."
    exit 1
  fi
  [[ "$target" == *:* ]] || target="$target:5555"
  echo "Connecting to $target ..."
  echo "If a popup 'Allow network debugging?' appears on the TV, tick 'Always allow' and press OK."
  adb connect "$target"
  sleep 3
  if adb devices | grep -q "^$target[[:space:]]*device"; then
    green "Connected to the TV."
  else
    red "Not connected yet. Check the TV screen for a popup, then run this command again."
    echo "On newer Google TVs you may need to pair first - see README.md, 'Pairing with a code'."
  fi
}

# ---------------------------------------------------------------- check
cmd_check() {
  pick_device
  bold "== TV =="
  echo "Model:    $(sh_tv getprop ro.product.manufacturer) $(sh_tv getprop ro.product.model)"
  echo "Android:  $(sh_tv getprop ro.build.version.release)"

  bold "== Storage (under ~15% free makes a TV very slow) =="
  sh_tv df -h /data | tail -1 | awk '{print "Used " $3 " of " $2 ", free " $4 " (" $5 " full)"}'

  bold "== Memory =="
  sh_tv cat /proc/meminfo | awk '/MemTotal|MemAvailable/ {printf "%-14s %6.0f MB\n", $1, $2/1024}'

  bold "== Apps using the most memory right now =="
  sh_tv dumpsys meminfo | awk '/Total PSS by process/{f=1;next} f&&/^$/{exit} f' | head -12

  bold "== Bloatware from packages.txt found on this TV =="
  local installed found=0
  installed=$(installed_packages)
  while IFS='|' read -r pkg kind desc; do
    pkg=$(trim "$pkg"); kind=$(trim "$kind"); desc=$(trim "$desc")
    if grep -qx "$pkg" <<<"$installed"; then
      printf '  %-9s %-45s %s\n' "[$kind]" "$pkg" "$desc"; found=1
    fi
  done < <(grep -v '^\s*#' "$PKG_LIST" | grep '|')
  [[ $found -eq 1 ]] || echo "  (none)"

  bold "== Preinstalled apps with an icon (clean step 3 asks about these) =="
  visible_system_apps | sed 's/^/  /'

  bold "== Apps you installed yourself (this tool never touches these) =="
  sh_tv pm list packages -3 | sed 's/^package:/  /' | sort

  bold "== Apps already switched off =="
  sh_tv pm list packages -d | sed 's/^package:/  /' | sort
  echo
  echo "Nothing was changed. Run './tv-cleanup.sh clean' to switch off bloatware."
}

# ---------------------------------------------------------------- clean
# Never offered for switching off: the TV needs these to work.
PROTECTED_RE='launcher|launcherx|tv\.settings|^com\.android\.vending$|^com\.google\.android\.gms|katniss|setupwraith|setupwizard|tvinput|hdmi|systemui|inputmethod|remote|^com\.android\.tv$|^android$|^com\.google\.android\.tv$|livetv|unusedapps'

disable_pkg() {
  local pkg="$1" out
  out=$(sh_tv pm disable-user --user 0 "$pkg")
  if [[ "$out" == *disabled* ]]; then
    echo "$pkg" >> "$LOG"; green "    switched off $pkg"
  else
    red "    could not switch off $pkg: $out"
  fi
}

# Preinstalled (system) apps that have an icon on the TV's app list.
visible_system_apps() {
  local system launchable
  system=$(sh_tv pm list packages -s -e | sed 's/^package://' | sort)
  launchable=$(sh_tv cmd package query-activities --brief -a android.intent.action.MAIN \
                 -c android.intent.category.LEANBACK_LAUNCHER | grep -o '^ *[a-zA-Z0-9_.]*/' \
                 | tr -d ' /' | sort -u)
  comm -12 <(echo "$system") <(echo "$launchable") | grep -Ev "$PROTECTED_RE"
}

cmd_clean() {
  pick_device
  echo "Nothing will be uninstalled. Apps are only switched off, and './tv-cleanup.sh restore' turns them back on."
  local enabled safe=() opt=() opt_desc=() listed
  enabled=$(sh_tv pm list packages -e | sed 's/^package://' | sort)
  while IFS='|' read -r pkg kind desc; do
    pkg=$(trim "$pkg"); kind=$(trim "$kind"); desc=$(trim "$desc")
    grep -qx "$pkg" <<<"$enabled" || continue
    if [[ "$kind" == SAFE ]]; then safe+=("$pkg|$desc"); else opt+=("$pkg"); opt_desc+=("$desc"); fi
  done < <(grep -v '^\s*#' "$PKG_LIST" | grep '|')
  listed=$(grep -v '^\s*#' "$PKG_LIST" | grep '|' | cut -d'|' -f1 | tr -d '[:blank:]')

  bold "Step 1/3: hidden background apps nobody needs on a TV"
  if [[ ${#safe[@]} -eq 0 ]]; then
    echo "  none found"
  else
    for s in "${safe[@]}"; do echo "  - ${s#*|}  (${s%%|*})"; done
    if ask "Switch all of these off?"; then
      for s in "${safe[@]}"; do disable_pkg "${s%%|*}"; done
    fi
  fi

  bold "Step 2/3: optional Google / brand extras"
  if [[ ${#opt[@]} -eq 0 ]]; then echo "  none found"; fi
  for i in "${!opt[@]}"; do
    if ask "  Switch off ${opt_desc[$i]} (${opt[$i]})?"; then disable_pkg "${opt[$i]}"; fi
  done

  bold "Step 3/3: apps that came preinstalled on the TV (Sansui/partner apps)"
  echo "  Say 'y' only to apps you NEVER open. Apps you installed yourself are not shown."
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    grep -qx "$pkg" <<<"$listed" && continue   # already asked above
    if ask "  Switch off $pkg?"; then disable_pkg "$pkg"; fi
  done < <(visible_system_apps)

  echo
  green "Done. Restart the TV (Settings > System > Restart) to feel the full effect."
  echo "Changed your mind? './tv-cleanup.sh restore' switches everything back on."
}

# ---------------------------------------------------------------- speedup
cmd_speedup() {
  pick_device
  bold "1. Freeing app cache (temporary files only; logins and settings are kept) ..."
  sh_tv pm trim-caches 999G >/dev/null
  sh_tv df -h /data | tail -1 | awk '{print "   free space now: " $4}'

  bold "2. Stopping apps running in the background ..."
  sh_tv am kill-all >/dev/null
  green "   done"

  if ask "3. Optimise all apps so they open faster? (takes 5-20 minutes, leave the TV on)"; then
    echo "   working... (the TV may feel sluggish until this finishes)"
    sh_tv cmd package compile -m speed-profile -a >/dev/null
    green "   apps optimised"
  fi

  if ask "4. Make menu animations twice as fast (feels snappier)?"; then
    sh_tv settings put global window_animation_scale 0.5
    sh_tv settings put global transition_animation_scale 0.5
    sh_tv settings put global animator_duration_scale 0.5
    green "   animations set to 0.5x (undo: './tv-cleanup.sh speedup-undo')"
  fi
  echo "Now restart the TV. Tip: restart it once a week; it clears memory better than anything else."
}

cmd_speedup_undo() {
  pick_device
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    sh_tv settings put global "$k" 1.0
  done
  green "Animations back to normal."
}

# ---------------------------------------------------------------- restore
cmd_restore() {
  pick_device
  if [[ ! -s "$LOG" ]]; then echo "Nothing to restore ($LOG is empty)."; exit 0; fi
  sort -u "$LOG" | while read -r pkg; do
    out=$(sh_tv pm enable --user 0 "$pkg")
    # also covers apps removed by an older version of this tool
    [[ "$out" == *enabled* ]] || out=$(sh_tv cmd package install-existing --user 0 "$pkg")
    if [[ "$out" == *enabled* || "$out" == *installed* ]]; then green "  switched on $pkg"; else red "  $pkg: $out"; fi
  done
  mv "$LOG" "$LOG.restored-$(date +%Y%m%d%H%M%S)"
  green "Restore finished. Restart the TV."
}

# ---------------------------------------------------------------- main
need_adb
CMD="${1:-help}"; shift || true
case "$CMD" in
  connect)      cmd_connect "$@" ;;
  check)        cmd_check ;;
  clean)        cmd_clean ;;
  speedup)      cmd_speedup ;;
  speedup-undo) cmd_speedup_undo ;;
  restore)      cmd_restore ;;
  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
