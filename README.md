# ReLu_Jetson

Opptak av data med SO-101-armene på labens Jetson Orin Nano (LeRobot, LeRobotDataset v3).

> ## 🚨 Velg riktig stasjon
> | Stasjon | Plassering | Fil |
> |---|---|---|
> | **s1** | **IKKE ved vinduene** | `stations/s1.yaml` |
> | **s2** | **Ved vinduene** | `stations/s2.yaml` |
>
> Hver arm har sin egen kalibreringsfil. Velger du feil stasjon, kan armen kjøre inn i endestoppene.

## Opptak

```bash
conda activate lerobot
cd ~/ReLu_Jetson
python record.py --station stations/s1.yaml --dataset pick_cube \
    --task "Pick up the cube and place it in the box" --operator "Lars Olav"
```

| Tast | Handling |
|---|---|
| **p** | Start opptak. Trykk **p** igjen for å lagre episoden |
| **r** | Forkast episoden som tas opp nå |
| **q** | Avslutt. En episode som ikke er lagret, blir forkastet |

Mellom episodene styrer leaderen fortsatt followeren, men ingenting blir tatt opp. Etter 120 sekunder lagres en episode automatisk. Grensen kan endres med `--max-episode-s`.

Datasettene lagres i `~/relu_data/<dataset>_<stasjon>_<dato_tid>/`, og mappen kan endres med `--root`. Hver økt får sin egen mappe, så ingenting blir overskrevet. Metadata for hver episode (operatør, stasjon, tidspunkt og lengde) ligger i `relu/episodes.jsonl` i datasettmappen.

## Porter og kameraer

Portene (`/dev/ttyACM0`, `/dev/ttyACM1`) kan bytte plass når armene kobles fra og til igjen. Sjekk dem før opptak, og rett `port` i stasjonsfilen:

```bash
ls -l /dev/serial/by-id/      # stabile navn per arm, kan brukes direkte som port
lerobot-find-cameras opencv   # finn front- og wrist-kameraet
```

Brukeren må ha tilgang til portene: `sudo usermod -aG dialout $USER`. Logg ut og inn igjen etterpå.

## Kalibrering

Skriptet leser kalibreringen fra standardmappen til LeRobot:

```
~/.cache/huggingface/lerobot/calibration/robots/so_follower/follower_s1.json
~/.cache/huggingface/lerobot/calibration/teleoperators/so_leader/leader_s1.json
```

Mappene heter `so_follower` og `so_leader`, ikke `so101_...`. Ligger filene et annet sted, må `calibration_dir` settes i stasjonsfilen. Hvis filen ikke finnes, stopper skriptet i stedet for å starte en ny kalibrering.

## Se på opptaket

```bash
lerobot-dataset-viz --repo-id relu/<mappenavn> --root ~/relu_data/<mappenavn> --episode-index 0
```
