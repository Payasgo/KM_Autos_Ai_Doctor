# AI Car Doctor — Flutter + FastAPI

Cross-platform Android/iOS app for preliminary engine-bay visual screening. It supports camera capture, gallery upload, and a FastAPI image inspection endpoint.

> This project is not a certified diagnostic device. Image-based component recognition does not establish mechanical faults, roadworthiness, or hidden sensor values. Keep the engine off and cool while taking photographs. Use an OBD-II scanner and qualified technician for diagnosis.

## Backend (Windows PowerShell)

```powershell
cd backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Verify `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/docs`. The API accepts JPG/PNG/WEBP up to 10 MB at `POST /api/v1/diagnose`. The health response reports whether the configured model can actually load.

Run backend tests from `backend`:
```powershell
python -m pytest -q
```

## Flutter

```powershell
cd mobile
flutter pub get
flutter run
```

Configure the API address with `--dart-define=API_BASE_URL=...`:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://127.0.0.1:8000`
- Physical Android/iPhone on same Wi-Fi: `http://YOUR_COMPUTER_LAN_IP:8000`

Example:
```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```
For production use HTTPS and a deployed backend.

## Dataset and model

A custom model must be trained from data that matches its class names and task. The checked-in `backend/yolo26n.pt` is a generic starting checkpoint, **not** an automotive detector and not a fault-diagnosis model. Do not point `YOLO_WEIGHTS` at it and present its predictions as car findings.

Dataset layout expected by `backend/automotive_dataset/data.yaml`:
```
backend/automotive_dataset/
  data.yaml
  images/{train,val,test}/
  labels/{train,val,test}/
```
Use matching image/label basenames. YOLO detection labels must be five values per object: class_id x_center y_center width height (normalized 0–1). Polygon rows indicate segmentation-format annotations and must be exported/converted consistently before detection training. Check every split and class ID before training.

Install training dependencies and run from repository root:
```powershell
pip install -r backend/requirements.txt
python model_training/train.py --epochs 100 --device cpu
```
For an NVIDIA CUDA GPU use `--device 0`. CPU training may take a long time. Training produces a best checkpoint under `runs/train/automotive_parts/weights/best.pt`; validate per-class metrics and real-world false negatives before deployment. Copy validated weights to `backend/models/engine_inspection.pt`.

The example component dataset recognises parts only. It cannot identify faults unless a separate defect dataset and validated defect classes are developed.

## Docker

```bash
docker compose up --build
```
Place validated weights at `backend/models/engine_inspection.pt` for the configured volume mount.

## Safety and production

Use HTTPS, authentication, rate limiting, consent, image retention/deletion controls, and platform privacy disclosures before public deployment. The current camera path captures a still frame for server analysis; it is not continuous live AI video scanning.
