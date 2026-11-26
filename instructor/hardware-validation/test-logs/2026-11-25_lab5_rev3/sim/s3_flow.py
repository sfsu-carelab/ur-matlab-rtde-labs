import numpy as np
from PIL import Image
from cell import *; from port import *
from s2_mc import SPREAD, RED
np.set_printoptions(precision=3, suppress=True)
IMG = [0.95, -71.2, -33.84, -142.19, 89.36, 180.96]; READY = [0, -80, -80, -110, 90, 0]
SEED = np.deg2rad([10, -125, -95, -50, 90, 180])
def down_q(xy, tipz, yaw=1.7, tilt=None, seed=SEED):
    T = np.eye(4); T[:3, :3] = eul2R([yaw, 0, np.pi]) if tilt is None else tilt; T[:3, 3] = [xy[0], xy[1], tipz + GRIP]
    return ik_step(T, seed)
def path_stats(q0, q1, size, n=200):
    """Along a joint-interpolated move: min tip height above table, sideways travel while the tip is below the cube top."""
    tips = np.array([(lambda T: T[:3, 3] + T[:3, 2] * GRIP)(fk(q0 + s * (q1 - q0))) for s in np.linspace(0, 1, n)])
    hz = tips[:, 2] - Z_TABLE; low = hz < size
    side = np.linalg.norm(tips[low, :2] - tips[0, :2], axis=1).max() if low.any() else 0
    line = tips[0] + np.outer(np.linspace(0, 1, n), tips[-1] - tips[0]); bow = np.linalg.norm(tips - line, axis=1).max()
    return hz.min() * 1000, side * 1000, bow * 1000
class World:
    def __init__(s, size=0.025, slider=1.0, cam=None, rng=None, start=READY):
        s.cam = cam or Camera(); s.rng = rng or np.random.default_rng(3); s.size = size
        s.ur = Robot(start, slider=slider); s.cubes = []; s.events = []
    def boxes(s): return [Box((0, 0), 0.16, 0.074, COL['metal'])] + [Box(c['xy'], s.size, s.size, COL['red'], yaw=c['yaw']) for c in s.cubes if not c.get('held')]
    def capture(s):
        s.ur.clk.t += 1.6
        return render(s.cam, s.boxes(), arm_q=s.ur.q(), rng=s.rng, gripper_open=s.ur.gripper == 'open')
    def on_grip(s):
        T = fk(s.ur.q()); tip = T[:3, 3] + T[:3, 2] * GRIP
        for c in s.cubes:
            e = T[:3, :3].T @ np.r_[c['xy'] - tip[:2], 0]                 # error in the gripper frame; x = closing axis
            d = np.linalg.norm(e[:2]) * 1000; half = s.size * (abs(np.cos(c['yaw'] - 1.7)) + abs(np.sin(c['yaw'] - 1.7))) / 2
            if d < 60:
                ok = abs(e[0]) + half < 0.0425 - 0.003 and abs(e[1]) < 0.012 + s.size / 2 - 0.006
                s.events.append('grip: tip-to-cube %.1f mm (closing axis %.1f, across %.1f), tip %.0f mm above table -> %s' % (d, e[0]*1000, e[1]*1000, (tip[2]-Z_TABLE)*1000, 'GRASPED' if ok else 'MISS/COLLISION'))
                c['held'] = ok
    def on_release(s):
        tip = s.ur.tip()
        for c in s.cubes:
            if c.get('held'): c['held'] = False; c['xy'] = tip[:2].copy(); s.events.append('released at %s, %.0f mm above table' % (np.round(tip[:2], 3), (tip[2] - Z_TABLE) * 1000))
def calibrate(w, spots, tilt_max=3, jog=0.002, out=lambda *a: None):
    from s2_mc import touch
    def student(ev, k, **kw):
        if ev == 'place':
            w.cubes[:] = [dict(xy=np.array(spots[k]), yaw=1.7 if k == 0 else w.rng.uniform(0, 1.5))]
            w.ur.q0 = w.ur.q1 = np.deg2rad(IMG); w.ur.dur = 0          # student jogs out of view
        elif ev == 'touch':
            p = touch(spots[k], w.rng, tilt_max, jog, yaw=1.7 if k == 0 else None)
            q, err = ik_step(pose2T(p), SEED); assert err < 1e-6, err
            w.ur.q0 = w.ur.q1 = q; w.ur.dur = 0
        return ''
    return UR_CalibrateCamera(w.ur, w.capture, *RED, student, out=out)
if __name__ == '__main__':
    quiet = lambda *a: None
    # ---------- A. staged flow of the student, 25% slider
    print('=== A. staged flow (25 mm cube, slider 25%)')
    w = World(slider=0.25); cfg = dict(hsvLow=[0.25, 0.35, 0.25], hsvHigh=[0.45, 1, 1]); w.cubes = [dict(xy=np.array([0.35, -0.05]), yaw=0.3)]
    r = UR_VisionPick_Lab(w.ur, w.capture, cfg); print(' empty cfg -> stage', r['stage'], 'moves', len(w.ur.log))
    cfg['imaging_pose'] = IMG; t = w.ur.clk.t
    r = UR_VisionPick_Lab(w.ur, w.capture, cfg); print(' TASK 2 filled, default green -> stage', r['stage'], 'blobs', len(r['stats']), 'largest', r['stats'][:2], 'uv', np.round(r.get('uv', [np.nan]), 0), '| first move Ready->imaging took %.1f s, NO yes prompt before it' % (w.ur.clk.t - t - 1.6))
    cfg.update(hsvLow=RED[0], hsvHigh=RED[1]); r = UR_VisionPick_Lab(w.ur, w.capture, cfg, out=quiet); print(' red band -> stage', r['stage'], 'blobs', r['stats'])
    cal = calibrate(w, SPREAD); print(' calibration: residuals', np.round(cal['res'], 2), 'RMS %.2f' % cal['rms'], '| touch Z', np.round(cal['touch'][:, 5], 3))
    cfg.update(UV=cal['UV'], XY=cal['XY'])
    # robot is still at the placement-4 touch, fingers around the block
    qt = w.ur.q(); print(' run script straight after the last touch: move touch->imaging: min tip height %.0f mm, sideways travel while tip is below cube top %.0f mm (finger gap to a centred 25 mm cube is 30 mm; 17 mm for 50 mm)' % path_stats(qt, np.deg2rad(IMG), 0.025)[:2])
    for sz in (0.025, 0.05): print('    cube %d mm: sideways while below top = %.0f mm' % (sz*1000, path_stats(qt, np.deg2rad(IMG), sz)[1]))
    cfg['ref_pick_pose'] = cal['ref_pick_pose']
    qp, _ = down_q((0.34, -0.03), Z_TABLE + 0.045); cfg['place_pos'] = np.rad2deg(qp)      # 40 mm above pick height, like 11-04
    w.cubes[:] = [dict(xy=np.array([0.31, 0.10]), yaw=1.7)]
    r = UR_VisionPick_Lab(w.ur, w.capture, cfg, answer='no', out=quiet); print(' answer no -> stage', r['stage'], 'robot moves so far', len(w.ur.log))
    # ---------- B. five picks, each slider
    for slider in (0.10, 0.25, 0.50, 1.00):
        w.ur.slider = slider; rng = np.random.default_rng(11); cyc = []; st = None; w.events.clear()
        for i in range(5):
            w.cubes[:] = [dict(xy=np.array([rng.uniform(0.24, 0.42), rng.uniform(-0.22, 0.16)]), yaw=1.7 + rng.uniform(-0.2, 0.2))]
            r = UR_VisionPick_Lab(w.ur, w.capture, cfg, out=quiet, hooks={'3 grip': w.on_grip, '6 release': w.on_release})
            cyc.append(r['cycle']); st = r['steps']
        print('=== B. slider %3.0f%%: cycle %.1f s (range %.1f-%.1f); steps %s; dropped cmds %d' % (slider*100, np.mean(cyc), min(cyc), max(cyc), ' '.join('%s=%.1f' % (n.split()[1], d) for n, d in st), len(w.ur.dropped)))
        if slider == 0.25:
            for e in w.events: print('   ', e)
    for slider in (0.08, 0.07, 0.05):
        w2 = World(slider=slider, start=READY)
        try: moveToJ(w2.ur, IMG, 5); print('=== slider %.0f%%: imaging move ok in %.0f s' % (slider*100, w2.ur.clk.t))
        except LabError as e: print('=== slider %.0f%%: script error at t=%.0f s (%s) while the robot keeps moving for another %.0f s' % (slider*100, w2.ur.clk.t, str(e)[:10], w2.ur.t0 + w2.ur.dur - w2.ur.clk.t))
    # ---------- C. joint-interpolated path checks around a pick
    print('=== C. path geometry of the pick moves (25 picks over the area)')
    rng = np.random.default_rng(5); rows = []
    for i in range(25):
        xy = [rng.uniform(0.22, 0.44), rng.uniform(-0.25, 0.18)]
        pick = np.r_[cal['ref_pick_pose'][:3], xy, cal['ref_pick_pose'][5]]; pre = pick.copy(); pre[5] += 0.10
        w.ur.q0 = w.ur.q1 = np.deg2rad(IMG); w.ur.dur = 0
        q1 = poseToJoints(w.ur, pre, np.deg2rad(IMG)); q2 = poseToJoints(w.ur, pick, q1)
        a = path_stats(np.deg2rad(IMG), q1, 0.025); b = path_stats(q1, q2, 0.025); c = path_stats(q2, q1, 0.025); d = path_stats(q1, qp, 0.025)
        rows.append([a[0], b[2], b[0], d[0], np.abs(np.rad2deg(q1 - np.deg2rad(IMG))).max()])
    rows = np.array(rows); print('   approach: min tip height %.0f mm; largest joint travel imaging->approach %.0f deg (max over picks)' % (rows[:, 0].min(), rows[:, 4].max()))
    print('   descent bow sideways: med %.1f max %.1f mm; min tip height in descent %.1f mm (target 5 mm)' % (np.median(rows[:, 1]), rows[:, 1].max(), rows[:, 2].min()))
    print('   lift->place(40 mm above pick height): min tip height %.0f mm' % rows[:, 3].min())
    # ---------- D. place_pos at table height
    qlow, _ = down_q((0.34, -0.03), Z_TABLE + 0.005); mins = []; sides = []
    for i in range(25):
        xy = [rng.uniform(0.22, 0.44), rng.uniform(-0.25, 0.18)]
        pre = np.r_[cal['ref_pick_pose'][:3], xy, cal['ref_pick_pose'][5] + 0.10]; q1 = poseToJoints(w.ur, pre, np.deg2rad(IMG))
        mins.append(path_stats(q1, qlow, 0.025)[0])
    out_ = path_stats(qlow, np.deg2rad(IMG), 0.025)
    print('=== D. place_pos taught AT pick height: lift->place min tip height over 25 picks: %.1f..%.1f mm (5 = taught; cube bottom is 5 mm lower, so <5 presses the cube into the table)' % (min(mins), max(mins)))
    print('   place->imaging with open fingers: sideways travel while below cube top: %.0f mm (25 mm cube), %.0f mm (50 mm cube)' % (out_[1], path_stats(qlow, np.deg2rad(IMG), 0.05)[1]))
    out40 = path_stats(qp, np.deg2rad(IMG), 0.025); print('   place 40 mm above pick height -> imaging: sideways travel while below 25 mm cube top: %.0f mm; 50 mm cube top: %.0f mm' % (out40[1], path_stats(qp, np.deg2rad(IMG), 0.05)[1]))
    # ---------- E. reach
    print('=== E. block farther and farther out along the 30 deg ray')
    for rad in (0.46, 0.50, 0.53, 0.56, 0.60, 0.70):
        w3 = World(slider=1.0, start=IMG); w3.cubes = [dict(xy=np.array([rad*np.cos(-0.3), rad*np.sin(-0.3)]), yaw=1.7)]; A_ = fit_pixel_to_base(cal['UV'], cal['XY'])[0]
        try:
            r = UR_VisionPick_Lab(w3.ur, w3.capture, cfg, out=quiet, hooks={'3 grip': w3.on_grip}); msg = 'completed; ' + (w3.events[0] if w3.events else 'nothing gripped')
            el = np.rad2deg(w3.ur.log[2][2][2]); msg += ' | elbow at pick %.0f deg' % el
        except LabError as e: msg = 'ERROR after %d robot moves: %s' % (len(w3.ur.log) - 1, str(e)[:95])
        except KeyError: msg = 'no detection (out of view)'
        print('   r = %.2f m: %s' % (rad, msg))
    # ---------- F. block left at the drop-off, script run again; two blocks; stray
    print('=== F. repeat runs')
    w.ur.slider = 1.0; w.events.clear(); w.cubes[:] = [dict(xy=np.array([0.30, 0.05]), yaw=1.7)]
    r1 = UR_VisionPick_Lab(w.ur, w.capture, cfg, out=quiet, hooks={'3 grip': w.on_grip, '6 release': w.on_release})
    r2 = UR_VisionPick_Lab(w.ur, w.capture, cfg, out=quiet, hooks={'3 grip': w.on_grip, '6 release': w.on_release})
    print('   run 2 without moving the block: detects it at the drop-off, predicted XY', np.round(r2['tgt'], 3)); [print('   ', e) for e in w.events]
    w.events.clear(); w.cubes.append(dict(xy=np.array([0.28, -0.15]), yaw=1.7))
    r3 = UR_VisionPick_Lab(w.ur, w.capture, cfg, answer='no', out=quiet); print('   two same-colour blocks in view: blob areas', r3['stats'], '-> target', np.round(r3['tgt'], 3), '(blocks at', [list(np.round(c['xy'], 2)) for c in w.cubes], ')')
    # ---------- G. yaw of the block relative to placement 1
    print('=== G. block yaw vs centroid and grasp (cube at 0.35,-0.10)')
    for size in (0.025, 0.05):
        for dyaw in (0, 15, 30, 45):
            w4 = World(size=size, start=IMG); w4.cubes = [dict(xy=np.array([0.35, -0.10]), yaw=1.7 + np.deg2rad(dyaw))]
            r = UR_VisionPick_Lab(w4.ur, w4.capture, cfg, out=quiet, hooks={'3 grip': w4.on_grip})
            print('   %2.0f mm cube, yaw %2d deg: %s' % (size*1000, dyaw, w4.events[0] if w4.events else 'no grip event'))
    # ---------- H. arm in the calibration picture
    print('=== H. arm left above the block for the calibration picture (retract height vs centroid shift, px)')
    for spot in ((0.25, -0.24), (0.42, 0.17), (0.34, -0.03)):
        w5 = World(start=IMG); w5.cubes = [dict(xy=np.array(spot), yaw=1.7)]; uv0 = detect_block(w5.capture(), *RED)[0]; s = []
        for hgt in (0.0, 0.05, 0.10, 0.20):
            q, _ = down_q(spot, Z_TABLE + 0.005 + hgt); w5.ur.q0 = w5.ur.q1 = q; uv = detect_block(w5.capture(), *RED)[0]; s.append('%+.0f cm: %s' % (hgt*100, 'no blob' if np.isnan(uv).any() else '%.1f' % np.linalg.norm(uv - uv0)))
        print('   spot', spot, ' | '.join(s))
