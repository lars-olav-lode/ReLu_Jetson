#!/usr/bin/env bash
# STATION=s1 \
# FOLLOWER_PORT="/dev/ttyACM0" \
# MODEL_PATH="/home/relu/models/pick_place/pretrained_model" \
# TASK="Legg klossen i boksen" \
# DURATION_S=30 \
# bash scripts/run_policy.sh



set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_environment lerobot-rollout
load_station
require_ports follower

cd "$(dirname "$0")/.."

missing=()
[ -z "${STATION:-}" ] && missing+=("STATION (s1 eller s2)")
[ -z "${FOLLOWER_PORT:-}" ] && missing+=("FOLLOWER_PORT")
[ -z "${MODEL_PATH:-}" ] && missing+=("MODEL_PATH (lokal modellmappe)")
[ -z "${TASK:-}" ] && missing+=("TASK")

if [ ${#missing[@]} -gt 0 ]; then
  echo "Mangler variabler:"
  for m in "${missing[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

if [ "$STATION" != "s1" ] && [ "$STATION" != "s2" ]; then
  echo "STATION må være s1 eller s2."
  exit 1
fi

if ! command -v lerobot-rollout >/dev/null 2>&1; then
  echo "Finner ikke lerobot-rollout."
  echo "Kontroller aktivt miljø og LeRobot-versjon."
  exit 1
fi

if [ ! -d "$MODEL_PATH" ]; then
  echo "Modellmappen finnes ikke: $MODEL_PATH"
  exit 1
fi

CALIB_DIR="calibration/robots/so101_follower"
CALIB_FILE="$CALIB_DIR/follower_${STATION}.json"

if [ ! -f "$CALIB_FILE" ]; then
  echo "Mangler kalibrering: $CALIB_FILE"
  echo "Kjør scripts/calibration.sh med samme STATION og TARGET=follower først."
  exit 1
fi

echo "Stasjon: $STATION"
echo "Follower: $FOLLOWER_PORT"
echo "Modell: $MODEL_PATH"
echo "Oppgave: $TASK"
echo "Kjøretid: ${DURATION_S:-30} sekunder"

RENAME_FLAGS=()
[ -z "${RENAME_MAP:-}" ] || RENAME_FLAGS=(--rename_map="$RENAME_MAP")

lerobot-rollout \
  --strategy.type=base \
  --robot.type=so101_follower \
  --robot.port="$FOLLOWER_PORT" \
  --robot.id="follower_${STATION}" \
  --robot.calibration_dir="$CALIB_DIR" \
  --robot.cameras="$(station_cameras)" \
  --policy.path="$MODEL_PATH" \
  "${RENAME_FLAGS[@]}" \
  --device="${DEVICE:-cuda}" \
  --task="$TASK" \
  --fps="${FPS:-30}" \
  --duration="${DURATION_S:-30}" \
  --display_data="${DISPLAY_DATA:-false}"
