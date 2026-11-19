"""Probe: load Octo (MathWorks vlapy wrapper) and run it on a real lab frame.

usage: python -I octo_probe.py <vlapy_dir> <image.png> "<task>" [n_steps]
"""
import sys, time, json
from pathlib import Path

vlapy, img_path, task = sys.argv[1], sys.argv[2], sys.argv[3]
n = int(sys.argv[4]) if len(sys.argv) > 4 else 5
sys.path.insert(0, vlapy)

t0 = time.time()
import numpy as np
from PIL import Image
import octoModel
print(f"imports: {time.time()-t0:.1f} s", flush=True)

t0 = time.time()
policy = octoModel.OctoInference()
print(f"OctoInference() load: {time.time()-t0:.1f} s  model={policy.model_type}", flush=True)

img = np.asarray(Image.open(img_path).convert("RGB"), dtype=np.uint8)
print(f"image {img.shape} {img.dtype}", flush=True)

for k in range(n):
    t0 = time.time()
    raw, act = policy.step(img, task)
    dt = time.time() - t0
    out = {
        "step": k, "dt_s": round(dt, 3),
        "world_vector_m": [round(float(v), 5) for v in act["world_vector"]],
        "rot_axangle_rad": [round(float(v), 5) for v in act["rot_axangle"]],
        "gripper": float(np.ravel(act["gripper"])[0]),
        "raw_open_gripper": round(float(np.ravel(raw["open_gripper"])[0]), 4),
    }
    print(json.dumps(out), flush=True)
