#!/bin/bash
# Teleoperasjon på en ReLu SO-101-stasjon.
#
# Bruk:
#   STATION=s1 FOLLOWER_PORT=COM5 LEADER_PORT=COM6 CAM_FRONT=0 CAM_WRIST=1 bash scripts/teleop.sh
#
# STATION: s1 = IKKE ved vinduene, s2 = ved vinduene

set -e
cd "$(dirname "$0")/.."

if [ "$STATION" != "s1" ] && [ "$STATION" != "s2" ]; then
  echo "Du må velge stasjon:"
  echo "  STATION=s1  → IKKE ved vinduene"
  echo "  STATION=s2  → ved vinduene"
  exit 1
fi

echo "Stasjon: $STATION"

lerobot-teleoperate \
  --robot.type=so101_follower --robot.port=${FOLLOWER_PORT:-COM3} --robot.id=follower_${STATION} \
  --robot.calibration_dir=calibration/robots/so101_follower \
  --robot.cameras="{ front: {type: opencv, index_or_path: ${CAM_FRONT:-0}, width: 640, height: 480, fps: 30}, wrist: {type: opencv, index_or_path: ${CAM_WRIST:-2}, width: 640, height: 480, fps: 30}}" \
  --teleop.type=so101_leader --teleop.port=${LEADER_PORT:-COM4} --teleop.id=leader_${STATION} \
  --teleop.calibration_dir=calibration/teleoperators/so101_leader \
  --display_data=true