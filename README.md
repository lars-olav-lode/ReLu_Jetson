# ReLu SO-101 – oppsett og bruk

Dette prosjektet inneholder Bash-skript for to ReLu SO-101-stasjoner: motoroppsett,
kalibrering, teleoperasjon, opptak av demonstrasjoner, trening og evaluering av modeller.
Follower er robotarmen som utfører oppgaven. Leader er armen operatøren beveger for
å styre follower under teleoperasjon og opptak.

## 1. Før du starter

Du trenger Miniconda, Bash og tilgang til robotenes USB-porter og kameraer.
På Jetson/Linux bruker du en Bash-terminal. På Windows bruker du Git Bash med
Miniconda tilgjengelig i samme terminal. Kommandoeksemplene nedenfor er Bash,
og kan ikke limes direkte inn i PowerShell.

Åpne prosjektmappen i terminalen. Bruk anførselstegn dersom stien inneholder mellomrom:

```bash
cd "/sti/til/ReLu_Jetson"
conda --version
```

Hvis Conda er installert, men aktivering ikke virker i Bash, kjør `conda init bash`
fra en terminal som finner Conda, og åpne en ny Bash-terminal.

Rediger deretter [configs/station.env](configs/station.env) med riktig stasjon,
porter og kameraindekser før du bruker roboten.

## 2. Installer og kontroller programvaremiljøet

```bash
bash scripts/initialisering.sh
conda activate lerobot
```

[initialisering.sh](scripts/initialisering.sh) oppretter miljøet `lerobot` fra
[environment.yml](environment.yml) dersom det ikke finnes. Conda-filen inneholder
Python 3.12, FFmpeg 7.1.1 og pip. Skriptet installerer deretter LeRobot med
`core_scripts`, `training`, `feetech` og `smolvla`.

Skriptet kontrollerer pakkeavhengigheter, import av LeRobot/PyTorch/OpenCV/serial,
CUDA-status og kommandoene som prosjektet bruker. Et eksisterende miljø blir
kontrollert uten installasjon eller oppdatering. For å oppdatere eksplisitt:

```bash
UPDATE_ENV=true bash scripts/initialisering.sh
```

`LEROBOT_SPEC` kan brukes sammen med førstegangsoppsett eller `UPDATE_ENV=true`
for å velge en bestemt pakkeversjon eller installasjonskilde. Standardinstallasjonen
har ingen fast LeRobot-versjon. Hvis miljøet finnes, men LeRobot mangler,
bruk oppdateringskommandoen for å installere pakkene.

På Jetson må PyTorch, torchvision og videobibliotekene passe JetPack/CUDA.
Standardinstallasjonen garanterer ikke GPU-støtte på Jetson. Kontroller utskriften
`CUDA tilgjengelig` og installer plattformtilpassede pakker i samme miljø ved behov.
Du kan også kontrollere dette manuelt etter aktivering:

```bash
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```

Aktiver miljøet på nytt i hver ny terminal. Aktiveringen inne i initialiseringsskriptet
varer bare mens skriptet kjører; derfor må du kjøre `conda activate lerobot` etterpå.

## 3. Still inn stasjonen

Robot-skriptene laster `configs/station.env` automatisk. Du trenger ikke kjøre
`source` eller eksportere filen manuelt.

| Variabel | Betydning | Verdi i den medfølgende filen |
| --- | --- | --- |
| `STATION` | `s1`: ikke ved vinduene. `s2`: ved vinduene | `s1` |
| `FOLLOWER_PORT` | USB-port for follower | `/dev/ttyACM0` |
| `LEADER_PORT` | USB-port for leader | `/dev/ttyACM1` |
| `CAM_FRONT` | Indeks for frontkamera | `0` |
| `CAM_WRIST` | Indeks for håndleddskamera | `2` |
| `FPS` | Datasettfrekvens; kontrollfrekvens i policy-skriptene | `30` |
| `EPISODES` | Antall demonstrasjoner ved opptak | `10` |
| `EPISODE_S` | Maksimal lengde på hver demonstrasjon i sekunder | `30` |
| `RESET_S` | Tid mellom demonstrasjoner i sekunder | `10` |
| `DEVICE` | Enhet for policykjøring, eksempelvis `cuda` eller `cpu` | `cuda` |
| `DISPLAY_DATA` | Vis kameraer og robotdata | `false` |
| `DURATION_S` | Maksimal lengde på policykjøring/testforsøk i sekunder | `30` |
| `RENAME_MAP` | Valgfri JSON-kobling fra kameranavn til modellens navn | Kommentert ut |

Portene er eksempler. Identifiser de faktiske portene på maskinen;
follower og leader må ha forskjellige porter. På Windows bruker du eksempelvis
`COM3` og `COM4`. De tilgjengelige LeRobot-verktøyene kan hjelpe med identifisering:

```bash
lerobot-find-port
lerobot-find-cameras opencv
```

Begge kameraene brukes som `front` og `wrist`, med 640 × 480 oppløsning og
30 kamera-FPS. Denne kamerafrekvensen er fast i skriptene; `FPS` endrer ikke den.

Variabler du setter foran kommandoen eller eksporterer i terminalen overstyrer
stasjonsfilen. En verdi foran kommandoen gjelder bare den kjøringen:

```bash
DISPLAY_DATA=true bash scripts/teleop.sh
CAM_FRONT=1 bash scripts/teleop.sh
```

For flere stasjoner/maskiner kan du lage separate filer med samme variabler:

```bash
STATION_ENV=configs/station_s2.env bash scripts/teleop.sh
```

Velg riktig stasjonsfil og porter sammen. Å sette `STATION=s2` alene endrer robotens
ID og kalibreringsfil, men finner ikke automatisk portene til stasjon 2.
Relative konfigurasjons-, data- og modellstier tolkes fra prosjektroten.

## 4. Sett opp nye motorer

Dette gjøres for nye eller ukonfigurerte motorer, ikke ved vanlig oppstart:

```bash
bash scripts/setup_motors_follower.sh
bash scripts/setup_motors_leader.sh
```

[setup_motors_follower.sh](scripts/setup_motors_follower.sh) bruker
`FOLLOWER_PORT` og `so101_follower`. [setup_motors_leader.sh](scripts/setup_motors_leader.sh)
bruker `LEADER_PORT` og `so101_leader`.

CLI-en ber deg koble til bestemte motorer. Koble til bare motoren som etterspørres,
og kontroller at girutvekslingen passer til leddet. Motoroppsettet konfigurerer
motor-ID-er og kommunikasjon; kalibrering gjøres i neste steg.

## 5. Kalibrer armene

[calibration.sh](scripts/calibration.sh) kalibrerer begge armer som standard:

```bash
bash scripts/calibration.sh
```

Følg instruksjonene i terminalen for armstilling og bevegelse gjennom leddenes
arbeidsområder. Du kan også velge én arm:

```bash
TARGET=follower bash scripts/calibration.sh
TARGET=leader bash scripts/calibration.sh
```

For `s1` lagres filene her:

```text
calibration/robots/so101_follower/follower_s1.json
calibration/teleoperators/so101_leader/leader_s1.json
```

For `s2` brukes tilsvarende `follower_s2.json` og `leader_s2.json`.
Alle robot-skriptene bruker de samme ID-ene og mappene. Teleoperasjon og opptak
krever begge kalibreringsfilene. Policykjøring og evaluering trenger bare follower.
Kalibrer ved førstegangsoppsett og ved behov når robotoppsettet endres.

## 6. Test teleoperasjon

[teleop.sh](scripts/teleop.sh) lar leader styre follower, uten å lagre et datasett:

```bash
DISPLAY_DATA=true bash scripts/teleop.sh
```

Kontroller at armene følger hverandre og at `front`/`wrist` viser riktige kameraer
før du tar opp demonstrasjoner. Avslutt terminalkjøringen med `Ctrl+C`.

## 7. Ta opp demonstrasjoner

[record.sh](scripts/record.sh) lagrer kamerabilder og robotdata mens du styrer med leader.
Du må sette datasettets navn, oppgavebeskrivelse og lagringsmappe:

```bash
DATASET=pick_place \
TASK="Legg klossen i boksen" \
DATA_DIR="/data/robot-data/pick_place_s1" \
DISPLAY_DATA=true \
bash scripts/record.sh
```

Datasett-ID-en bygges som `local/${DATASET}_${STATION}`, eksempelvis
`local/pick_place_s1`. Det faktiske datasettet lagres i `DATA_DIR`.
Datasettet lastes ikke opp til Hugging Face.

`EPISODES`, `EPISODE_S`, `RESET_S` og `FPS` kommer fra stasjonsfilen og kan overstyres:

```bash
DATASET=pick_place TASK="Legg klossen i boksen" \
DATA_DIR="/data/robot-data/pick_place_s1" \
EPISODES=20 EPISODE_S=40 RESET_S=15 bash scripts/record.sh
```

Bruk en ny mappe for et nytt datasett. For å fortsette opptak i et eksisterende
kompatibelt datasett, bruk samme navn, stasjon og mappe med `RESUME=true`.
På Windows kan `DATA_DIR` eksempelvis være `C:/robot-data/pick_place_s1`.

## 8. Tren en modell

[train.sh](scripts/train.sh) kjører trening fra et lokalt LeRobot-datasett.
På en egen treningsserver må du ha prosjektet, aktivt `lerobot`-miljø og hele
datasettmappen, inkludert metadata og videoer.

Treningsskriptet leser ikke `station.env`. Sett treningsvariablene i kommandoen
eller eksporter dem i terminalen:

```bash
DATASET_REPO_ID="local/pick_place_s1" \
DATA_DIR="/data/robot-data/pick_place_s1" \
OUTPUT_DIR="/data/training/pick_place_s1_run01" \
POLICY_BASE="lerobot/smolvla_base" \
DEVICE=cuda \
TRAIN_STEPS=20000 \
BATCH_SIZE=8 \
bash scripts/train.sh
```

`DATASET_REPO_ID` skal samsvare med ID-en til datasettet du faktisk lagret;
kontroller datasettmetadataene. `OUTPUT_DIR` må være en ny mappe.
Bruk `POLICY_BASE` for finjustering av en eksisterende modell, eller `POLICY_TYPE`
for å starte med en modelltype, eksempelvis `POLICY_TYPE=act`. Hvis begge er satt,
brukes `POLICY_BASE`.

| Valgfri variabel | Standard | Betydning |
| --- | --- | --- |
| `DEVICE` | `cuda` | Treningsenhet |
| `TRAIN_STEPS` | `20000` | Antall treningssteg |
| `BATCH_SIZE` | `8` | Antall eksempler per batch |
| `NUM_WORKERS` | `4` | Arbeidere for datalasting |
| `SAVE_FREQ` | `1000` | Steg mellom checkpoints |
| `LOG_FREQ` | `100` | Steg mellom loggoppdateringer |
| `SEED` | `42` | Tilfeldighetsfrø |
| `JOB_NAME` | Navnet på output-mappen | Navn på treningskjøringen |
| `WANDB_ENABLE` | `false` | Aktiver Weights & Biases |
| `RENAME_MAP` | Tom | Tilpass navn på modellens observasjoner |

Treningsloggen lagres som `${OUTPUT_DIR}.log`. Checkpoints lagres under
`OUTPUT_DIR`. Modellen lastes ikke opp til Hugging Face. Nedlasting av en
`POLICY_BASE` fra Hugging Face kan kreve internettilgang og eventuelt innlogging.

### Kameranavn og modellen

Hvis modellen forventer `camera1` og `camera2` fremfor `front` og `wrist`, bruk:

```bash
export RENAME_MAP='{"observation.images.front":"observation.images.camera1","observation.images.wrist":"observation.images.camera2"}'
```

Sett dette før treningskommandoen, eller legg det foran kommandoen. Bruk samme
kobling for den ferdige modellen ved policykjøring og evaluering. På robotmaskinen
kan koblingen legges i `station.env`. Sett koblingen etter modellens faktiske
forventninger; ikke alle modeller trenger den.

## 9. Kjør en ferdig modell

[run_policy.sh](scripts/run_policy.sh) brukes til en rask autonom prøve uten datasettopptak:

```bash
MODEL_PATH="/home/relu/models/pick_place/pretrained_model" \
TASK="Legg klossen i boksen" \
DURATION_S=30 \
bash scripts/run_policy.sh
```

`MODEL_PATH` skal peke på den lokale `pretrained_model`-mappen til checkpointet du
vil bruke, ikke bare på hele treningsmappen. Kopier modellen til robotmaskinen
hvis treningen foregikk på en annen maskin. Kameraer, kalibrering, `DEVICE`,
`DISPLAY_DATA` og eventuell `RENAME_MAP` kommer fra stasjonsfilen eller terminalen.
Leader er ikke nødvendig for policykjøring.

## 10. Evaluer modellen systematisk

[eval_policy.sh](scripts/eval_policy.sh) kjører ett lagret forsøk om gangen:

```bash
MODEL_PATH="/home/relu/models/pick_place/pretrained_model" \
TASK="Legg klossen i boksen" \
EVAL_EPISODES=10 \
DURATION_S=30 \
EVAL_DIR="/data/evaluations" \
bash scripts/eval_policy.sh
```

`EVAL_EPISODES` er separat fra opptaksvariabelen `EPISODES` og har standardverdi 10.
`EVAL_DIR` har standardverdi `evaluations` under prosjektroten.
`DURATION_S`, `FPS` og `EVAL_EPISODES` må være positive heltall.

Før hvert forsøk tilbakestiller du robot og oppgave og trykker Enter for å starte.
Etterpå registrerer du `v` for vellykket eller `m` for mislykket. `q` avslutter;
et allerede startet forsøk uten vurdering registreres som `unrated`.
Definer på forhånd hva som teller som suksess, eksempelvis at klossen ligger i
boksen ved slutten av forsøket. Kameraopptaket gir ingen automatisk suksessvurdering.

Hver kjøring får en unik mappe med:

| Fil/mappe | Innhold |
| --- | --- |
| `config.json` | Modellsti, oppgave og innstillinger for kjøringen |
| `episode_001/`, osv. | Separate LeRobot-datasett med videoer og robotdata |
| `episode_001.log`, osv. | Terminalutskrift per forsøk |
| `results.csv` | Resultat og datasettmappe per forsøk |
| `summary.json` | Antall suksesser, feil, uvurderte forsøk og suksessrate |

8 vellykkede av 10 vurderte forsøk gir 80 % suksessrate. Uvurderte forsøk og
kjørefeil telles separat og inngår ikke i nevneren. Ved kjørefeil stopper evalueringen.
Resultatene skrives fortløpende; oppsummeringen oppdateres også ved vanlig avslutning
og avbrudd som skriptet håndterer. Ingenting lastes opp til Hugging Face.

## Oversikt over skriptene

| Skript | Når det brukes |
| --- | --- |
| `initialisering.sh` | Installer miljøet første gang, kontroller det senere, oppdater eksplisitt |
| `setup_motors_follower.sh` | Konfigurer nye follower-motorer |
| `setup_motors_leader.sh` | Konfigurer nye leader-motorer |
| `calibration.sh` | Kalibrer begge armer eller valgt arm |
| `teleop.sh` | Styr follower med leader uten opptak |
| `record.sh` | Lagre demonstrasjoner som treningsdatasett |
| `train.sh` | Tren eller finjuster modellen |
| `run_policy.sh` | Rask modellprøve uten opptak |
| `eval_policy.sh` | Lagrede testforsøk med manuell vurdering og suksessrate |
| `common.sh` | Felles miljøkontroll, stasjonslasting, kameraoppsett og validering; lastes av de andre skriptene |
| `tests/test_scripts.sh` | Kontroller Bash-syntaks og simulerte kommandoforløp uten robot |

## Vanlig oppstart ved en ny økt

Når motorer og kalibrering allerede er klare:

1. Åpne Bash i prosjektmappen.
2. Kjør `conda activate lerobot`.
3. Kontroller stasjon, porter og kameraer i `configs/station.env`.
4. Kjør skriptet du trenger, eksempelvis `DISPLAY_DATA=true bash scripts/teleop.sh`.

Du trenger ikke motoroppsett eller reinstallasjon ved hver økt.

## Feilsøking

| Problem | Hva du kontrollerer |
| --- | --- |
| «Aktiver Miniconda-miljøet» | Kjør `conda activate lerobot` i samme Bash-terminal |
| Kommando «kommer fra feil miljø» | Kontroller `command -v python` og LeRobot-kommandoen; begge må ligge i aktivt Conda-miljø |
| LeRobot-kommando mangler | Kontroller installasjon/versjon; `lerobot-rollout` med `episodic` må være tilgjengelig for evaluering |
| Manglende kalibrering | Kontroller `STATION` og kjør kalibrering for riktig arm |
| Kamera mangler eller er feil | Finn kameraindeksene og kontroller `CAM_FRONT`/`CAM_WRIST` |
| Ingen kontakt med robot | Kontroller strøm, USB, faktisk port og tilgang til porten |
| Modellen finner ikke kameraene | Kontroller modellens observasjonsnavn og `RENAME_MAP` |
| CUDA er ikke tilgjengelig | Kontroller PyTorch/CUDA/JetPack-oppsettet, eller velg `DEVICE=cpu` der modellen støtter det |
| Output-mappen finnes allerede | Velg en ny `OUTPUT_DIR` for trening |
| «bad interpreter» eller `$'\r'` | Lagre Bash- og stasjonsfilene med LF-linjeskift; prosjektets `.gitattributes` angir LF |

For å kontrollere skriptene uten å kjøre robotkommandoer:

```bash
bash tests/test_scripts.sh
```

Testen bruker simulerte CLI-er og bekrefter ikke faktisk robotkommunikasjon,
modellkompatibilitet, videolagring eller CUDA på Jetson.
