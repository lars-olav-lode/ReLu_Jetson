#!/usr/bin/env bash
# Bruk: conda activate lerobot
#      bash scripts/setup_motors_leader.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_environment lerobot-setup-motors
load_station
require_ports leader

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

: "${LEADER_PORT:?Mangler LEADER_PORT i configs/station.env}"

if ! command -v lerobot-setup-motors >/dev/null 2>&1; then
  echo "Finner ikke lerobot-setup-motors. Kjør conda activate lerobot og kontroller LeRobot-installasjonen."
  exit 1
fi

echo "==> Setter opp leader-motorer på $LEADER_PORT"
echo "    Koble til bare motoren som CLI-en ber om."
echo "    Pass på at motorens girutveksling stemmer med leddet som etterspørres."
echo

lerobot-setup-motors \
  --teleop.type=so101_leader \
  --teleop.port="$LEADER_PORT"
