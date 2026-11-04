# Model integration and training guide

The backend accepts an Ultralytics YOLO model file via `YOLO_WEIGHTS`. No pretrained automotive fault model is bundled: there is no responsible universal model that can be assumed accurate across all makes, years, engine layouts, camera conditions, and failure modes.

## Suggested first dataset classes
Start with component recognition only:
- battery
- alternator
- radiator
- coolant_reservoir
- engine_oil_cap
- air_filter_box
- serpentine_belt
- hose
- electrical_connector

Then build a separate, carefully validated visible-condition dataset for narrowly defined conditions such as:
- visible_corrosion_on_battery_terminal
- visibly_cracked_belt
- visible_fluid_residue
- visibly_disconnected_hose

Avoid broad labels such as `bad_engine`, `engine_failure`, or `needs_replacement`. These cannot be reliably inferred from one image.

## Dataset format
Use YOLO detection labels (one `.txt` per image) and `data.yaml`. Split by vehicle identity into train/val/test to prevent near-duplicate leakage. Obtain consent and ensure licensing permits training and commercial use.

Example training command after installing ultralytics:
```bash
yolo detect train model=yolo11n.pt data=data.yaml epochs=100 imgsz=640
```
Copy the best weights to `backend/models/engine_inspection.pt`, install `ultralytics`, and restart the API.

## Validation gates
- Hold out vehicles and capture sessions, not random adjacent frames.
- Measure precision, recall, per-class AP, calibration, and false negatives.
- Test day/night, glare, dust, engine variants, phone cameras, and occlusion.
- Do not display a fault severity until the specific defect class is validated.
- Have automotive technicians review labels and failure cases.
