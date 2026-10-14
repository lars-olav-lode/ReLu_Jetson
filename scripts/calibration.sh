#!/usr/bin/env bash
# Kalibrering av ReLu SO-101: s1 = ikke ved vinduene, s2 = ved vinduene.
#
# Begge armer:
#   STATION=s1 FOLLOWER_PORT=/dev/ttyACM0 LEADER_PORT=/dev/ttyACM1 bash scripts/calibration.sh
# Bare follower (for policykjøring):
#   STATION=s1 FOLLOWER_PORT=/dev/ttyACM0 TARGET=follower bash scripts/calibration.sh
# Bare leader:
#   STATION=s1 LEADER_PORT=/dev/ttyACM1 TARGET=leader bash scripts/calibration.sh
# Portene kan også være COM3/COM4 på Windows.
# configs/station.env lastes automatisk; kommandolinjevariabler overstyrer filen.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_environment lerobot-calibrate
load_station
cd "$(dirname "$0")/.."

TARGET="${TARGET:-both}"
case "$TARGET" in
  both|follower|leader) ;;
  *) echo "TARGET må være both, follower eller leader."; exit 1 ;;
esac

missing=()
[ -z "${STATION:-}" ] && missing+=("STATION (s1 eller s2)")
if [ "$TARGET" != "leader" ] && [ -z "${FOLLOWER_PORT:-}" ]; then
  missing+=("FOLLOWER_PORT")
fi
if [ "$TARGET" != "follower" ] && [ -z "${LEADER_PORT:-}" ]; then
  missing+=("LEADER_PORT")
fi
if [ ${#missing[@]} -gt 0 ]; then
  echo "Mangler variabler:"
  for m in "${missing[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

if [ "$STATION" != "s1" ] && [ "$STATION" != "s2" ]; then
  echo "STATION må være s1 (ikke ved vinduene) eller s2 (ved vinduene)."
  exit 1
fi

if [ "$TARGET" = "both" ] && [ "$FOLLOWER_PORT" = "$LEADER_PORT" ]; then
  echo "FOLLOWER_PORT og LEADER_PORT må være forskjellige."
  exit 1
fi

if ! command -v lerobot-calibrate >/dev/null 2>&1; then
  echo "Finner ikke lerobot-calibrate. Aktiver riktig miljø og kontroller LeRobot-installasjonen."
  exit 1
fi

echo "Stasjon: $STATION"
echo "Følg instruksjonene fra LeRobot i terminalen for hver arm."

if [ "$TARGET" != "leader" ]; then
  CALIB_DIR="calibration/robots/so101_follower"
  mkdir -p "$CALIB_DIR"
  echo "Kalibrerer follower: $FOLLOWER_PORT (follower_${STATION})"
  lerobot-calibrate \
    --robot.type=so101_follower \
    --robot.port="$FOLLOWER_PORT" \
    --robot.id="follower_${STATION}" \
    --robot.calibration_dir="$CALIB_DIR"
  if [ ! -f "$CALIB_DIR/follower_${STATION}.json" ]; then
    echo "Kalibreringsfilen ble ikke opprettet: $CALIB_DIR/follower_${STATION}.json"
    exit 1
  fi
fi

if [ "$TARGET" != "follower" ]; then
  CALIB_DIR="calibration/teleoperators/so101_leader"
  mkdir -p "$CALIB_DIR"
  echo "Kalibrerer leader: $LEADER_PORT (leader_${STATION})"
  lerobot-calibrate \
    --teleop.type=so101_leader \
    --teleop.port="$LEADER_PORT" \
    --teleop.id="leader_${STATION}" \
    --teleop.calibration_dir="$CALIB_DIR"
  if [ ! -f "$CALIB_DIR/leader_${STATION}.json" ]; then
    echo "Kalibreringsfilen ble ikke opprettet: $CALIB_DIR/leader_${STATION}.json"
    exit 1
  fi
fi

echo "Kalibrering fullført for $STATION ($TARGET)."
