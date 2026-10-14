#!/usr/bin/env bash
# Ubuntu/Linux x86_64 GPU server. Run: bash scripts/initialise_rtx4500.sh
# Installs user-local software only; does not start training.
set -Eeuo pipefail
trap 'echo "Oppsett feilet ved linje $LINENO. Rett feilen og kjør skriptet igjen." >&2' ERR

[[ "$(uname -s)" = Linux && "$(uname -m)" = x86_64 ]] || {
  echo "Dette skriptet krever Linux x86_64." >&2; exit 1;
}
command -v nvidia-smi >/dev/null || {
  echo "NVIDIA-driver/GPU er ikke tilgjengelig. Kontroller serveroppsettet." >&2; exit 1;
}
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

CONDA_ROOT="${CONDA_ROOT:-$HOME/miniconda3}"
LEROBOT_SPEC="${LEROBOT_SPEC:-lerobot[core_scripts,training,feetech,smolvla]}"

if ! command -v conda >/dev/null 2>&1; then
  if [[ ! -f "$CONDA_ROOT/etc/profile.d/conda.sh" ]]; then
    [[ ! -e "$CONDA_ROOT" ]] || {
      echo "$CONDA_ROOT finnes, men er ikke en komplett Conda-installasjon." >&2; exit 1;
    }
    command -v curl >/dev/null || { echo "curl mangler." >&2; exit 1; }
    installer="$(mktemp /tmp/miniconda-installer-XXXXXXXX.sh)"
    trap 'rm -f -- "$installer"' EXIT
    echo "Installerer Miniconda i $CONDA_ROOT. Installasjonen omfattes av Anacondas vilkår."
    curl -fL --retry 3 https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o "$installer"
    bash "$installer" -b -p "$CONDA_ROOT"
    rm -f -- "$installer"
    trap - EXIT
  fi
  source "$CONDA_ROOT/etc/profile.d/conda.sh"
fi
conda_base="$(conda info --base)"
source "$conda_base/etc/profile.d/conda.sh"
# Make conda available in future interactive Bash sessions.
# This updates the user's ~/.bashrc, not system shell configuration.
conda init bash

# Use conda-forge explicitly, without changing global channel settings.
# evdev is prebuilt here: no system headers or root permissions needed.
if conda env list | awk '$1 == "lerobot" {found=1} END {exit !found}'; then
  conda install -y -n lerobot --override-channels -c conda-forge \
    python=3.12 ffmpeg=7.1.1 pip evdev
else
  conda create -y -n lerobot --override-channels -c conda-forge \
    python=3.12 ffmpeg=7.1.1 pip evdev
fi
conda activate lerobot

# May be pinned by setting LEROBOT_SPEC to the tested package version.
# Re-running also repairs an interrupted pip installation.
python -m pip install "$LEROBOT_SPEC"
python -m pip check
command -v lerobot-train
python - <<'PY'
import importlib.metadata
import torch
import evdev

print('LeRobot:', importlib.metadata.version('lerobot'))
print('PyTorch:', torch.__version__)
print('PyTorch CUDA:', torch.version.cuda)
if not torch.cuda.is_available():
    raise SystemExit('CUDA er ikke tilgjengelig i PyTorch.')
x = torch.randn(256, 256, device='cuda', requires_grad=True)
y = x @ x
y.sum().backward()
torch.cuda.synchronize()
print('GPU-test OK:', torch.cuda.get_device_name(0))
PY

# Record resolved versions for troubleshooting and later pinning.
manifest_dir="$CONDA_PREFIX/setup-manifests"
mkdir -p "$manifest_dir"
python -m pip freeze > "$manifest_dir/pip-freeze.txt"
conda list --explicit > "$manifest_dir/conda-explicit.txt"

printf '\nOppsett fullført. Aktiver miljøet i terminalen med:\n'
printf 'source "%s/etc/profile.d/conda.sh"\n' "$conda_base"
echo 'conda activate lerobot'
echo "Pakkeversjoner er lagret i: $manifest_dir"
echo 'Trening startes separat med bash scripts/train.sh.'

# Start interactive shell with lerobot activated
if [[ -t 0 && -t 1 ]]; then
  echo "Åpner Bash med lerobot aktivert. Bruk exit for å gå tilbake."
  exec bash --rcfile <(
    printf '%s\n' '[[ ! -f ~/.bashrc ]] || source ~/.bashrc'
    printf 'source %q\n' "$conda_base/etc/profile.d/conda.sh"
    printf '%s\n' 'conda activate lerobot'
  ) -i
fi
