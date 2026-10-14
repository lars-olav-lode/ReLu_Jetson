#!/usr/bin/env bash
# Teleoperasjon på en ReLu SO-101-stasjon.
#
# Bruk:
#   STATION=s1 FOLLOWER_PORT=COM5 LEADER_PORT=COM6 CAM_FRONT=0 CAM_WRIST=1 bash scripts/teleop.sh
#
# STATION: s1 = IKKE ved vinduene, s2 = ved vinduene

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_environment lerobot-teleoperate
load_station
cd "$(dirname "$0")/.."

if [ "$STATION" != "s1" ] && [ "$STATION" != "s2" ]; then
  echo "Du må velge stasjon:"
  echo "  STATION=s1  → IKKE ved vinduene"
  echo "  STATION=s2  → ved vinduene"
  exit 1
fi

echo "Stasjon: $STATION"

require_ports follower leader
require_calibration follower leader

lerobot-teleoperate \
  --robot.type=so101_follower --robot.port="$FOLLOWER_PORT" --robot.id="follower_${STATION}" \
  --robot.calibration_dir=calibration/robots/so101_follower \
  --robot.cameras="$(station_cameras)" \
  --teleop.type=so101_leader --teleop.port="$LEADER_PORT" --teleop.id="leader_${STATION}" \
  --teleop.calibration_dir=calibration/teleoperators/so101_leader \
  --display_data="${DISPLAY_DATA:-true}"
