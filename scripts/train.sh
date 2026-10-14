#!/usr/bin/env bash

# DATASET_REPO_ID="local/pick_place_s1" \
# DATA_DIR="/data/robot-data/pick_place_s1" \
# OUTPUT_DIR="/data/training/pick_place_s1_run01" \
# POLICY_BASE="lerobot/smolvla_base" \
# TRAIN_STEPS=20000 \
# BATCH_SIZE=8 \
# RENAME_MAP='{"observation.images.front":"observation.images.camera1","observation.images.wrist":"observation.images.camera2"}' \
# bash scripts/train.sh

# rename_map kobler kameranavnene i datasettet til navnene modellen forventer. For eksempel kan front kobles til camera1 og wrist til camera2. Dette endrer ikke bildene eller filene, bare navnene som brukes når dataene sendes til modellen. Samme kobling må brukes under trening og modellkjøring.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_environment lerobot-train

cd "$(dirname "$0")/.."

# Påkrevde innstillinger
: "${DATASET_REPO_ID:?Sett DATASET_REPO_ID, f.eks. local/pick_place_s1}"
: "${DATA_DIR:?Sett DATA_DIR til datasettmappen på serveren}"
: "${OUTPUT_DIR:?Sett OUTPUT_DIR til en ny treningsmappe}"

POLICY_BASE="${POLICY_BASE:-}"
POLICY_TYPE="${POLICY_TYPE:-}"
RENAME_MAP="${RENAME_MAP:-}"

if ! command -v lerobot-train >/dev/null 2>&1; then
  echo "Finner ikke lerobot-train. Aktiver riktig miljø."
  exit 1
fi

if [ ! -f "$DATA_DIR/meta/info.json" ]; then
  echo "Finner ikke et LeRobot-datasett i: $DATA_DIR"
  exit 1
fi

if [ -e "$OUTPUT_DIR" ]; then
  echo "OUTPUT_DIR finnes allerede. Velg en ny treningsmappe."
  exit 1
fi

# Velg eksisterende modell eller modelltype.
if [ -n "$POLICY_BASE" ]; then
  POLICY_FLAGS=(--policy.path="$POLICY_BASE")
elif [ -n "$POLICY_TYPE" ]; then
  POLICY_FLAGS=(--policy.type="$POLICY_TYPE")
else
  echo "Sett POLICY_BASE for finjustering eller POLICY_TYPE for ny modell."
  exit 1
fi

# Valgfri tilpasning av kameranavn.
RENAME_FLAGS=()
if [ -n "$RENAME_MAP" ]; then
  RENAME_FLAGS=(--rename_map="$RENAME_MAP")
fi

mkdir -p "$(dirname "$OUTPUT_DIR")"

echo "Modell: ${POLICY_BASE:-$POLICY_TYPE}"
echo "Datasett: $DATASET_REPO_ID"
echo "Datamappe: $DATA_DIR"
echo "Resultater: $OUTPUT_DIR"

lerobot-train \
  --dataset.repo_id="$DATASET_REPO_ID" \
  --dataset.root="$DATA_DIR" \
  "${POLICY_FLAGS[@]}" \
  "${RENAME_FLAGS[@]}" \
  --policy.device="${DEVICE:-cuda}" \
  --policy.push_to_hub=false \
  --output_dir="$OUTPUT_DIR" \
  --job_name="${JOB_NAME:-$(basename "$OUTPUT_DIR")}" \
  --steps="${TRAIN_STEPS:-20000}" \
  --batch_size="${BATCH_SIZE:-8}" \
  --num_workers="${NUM_WORKERS:-4}" \
  --save_checkpoint=true \
  --save_freq="${SAVE_FREQ:-1000}" \
  --log_freq="${LOG_FREQ:-100}" \
  --eval_freq=0 \
  --seed="${SEED:-42}" \
  --wandb.enable="${WANDB_ENABLE:-false}" \
  2>&1 | tee "${OUTPUT_DIR}.log"

echo "Trening fullført: $OUTPUT_DIR"