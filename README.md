# AI Car Doctor — Cross-platform MVP

Flutter mobile app (Android + iOS) with a FastAPI backend. Supports live camera capture, gallery uploads, scan reports, and an optional YOLOv8/YOLO11 detection adapter.

## What works in this MVP
- Open a live camera preview, capture an engine-bay photo, or select an existing image.
- Upload it to the backend.
- Receive a structured inspection report with severity, visible findings, limitations, and recommended next steps.
- Optional custom YOLO model integration through `YOLO_WEIGHTS`.
- Health endpoint and local Docker deployment.

## Important diagnostic limitation
This MVP is an inspection assistant, not a certified vehicle diagnostic device. A photograph cannot establish hidden mechanical/electrical faults or measure oil pressure, compression, coolant temperature, charging voltage, or sensor values. Without a trained and validated model, the backend deliberately returns `model_status: "not_configured"` and does not invent detections. Treat all visual findings as preliminary. Never work around a running engine, hot/cooling system, moving belts/fans, high-voltage hybrid/EV components, or exposed electrical parts. Turn the engine off, remove the key, let hot parts cool, and seek a qualified technician for safety-critical concerns.

## Architecture
```text
ai_car_doctor/
├── mobile/                 # Flutter Android/iOS app
│   ├── lib/
│   ├── android/
│   └── ios/
├── backend/                # FastAPI image upload + inference API
│   ├── app/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
├── model_training/         # Dataset/model setup notes
└── docker-compose.yml
```

## 1. Run the backend
Requirements: Python 3.10+.

```bash
cd backend
python -m venv .venv
# macOS/Linux:
source .venv/bin/activate
# Windows:
# .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open `http://localhost:8000/docs` for interactive API docs and `http://localhost:8000/health` for health status.

Optional detector:
1. Train or obtain a model specifically validated for automotive engine-bay components/defects.
2. Put weights at `backend/models/engine_inspection.pt` (or set `YOLO_WEIGHTS` to an absolute path).
3. Install optional inference dependency: `pip install ultralytics`.
4. Restart backend. The API will return model detections when the weights are available.

Do not use a generic object-detection model as a mechanical fault detector. The model's class names must correspond to your labeled dataset. A detected component is not proof that the component is faulty.

## 2. Run the Flutter app
Install Flutter stable and platform tooling: https://docs.flutter.dev/get-started/install

```bash
cd mobile
flutter pub get
flutter run
```

The app defaults to `http://10.0.2.2:8000` on Android emulator. Change the API URL in `mobile/lib/config.dart`:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://127.0.0.1:8000`
- Physical phone: `http://YOUR_COMPUTER_LAN_IP:8000` (phone and computer must share Wi-Fi; allow port 8000 through firewall).
For production, use HTTPS and a deployed backend URL.

### Platform permissions
Camera and photo library permission descriptions are included in `ios/Runner/Info.plist`. Android camera permission is declared in `android/app/src/main/AndroidManifest.xml`. If regenerating platform folders with Flutter, re-apply these permissions.

## 3. Docker
From project root:
```bash
docker compose up --build
```

## API
`POST /api/v1/diagnose` multipart form:
- `image`: JPG/PNG/WEBP image
- `vehicle_make` (optional)
- `vehicle_model` (optional)
- `vehicle_year` (optional)

`GET /health`

## Model training
See `model_training/README.md`. You need a legally usable, consented dataset with labeled engine components and separately labeled visible defects. Include normal examples and diverse makes, model years, lighting, angles, and engine layouts. Split by vehicle (not near-duplicate images) into train/validation/test. Report per-class precision/recall and false-negative rates. Do not deploy until independently validated in realistic conditions.

## Production checklist
- HTTPS, authentication, rate limiting, upload size limits, malware scanning, and retention/deletion policy.
- Explicit user consent before uploading images; strip EXIF/location metadata.
- Validate model performance by vehicle class, lighting, camera, and region.
- Human review and disclaimers for safety-critical results.
- Add OBD-II adapter support using a tested Bluetooth LE/Classic adapter and standardized PIDs/DTCs; do not infer live sensor values from images.
- Add crash reporting, privacy policy, terms, and app-store compliance.
