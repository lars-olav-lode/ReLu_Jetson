#!/usr/bin/env bash
# Førstegangsoppsett: bash scripts/initialisering.sh
# Eksplisitt oppdatering: UPDATE_ENV=true bash scripts/initialisering.sh
# Valgfri pakkeversjon/kilde: LEROBOT_SPEC='lerobot[core_scripts,training,feetech,smolvla]==VERSJON'
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$REPO_ROOT"

command -v conda >/dev/null 2>&1 || { echo "Conda mangler i terminalen. Installer/initialiser Miniconda for Bash først."; exit 1; }
[[ -f environment.yml ]] || { echo "Finner ikke environment.yml."; exit 1; }
UPDATE_ENV="${UPDATE_ENV:-false}"
[[ "$UPDATE_ENV" = true || "$UPDATE_ENV" = false ]] || { echo "UPDATE_ENV må være true eller false."; exit 1; }
hook="$(conda shell.bash hook)"
eval "$hook"

# Test miljønavnet, ikke om Python i miljøet virker.
environments="$(conda env list)"
exists=false
while read -r name rest; do
  if [[ "$name" = lerobot ]]; then exists=true; break; fi
 done <<< "$environments"
install=false
if [[ "$exists" = false ]]; then
  echo "==> Oppretter lerobot-miljø..."
  conda env create -f environment.yml
  install=true
elif [[ "$UPDATE_ENV" = true ]]; then
  echo "==> Oppdaterer lerobot-miljø..."
  conda env update -n lerobot -f environment.yml
  install=true
else
  echo "==> Bruker eksisterende lerobot-miljø uten pakkeendringer."
fi
conda activate lerobot
if [[ "$install" = true ]]; then
  echo "==> Installerer LeRobot med SO-101-, trenings- og SmolVLA-støtte..."
  python -m pip install "${LEROBOT_SPEC:-lerobot[core_scripts,training,feetech,smolvla]}"
fi
python -m pip check
python -c "import lerobot, torch, cv2, serial; print('Pakker: OK'); print('PyTorch:', torch.__version__); print('CUDA tilgjengelig:', torch.cuda.is_available())"
require_environment lerobot-calibrate lerobot-setup-motors lerobot-teleoperate lerobot-record lerobot-rollout lerobot-train
load_station
printf '\n==> Programvaremiljøet er kontrollert.\n'
echo "Aktiver det i terminalen: conda activate lerobot"
echo "Robot-skriptene laster configs/station.env automatisk."
echo "Nye motorer: setup_motors_follower.sh / setup_motors_leader.sh, deretter calibration.sh."
