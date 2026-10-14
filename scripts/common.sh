#!/usr/bin/env bash
# Felles funksjoner; lastes av skriptene, kjøres ikke direkte.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_station() {
  local config="${STATION_ENV:-$REPO_ROOT/configs/station.env}" name
  local -a names=(STATION FOLLOWER_PORT LEADER_PORT CAM_FRONT CAM_WRIST FPS
    EPISODES EPISODE_S RESET_S DEVICE DISPLAY_DATA DURATION_S RENAME_MAP)
  local -A overrides=()
  for name in "${names[@]}"; do
    if [[ -v "$name" ]]; then overrides["$name"]="${!name}"; fi
  done
  [[ "$config" = /* || "$config" = ?:/* ]] || config="$REPO_ROOT/$config"
  [[ -f "$config" ]] || { echo "Finner ikke stasjonsfil: $config" >&2; return 1; }
  source "$config"
  for name in "${names[@]}"; do
    if [[ -v "overrides[$name]" ]]; then printf -v "$name" '%s' "${overrides[$name]}"; fi
    if [[ -v "$name" ]]; then export "$name"; fi
  done
  [[ "${STATION:-}" = s1 || "${STATION:-}" = s2 ]] || {
    echo "STATION må være s1 eller s2." >&2; return 1;
  }
}

require_environment() {
  [[ -n "${CONDA_PREFIX:-}" && "${CONDA_DEFAULT_ENV:-}" = lerobot ]] || {
    echo "Aktiver Miniconda-miljøet: conda activate lerobot" >&2; return 1;
  }
  local tool resolved prefix="$CONDA_PREFIX"
  if command -v cygpath >/dev/null 2>&1; then prefix="$(cygpath -u "$prefix")"; fi
  for tool in python "$@"; do
    resolved="$(command -v "$tool")" || { echo "Finner ikke $tool i lerobot-miljøet." >&2; return 1; }
    case "$resolved" in
      "$prefix"/*) ;;
      *) echo "$tool kommer fra feil miljø: $resolved" >&2; return 1 ;;
    esac
  done
}

require_ports() {
  local arm name
  for arm in "$@"; do
    case "$arm" in follower) name=FOLLOWER_PORT ;; leader) name=LEADER_PORT ;; esac
    [[ -n "${!name:-}" ]] || { echo "Mangler $name i station.env." >&2; return 1; }
  done
  if [[ $# = 2 && "$FOLLOWER_PORT" = "$LEADER_PORT" ]]; then
    echo "Follower og leader må ha forskjellige porter." >&2; return 1
  fi
}

require_calibration() {
  local arm file
  for arm in "$@"; do
    case "$arm" in
      follower) file="calibration/robots/so101_follower/follower_${STATION}.json" ;;
      leader) file="calibration/teleoperators/so101_leader/leader_${STATION}.json" ;;
    esac
    [[ -f "$file" ]] || { echo "Mangler $file. Kjør scripts/calibration.sh først." >&2; return 1; }
  done
}

station_cameras() {
  printf '{ front: {type: opencv, index_or_path: %s, width: 640, height: 480, fps: 30}, wrist: {type: opencv, index_or_path: %s, width: 640, height: 480, fps: 30}}' "${CAM_FRONT:-0}" "${CAM_WRIST:-2}"
}
