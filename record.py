"""ReLu-opptak på Jetson (SO-101, LeRobot).

  p = start opptak / trykk p igjen for å lagre episoden
  r = forkast episoden som tas opp nå (reset)
  q = avslutt (en episode som ikke er lagret, forkastes)

Eksempel:
  python record.py --station stations/s1.yaml --dataset pick_cube \\
      --task "Pick up the cube and place it in the box" --operator "Lars Olav"
"""

import argparse
import json
import queue
import sys
from datetime import datetime
from pathlib import Path

import yaml
from lerobot.cameras import CameraConfig
from lerobot.datasets import (
    LeRobotDataset,
    VideoEncodingManager,
    aggregate_pipeline_dataset_features,
    create_initial_features,
)
from lerobot.processor import make_default_processors
from lerobot.robots import RobotConfig, make_robot_from_config
from lerobot.scripts.lerobot_record import record_loop  # registrerer også arm- og kameratyper
from lerobot.teleoperators import TeleoperatorConfig, make_teleoperator_from_config
from lerobot.utils.feature_utils import combine_feature_dicts
from lerobot.utils.keyboard_input import TerminalKeyListener


def make_devices(station):
    """Lager follower og leader fra stasjonsfila.

    Kalibreringen leses fra `calibration_dir` hvis den står i stasjonsfila,
    ellers fra LeRobots standardmappe (~/.cache/huggingface/lerobot/calibration).
    """
    robot = dict(station["robot"])
    teleop = dict(station["teleop"])
    for cfg in (robot, teleop):
        if cfg.get("calibration_dir"):
            cfg["calibration_dir"] = Path(cfg["calibration_dir"]).expanduser()

    cameras = {}
    for name, cam in (robot.pop("cameras", None) or {}).items():
        cam = dict(cam)
        if isinstance(cam.get("index_or_path"), str):
            cam["index_or_path"] = Path(cam["index_or_path"])
        cameras[name] = CameraConfig.get_choice_class(cam.pop("type", "opencv"))(**cam)

    robot_cfg = RobotConfig.get_choice_class(robot.pop("type"))(cameras=cameras, **robot)
    teleop_cfg = TeleoperatorConfig.get_choice_class(teleop.pop("type"))(**teleop)
    devices = make_robot_from_config(robot_cfg), make_teleoperator_from_config(teleop_cfg)

    # Stopp heller enn å starte en ny kalibrering ved et uhell
    for device in devices:
        if not device.calibration_fpath.is_file():
            sys.exit(
                f"Fant ikke kalibreringsfila {device.calibration_fpath}\n"
                "Sett riktig calibration_dir i stasjonsfila, eller kalibrer armen (se README)."
            )
    return devices


def save_metadata(path, episodes):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(e, ensure_ascii=False) + "\n" for e in episodes), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--station", required=True, help="stations/s1.yaml (IKKE ved vinduene) eller stations/s2.yaml (ved vinduene)")
    parser.add_argument("--dataset", required=True, help="navn på datasettet, f.eks. pick_cube")
    parser.add_argument("--task", required=True, help="beskrivelse av oppgaven, samme tekst hver gang")
    parser.add_argument("--operator", required=True, help="hvem som styrer armen")
    parser.add_argument("--root", default="~/relu_data", help="hvor datasettene lagres (standard: ~/relu_data)")
    parser.add_argument("--max-episode-s", type=float, default=120, help="episoden lagres automatisk etter så mange sekunder")
    args = parser.parse_args()

    if not sys.stdin.isatty():
        sys.exit("Kjør skriptet i en vanlig terminal (eller over SSH), ellers kan ikke tastene leses.")

    # --- Oppsett ---
    station = yaml.safe_load(Path(args.station).read_text(encoding="utf-8"))
    fps = station.get("fps", 30)
    robot, teleop = make_devices(station)
    teleop_proc, robot_proc, obs_proc = make_default_processors()
    features = combine_feature_dicts(
        aggregate_pipeline_dataset_features(
            pipeline=teleop_proc, initial_features=create_initial_features(action=robot.action_features)
        ),
        aggregate_pipeline_dataset_features(
            pipeline=obs_proc, initial_features=create_initial_features(observation=robot.observation_features)
        ),
    )

    name = f"{args.dataset}_{station['station']}_{datetime.now():%Y%m%d_%H%M%S}"  # ny mappe hver økt
    root = Path(args.root).expanduser() / name
    dataset = LeRobotDataset.create(
        f"relu/{name}", fps, root=root, robot_type=robot.name, features=features,
        image_writer_threads=4 * len(robot.cameras),
    )
    metadata_path = root / "relu" / "episodes.jsonl"
    episodes = []

    # --- Tastatur: tasten legges i en kø, og robot-løkka avbrytes ---
    keys = queue.Queue()
    events = {"exit_early": False, "rerecord_episode": False, "stop_recording": False}

    def on_key(key):
        key = key.lower()
        if key in ("p", "r", "q"):
            keys.put(key)
            events["exit_early"] = True

    loop_args = dict(
        robot=robot, teleop=teleop, fps=fps, events=events, single_task=args.task,
        teleop_action_processor=teleop_proc, robot_action_processor=robot_proc,
        robot_observation_processor=obs_proc,
    )

    teleop.connect()
    robot.connect()
    listener = TerminalKeyListener(on_key)
    listener.start()
    print(__doc__)
    print(f"Klar: stasjon {station['station']} ({station.get('location')}). Lagrer i {root}")
    print("Trykk p for å starte.")

    try:
        with VideoEncodingManager(dataset):
            while True:
                # Venter: leader styrer follower, ingenting tas opp
                events["exit_early"] = False
                record_loop(control_time_s=float("inf"), **loop_args)
                key = keys.get()
                if key == "q":
                    break
                if key != "p":
                    continue

                # Opptak
                events["exit_early"] = False
                started_at = datetime.now().astimezone()
                print(f"● Tar opp episode {dataset.num_episodes}   (p = lagre, r = forkast, q = avslutt)")
                record_loop(dataset=dataset, control_time_s=args.max_episode_s, **loop_args)
                key = keys.get() if not keys.empty() else "p"  # tom kø = tiden gikk ut, lagre

                if key in ("r", "q"):
                    dataset.clear_episode_buffer()
                    print("✖ Episoden er forkastet.")
                    if key == "q":
                        break
                    print("Trykk p for å ta opp på nytt.")
                    continue
                if not dataset.has_pending_frames():
                    continue

                frames_before = dataset.num_frames
                index = dataset.num_episodes
                dataset.save_episode()
                episodes.append({
                    "episode_index": index,
                    "task": args.task,
                    "operator": args.operator,
                    "station": station["station"],
                    "location": station.get("location"),
                    "robot_id": station["robot"]["id"],
                    "started_at": started_at.isoformat(timespec="seconds"),
                    "duration_s": round((datetime.now().astimezone() - started_at).total_seconds(), 1),
                    "num_frames": dataset.num_frames - frames_before,
                })
                save_metadata(metadata_path, episodes)
                print(f"✔ Episode {index} lagret. Trykk p for neste, q for å avslutte.")
    finally:
        listener.stop()
        if dataset.has_pending_frames():
            dataset.clear_episode_buffer()
        dataset.finalize()
        if robot.is_connected:
            robot.disconnect()
        if teleop.is_connected:
            teleop.disconnect()

    print(f"Ferdig: {len(episodes)} episoder lagret i {root}")


if __name__ == "__main__":
    main()
