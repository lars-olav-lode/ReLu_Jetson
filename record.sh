# STATION=s1 \
# DATASET=pick_place \
# TASK="Legg klossen i boksen" \
# DATA_DIR="C:/Users/larso/robot-data/pick_place_s1" \
# bash scripts/record.sh


#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

missing=()
[ -z "${STATION:-}" ] && missing+=("STATION (s1 eller s2)")
[ -z "${DATASET:-}" ] && missing+=("DATASET")
[ -z "${TASK:-}" ] && missing+=("TASK")
[ -z "${DATA_DIR:-}" ] && missing+=("DATA_DIR (mappe for datasettet)")

if [ ${#missing[@]} -gt 0 ]; then
  echo "Mangler variabler:"
  for m in "${missing[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

if [ "$STATION" != "s1" ] && [ "$STATION" != "s2" ]; then
  echo "STATION må være s1 (IKKE ved vinduene) eller s2 (ved vinduene)."
  exit 1
fi

REPO_ID="local/${DATASET}_${STATION}"

echo "Stasjon: $STATION"
echo "Datasett: $REPO_ID"
echo "Lagringsmappe: $DATA_DIR"
echo "Oppgave: $TASK"
echo "Opplasting til HF: av"

lerobot-record \
  --robot.type=so101_follower \
  --robot.port="${FOLLOWER_PORT:-COM3}" \
  --robot.id="follower_${STATION}" \
  --robot.calibration_dir=calibration/robots/so101_follower \
  --robot.cameras="{ front: {type: opencv, index_or_path: ${CAM_FRONT:-0}, width: 640, height: 480, fps: 30}, wrist: {type: opencv, index_or_path: ${CAM_WRIST:-2}, width: 640, height: 480, fps: 30}}" \
  --teleop.type=so101_leader \
  --teleop.port="${LEADER_PORT:-COM4}" \
  --teleop.id="leader_${STATION}" \
  --teleop.calibration_dir=calibration/teleoperators/so101_leader \
  --display_data=true \
  --dataset.repo_id="$REPO_ID" \
  --dataset.root="$DATA_DIR" \
  --dataset.single_task="$TASK" \
  --dataset.num_episodes="${EPISODES:-10}" \
  --dataset.episode_time_s="${EPISODE_S:-30}" \
  --dataset.reset_time_s="${RESET_S:-10}" \
  --dataset.fps="${FPS:-30}" \
  --dataset.push_to_hub=false \
  --resume="${RESUME:-false}"