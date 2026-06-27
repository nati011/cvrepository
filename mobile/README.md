# CV Exec Feed (Flutter)

This folder contains the Flutter mobile client for exec candidate review:

- Feed tab: ranked candidate cards with `shortlist / pass / star` actions.
- Chat tab: ask questions across the CV pile with cited answers.
- Stats tab: leaderboard + streak metrics from reactions.

## Bootstrap

If platform folders are missing, initialize them once:

```bash
cd mobile
flutter create .
flutter pub get
```

## Run

The API base URL is injected at run time via `--dart-define=API_BASE_URL`. The
`run.sh` helper auto-detects this machine's LAN IP from `env.sh` so a physical
device on the same Wi‑Fi can reach the backend:

```bash
cd mobile
source env.sh        # exports JAVA/Android paths + API_BASE_URL
./run.sh             # auto-detects device + host IP, e.g. http://192.168.x.x:8080
```

Overrides:

```bash
API_HOST=192.168.1.50 API_PORT=8080 ./run.sh   # pin a specific host/port
./run.sh -d <device-id>                          # target a specific device
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
```

Notes:
- Real device: the phone and this machine must be on the same network, and the
  API must be reachable at the host IP (default port **8080**).
- Emulator: use `10.0.2.2` (the emulator's alias for the host loopback).
