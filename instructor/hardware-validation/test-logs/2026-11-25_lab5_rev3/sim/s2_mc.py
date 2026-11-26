import numpy as np, sys
from cell import *; from port import *
RED = ([0.95, 0.5, 0.3], [0.05, 1, 1])
SPREAD = [(0.25, -0.24), (0.25, 0.17), (0.43, -0.20), (0.42, 0.17)]
CLUSTER = [(0.40, 0.02), (0.38, 0.14), (0.45, 0.07), (0.44, 0.16)]        # all in one half, like the 2026-11-04 points 1-4
def see(cam, xy, yaw, size, rng, noise=4):
    b = Box(xy, size, size, COL['red'], yaw=yaw)
    (c,), _ = cam.project(np.array([[xy[0], xy[1], Z_TABLE + size]])); r = int(80 + size * 1500)
    u0, v0 = int(max(c[0] - r, 0)), int(max(c[1] - r, 0)); u1, v1 = int(min(c[0] + r, W)), int(min(c[1] + r, H))
    img = render(cam, [b], roi=(u0, v0, u1, v1), noise=noise, rng=rng)
    uv, _, st = detect_block(img, *RED, 200)
    return uv + [u0, v0]
def touch(xy, rng, tilt_max, jog, yaw=None, off=(0, 0)):
    """Flange pose as readCartesianPose would report it when the student has the open gripper on the block."""
    tilt = np.deg2rad(rng.uniform(0, tilt_max)); az = rng.uniform(0, 2*np.pi); yaw = rng.uniform(1.3, 2.0) if yaw is None else yaw
    Rdown = eul2R([yaw, 0, np.pi]); ax = np.array([np.cos(az), np.sin(az), 0])
    K = np.array([[0, -ax[2], ax[1]], [ax[2], 0, -ax[0]], [-ax[1], ax[0], 0]])
    R = (np.eye(3) + np.sin(tilt) * K + (1 - np.cos(tilt)) * K @ K) @ Rdown
    tip = np.r_[np.array(xy) + rng.normal(0, jog, 2) + off, Z_TABLE + 0.005 + rng.normal(0, 0.002)]
    fl = tip - R[:, 2] * GRIP
    return np.r_[eul_zyx(R), fl]
def trial(rng, cam_tilt=(2, -1.5), size=0.025, tilt_max=3, jog=0.002, layout=SPREAD, npick=5, off1=(0, 0)):
    cam = Camera(tilt_deg=cam_tilt); UV, XY = [], []; ref = None
    for k, xy in enumerate(layout):
        UV.append(see(cam, xy, rng.uniform(0, np.pi/2), size, rng)); p = touch(xy, rng, tilt_max, jog, off=off1 if k == 0 else (0, 0)); XY.append(p[3:5])
        if k == 0: ref = p
    A, res, rms = fit_pixel_to_base(UV, XY); errs = []
    Rref = eul2R(ref[:3])
    for _ in range(npick):
        while True:
            xy = np.array([rng.uniform(0.22, 0.44), rng.uniform(-0.25, 0.18)])
            if np.linalg.norm(xy) < 0.48: break
        tgt = pixel_to_base(A, see(cam, xy, rng.uniform(0, np.pi/2), size, rng))
        tip = np.r_[tgt, 0] + Rref[:, 2] * GRIP
        errs.append(np.linalg.norm(tip[:2] - xy) * 1000)
    return rms, errs
def run(name, n=40, **kw):
    rng = np.random.default_rng(7); R, E = [], []
    for _ in range(n):
        r, e = trial(rng, **kw); R.append(r); E += e
    R, E = np.array(R), np.array(E)
    print('%-58s RMS med %.2f p90 %.2f max %.2f | pick err mm med %.1f p90 %.1f max %.1f | >10mm %2.0f%% >15mm %2.0f%%' % (
        name, np.median(R), np.percentile(R, 90), R.max(), np.median(E), np.percentile(E, 90), E.max(), 100*(E > 10).mean(), 100*(E > 15).mean()))
if __name__ == '__main__':
    run('ideal: no cam tilt, no touch tilt, no jog err, 25 mm', cam_tilt=(0, 0), tilt_max=0, jog=0)
    run('ideal but 50 mm cube', cam_tilt=(0, 0), tilt_max=0, jog=0, size=0.05)
    for ct in (2, 5, 10): run('camera tilt %d deg only, 25 mm' % ct, cam_tilt=(ct, -ct*0.75), tilt_max=0, jog=0)
    run('camera tilt 5 deg only, 50 mm', cam_tilt=(5, -3.75), tilt_max=0, jog=0, size=0.05)
    run('jog error 2 mm only', cam_tilt=(0, 0), tilt_max=0, jog=0.002)
    for tm in (1, 3, 5): run('touch tilt 0..%d deg only' % tm, cam_tilt=(0, 0), tilt_max=tm, jog=0)
    run('BASELINE: cam 2 deg, tilt 0..3, jog 2 mm, spread, 25 mm')
    run('baseline, 50 mm cube', size=0.05)
    run('baseline but tilt 0..1 deg (X/Y/Z jog from a tool-down pose)', tilt_max=1)
    run('baseline but tilt 0..5 deg (FreeDrive touches, as 11-04)', tilt_max=5)
    run('baseline, CLUSTERED points', layout=CLUSTER)
    run('clustered, tilt 0..5 (the 11-04 situation)', layout=CLUSTER, tilt_max=5)
    run('baseline, 5 points (spread + centre)', layout=SPREAD + [(0.34, -0.03)])
    run('baseline, placement-1 touch 8 mm off centre', off1=(0.008, 0))
