#!/usr/bin/env bash
# Aktiver først: conda activate lerobot
# Stasjonsoppsettet lastes automatisk fra configs/station.env.
# MODEL_PATH=/home/relu/models/pick_place/pretrained_model \
# TASK="Legg klossen i boksen" EVAL_EPISODES=10 bash scripts/eval_policy.sh
# EVAL_DIR angir lagringsmappe (standard: evaluations).
# Hvert forsøk får et separat LeRobot-datasett med videoer og robotdata.
# Tilbakestill robot og oppgave manuelt før hvert forsøk.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_environment lerobot-rollout
load_station
require_ports follower
cd "$(dirname "${BASH_SOURCE[0]}")/.."

: "${STATION:?Sett STATION til s1 eller s2}"
: "${FOLLOWER_PORT:?Sett FOLLOWER_PORT}"
: "${MODEL_PATH:?Sett MODEL_PATH til lokal modellmappe}"
: "${TASK:?Sett TASK}"
[[ "$STATION" = s1 || "$STATION" = s2 ]] || { echo "STATION må være s1 eller s2."; exit 1; }
[[ -d "$MODEL_PATH" ]] || { echo "Modellmappen finnes ikke: $MODEL_PATH"; exit 1; }
CALIB_DIR=calibration/robots/so101_follower
[[ -f "$CALIB_DIR/follower_${STATION}.json" ]] || {
  echo "Mangler kalibrering. Kjør scripts/calibration.sh med samme STATION og TARGET=follower."
  exit 1
}
for tool in lerobot-rollout python; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Finner ikke $tool. Aktiver lerobot-miljøet."; exit 1; }
done
[[ -t 0 ]] || { echo "Evalueringen må kjøres i en interaktiv terminal."; exit 1; }
EVAL_EPISODES="${EVAL_EPISODES:-10}"
DURATION_S="${DURATION_S:-30}"
FPS="${FPS:-30}"
for name in EVAL_EPISODES DURATION_S FPS; do
  value="${!name}"
  [[ "$value" =~ ^[1-9][0-9]*$ && ${#value} -le 6 ]] || {
    echo "$name må være et positivt heltall med maksimalt seks sifre."; exit 1;
  }
done
RENAME_FLAGS=()
[[ -z "${RENAME_MAP:-}" ]] || RENAME_FLAGS=(--rename_map="$RENAME_MAP")

mkdir -p "${EVAL_DIR:-evaluations}"
RUN_DIR="$(mktemp -d "${EVAL_DIR:-evaluations}/eval_${STATION}_$(date +%Y%m%d_%H%M%S)_XXXXXX")"
RUN_ID="$(basename "$RUN_DIR")"
export STATION FOLLOWER_PORT MODEL_PATH TASK EVAL_EPISODES DURATION_S FPS
python - "$RUN_DIR" <<'PY'
import json, os, sys
from pathlib import Path
keys = ('STATION', 'FOLLOWER_PORT', 'MODEL_PATH', 'TASK', 'EVAL_EPISODES',
        'DURATION_S', 'FPS', 'DEVICE', 'CAM_FRONT', 'CAM_WRIST', 'RENAME_MAP')
config = {key: os.environ.get(key) for key in keys}
config.update(DEVICE=os.environ.get('DEVICE', 'cuda'),
              CAM_FRONT=os.environ.get('CAM_FRONT', '0'),
              CAM_WRIST=os.environ.get('CAM_WRIST', '2'))
Path(sys.argv[1], 'config.json').write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding='utf-8')
PY
printf 'episode,status,dataset\n' > "$RUN_DIR/results.csv"
summarize() {
  python - "$RUN_DIR" <<'PY'
import csv, json, sys
from pathlib import Path
root = Path(sys.argv[1])
rows = list(csv.DictReader((root / 'results.csv').open(encoding='utf-8')))
success = sum(row['status'] == 'success' for row in rows)
failure = sum(row['status'] == 'failure' for row in rows)
rated = success + failure
summary = dict(success=success, failure=failure, rated=rated,
               unrated=sum(row['status'] == 'unrated' for row in rows),
               errors=sum(row['status'] == 'error' for row in rows),
               success_rate_percent=100 * success / rated if rated else None)
(root / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(f'Suksessrate: {success} av {rated} = {100 * success / rated:.1f} %'
      if rated else 'Ingen vurderte forsøk ennå.')
print(f"Uten vurdering: {summary['unrated']}. Kjørefeil: {summary['errors']}.")
print(f'Resultater: {root}')
PY
}
trap summarize EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo "Evaluering: $RUN_DIR"
for ((episode=1; episode<=EVAL_EPISODES; episode++)); do
  printf -v label 'episode_%03d' "$episode"
  dataset="$RUN_DIR/$label"
  read -r -p "Tilbakestill robot og oppgave. Enter starter forsøk $episode/$EVAL_EPISODES (q avslutter): " answer || break
  [[ "$answer" != q ]] || break
  # Registrer forsøket før kjøring, også ved avbrudd eller manglende vurdering.
  printf '%s,unrated,%s\n' "$episode" "$label" >> "$RUN_DIR/results.csv"
  status=error
  if lerobot-rollout \
    --strategy.type=episodic \
    --robot.type=so101_follower \
    --robot.port="$FOLLOWER_PORT" \
    --robot.id="follower_${STATION}" \
    --robot.calibration_dir="$CALIB_DIR" \
    --robot.cameras="$(station_cameras)" \
    --policy.path="$MODEL_PATH" \
    --device="${DEVICE:-cuda}" \
    "${RENAME_FLAGS[@]}" \
    --task="$TASK" \
    --fps="$FPS" \
    --display_data="${DISPLAY_DATA:-false}" \
    --dataset.repo_id="local/rollout_${RUN_ID}_${label}" \
    --dataset.root="$dataset" \
    --dataset.single_task="$TASK" \
    --dataset.num_episodes=1 \
    --dataset.episode_time_s="$DURATION_S" \
    --dataset.reset_time_s=0 \
    --dataset.fps="$FPS" \
    --dataset.video=true \
    --dataset.push_to_hub=false \
    2>&1 | tee "$RUN_DIR/${label}.log" && python - "$dataset" <<'PY'
import json, sys
from pathlib import Path
info = json.loads(Path(sys.argv[1], 'meta', 'info.json').read_text(encoding='utf-8'))
if info.get('total_episodes') != 1 or info.get('total_frames', 0) < 1:
    raise SystemExit('Forventet ett lagret forsøk med robotdata. Kontroller opptaket.')
PY
  then
    status=unrated
    while read -r -p "Resultat: v = vellykket, m = mislykket, q = avslutt uten vurdering: " answer; do
      case "$answer" in
        v|V) status=success; break ;;
        m|M) status=failure; break ;;
        q|Q) break ;;
        *) echo "Skriv v, m eller q." ;;
      esac
    done
  fi
  python - "$RUN_DIR/results.csv" "$status" <<'PY'
import csv, sys
from pathlib import Path
path = Path(sys.argv[1])
with path.open(encoding='utf-8', newline='') as file:
    rows = list(csv.DictReader(file))
rows[-1]['status'] = sys.argv[2]
temp = path.with_suffix('.tmp')
with temp.open('w', encoding='utf-8', newline='') as file:
    writer = csv.DictWriter(file, fieldnames=['episode', 'status', 'dataset'])
    writer.writeheader()
    writer.writerows(rows)
temp.replace(path)
PY
  summarize
  [[ "$status" != error ]] || { echo "Kjøringen feilet. Se loggen; evalueringen stopper."; exit 1; }
  [[ "$status" != unrated ]] || break
done
