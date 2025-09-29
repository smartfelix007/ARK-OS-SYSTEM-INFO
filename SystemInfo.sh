#!/bin/bash
# ArkOS Column Dashboard (Adaptive, Animated, Auto-Quit, ASCII Title)

trap 'echo; echo "Exiting..."; read -n 1 -s -r -p "Press any key to exit..."; exit' SIGINT

# Colors
CYAN='\033[1;36m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; PURPLE='\033[1;35m'
RED='\033[1;31m'; RESET='\033[0m'; BOLD='\033[1m'

# Animated bar
draw_bar() {
  local value=$1; local width=$2; local phase=$3
  local filled=$((value * width / 100)); local empty=$((width - filled)); local bar=""
  for ((i=0;i<filled;i++)); do
    if (( (i + phase) % 2 == 0 )); then bar+="▓"; else bar+="▒"; fi
  done
  for ((i=0;i<empty;i++)); do bar+="░"; done
  local color=$GREEN; [ "$value" -ge 80 ] && color=$RED; [ "$value" -ge 50 ] && [ "$value" -lt 80 ] && color=$YELLOW
  echo -e "${color}${bar}${RESET}"
}

# Paths
BATTERY_PATH="/sys/class/power_supply/BAT0"; [ ! -d "$BATTERY_PATH" ] && BATTERY_PATH="/sys/class/power_supply/battery"
CPU_TEMP_FILE=$(grep -l "cpu" /sys/class/thermal/thermal_zone*/type 2>/dev/null | head -n1)

START_TIME=$(date +%s)
EXIT_TIMEOUT=31
REFRESH_TIME=10
ANIM_PHASE=0

ASCII_TITLE=(
"   _________               __                   .___        _____       "
" /   _____/__.__. _______/  |_  ____   _____   |   | _____/ ____\____  "
" \_____  <   |  |/  ___/\   __\/ __ \ /     \  |   |/    \   __\/  _ \ "
" /        \___  |\___ \  |  | \  ___/|  Y Y  \ |   |   |  \  | (  <_> )"
"/_______  / ____/____  > |__|  \___  >__|_|  / |___|___|  /__|  \____/ "
"        \/\/         \/            \/      \/           \/              "
)

while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TIME))
  [ $ELAPSED -ge $EXIT_TIMEOUT ] && break

  clear
  TERM_WIDTH=$(tput cols)
  COL_COUNT=3
  PADDING=2
  COL_WIDTH=$(( (TERM_WIDTH - (COL_COUNT+1)*PADDING) / COL_COUNT ))
  [ $COL_WIDTH -lt 15 ] && COL_WIDTH=15  # Minimum column width

  # HEADER ASCII TITLE
  HEADER_LINE=$(printf "╔%0.s═" $(seq 1 $TERM_WIDTH))
  echo -e "${CYAN}$HEADER_LINE${RESET}"
  for line in "${ASCII_TITLE[@]}"; do
    printf "${CYAN}║${RESET}%-*s%*s${CYAN}║\n" "$TERM_WIDTH" "$line" ""
  done
  SUBTITLE="By smartfelix007@gmail.com"
  printf "${CYAN}║${RESET}%-*s%*s${CYAN}║\n" "$TERM_WIDTH" "$SUBTITLE" ""
  HEADER_SPLIT=$(printf "╟%0.s─" $(seq 1 $TERM_WIDTH))
  echo -e "${CYAN}$HEADER_SPLIT${RESET}"

  # CPU
  CPU_LOAD=$(awk '{u=$2+$4; t=$2+$4+$5; if(t>0) print int(u/t*100); else print 0}' /proc/stat | head -n1)
  [ -z "$CPU_LOAD" ] && CPU_LOAD=0
  CPU_TEMP=$([ -f "$CPU_TEMP_FILE" ] && echo $(( $(<"$CPU_TEMP_FILE")/1000 )) || echo "N/A")

  # Battery
  if [ -d "$BATTERY_PATH" ]; then
    BATTERY_STATUS=$( [ -f "$BATTERY_PATH/status" ] && cat "$BATTERY_PATH/status" || echo "N/A" )
    BATTERY_CAPACITY=$( [ -f "$BATTERY_PATH/capacity" ] && cat "$BATTERY_PATH/capacity" || echo 0 )
  else
    BATTERY_STATUS="N/A"; BATTERY_CAPACITY=0
  fi
  CAPACITY_NUM=$BATTERY_CAPACITY; ! [[ "$CAPACITY_NUM" =~ ^[0-9]+$ ]] && CAPACITY_NUM=0
  [ "$BATTERY_STATUS" = "Charging" ] && BAT_ICON="⚡" || [ "$CAPACITY_NUM" -ge 80 ] && BAT_ICON="🟩" || [ "$CAPACITY_NUM" -ge 30 ] && BAT_ICON="🟨" || BAT_ICON="🟥"

  # RAM
  read -r total used free <<< $(free -m | awk '/^Mem:/ {print $2,$3,$4}')
  usage=$((used*100/total))

  # Wi-Fi
  WIFI_INTERFACE=$(iw dev | awk '/Interface/{print $2}' | head -n1)
  if [ -n "$WIFI_INTERFACE" ]; then
    WIFI_STATUS=$(iw dev "$WIFI_INTERFACE" link 2>/dev/null)
    if echo "$WIFI_STATUS" | grep -q 'Connected'; then
      WIFI_SSID=$(echo "$WIFI_STATUS" | grep 'SSID' | cut -d' ' -f2-)
      WIFI_SIGNAL=$(echo "$WIFI_STATUS" | grep 'signal' | awk '{print $2}' | tr -d '-')
      SIGNAL_PCT=$(( (100 - WIFI_SIGNAL) * 2 )); [ $SIGNAL_PCT -gt 100 ] && SIGNAL_PCT=100
      WIFI_ICON=$([ "$SIGNAL_PCT" -ge 80 ] && echo "📶" || [ "$SIGNAL_PCT" -ge 40 ] && echo "📡" || echo "❌")
    else
      WIFI_SSID="Not Connected"; SIGNAL_PCT=0; WIFI_ICON="❌"
    fi
  else
    WIFI_SSID="No Adapter"; SIGNAL_PCT=0; WIFI_ICON="🌐"
  fi

  # Storage
  STORAGE_LINES=()
  while read fs size used avail perc mount; do
    perc_val=${perc%\%}
    STORAGE_LINES+=("💾 $mount: $used/$size ($perc) $(draw_bar $perc_val $COL_WIDTH $ANIM_PHASE)")
  done < <(df -h | grep -vE '^Filesystem|tmpfs|overlay|cdrom')

  # Columns
  COL1="💻 CPU: $CPU_LOAD% $(draw_bar $CPU_LOAD $COL_WIDTH $ANIM_PHASE)\n🌡️ Temp: $CPU_TEMP°C $(draw_bar $CPU_TEMP $COL_WIDTH $ANIM_PHASE)"
  COL2="$BAT_ICON Battery: $CAPACITY_NUM% $(draw_bar $CAPACITY_NUM $COL_WIDTH $ANIM_PHASE) ($BATTERY_STATUS)\n🧠 RAM: $used/$total MB ($usage%) $(draw_bar $usage $COL_WIDTH $ANIM_PHASE)"
  COL3="$WIFI_ICON Wi-Fi: $WIFI_SSID ($SIGNAL_PCT%) $(draw_bar $SIGNAL_PCT $COL_WIDTH $ANIM_PHASE)"
  for line in "${STORAGE_LINES[@]}"; do COL3+="\n$line"; done

  mapfile -t L1 <<< "$(echo -e "$COL1")"
  mapfile -t L2 <<< "$(echo -e "$COL2")"
  mapfile -t L3 <<< "$(echo -e "$COL3")"
  MAX_LINES=${#L1[@]}; [ ${#L2[@]} -gt $MAX_LINES ] && MAX_LINES=${#L2[@]}; [ ${#L3[@]} -gt $MAX_LINES ] && MAX_LINES=${#L3[@]}

  for ((i=0;i<MAX_LINES;i++)); do
    C1=${L1[i]:-}; C2=${L2[i]:-}; C3=${L3[i]:-}
    # Truncate to column width if too long
    C1=${C1:0:$COL_WIDTH}; C2=${C2:0:$COL_WIDTH}; C3=${C3:0:$COL_WIDTH}
    printf "${CYAN}║${RESET} %-*s %-*s %-*s ${CYAN}║\n" $COL_WIDTH "$C1" $COL_WIDTH "$C2" $COL_WIDTH "$C3"
  done

  FOOTER_LINE=$(printf "╚%0.s═" $(seq 1 $TERM_WIDTH))
  echo -e "${CYAN}$FOOTER_LINE${RESET}"
  echo "Updating in $REFRESH_TIME s... Auto-exit in $((EXIT_TIMEOUT - ELAPSED)) s."

  ANIM_PHASE=$(( (ANIM_PHASE + 1) % 2 ))
  sleep $REFRESH_TIME
done

clear
echo "Dashboard exited after $EXIT_TIMEOUT seconds."
