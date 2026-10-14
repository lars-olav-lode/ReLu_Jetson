#!/usr/bin/env bash
# Asynkron policykjøring: Jetson styrer armen, policy-serveren kjører modellen.
# Se docs/async.md for miljø, server og SSH-tunnel. Dette er ikke datasettevaluering.
# TASK="Put the cube in the container" DRY_RUN=true bash scripts/eval_async.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$REPO_ROOT"
load_station
require_ports follower

TASK="${TASK_OVERRIDE:-${TASK:-}}"
: "${TASK:?Sett TASK til oppgaven modellen skal utføre.}"
SERVER_ADDRESS="${SERVER_ADDRESS:-127.0.0.1:18080}"
ASYNC_POLICY="${ASYNC_POLICY:-Harrysunshine/so101-smolvla-9task}"
POLICY_TYPE_ASYNC="${POLICY_TYPE_ASYNC:-smolvla}"
# Angi navn fra modellens config; SmolVLA-modeller har ikke universelle kameranavn.
CAMERA_FRONT_KEY="${CAMERA_FRONT_KEY:-camera1}"
CAMERA_WRIST_KEY="${CAMERA_WRIST_KEY:-camera2}"
ACTIONS_PER_CHUNK="${ACTIONS_PER_CHUNK:-50}"
CHUNK_THRESHOLD="${CHUNK_THRESHOLD:-0.5}"
AGG_FN="${AGG_FN:-weighted_average}"
DRY_RUN="${DRY_RUN:-false}"
for name in FPS ACTIONS_PER_CHUNK; do
  [[ "${!name}" =~ ^[1-9][0-9]*$ ]] || { echo "$name må være et positivt heltall." >&2; exit 1; }
done
[[ "$CHUNK_THRESHOLD" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] || {
  echo 'CHUNK_THRESHOLD må være mellom 0 og 1.' >&2; exit 1;
}
[[ "$DRY_RUN" = true || "$DRY_RUN" = false ]] || { echo 'DRY_RUN må være true eller false.' >&2; exit 1; }
case "$AGG_FN" in weighted_average|latest_only|average|conservative) ;; *) echo 'Ukjent AGG_FN.' >&2; exit 1 ;; esac
for name in CAMERA_FRONT_KEY CAMERA_WRIST_KEY; do
  [[ "${!name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { echo "Ugyldig $name." >&2; exit 1; }
done
[[ "$CAMERA_FRONT_KEY" != "$CAMERA_WRIST_KEY" ]] || { echo 'Kameranavnene må være forskjellige.' >&2; exit 1; }

# Behold kameraindekser, oppløsning og kamera-FPS fra prosjektets fellesoppsett.
cameras="$(station_cameras)"
cameras="${cameras/front:/$CAMERA_FRONT_KEY:}"
cameras="${cameras/wrist:/$CAMERA_WRIST_KEY:}"
args=(
  --robot.type=so101_follower
  --robot.port="$FOLLOWER_PORT"
  --robot.id="follower_${STATION}"
  --robot.calibration_dir="$REPO_ROOT/calibration/robots/so101_follower"
  --robot.cameras="$cameras"
  --task="$TASK"
  --server_address="$SERVER_ADDRESS"
  --policy_type="$POLICY_TYPE_ASYNC"
  --pretrained_name_or_path="$ASYNC_POLICY"
  --policy_device=cuda
  --client_device=cpu
  --actions_per_chunk="$ACTIONS_PER_CHUNK"
  --chunk_size_threshold="$CHUNK_THRESHOLD"
  --fps="$FPS"
  --aggregate_fn_name="$AGG_FN"
)
# Bruk samme aktive Conda-miljø som resten av prosjektet.
if [[ "$DRY_RUN" = false ]]; then
  require_environment
  require_calibration follower
fi
if [[ "$DRY_RUN" = true ]]; then
  printf '%q ' python -m lerobot.async_inference.robot_client "${args[@]}"
  printf '\n'
  exit 0
fi
# --help importerer CLI-en, men starter ikke RobotClient eller robotkommunikasjon.
if ! python -m lerobot.async_inference.robot_client --help >/dev/null; then
  echo 'Async-klienten kan ikke lastes. Kontroller LeRobot-versjon og async-avhengigheter på begge maskinene. Se docs/async.md.' >&2
  exit 1
fi
echo "Policy på GPU-server: $ASYNC_POLICY ($SERVER_ADDRESS)"
echo "Jetson-klient: CPU; follower_${STATION}; $FOLLOWER_PORT"
echo 'Starter robotkjøring. Avslutt med Ctrl+C. DURATION_S gjelder ikke denne klienten.'
exec python -m lerobot.async_inference.robot_client "${args[@]}"
