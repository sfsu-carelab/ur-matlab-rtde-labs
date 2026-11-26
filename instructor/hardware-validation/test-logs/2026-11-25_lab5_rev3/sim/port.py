"""Line-by-line port of the Lab 5 student code logic (labs/lab5-vision-guided-pick)."""
import numpy as np
from matplotlib.colors import rgb_to_hsv
from scipy import ndimage
from kin import *
import cell
def detect_block(img, hsvLow, hsvHigh, minAreaPx=200):
    hsv = rgb_to_hsv(img.astype(float) / 255); h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    if hsvLow[0] <= hsvHigh[0]: hm = (h >= hsvLow[0]) & (h <= hsvHigh[0])
    else: hm = (h >= hsvLow[0]) | (h <= hsvHigh[0])
    mask = hm & (s >= hsvLow[1]) & (s <= hsvHigh[1]) & (v >= hsvLow[2]) & (v <= hsvHigh[2])
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n == 0: return np.array([np.nan, np.nan]), mask, []
    areas = ndimage.sum(mask, lab, range(1, n + 1))
    keep = [i + 1 for i, a in enumerate(areas) if a >= round(minAreaPx)]
    mask = np.isin(lab, keep)
    if not keep: return np.array([np.nan, np.nan]), mask, []
    k = keep[int(np.argmax([areas[i - 1] for i in keep]))]
    rr, cc = np.nonzero(lab == k)
    stats = sorted([int(areas[i - 1]) for i in keep], reverse=True)
    return np.array([cc.mean() + 1, rr.mean() + 1]), mask, stats           # MATLAB centroids are 1-based
def fit_pixel_to_base(UV, XY):
    UV = np.asarray(UV, float); XY = np.asarray(XY, float); n = len(UV)
    assert len(XY) == n and n >= 3
    M = np.c_[UV, np.ones(n)]; A = np.linalg.lstsq(M, XY, rcond=None)[0].T
    err = XY - M @ A.T
    return A, np.sqrt((err**2).sum(1)) * 1000, np.sqrt((err**2).sum(1).mean()) * 1000
def pixel_to_base(A, uv): return A @ np.r_[uv, 1]
def pass_word(r): return '(excellent)' if r < 3 else '(acceptable)' if r < 5 else '(POOR)'
class LabError(Exception): pass
# ---- helpers of UR_VisionPick_Lab
def pause(ur, dt): ur.clk.t += dt
def serverIdle(ur): return ur.readMotionStatus().lower() != 'executing'
def waitForArrival(ur, readFcn, target, idx, tol):
    maxWait = 60; t0 = ur.clk.t; prev = readFcn()
    while ur.clk.t - t0 < maxWait:
        pause(ur, 0.2); cur = readFcn()
        arrived = np.max(np.abs(cur[idx] - target[idx])) < tol and np.max(np.abs(cur[idx] - prev[idx])) < tol
        if arrived and serverIdle(ur):
            pause(ur, 0.3); return True
        prev = cur
    return False
def moveToJ(ur, q_deg, endTime):
    q = np.deg2rad(q_deg); ur.sendJointConfigurationAndWait(q, EndTime=endTime)
    if not waitForArrival(ur, ur.readJointConfiguration, q, slice(0, 6), np.deg2rad(0.5)):
        raise LabError('moveFailed: Joint move to [%s] deg did not complete.' % np.round(q_deg, 2))
def poseToJoints(ur, pose, q0):
    T0 = fk(q0); T1 = pose2T(pose)
    n = max(1, int(np.ceil(np.linalg.norm(T1[:3, 3] - T0[:3, 3]) / 0.05)))
    q = np.array(q0, float); rv = rotvec(T0[:3, :3].T @ T1[:3, :3]); ang = np.linalg.norm(rv)
    for k in range(1, n + 1):
        s = k / n; Tk = np.eye(4); Tk[:3, 3] = T0[:3, 3] + s * (T1[:3, 3] - T0[:3, 3])
        if ang > 1e-9:
            a = rv / ang; K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
            Tk[:3, :3] = T0[:3, :3] @ (np.eye(3) + np.sin(s*ang) * K + (1 - np.cos(s*ang)) * K @ K)
        else: Tk[:3, :3] = T1[:3, :3]
        q, err = ik_step(Tk, q)
    if err > 1e-3:
        raise LabError('ikFailed: No joint solution near the current pose for x = %.3f, y = %.3f, z = %.3f (pose error %.2g).' % (pose[3], pose[4], pose[5], err))
    return q
def moveToC(ur, pose, endTime):
    q0 = ur.readJointConfiguration(); q = poseToJoints(ur, pose, q0)
    ur.sendJointConfigurationAndWait(q, EndTime=endTime)
    if not waitForArrival(ur, ur.readCartesianPose, pose, slice(3, 6), 0.002):
        raise LabError('moveFailed: Cartesian move to x = %.3f, y = %.3f, z = %.3f did not complete.' % tuple(pose[3:]))
def waitForGripper(ur):
    t0 = ur.clk.t; started = False
    while ur.clk.t - t0 < 1.0 and not started:
        pause(ur, 0.05); started = not serverIdle(ur)
    t0 = ur.clk.t
    while ur.clk.t - t0 < 10 and not serverIdle(ur): pause(ur, 0.05)
    pause(ur, 0.3)
def grip(ur, action, settle):
    ur.actuateGripper(action); waitForGripper(ur); pause(ur, settle)
def UR_VisionPick_Lab(ur, capture, cfg, answer='yes', out=print, hooks=None):
    """cfg keys as the TASK blocks. Returns dict with stage reached and values."""
    nan = np.isnan; res = dict(stage=0); hooks = hooks or {}
    imaging_pose = np.array(cfg.get('imaging_pose', [np.nan]*6), float)
    UV = np.array(cfg.get('UV', np.full((4, 2), np.nan)), float); XY = np.array(cfg.get('XY', np.full((4, 2), np.nan)), float)
    ref = np.array(cfg.get('ref_pick_pose', [np.nan]*6), float); place = np.array(cfg.get('place_pos', [np.nan]*6), float)
    approach_dz, moveEndTime, gripSettle = 0.10, 5, 0.5
    if nan(imaging_pose).any(): out('imaging_pose not set (TASK 2)'); return res
    moveToJ(ur, imaging_pose, moveEndTime); img = capture(); res.update(stage=1, img=img)
    uv, mask, stats = detect_block(img, cfg['hsvLow'], cfg['hsvHigh'], cfg.get('minAreaPx', 200)); res.update(mask=mask, stats=stats)
    if nan(uv).any(): out('No block detected: tune TASK 3'); return res
    out('Block detected at pixel (%.1f, %.1f).' % tuple(uv)); res.update(stage=2, uv=uv)
    if nan(UV).any() or nan(XY).any(): out('Calibration table not complete (TASK 4)'); return res
    A, r, rms = fit_pixel_to_base(UV, XY); tgt = pixel_to_base(A, uv)
    out('Calibration residuals (mm): %s RMS %.2f %s; predicted X = %.4f Y = %.4f' % (np.round(r, 2), rms, pass_word(rms), tgt[0], tgt[1]))
    res.update(stage=3, tgt=tgt, rms=rms)
    if nan(ref).any() or nan(place).any(): out('ref_pick_pose / place_pos not set (TASK 5)'); return res
    pick = ref.copy(); pick[3:5] = tgt; pre = pick.copy(); pre[5] += approach_dz
    if answer.lower() != 'yes': out('Aborted.'); return res
    t0 = ur.clk.t; steps = []
    def step(name, f):
        ts = ur.clk.t; f(); steps.append((name, ur.clk.t - ts))
        if name in hooks: hooks[name]()
    step('1 approach', lambda: moveToC(ur, pre, moveEndTime)); step('2 down', lambda: moveToC(ur, pick, moveEndTime))
    step('3 grip', lambda: grip(ur, 'grip', gripSettle)); step('4 lift', lambda: moveToC(ur, pre, moveEndTime))
    step('5 place', lambda: moveToJ(ur, place, moveEndTime)); step('6 release', lambda: grip(ur, 'release', gripSettle))
    step('7 imaging', lambda: moveToJ(ur, imaging_pose, moveEndTime))
    res.update(stage=4, steps=steps, cycle=ur.clk.t - t0, pick=pick, pre=pre); return res
def UR_CalibrateCamera(ur, capture, hsvLow, hsvHigh, student, minAreaPx=200, nPlacements=4, out=print):
    """student(event, k, **kw) plays the person: 'place' (before picture), 'check' -> '' or 'r', 'touch' (jogs), 'noblob'."""
    UV = np.full((nPlacements, 2), np.nan); XY = UV.copy(); touch = np.full((nPlacements, 6), np.nan); k = 0; guard = 0
    while k < nPlacements:
        guard += 1
        if guard > 40: raise LabError('calibration loop never finishes (no blob at spot %d)' % (k + 1))
        student('place', k); img = capture()
        uv, mask, stats = detect_block(img, hsvLow, hsvHigh, minAreaPx)
        if np.isnan(uv).any(): student('noblob', k); continue
        if student('check', k, uv=uv, img=img, mask=mask).strip().lower() == 'r': continue
        student('touch', k); p = ur.readCartesianPose()
        UV[k] = uv; XY[k] = p[3:5]; touch[k] = p; k += 1
    A, r, rms = fit_pixel_to_base(UV, XY)
    return dict(UV=UV, XY=XY, ref_pick_pose=touch[0], res=r, rms=rms, touch=touch)
