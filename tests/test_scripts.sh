#!/usr/bin/env bash
# Konfigurasjon og kommandobygging uten Conda, modeller eller robotmaskinvare.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for script in scripts/*.sh; do bash -n "$script"; done
source scripts/common.sh
load_station
[[ "$STATION" = s1 && "$FOLLOWER_PORT" = /dev/ttyACM0 ]]
STATION=s2 FOLLOWER_PORT='custom port' CAM_FRONT=5 load_station
export STATION=s2 FOLLOWER_PORT='custom port' CAM_FRONT=5
load_station
[[ "$STATION" = s2 && "$FOLLOWER_PORT" = 'custom port' && "$CAM_FRONT" = 5 ]]
[[ "$(bash -c 'printf %s "$CAM_FRONT"')" = 5 ]]
if (STATION=invalid; load_station) >/dev/null 2>&1; then exit 1; fi
if (STATION_ENV=missing.env; load_station) >/dev/null 2>&1; then exit 1; fi
if (FOLLOWER_PORT=same; LEADER_PORT=same; require_ports follower leader) >/dev/null 2>&1; then exit 1; fi
if (unset CONDA_PREFIX CONDA_DEFAULT_ENV; require_environment) >/dev/null 2>&1; then exit 1; fi

fixture="$(mktemp -d)"
mkdir -p "$fixture/scripts" "$fixture/configs" "$fixture/env/bin" \
  "$fixture/calibration/robots/so101_follower" \
  "$fixture/calibration/teleoperators/so101_leader" "$fixture/model" "$fixture/data/meta"
cp scripts/*.sh "$fixture/scripts/"
cp configs/station.env "$fixture/configs/"
touch "$fixture/calibration/robots/so101_follower/follower_s2.json" \
  "$fixture/calibration/teleoperators/so101_leader/leader_s2.json" "$fixture/data/meta/info.json"
for tool in python lerobot-teleoperate lerobot-record lerobot-rollout lerobot-train lerobot-calibrate lerobot-setup-motors; do
  cat > "$fixture/env/bin/$tool" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE"
SH
  chmod +x "$fixture/env/bin/$tool"
done
export CONDA_PREFIX="$fixture/env" CONDA_DEFAULT_ENV=lerobot PATH="$fixture/env/bin:$PATH"
export CAPTURE="$fixture/args" MODEL_PATH="$fixture/model" TASK='Test task'
export DATASET=test DATASET_REPO_ID=local/test_s2 DATA_DIR="$fixture/data" OUTPUT_DIR="$fixture/output" POLICY_TYPE=act
cd "$fixture"
for script in teleop record run_policy setup_motors_follower setup_motors_leader calibration train; do
  bash "scripts/$script.sh" > "$fixture/$script.log"
  if [[ "$script" != train ]]; then
    if [[ "$script" != setup_motors_leader && "$script" != calibration ]]; then
      [[ "$(cat "$CAPTURE")" = *'port=custom port'* ]]
    else
      [[ "$(cat "$CAPTURE")" = *'port=/dev/ttyACM1'* ]]
    fi
  fi
done
echo "PASS: syntax, station defaults/overrides/export, invalid config/environment/ports, seven mocked CLI flows."
echo "Test fixtures: $fixture"
