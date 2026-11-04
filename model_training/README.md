# Automotive model training

Before training, run the dataset audit from the repository root:

```powershell
python -m pip install PyYAML Pillow
python model_training/validate_dataset.py
```

The audit checks train/val/test image and label folders, matching file basenames, readable images, class IDs, normalized box values, and YOLO detection label shape. It rejects polygon rows (more than five values) because this project trains a **detection** model. If your export contains polygons, re-export it as YOLO Detection or build a separate segmentation pipeline; do not train on mixed label formats.

Only after the audit passes:

```powershell
pip install -r backend/requirements.txt
python model_training/train.py --epochs 100 --device cpu
```

The script uses the checked-in generic checkpoint at `backend/yolo26n.pt` as a starting point. This is **not** an automotive-trained model. Training produces a component detector only, not a fault diagnosis model.

The dataset class spellings/order must exactly match the exported annotation class IDs. Confirm the original dataset README and YAML before changing names. Split by vehicle identity rather than adjacent frames to prevent leakage. Keep a vehicle-level holdout set and evaluate per-class precision, recall, mAP, and false negatives before use.

For visible fault recognition, build a separate dataset with narrowly defined defect labels, normal examples, technician-reviewed annotations, and realistic validation across vehicle types and lighting. Do not claim the model detects a fault unless those defect labels were trained and independently validated.
